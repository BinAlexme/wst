Clear-Host
# Выполнена настрока сохранения пути,виде файла .json. создается при переносе содержимого данных. 
function Get-SettingsFilePath {
    if ($PSScriptRoot -and (Test-Path $PSScriptRoot -PathType Container)) {
        return (Join-Path $PSScriptRoot "Settings.json")
    }

    $settingsFolder = Join-Path $env:APPDATA "wstset"

    if (-not (Test-Path $settingsFolder -PathType Container)) {
        New-Item -Path $settingsFolder -ItemType Directory -Force | Out-Null
    }

    return (Join-Path $settingsFolder "Settings.json")
}

$settingsFilePath = Get-SettingsFilePath

function Get-SavedUserdataDestination {
    param(
        [string]$SettingsPath
    )

    if (-not (Test-Path $SettingsPath -PathType Leaf)) {
        return $null
    }

    try {
        $settings = Get-Content -LiteralPath $SettingsPath -Raw -ErrorAction Stop |
            ConvertFrom-Json -ErrorAction Stop

        if ($settings.UserdataDestination) {
            return [string]$settings.UserdataDestination
        }
    }
    catch {
        Write-Host "Не удалось прочитать файл настроек: $SettingsPath" -ForegroundColor DarkYellow
    }

    return $null
}

function Save-UserdataDestination {
    param(
        [string]$DestinationPath,
        [string]$SettingsPath
    )

    try {
        $settingsFolder = Split-Path -Path $SettingsPath -Parent

        if (-not (Test-Path $settingsFolder -PathType Container)) {
            New-Item -Path $settingsFolder -ItemType Directory -Force | Out-Null
        }

        [PSCustomObject]@{
            UserdataDestination = $DestinationPath
        } |
            ConvertTo-Json |
            Set-Content -LiteralPath $SettingsPath -Encoding UTF8

        Write-Host "Базовый путь сохранён: $DestinationPath" -ForegroundColor DarkGray
    }
    catch {
        Write-Host "Не удалось сохранить путь в настройках." -ForegroundColor DarkYellow
        Write-Host $_.Exception.Message -ForegroundColor DarkGray
    }
}

function Get-UserdataDestinationPath {
    param(
        [string]$SettingsPath
    )

    $savedDestination = Get-SavedUserdataDestination -SettingsPath $SettingsPath

    # При сохраненном пути спрашивает, использовать ли его.
    if (-not [string]::IsNullOrWhiteSpace($savedDestination)) {
        Write-Host "`nСохранённый базовый путь:" -ForegroundColor Cyan
        Write-Host $savedDestination -ForegroundColor White

        $useSavedPath = Read-Host "Использовать сохранённый путь? (y/n)"

        if ($useSavedPath -match '^(да|y|yes)$') {
            return $savedDestination
        }
    }
    else {
        Write-Host "`nСохранённый путь для переноса userdata не найден." -ForegroundColor Yellow
    }

    # Если пользователь отказался от сущеструвующего пути. Будет предложен другой вариант сохранения.
    do {
        $newDestination = Read-Host "Введите БАЗОВЫЙ путь для переноса"

        if ([string]::IsNullOrWhiteSpace($newDestination)) {
            Write-Host "Путь не может быть пустым." -ForegroundColor Red
            continue
        }

        $newDestination = $newDestination.Trim().Trim('"')

        try {
            $newDestination = [System.IO.Path]::GetFullPath($newDestination)
        }
        catch {
            Write-Host "Указан некорректный путь." -ForegroundColor Red
            $newDestination = $null
        }
    }
    while ([string]::IsNullOrWhiteSpace($newDestination))

    Save-UserdataDestination `
        -DestinationPath $newDestination `
        -SettingsPath $SettingsPath

    return $newDestination
}

function Get-AllDrives {
    Get-PSDrive -PSProvider FileSystem |
        Select-Object -ExpandProperty Root
}

function Find-SteamUserdata-Quiet {
    $allDrives = Get-AllDrives

    foreach ($drive in $allDrives) {
        $steamFolder = Get-ChildItem `
            -Path $drive `
            -Directory `
            -Force `
            -Recurse `
            -Depth 3 `
            -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name -eq "Steam" -or $_.Name -eq "steam"
            } |
            Select-Object -First 1

        if ($steamFolder) {
            $userdataPath = Join-Path $steamFolder.FullName "userdata"

            if (Test-Path $userdataPath -PathType Container) {
                return $userdataPath
            }
        }
    }

    return $null
}

# Чистка содержимых файлов
function Clear-FolderContent {
    param(
        [string]$FolderPath,
        [string]$ProgressTitle = "Удаление файлов"
    )

    if (-not (Test-Path $FolderPath -PathType Container)) {
        return
    }

    $items = @(Get-ChildItem -LiteralPath $FolderPath -Force)

    if ($items.Count -eq 0) {
        return
    }

    $shell = New-Object -ComObject Shell.Application
    $parent = $shell.Namespace($FolderPath)

    $itemCount = $items.Count
    $itemCurrent = 0

    foreach ($item in $items) {
        $itemCurrent++

        Write-Progress `
            -Activity $ProgressTitle `
            -Status "Удаление $itemCurrent из $itemCount" `
            -CurrentOperation $item.Name `
            -PercentComplete (($itemCurrent / $itemCount) * 100)

        $shellItem = $parent.ParseName($item.Name)

        if ($shellItem) {
            $shellItem.InvokeVerb("delete")
        }
    }

    Write-Progress -Activity $ProgressTitle -Completed
}


# Перенос userdata
function Move-UserdataContent {
    param(
        [string]$UserdataSource,
        [string]$BaseDestination,

        # Если включён — это пункт 3, будет папка с датой.
        [switch]$CreateDateFolder
    )

    if (-not $UserdataSource -or -not (Test-Path $UserdataSource -PathType Container)) {
        Write-Host "Папка userdata не найдена. Перенос пропущен." -ForegroundColor DarkYellow
        return $false
    }

    try {
        $sourceFullPath = (
            Resolve-Path -LiteralPath $UserdataSource -ErrorAction Stop
        ).Path.TrimEnd("\")

        $baseDestinationPath = (
            [System.IO.Path]::GetFullPath($BaseDestination)
        ).TrimEnd("\")
    }
    catch {
        Write-Host "Не удалось определить корректный путь источника или назначения." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor DarkGray
        return $false
    }

    # Здесь заданные примеры прошлых версий
    # T:\210926
    # T:\userdatawst
    if ($CreateDateFolder) {
        $dateName = Get-Date -Format "ddMMyy"
        $destinationFullPath = Join-Path $baseDestinationPath $dateName
    }
    else {
        $destinationFullPath = Join-Path $baseDestinationPath "userdatawst"
    }

    $destinationFullPath = $destinationFullPath.TrimEnd("\")

    # Нельзя переносить папку userdata в тоже место.
    if ($sourceFullPath -eq $destinationFullPath) {
        Write-Host "Папка назначения совпадает с исходной папкой userdata." -ForegroundColor Red
        Write-Host "Перенос отменён." -ForegroundColor Yellow
        return $false
    }

    # Защита от создания папки внутри userdata.
    if ($destinationFullPath.StartsWith(
        $sourceFullPath + "\",
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        Write-Host "Папка назначения находится внутри userdata." -ForegroundColor Red
        Write-Host "Выберите путь вне папки userdata." -ForegroundColor Yellow
        return $false
    }

    $content = @(Get-ChildItem -LiteralPath $UserdataSource -Force)

    if ($content.Count -eq 0) {
        Write-Host "Папка userdata пуста. Переносить нечего." -ForegroundColor DarkGray
        return $false
    }

    # Создаёт базовую папку и userdatawst/дату автоматически.
    if (-not (Test-Path $destinationFullPath -PathType Container)) {
        try {
            New-Item `
                -Path $destinationFullPath `
                -ItemType Directory `
                -Force `
                -ErrorAction Stop | Out-Null

            Write-Host "Создана папка назначения: $destinationFullPath" -ForegroundColor Gray
        }
        catch {
            Write-Host "Не удалось создать папку назначения: $destinationFullPath" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor DarkGray
            return $false
        }
    }
    else {
        Write-Host "Используется папка назначения: $destinationFullPath" -ForegroundColor Cyan
    }

    $totalItems = $content.Count
    $currentItem = 0
    $movedAny = $false

    foreach ($item in $content) {
        $currentItem++

        Write-Progress `
            -Activity "Перемещение userdata" `
            -Status "Перемещение $currentItem из $totalItems" `
            -CurrentOperation $item.Name `
            -PercentComplete (($currentItem / $totalItems) * 100)

        try {
            Move-Item `
                -LiteralPath $item.FullName `
                -Destination $destinationFullPath `
                -ErrorAction Stop

            $movedAny = $true
        }
        catch {
            Write-Host "Не удалось переместить: $($item.Name)" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor DarkGray
        }
    }

    Write-Progress -Activity "Перемещение userdata" -Completed

    if ($movedAny) {
        Write-Host "Данные перенесены в: $destinationFullPath" -ForegroundColor Green
    }

    return $movedAny
}

function Process-StandardCleanup {
    param(
        [switch]$CreateDateFolder
    )

    # Очистка служебных папок Steam
    $total = $folders.Count
    $current = 0

    foreach ($folder in $folders) {
        $current++

        Write-Progress `
            -Activity "Удаление файлов" `
            -Status "Обработка папки $current из $total" `
            -CurrentOperation $folder `
            -PercentComplete (($current / [Math]::Max($total, 1)) * 100)

        Clear-FolderContent -FolderPath $folder
    }

    Write-Progress -Activity "Удаление файлов" -Completed

    # Отдельное подтверждение очистки userdata
    foreach ($folder in $confirmFolders) {
        if ($folder -and (Test-Path $folder -PathType Container)) {
            $answer = Read-Host "`nОчистить папку '$folder'? (y/n)"

            if ($answer -match '^(да|y|yes)$') {
                Clear-FolderContent `
                    -FolderPath $folder `
                    -ProgressTitle "Очистка подтвержденной папки"
            }
        }
    }

    Write-Host "`nПеремещение userdata..." -ForegroundColor Yellow

    # Пользователь выбирает путь, либо подтверждает сохраненный.
    $baseDestination = Get-UserdataDestinationPath `
        -SettingsPath $settingsFilePath
		
    $moved = Move-UserdataContent `
        -UserdataSource $userdataPath `
        -BaseDestination $baseDestination `
        -CreateDateFolder:$CreateDateFolder

    if ($moved -and $CreateDateFolder) {
        $dateName = Get-Date -Format "ddMMyy"
        $finalDateFolder = Join-Path $baseDestination $dateName

        Write-Host "`nРежим 3 завершён." -ForegroundColor Green
        Write-Host "Общая папка данных за $dateName :" -ForegroundColor Green
        Write-Host $finalDateFolder -ForegroundColor Cyan
    }

    Write-Host "`nГотово!" -ForegroundColor Green
}


# Пошел процесc
$userdataPath = Find-SteamUserdata-Quiet

if ($userdataPath -and (Test-Path $userdataPath -PathType Container)) {
    $userdataItems = @(Get-ChildItem -LiteralPath $userdataPath -Force)

    if ($userdataItems.Count -eq 0) {
        Write-Host "Папка userdata пустая." -ForegroundColor DarkGray
    }
    else {
        Write-Host "Содержимое папки: $userdataPath`n" -ForegroundColor Cyan

        foreach ($item in $userdataItems) {
            $type = if ($item.PSIsContainer) {
                "[DIR] "
            }
            else {
                "      "
            }

            Write-Host "$type$($item.Name)" -ForegroundColor White
        }
    }

    $continue = Read-Host "`nПродолжить выполнение скрипта? (y/n)"

    if ($continue -notmatch '^(да|y|yes)$') {
        Write-Host "Работа скрипта отменена пользователем." -ForegroundColor Yellow
        return
    }
}
else {
    Write-Host "Папка userdata не найдена автоматически." -ForegroundColor DarkYellow
    $continue = Read-Host "Продолжить выполнение скрипта без проверки userdata? (y/n)"

    if ($continue -notmatch '^(да|y|yes)$') {
        Write-Host "Работа скрипта отменена пользователем." -ForegroundColor Yellow
        return
    }
}

Write-Host "`nВыберите действие:"
Write-Host "1 - Содержимое папки"
Write-Host "2 - Содержимое папки + перенос"
Write-Host "3 - Содержимое папки + перенос + переименовать в дату"
$choice = Read-Host "Введите цифру"

# Если userdata найдена — Steam находится на уровень выше.
$steamBasePath = if ($userdataPath) {
    Split-Path $userdataPath -Parent
}
else {
    $null
}

# Запасной поиск Steam, если userdata найти не удалось.
if (-not $steamBasePath) {
    $allDrives = Get-AllDrives

    foreach ($drive in $allDrives) {
        $steamFolder = Get-ChildItem `
            -Path $drive `
            -Directory `
            -Force `
            -Recurse `
            -Depth 3 `
            -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name -eq "Steam" -or $_.Name -eq "steam"
            } |
            Select-Object -First 1

        if ($steamFolder) {
            $steamBasePath = $steamFolder.FullName
            break
        }
    }
}

if (-not $steamBasePath -or -not (Test-Path $steamBasePath -PathType Container)) {
    Write-Host "Папка Steam не найдена. Невозможно определить папки для очистки." -ForegroundColor Red
    return
}

Write-Host "`nНайдена папка Steam: $steamBasePath" -ForegroundColor Green

$cleanupFolderNames = @(
    "appcache",
    "config",
    "depotcache",
    "dumps",
    "friends",
    "logs"
)

$folders = @()

foreach ($name in $cleanupFolderNames) {
    $path = Join-Path $steamBasePath $name

    if (Test-Path $path -PathType Container) {
        $folders += $path
        Write-Host "Найдена папка для очистки: $path" -ForegroundColor Gray
    }
    else {
        Write-Host "Папка не найдена (пропуск): $path" -ForegroundColor DarkGray
    }
}

$confirmFolders = @(
    $userdataPath
)

switch ($choice) {
    "1" {
        $total = $folders.Count
        $current = 0

        foreach ($folder in $folders) {
            $current++

            Write-Progress `
                -Activity "Удаление файлов" `
                -Status "Обработка папки $current из $total" `
                -CurrentOperation $folder `
                -PercentComplete (($current / [Math]::Max($total, 1)) * 100)

            Clear-FolderContent -FolderPath $folder
        }

        Write-Progress -Activity "Удаление файлов" -Completed
        Write-Host "`nГотово!" -ForegroundColor Green
    }

    "2" {
        Process-StandardCleanup
    }

    "3" {
        Process-StandardCleanup -CreateDateFolder
    }

    default {
        Write-Host "Неверный выбор." -ForegroundColor Red
    }
}
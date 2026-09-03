Clear-Host

# Доступ ко всем дискам системы
function Get-AllDrives {
    Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Root
}

# Поиск userdata в папке steam
function Find-SteamUserdata-Quiet {
    $allDrives = Get-AllDrives

    foreach ($drive in $allDrives) {
        # Ищем папку steam (алгоритм рекурсивный)
        $steamFolder = Get-ChildItem -Path $drive -Directory -Force -Recurse -Depth 3 -ErrorAction SilentlyContinue | 
            Where-Object { $_.Name -eq "Steam" -or $_.Name -eq "steam" } |
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

# Поиск папки userdata
$userdataPath = Find-SteamUserdata-Quiet

# Проверка userdata
if ($userdataPath -and (Test-Path $userdataPath -PathType Container)) {
    $userdataItems = Get-ChildItem -LiteralPath $userdataPath -Force

    if ($userdataItems.Count -eq 0) {
        Write-Host "Папка userdata пустая." -ForegroundColor DarkGray
    }
    else {
        Write-Host "Содержимое папки: $userdataPath`n" -ForegroundColor Cyan
        foreach ($item in $userdataItems) {
            $type = if ($item.PSIsContainer) { "[DIR] " } else { "      " }
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

Write-Host "Выберите действие:"
Write-Host "1 - Содержимое папки"
Write-Host "2 - Содержимое папки + перенос"
Write-Host "3 - Содержимое папки + перенос + переименовать в дату"
$choice = Read-Host "Введите цифру"

# Путь к Steam (будет найден автоматически через userdata)
$steamBasePath = if ($userdataPath) { Split-Path $userdataPath -Parent } else { $null }

# Проверка еще раз
if (-not $steamBasePath) {
    $allDrives = Get-AllDrives
    foreach ($drive in $allDrives) {
        $steamFolder = Get-ChildItem -Path $drive -Directory -Force -Recurse -Depth 3 -ErrorAction SilentlyContinue | 
            Where-Object { $_.Name -eq "Steam" -or $_.Name -eq "steam" } |
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

# Папки для очистки, которые лежат в Steam
$cleanupFolderNames = @(
    "appcache",
    "config",
    "depotcache",
    "dumps",
    "friends",
    "logs"
)

# Автоматически находит эти папки внутри Steam
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

function Clear-FolderContent {
    param(
        [string]$FolderPath,
        [string]$ProgressTitle = "Удаление файлов"
    )

    if (Test-Path $FolderPath -PathType Container) {
        $items = Get-ChildItem -LiteralPath $FolderPath -Force
        if ($items.Count -eq 0) {
            return
        }

        $shell = New-Object -ComObject Shell.Application
        $parent = $shell.Namespace($FolderPath)

        $itemCount = $items.Count
        $itemCurrent = 0

        foreach ($item in $items) {
            $itemCurrent++
            Write-Progress -Activity $ProgressTitle -Status "Удаление $itemCurrent из $itemCount" -CurrentOperation $item.Name -PercentComplete (($itemCurrent / $itemCount) * 100)

            $shellItem = $parent.ParseName($item.Name)
            if ($shellItem) {
                $shellItem.InvokeVerb("delete")
            }
        }
    }
}

function Process-StandardCleanup {
    param(
        [switch]$RenameUserdataFolder
    )

    $total = $folders.Count
    $current = 0

    foreach ($folder in $folders) {
        $current++
        Write-Progress -Activity "Удаление файлов" -Status "Обработка папки $current из $total" -CurrentOperation $folder -PercentComplete (($current / $total) * 100)
        Clear-FolderContent -FolderPath $folder
    }

    foreach ($folder in $confirmFolders) {
        if ($folder -and (Test-Path $folder -PathType Container)) {
            $answer = Read-Host "`nОчистить папку '$folder'? (y/n)"
            if ($answer -match '^(да|y|yes)$') {
                Clear-FolderContent -FolderPath $folder -ProgressTitle "Очистка подтвержденной папки"
            }
        }
    }

    Write-Host "`nПеремещение userdata..." -ForegroundColor Yellow
    $userdataSource = $userdataPath
    $userdataDestination = "T:\userdatawst"

    if ($userdataSource -and (Test-Path $userdataSource -PathType Container)) {
        $content = Get-ChildItem -LiteralPath $userdataSource -Force
        if ($content.Count -gt 0) {
            if (-not (Test-Path $userdataDestination -PathType Container)) {
                New-Item -Path $userdataDestination -ItemType Directory | Out-Null
            }

            $totalItems = $content.Count
            $currentItem = 0
            foreach ($item in $content) {
                $currentItem++
                Write-Progress -Activity "Перемещение userdata" -Status "Перемещение $currentItem из $totalItems" -CurrentOperation $item.Name -PercentComplete (($currentItem / $totalItems) * 100)
                Move-Item -LiteralPath $item.FullName -Destination $userdataDestination
            }
        }
    }

    Write-Progress -Activity "Перемещение userdata" -Completed

    if ($RenameUserdataFolder -and $userdataDestination -and (Test-Path $userdataDestination -PathType Container)) {
        $dateName = Get-Date -Format "ddMMyy"
        $parentPath = Split-Path -Path $userdataDestination -Parent
        $newFolderPath = Join-Path $parentPath $dateName

        if (Test-Path $newFolderPath -PathType Container) {
            Write-Host "Папка $newFolderPath уже существует." -ForegroundColor DarkYellow
        }
        else {
            Rename-Item -Path $userdataDestination -NewName $dateName
            Write-Host "Папка переименована в: $dateName" -ForegroundColor Green
        }
    }

    Write-Host "`nГотово!" -ForegroundColor Green
}

switch ($choice) {
    "1" {
        $total = $folders.Count
        $current = 0

        foreach ($folder in $folders) {
            $current++
            Write-Progress -Activity "Удаление файлов" -Status "Обработка папки $current из $total" -CurrentOperation $folder -PercentComplete (($current / $total) * 100)
            Clear-FolderContent -FolderPath $folder
        }

        Write-Progress -Activity "Удаление файлов" -Completed
        Write-Host "`nГотово!" -ForegroundColor Green
    }

    "2" {
        Process-StandardCleanup
    }

    "3" {
        Process-StandardCleanup -RenameUserdataFolder
    }

    default {
        Write-Host "Неверный выбор."
    }
}
Clear-Host
Write-Host "Выберите действие:"
Write-Host "1 - Содержимое папки"
Write-Host "2 - Содержимое папки + перенос"
Write-Host "3 - Содержимое папки + перенос + переменовать в дату"
$choice = Read-Host "Введите цифру"

$folders = @( # <--- тут впишите свои источники которые должны будут стираться без подтверждений
    "V:\Program Files (x86)\Steam\appcache",
    "V:\Program Files (x86)\Steam\config",
    "V:\Program Files (x86)\Steam\depotcache",
    "V:\Program Files (x86)\Steam\dumps",
    "V:\Program Files (x86)\Steam\friends",
    "V:\Program Files (x86)\Steam\logs"
)

$confirmFolders = @(
    "V:\Program Files (x86)\Steam\userdata" # <--- тут свой путь к профилю
)

function Clear-FolderContent {
    param(
        [string]$FolderPath,
        [string]$ProgressTitle = "Удаление файлов"
    )

    if (Test-Path $FolderPath -PathType Container) {
        Write-Host "`nУдаление содержимого: $FolderPath" -ForegroundColor Yellow

        $items = Get-ChildItem -LiteralPath $FolderPath -Force
        if ($items.Count -eq 0) {
            Write-Host "Папка пустая." -ForegroundColor DarkGray
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
        if (Test-Path $folder -PathType Container) {
            $answer = Read-Host "`nОчистить папку '$folder'? (y/n)"
            if ($answer -match '^(да|y|yes)$') {
                Clear-FolderContent -FolderPath $folder -ProgressTitle "Очистка подтвержденной папки"
            }
            else {
                Write-Host "Пропуск: $folder" -ForegroundColor DarkGray
            }
        }
    }

    Write-Host "`nПеремещение userdata..." -ForegroundColor Yellow
    $userdataSource = "V:\Program Files (x86)\Steam\userdata"
    $userdataDestination = "T:\userdatawst"

    if (Test-Path $userdataSource -PathType Container) {
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

    if ($RenameUserdataFolder) {
        $dateName = Get-Date -Format "ddMMyy"
        $parentPath = Split-Path -Path $userdataDestination -Parent
        $newFolderPath = Join-Path $parentPath $dateName

        if (Test-Path $userdataDestination -PathType Container) {
            if (Test-Path $newFolderPath -PathType Container) {
                Write-Host "Папка $newFolderPath уже существует." -ForegroundColor DarkYellow
            }
            else {
                Rename-Item -Path $userdataDestination -NewName $dateName
                Write-Host "Папка переименована в: $dateName" -ForegroundColor Green
            }
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
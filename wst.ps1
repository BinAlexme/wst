Clear-Host
Write-Host "Выберите действие:"
Write-Host "1 - Содержимое папок"
Write-Host "2 - Содержимое папок + проверка userdata"
$choice = Read-Host "Введите 1 или 2"

switch ($choice) {
    "1" {
        $folders = @(
            "V:\Program Files (x86)\Steam\appcache",
            "V:\Program Files (x86)\Steam\config",
            "V:\Program Files (x86)\Steam\depotcache",
            "V:\Program Files (x86)\Steam\dumps",
            "V:\Program Files (x86)\Steam\friends",
            "V:\Program Files (x86)\Steam\logs"
        )

        $shell = New-Object -ComObject Shell.Application
        $total = $folders.Count
        $current = 0

        foreach ($folder in $folders) {
            $current++
            Write-Progress -Activity "Удаление файлов" -Status "Обработка папки $current из $total" -CurrentOperation $folder -PercentComplete (($current / $total) * 100)

            if (Test-Path $folder -PathType Container) {
                Write-Host "`nУдаление содержимого: $folder" -ForegroundColor Yellow
                
                $items = Get-ChildItem -LiteralPath $folder -Force
                $itemCount = $items.Count
                $itemCurrent = 0

                foreach ($item in $items) {
                    $itemCurrent++
                    Write-Progress -Activity "Удаление файлов" -Status "Удаление $itemCurrent из $itemCount" -CurrentOperation $item.Name -PercentComplete (($itemCurrent / $itemCount) * 100)
                    
                    $parent = $shell.Namespace($folder)
                    $shellItem = $parent.ParseName($item.Name)
                    if ($shellItem) {
                        $shellItem.InvokeVerb("delete")
                    }
                }
            }
        }
        Write-Progress -Activity "Удаление файлов" -Completed
        Write-Host "`nГотово!" -ForegroundColor Green
    }

    "2" {
        
        $folders = @(
            "V:\Program Files (x86)\Steam\appcache",
            "V:\Program Files (x86)\Steam\config",
            "V:\Program Files (x86)\Steam\depotcache",
            "V:\Program Files (x86)\Steam\dumps",
            "V:\Program Files (x86)\Steam\friends",
            "V:\Program Files (x86)\Steam\logs"
        )

        $shell = New-Object -ComObject Shell.Application
        $total = $folders.Count
        $current = 0

        foreach ($folder in $folders) {
            $current++
            Write-Progress -Activity "Удаление файлов" -Status "Обработка папки $current из $total" -CurrentOperation $folder -PercentComplete (($current / $total) * 100)

            if (Test-Path $folder -PathType Container) {
                Write-Host "`nУдаление содержимого: $folder" -ForegroundColor Yellow
                
                $items = Get-ChildItem -LiteralPath $folder -Force
                $itemCount = $items.Count
                $itemCurrent = 0

                foreach ($item in $items) {
                    $itemCurrent++
                    Write-Progress -Activity "Удаление файлов" -Status "Удаление $itemCurrent из $itemCount" -CurrentOperation $item.Name -PercentComplete (($itemCurrent / $itemCount) * 100)
                    
                    $parent = $shell.Namespace($folder)
                    $shellItem = $parent.ParseName($item.Name)
                    if ($shellItem) {
                        $shellItem.InvokeVerb("delete")
                    }
                }
            }
        }

        Write-Host "`nПеремещение userdata..." -ForegroundColor Yellow
        $userdataSource = "T:\userdata"
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
        Write-Host "`nГотово!" -ForegroundColor Green
    }

    default {
        Write-Host "Неверный выбор."
    }
}
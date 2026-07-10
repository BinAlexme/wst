# wst

### безлопастная чистка данных профиля стим
1. Основное требование, прописать пути, а то УДАЛИТ ВСЕ!!!
в каждом из пунктов, прописываете, один раз.

```PowerShell
$folders = @(
            "V:\Program Files (x86)\Steam\appcache",
            "V:\Program Files (x86)\Steam\config",
            "V:\Program Files (x86)\Steam\depotcache",
            "V:\Program Files (x86)\Steam\dumps",
            "V:\Program Files (x86)\Steam\friends",
            "V:\Program Files (x86)\Steam\logs"
```
2.Папка `userdata` как пример -> второй пункт

Здесь прописываете путь к первой папке `userdata` - или другой папке что нужно перекинуть.

Второй пусть к папке куда перемещать данные. 
```PowerShell
        $userdataSource = "T:\userdata"
        $userdataDestination = "T:\userdatawst"
```
3. Запуск
![start](https://github.com/BinAlexme/wst/blob/master/C6EOkujbnb.gif?raw=true)

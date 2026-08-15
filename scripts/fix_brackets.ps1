$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$f = "E:\Games\mod\src\main\java\com\example\shinobicore\ShinobiCore.java"
$c = [System.IO.File]::ReadAllText($f, $utf8)

# Удаляем мусорные последовательности скобок, оставшиеся от прошлого скрипта
$c = $c.Replace("});});});}", "}")
$c = $c.Replace("});});}", "}")
$c = $c.Replace("});}", "}")

[System.IO.File]::WriteAllText($f, $c, $utf8)
Write-Host "[OK] ShinobiCore.java очищен от лишних скобок!" -ForegroundColor Green
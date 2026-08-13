$utf8 = New-Object System.Text.UTF8Encoding($false)
$file = "E:\Games\mod\src\main\java\com\example\shinobicore\event\NinjaTickHandler.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)

# Проверяем баланс скобок
$openCount = ($c.ToCharArray() | Where-Object {$_ -eq '{'}).Count
$closeCount = ($c.ToCharArray() | Where-Object {$_ -eq '}'}).Count

Write-Host "Open braces: $openCount, Close braces: $closeCount"

if ($closeCount -lt $openCount) {
    # Добавляем недостающие закрывающие скобки
    $missing = $openCount - $closeCount
    Write-Host "Adding $missing missing closing brace(s)" -ForegroundColor Yellow
    
    # Находим последнюю строку файла и добавляем скобки
    $c = $c.TrimEnd() + "`n" + ("}" * $missing) + "`n"
    [System.IO.File]::WriteAllText($file, $c, $utf8)
    Write-Host "[OK] NinjaTickHandler.java: added missing braces" -ForegroundColor Green
} else {
    Write-Host "[OK] Braces balanced" -ForegroundColor Green
}

Write-Host "`nRun: .\gradlew.bat build" -ForegroundColor Cyan
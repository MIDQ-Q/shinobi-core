$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$file = "E:\Games\mod\src\main\java\com\example\shinobicore\client\ShinobiCoreClient.java"

if (-not (Test-Path $file)) {
    Write-Host "[FAIL] File not found: $file" -ForegroundColor Red
    exit 1
}

Write-Host "Reading ShinobiCoreClient.java..." -ForegroundColor Cyan
$c = [System.IO.File]::ReadAllText($file, $utf8)

# Ищем блок метода (вместе с комментарием и закрывающей скобкой)
$pattern = '(?ms)([ \t]*// === S0-06: Client receivers for new packets ===.*?ShinobiCore\.LOGGER\.info\("\[S0-06\] Network layer client receivers registered"\);\r?\n[ \t]*\})'
$match = [regex]::Match($c, $pattern)

if (-not $match.Success) {
    # Фоллбэк, если комментарий отсутствует
    $pattern = '(?ms)([ \t]*private void registerS06ClientReceivers\(\)[ \t]*\{.*?ShinobiCore\.LOGGER\.info\("\[S0-06\] Network layer client receivers registered"\);\r?\n[ \t]*\})'
    $match = [regex]::Match($c, $pattern)
}

if ($match.Success) {
    $methodBlock = $match.Groups[1].Value
    
    # 1. Удаляем метод из текущего (неправильного) места внутри onInitializeClient
    $c = $c.Replace($methodBlock, "")
    
    # Чистим лишние пустые строки, которые могли остаться
    $c = [regex]::Replace($c, '(\r?\n){3,}', "`n`n")
    
    # 2. Вставляем метод в конец класса, перед самой последней закрывающей скобкой '}'
    $lastBrace = $c.LastIndexOf("}")
    if ($lastBrace -gt 0) {
        $c = $c.Substring(0, $lastBrace) + "`n`n" + $methodBlock.TrimStart() + "`n" + $c.Substring($lastBrace)
    }
    
    [System.IO.File]::WriteAllText($file, $c, $utf8)
    Write-Host "[OK] Successfully moved registerS06ClientReceivers() to class level!" -ForegroundColor Green
    Write-Host "Now run: .\gradlew.bat build" -ForegroundColor Cyan
} else {
    Write-Host "[FAIL] Could not extract the method block via regex." -ForegroundColor Red
    Write-Host "Please open ShinobiCoreClient.java and manually move 'private void registerS06ClientReceivers()' outside of 'onInitializeClient()'." -ForegroundColor Yellow
}
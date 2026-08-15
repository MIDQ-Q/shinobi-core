$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$file = "E:\Games\mod\src\main\java\com\example\shinobicore\ShinobiCore.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)

$marker = "// === RASENSHURIKEN THROW HANDLER ==="

if ($c.Contains($marker)) {
    Write-Host "=== ИСПРАВЛЕНИЕ СИНТАКСИСА SHINOBICORE.JAVA ===" -ForegroundColor Cyan
    
    # 1. Отделяем неправильно вставленный кусок от основного файла
    $idx = $c.IndexOf($marker)
    $extracted = $c.Substring($idx)
    $c = $c.Substring(0, $idx)
    
    # 2. Находим конец второго хендлера (второе вхождение "});")
    $firstEnd = $extracted.IndexOf("});")
    $secondEnd = $extracted.IndexOf("});", $firstEnd + 3)
    
    if ($secondEnd -gt 0) {
        $handlers = $extracted.Substring(0, $secondEnd + 3)
        $remainder = $extracted.Substring($secondEnd + 3) # Здесь осталась закрывающая скобка класса }
        
        # 3. Вставляем хендлеры ВНУТРЬ метода onInitialize()
        if ($c.Contains("ModConfig.load();")) {
            $c = $c.Replace("ModConfig.load();", "ModConfig.load();`n`n" + $handlers)
        } elseif ($c.Contains("public void onInitialize() {")) {
            $c = $c.Replace("public void onInitialize() {", "public void onInitialize() {`n`n" + $handlers)
        } else {
            # Фоллбэк: вставляем перед последней закрывающей скобкой метода
            $lastBrace = $c.LastIndexOf("}")
            $c = $c.Insert($lastBrace, "`n`n" + $handlers + "`n")
        }
        
        # 4. Возвращаем остаток файла (закрывающую скобку класса)
        $c = $c + $remainder
        
        # 5. Чистим лишние пустые строки
        $c = $c -replace "(\r?\n\s*){3,}", "`n`n"
        
        [System.IO.File]::WriteAllText($file, $c, $utf8)
        Write-Host "[OK] Хендлеры успешно перемещены внутрь onInitialize()!" -ForegroundColor Green
    } else {
        Write-Host "[!] Не удалось корректно распарсить блок хендлеров." -ForegroundColor Red
    }
} else {
    Write-Host "Неправильно размещенный код не найден. Файл уже может быть чист." -ForegroundColor Yellow
}

Write-Host "`nТеперь запустите сборку:" -ForegroundColor Yellow
Write-Host ".\gradlew.bat build" -ForegroundColor White
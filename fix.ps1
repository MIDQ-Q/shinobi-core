$ErrorActionPreference = "Stop"
$basePath = "E:\Games\mod\src\main\java\com\example\shinobicore"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

function Clean-DuplicateRegex {
    param($Path, $RegexPattern, $Description)
    if (-not (Test-Path $Path)) { 
        Write-Host "[ERROR] File not found: $Path" -ForegroundColor Red
        return 
    }
    $content = [System.IO.File]::ReadAllText($Path)
    
    # Находим все совпадения паттерна в файле
    $matches = [regex]::Matches($content, $RegexPattern)
    if ($matches.Count -gt 1) {
        # Удаляем все совпадения, кроме самого первого (идем с конца, чтобы индексы не сбивались)
        for ($i = $matches.Count - 1; $i -ge 1; $i--) {
            $m = $matches[$i]
            $content = $content.Remove($m.Index, $m.Length)
        }
        [System.IO.File]::WriteAllText($Path, $content, $utf8NoBom)
        Write-Host "[FIXED] Удалено дубликатов: $($matches.Count - 1) для: $Description" -ForegroundColor Green
    } else {
        Write-Host "[OK] Дубликатов не найдено для: $Description" -ForegroundColor Cyan
    }
}

Write-Host "=== CLEANUP: Удаление дубликатов после повторного запуска скрипта ===" -ForegroundColor Magenta

$file1 = "$basePath\client\anim\json\PlayerJsonAnimState.java"
# 1. Удаление дубликатов объявления переменной lastRootOffsetY
Clean-DuplicateRegex $file1 "(?m)^[ \t]*public static float lastRootOffsetY = 0;\r?\n" "lastRootOffsetY declaration"
# 2. Удаление дубликатов блока вычисления rootPos
Clean-DuplicateRegex $file1 "(?m)^[ \t]*float\[\] rootPos = JsonAnimLibrary\.getRootOffset.*?;\r?\n[ \t]*lastRootOffsetY = .*?;\r?\n" "rootPos calculation"

$file2 = "$basePath\client\render\ShinobiPlayerModel.java"
# 3. Удаление дубликатов объявления переменной rootOffsetY
Clean-DuplicateRegex $file2 "(?m)^[ \t]*public float rootOffsetY = 0;\r?\n" "rootOffsetY declaration"

# 4. Удаление дубликатов переопределенного метода render
$renderRegex = "(?m)^[ \t]*@Override\r?\n[ \t]*public void render\(net\.minecraft\.client\.util\.math\.MatrixStack matrices, net\.minecraft\.client\.render\.VertexConsumer vertices, int light, int overlay, float red, float green, float blue, float alpha\) \{\r?\n[ \t]*matrices\.push\(\);\r?\n[ \t]*matrices\.translate\(0, this\.rootOffsetY, 0\);\r?\n[ \t]*super\.render\(matrices, vertices, light, overlay, red, green, blue, alpha\);\r?\n[ \t]*matrices\.pop\(\);\r?\n[ \t]*\}\r?\n"
Clean-DuplicateRegex $file2 $renderRegex "render() override method"

Write-Host ""
Write-Host "=== ГОТОВО ===" -ForegroundColor Cyan
Write-Host "Файлы очищены от дубликатов. Теперь запустите: .\gradlew.bat build" -ForegroundColor Yellow
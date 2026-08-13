$utf8 = New-Object System.Text.UTF8Encoding($false)
$src = "E:\Games\mod\src\main\java\com\example\shinobicore"
Write-Host "=== FIXING COMPILE ERRORS ===" -ForegroundColor Cyan

# === [1] KeyBindings.java: добавить поля SWITCH_STANCE и KATANA_DEFLECT ===
$file = "$src\client\KeyBindings.java"
$lines = [System.IO.File]::ReadAllLines($file, $utf8)
$newLines = New-Object System.Collections.ArrayList

$switchStyleLineIdx = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'public static KeyBinding SWITCH_STYLE;') {
        $switchStyleLineIdx = $i
        break
    }
}

if ($switchStyleLineIdx -ge 0) {
    # Копируем до SWITCH_STYLE
    for ($i = 0; $i -le $switchStyleLineIdx; $i++) {
        [void]$newLines.Add($lines[$i])
    }
    # Добавляем новые поля
    [void]$newLines.Add("    public static KeyBinding SWITCH_STANCE;")
    [void]$newLines.Add("    public static KeyBinding KATANA_DEFLECT;")
    # Копируем остальное
    for ($i = $switchStyleLineIdx + 1; $i -lt $lines.Count; $i++) {
        [void]$newLines.Add($lines[$i])
    }
    [System.IO.File]::WriteAllLines($file, $newLines.ToArray(), $utf8)
    Write-Host "[OK] KeyBindings.java: added SWITCH_STANCE and KATANA_DEFLECT fields" -ForegroundColor Green
} else {
    Write-Host "[SKIP] KeyBindings.java: SWITCH_STYLE not found" -ForegroundColor Red
}

# === [2] JutsuCaster.java: добавить импорт ShinobiCore ===
$file = "$src\jutsu\JutsuCaster.java"
$content = [System.IO.File]::ReadAllText($file, $utf8)

if (-not $content.Contains("import com.example.shinobicore.ShinobiCore;")) {
    $marker = "import com.example.shinobicore.stat.NinjaPlayerData;"
    if ($content.Contains($marker)) {
        $content = $content.Replace($marker, $marker + "`nimport com.example.shinobicore.ShinobiCore;")
        [System.IO.File]::WriteAllText($file, $content, $utf8)
        Write-Host "[OK] JutsuCaster.java: added ShinobiCore import" -ForegroundColor Green
    } else {
        Write-Host "[SKIP] JutsuCaster.java: marker not found" -ForegroundColor Red
    }
} else {
    Write-Host "[OK] JutsuCaster.java: ShinobiCore import already present" -ForegroundColor Gray
}

Write-Host "`n=== DONE ===" -ForegroundColor Cyan
Write-Host "Run: .\gradlew.bat build" -ForegroundColor Yellow
# fix_kick_scope.ps1 - Restore taijutsuLevel in KICK handler
$ErrorActionPreference = "Stop"
$root = "E:\Games\mod\src\main\java\com\example\shinobicore"
$utf8 = New-Object System.Text.UTF8Encoding($false)

$mp = "$root\network\ModPackets.java"
$content = [System.IO.File]::ReadAllText($mp, $utf8)
$lines = $content -split "`n"
$newLines = [System.Collections.Generic.List[string]]::new()

for ($i = 0; $i -lt $lines.Count; $i++) {
    $newLines.Add($lines[$i])
    
    # Ищем строку объявления стиля
    if ($lines[$i].Trim() -eq "TaijutsuStyle style = TaijutsuStyle.fromId(styleId);") {
        $isKickHandler = $false
        # Проверяем следующие 5 строк на наличие computeDamage с аргументом 2 (это кик)
        for ($j = 1; $j -le 5; $j++) {
            if (($i + $j) -lt $lines.Count -and $lines[$i+$j].Contains("computeDamage(taijutsuLevel, style, chakraMode, 2")) {
                $isKickHandler = $true
                break
            }
        }
        
        if ($isKickHandler) {
            # Если следующей строкой НЕ идет объявление taijutsuLevel, добавляем его
            if ($lines[$i+1].Trim() -ne "int taijutsuLevel = data.getStatLevel(StatType.TAIJUTSU);") {
                $newLines.Add("            int taijutsuLevel = data.getStatLevel(StatType.TAIJUTSU);")
                Write-Host "[FIX] Injected taijutsuLevel for KICK handler after line $($i+1)"
            } else {
                Write-Host "[SKIP] taijutsuLevel already present for KICK handler"
            }
        }
    }
}

$newContent = $newLines -join "`n"
[System.IO.File]::WriteAllText($mp, $newContent, $utf8)
Write-Host ""
Write-Host "=== KICK HANDLER FIXED ==="
Write-Host "Run: .\gradlew.bat build"
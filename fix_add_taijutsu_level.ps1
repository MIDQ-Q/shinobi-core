# fix_add_taijutsu_level.ps1 - Add taijutsuLevel declaration before cooldownMs
$ErrorActionPreference = "Stop"
$root = "E:\Games\mod\src\main\java\com\example\shinobicore"
$utf8 = New-Object System.Text.UTF8Encoding($false)

$mp = "$root\network\ModPackets.java"
$content = [System.IO.File]::ReadAllText($mp, $utf8)

# Ищем строку с lastAttack и вставляем taijutsuLevel после неё
$searchPattern = "long lastAttack = data.getLastAttackTimeMs();"
$insertText = "long lastAttack = data.getLastAttackTimeMs();`n            int taijutsuLevel = data.getStatLevel(StatType.TAIJUTSU);"

if ($content.Contains($searchPattern) -and -not $content.Contains($insertText)) {
    $content = $content.Replace($searchPattern, $insertText)
    Write-Host "[FIX] Added taijutsuLevel declaration before cooldownMs"
} else {
    Write-Host "[SKIP] taijutsuLevel already present or pattern not found"
}

# Удаляем дубликат если он есть ниже (перед computeDamage)
$lines = $content -split "`n"
$newLines = @()
$skipNext = $false

for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($skipNext) {
        $skipNext = $false
        continue
    }
    
    $line = $lines[$i]
    
    # Проверяем текущую строку
    if ($line.Trim() -eq "int taijutsuLevel = data.getStatLevel(StatType.TAIJUTSU);") {
        # Проверяем следующую строку - если это chakraMode или computeDamage, пропускаем (это дубликат)
        if ($i + 1 -lt $lines.Count) {
            $nextLine = $lines[$i + 1].Trim()
            if ($nextLine -eq "boolean chakraMode = data.isChakraMode();" -or $nextLine.StartsWith("float damage = TaijutsuFormulas.computeDamage")) {
                Write-Host "[FIX] Removing duplicate taijutsuLevel before computeDamage (line $($i+1))"
                continue  # Пропускаем эту строку
            }
        }
    }
    
    $newLines += $line
}

$content = $newLines -join "`n"

[System.IO.File]::WriteAllText($mp, $content, $utf8)
Write-Host ""
Write-Host "=== TAIJUTSU LEVEL FIXED ==="
Write-Host "Run: .\gradlew.bat build"
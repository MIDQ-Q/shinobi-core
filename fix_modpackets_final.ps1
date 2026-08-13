# fix_modpackets_final.ps1
$ErrorActionPreference = "Stop"
$root = "E:\Games\mod\src\main\java\com\example\shinobicore"
$utf8 = New-Object System.Text.UTF8Encoding($false)

$mp = "$root\network\ModPackets.java"
$content = [System.IO.File]::ReadAllText($mp, $utf8)

# === ШАГ 1: Добавляем объявление taijutsuLevel перед cooldownMs ===
$search1 = "long lastAttack = data.getLastAttackTimeMs();`n            int cooldownMs = TaijutsuFormulas.attackCooldownTicks(style, data.isChakraMode(), taijutsuLevel)"
$replace1 = "long lastAttack = data.getLastAttackTimeMs();`n            int taijutsuLevel = data.getStatLevel(StatType.TAIJUTSU);`n            int cooldownMs = TaijutsuFormulas.attackCooldownTicks(style, data.isChakraMode(), taijutsuLevel)"

if ($content.Contains($search1)) {
    $content = $content.Replace($search1, $replace1)
    Write-Host "[FIX] Step 1: Added taijutsuLevel before cooldownMs"
} else {
    Write-Host "[SKIP] Step 1: taijutsuLevel already present or pattern changed"
}

# === ШАГ 2: Удаляем ВТОРОЕ (дублирующее) объявление перед computeDamage ===
$damageIdx = $content.IndexOf("float damage = TaijutsuFormulas.computeDamage(taijutsuLevel, style, chakraMode, serverStep")
if ($damageIdx -gt 0) {
    $sub = $content.Substring(0, $damageIdx)
    $taiIdx = $sub.LastIndexOf("int taijutsuLevel = data.getStatLevel(StatType.TAIJUTSU);")
    
    if ($taiIdx -gt 0) {
        # Находим границы этой строки
        $lineStart = $sub.LastIndexOf("`n", $taiIdx) + 1
        $lineEnd = $sub.IndexOf("`n", $taiIdx) + 1
        
        $lineContent = $sub.Substring($lineStart, $lineEnd - $lineStart).Trim()
        if ($lineContent -eq "int taijutsuLevel = data.getStatLevel(StatType.TAIJUTSU);") {
            $content = $content.Substring(0, $lineStart) + $content.Substring($lineEnd)
            Write-Host "[FIX] Step 2: Removed duplicate taijutsuLevel before computeDamage"
        } else {
            Write-Host "[WARN] Step 2: Line mismatch: $lineContent"
        }
    } else {
        Write-Host "[SKIP] Step 2: No duplicate found before computeDamage"
    }
} else {
    Write-Host "[WARN] Step 2: Could not find computeDamage"
}

[System.IO.File]::WriteAllText($mp, $content, $utf8)
Write-Host ""
Write-Host "=== MODPACKETS FIXED ==="
Write-Host "Run: .\gradlew.bat build"
# fix_phase7_errors.ps1 - Fix compilation errors from Phase 7
$ErrorActionPreference = "Stop"
$root = "E:\Games\mod\src\main\java\com\example\shinobicore"
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Write-File($path, $content) {
    [System.IO.File]::WriteAllText($path, $content, $utf8)
    Write-Host "[OK] $path"
}

# ============================================================
# 1. Fix TaijutsuFormulas.java - ensure overloaded method exists
# ============================================================
$tf = "$root\combat\TaijutsuFormulas.java"
$tfContent = [System.IO.File]::ReadAllText($tf, $utf8)

if ($tfContent.Contains("PHASE7_SPEED_SCALING")) {
    Write-Host "[SKIP] TaijutsuFormulas: overloaded method already exists"
} else {
    # Add overloaded method before the last closing brace
    $newMethod = @"

    // === PHASE7_SPEED_SCALING ===
    public static int attackCooldownTicks(TaijutsuStyle style, boolean chakraMode, int taijutsuLevel) {
        float baseCooldown = 12.0f;
        float speedMult = style.getSpeedMult() * (chakraMode ? ModConfig.instance.taijutsu.chakraModeSpeedMult : 1.0f);
        float levelMult = 1.0f + taijutsuLevel * 0.003f;
        return Math.max(3, (int) (baseCooldown / (speedMult * levelMult)));
    }
"@
    # Find the last } and insert before it
    $lastBrace = $tfContent.LastIndexOf("}")
    if ($lastBrace -gt 0) {
        $tfContent = $tfContent.Substring(0, $lastBrace) + $newMethod + "`n" + $tfContent.Substring($lastBrace)
        Write-File $tf $tfContent
        Write-Host "[FIX] TaijutsuFormulas: added overloaded attackCooldownTicks(Style, boolean, int)"
    } else {
        Write-Host "[ERROR] TaijutsuFormulas: cannot find closing brace!"
    }
}

# ============================================================
# 2. Fix ModPackets.java - add taijutsuLevel declaration
# ============================================================
$mp = "$root\network\ModPackets.java"
$mpContent = [System.IO.File]::ReadAllText($mp, $utf8)

$searchMp = "long lastAttack = data.getLastAttackTimeMs();"
$insertAfter = "            long lastAttack = data.getLastAttackTimeMs();`n            int taijutsuLevel = data.getStatLevel(StatType.TAIJUTSU);"

if ($mpContent.Contains("PHASE7_ANTICHEAT") -and -not $mpContent.Contains("int taijutsuLevel = data.getStatLevel(StatType.TAIJUTSU);`n            int cooldownMs")) {
    # Check if taijutsuLevel is already declared near cooldownMs
    $mpContent = $mpContent.Replace($searchMp, $insertAfter)
    Write-File $mp $mpContent
    Write-Host "[FIX] ModPackets: added taijutsuLevel declaration before cooldownMs"
} else {
    Write-Host "[SKIP] ModPackets: taijutsuLevel already declared or marker not found"
}

Write-Host ""
Write-Host "=== PHASE 7 ERRORS FIXED ==="
Write-Host "Run: .\gradlew.bat build"
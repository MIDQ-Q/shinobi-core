# ============================================================
#  FIX S1-08: NinjaTickHandler grantPassiveXp call
#  Uses single-line anchor to avoid indent mismatch
#  PS 5.1 compatible. ASCII only. UTF8 no BOM.
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$nthPath = Join-Path $root "src\main\java\com\example\shinobicore\event\NinjaTickHandler.java"

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  FIX S1-08: NinjaTickHandler grantPassiveXp" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $nthPath)) {
    Write-Host "[MISS] $nthPath" -ForegroundColor Red
    exit 1
}

$c = [System.IO.File]::ReadAllText($nthPath, $utf8)
$cNorm = $c.Replace("`r`n", "`n")

# Idempotency: already patched?
if ($cNorm.Contains("grantPassiveXp")) {
    Write-Host "[SKIP] grantPassiveXp already present in NinjaTickHandler" -ForegroundColor Yellow
    exit 0
}

# Find the single-line anchor (indent-independent)
$anchor = "// === END PHASE_FIX2_TICK ==="
if (-not $c.Contains($anchor)) {
    Write-Host "[FAIL] anchor not found: $anchor" -ForegroundColor Red
    Write-Host "Trying fallback anchor..." -ForegroundColor Yellow
    # Fallback: try sendChakraSync as anchor
    $anchor2 = "ShinobiCore.sendChakraSync(player);"
    if (-not $c.Contains($anchor2)) {
        Write-Host "[FAIL] fallback anchor not found either" -ForegroundColor Red
        exit 1
    }
    $insert = "// === S1-08: PASSIVE XP DRIFT ===`n        NinjaFormula.grantPassiveXp(data);`n        ShinobiCore.sendChakraSync(player);"
    $c = $c.Replace($anchor2, $insert)
} else {
    $insert = "// === END PHASE_FIX2_TICK ===`n        // === S1-08: PASSIVE XP DRIFT ===`n        NinjaFormula.grantPassiveXp(data);"
    $c = $c.Replace($anchor, $insert)
}

[System.IO.File]::WriteAllText($nthPath, $c, $utf8)
Write-Host "[OK] grantPassiveXp inserted into NinjaTickHandler" -ForegroundColor Green
Write-Host ""
Write-Host "  Next: .\gradlew.bat build" -ForegroundColor Yellow
exit 0
# ============================================================
#  FIX: S1-08 Passive XP drift (grantPassiveXp)
#  Adds the missing method to NinjaFormula.java
#  PS 5.1 compatible. UTF8 no BOM. Idempotent.
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$java = "$root\src\main\java\com\example\shinobicore"
$formulaPath = "$java\stat\NinjaFormula.java"

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  FIX: S1-08 Add grantPassiveXp to NinjaFormula.java" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $formulaPath)) {
    Write-Host "[FAIL] File not found: $formulaPath" -ForegroundColor Red
    exit 1
}

$c = [System.IO.File]::ReadAllText($formulaPath, $utf8)
$cNorm = $c.Replace("`r`n", "`n")

# Idempotency check
if ($cNorm.Contains("grantPassiveXp")) {
    Write-Host "[SKIP] Method grantPassiveXp already exists in NinjaFormula.java" -ForegroundColor Yellow
} else {
    # Injecting the exact snippet you provided
    $newMethod = @"

    // === S1-08: Пассивный дрейф опыта ===
    public static void grantPassiveXp(NinjaPlayerData data) {
        // Пассивный прирост: 1 XP резерва за вызов (NinjaTickHandler вызывает это раз в секунду).
        // Встроенная система бюджетов (tryConsumeXpBudget внутри grantReserveXp) 
        // сама ограничит бесконечный фарм лимитом maxXpPerMinute из конфига.
        grantReserveXp(data, 1);
    }
"@
    
    # Find the last closing brace of the class to insert before it
    $lastBraceIndex = $cNorm.LastIndexOf("}")
    if ($lastBraceIndex -lt 0) {
        Write-Host "[FAIL] Could not find class closing brace in NinjaFormula.java" -ForegroundColor Red
        exit 1
    }
    
    $before = $cNorm.Substring(0, $lastBraceIndex)
    $after = $cNorm.Substring($lastBraceIndex)
    
    $newContent = $before + $newMethod + "`n" + $after
    
    # Write back with UTF-8 NO BOM
    [System.IO.File]::WriteAllText($formulaPath, $newContent, $utf8)
    Write-Host "[OK] Successfully added grantPassiveXp method to NinjaFormula.java" -ForegroundColor Green
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Yellow
Write-Host "  Running .\gradlew.bat build to verify..." -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Yellow
Write-Host ""

Set-Location $root
& .\gradlew.bat build
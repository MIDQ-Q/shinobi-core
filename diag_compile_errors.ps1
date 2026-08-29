$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcBase = Join-Path $root "src\main\java\com\example\shinobicore"

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host " FIX: Two specific compile errors" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

$fixedCount = 0

# ============================================================
# FIX 1: ChakraClientController.java (missing fatigueRecoveryPerSec)
# ============================================================
Write-Host "[1/2] Fixing ChakraClientController.java..." -ForegroundColor Yellow
$f1 = Join-Path $srcBase "chakra\client\ChakraClientController.java"
if (Test-Path $f1) {
    $c = [System.IO.File]::ReadAllText($f1, $utf8)
    
    $oldLine = "fatigue -= config.chakra.fatigueRecoveryPerSec / 20.0f;"
    $newLine = "fatigue -= 2.0f / 20.0f; // Default fatigue recovery"
    
    if ($c.Contains($oldLine)) {
        $c = $c.Replace($oldLine, $newLine)
        [System.IO.File]::WriteAllText($f1, $c, $utf8)
        Write-Host "  [FIXED] Replaced missing config field with default value" -ForegroundColor Green
        $fixedCount++
    } else {
        Write-Host "  [SKIP] Pattern not found or already fixed" -ForegroundColor Yellow
    }
}

# ============================================================
# FIX 2: ChakraKeyHandler.java (wrong method name)
# ============================================================
Write-Host "[2/2] Fixing ChakraKeyHandler.java..." -ForegroundColor Yellow
$f2 = Join-Path $srcBase "chakra\client\ChakraKeyHandler.java"
if (Test-Path $f2) {
    $c = [System.IO.File]::ReadAllText($f2, $utf8)
    
    $oldCall = "ChakraClientController.isChakraMode()"
    $newCall = "ChakraClientController.isChakraModeActive()"
    
    if ($c.Contains($oldCall)) {
        $c = $c.Replace($oldCall, $newCall)
        [System.IO.File]::WriteAllText($f2, $c, $utf8)
        Write-Host "  [FIXED] Corrected method name to isChakraModeActive()" -ForegroundColor Green
        $fixedCount++
    } else {
        Write-Host "  [SKIP] Pattern not found or already fixed" -ForegroundColor Yellow
    }
}

# ============================================================
# BUILD
# ============================================================
Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host " BUILDING..." -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan

Push-Location $root
try {
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $out = & ".\gradlew.bat" build 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP

    if ($exitCode -eq 0) {
        Write-Host ""
        Write-Host " [PASS] BUILD SUCCESSFUL!" -ForegroundColor Green
        Write-Host ""
        Write-Host "==============================================================" -ForegroundColor Green
        Write-Host " ALL ERRORS FIXED - PROJECT IS READY" -ForegroundColor Green
        Write-Host "==============================================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Run: .\gradlew.bat runClient" -ForegroundColor Yellow
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host " [FAIL] Build still failing:" -ForegroundColor Red
        $out | Where-Object { $_ -match "error:" } | Select-Object -First 20 | ForEach-Object { Write-Host " $_" -ForegroundColor Red }
    }
} finally {
    Pop-Location
}

exit 0
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcBase = Join-Path $root "src\main\java\com\example\shinobicore"

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  FINAL FIX: MovementModule import" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

$moveModulePath = Join-Path $srcBase "modules\movement\MovementModule.java"

if (-not (Test-Path $moveModulePath)) {
    Write-Host "  [FATAL] MovementModule.java not found!" -ForegroundColor Red
    exit 1
}

$content = [System.IO.File]::ReadAllText($moveModulePath, $utf8)
$content = $content.Replace("`r`n", "`n")
$fixed = $false

# Fix 1: Remove dead import of movement.event package
if ($content.Contains("import com.example.shinobicore.modules.movement.event.*;")) {
    $content = $content.Replace("import com.example.shinobicore.modules.movement.event.*;`n", "")
    Write-Host "  [FIX] Removed dead import movement.event.*" -ForegroundColor Green
    $fixed = $true
}

# Fix 2: If there's a specific import like movement.event.SomeEvent
if ($content -match "import com\.example\.shinobicore\.modules\.movement\.event\.") {
    $content = $content -replace "import com\.example\.shinobicore\.modules\.movement\.event\.[^;]+;", ""
    Write-Host "  [FIX] Removed specific movement.event imports" -ForegroundColor Green
    $fixed = $true
}

# Fix 3: Also check for movement.common.events (the correct package)
# MovementModule doesn't actually use any movement events directly,
# it uses CoreEvents from core.event. So just removing is correct.

# Fix 4: Verify CoreEvents import exists
if (-not $content.Contains("import com.example.shinobicore.core.event.CoreEvents;")) {
    # Add it after the package line
    $content = $content.Replace(
        "package com.example.shinobicore.modules.movement;",
        "package com.example.shinobicore.modules.movement;`n`nimport com.example.shinobicore.core.event.CoreEvents;"
    )
    Write-Host "  [FIX] Added missing CoreEvents import" -ForegroundColor Green
    $fixed = $true
}

if ($fixed) {
    [System.IO.File]::WriteAllText($moveModulePath, $content, $utf8)
    Write-Host ""
    Write-Host "  [OK] MovementModule.java saved" -ForegroundColor Green
} else {
    Write-Host "  [SKIP] No changes needed" -ForegroundColor Yellow
}

# ============================================================
# BUILD
# ============================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  RUNNING BUILD" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

Push-Location $root
try {
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = & ".\gradlew.bat" build 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP

    Write-Host ""
    if ($exitCode -eq 0) {
        Write-Host "================================================================" -ForegroundColor Green
        Write-Host "  [PASS] BUILD SUCCESSFUL!" -ForegroundColor Green
        Write-Host "================================================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "  All errors fixed. Ready to run:" -ForegroundColor White
        Write-Host "    .\gradlew.bat runClient" -ForegroundColor Yellow
    } else {
        Write-Host "================================================================" -ForegroundColor Red
        Write-Host "  [FAIL] BUILD FAILED" -ForegroundColor Red
        Write-Host "================================================================" -ForegroundColor Red
        Write-Host ""
        Write-Host "  Remaining errors:" -ForegroundColor Yellow
        $out | Where-Object { $_ -match 'error:' } | Select-Object -First 30 | ForEach-Object {
            Write-Host "  $_" -ForegroundColor Red
        }
    }
} finally {
    Pop-Location
}
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$mixinsPath = Join-Path $root "src\main\resources\shinobicore.mixins.json"

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host " FIX: Rewriting broken shinobicore.mixins.json" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

$jsonContent = @'
{
  "required": true,
  "minVersion": "0.8",
  "package": "com.example.shinobicore.mixin",
  "compatibilityLevel": "JAVA_17",
  "mixins": [
  ],
  "client": [
    "PlayerWaterWalkMixin"
  ],
  "injectors": {
    "defaultRequire": 1
  }
}
'@

[System.IO.File]::WriteAllText($mixinsPath, $jsonContent, $utf8)
Write-Host " [OK] shinobicore.mixins.json rewritten with valid JSON." -ForegroundColor Green

Write-Host ""
Write-Host "Rebuilding project..." -ForegroundColor Yellow

Push-Location $root
try {
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $out = & ".\gradlew.bat" build 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP

    if ($exitCode -eq 0) {
        Write-Host " [PASS] BUILD SUCCESSFUL!" -ForegroundColor Green
        Write-Host ""
        Write-Host "JSON is fixed. You can now run:" -ForegroundColor Cyan
        Write-Host "  .\gradlew.bat runClient" -ForegroundColor Yellow
    } else {
        Write-Host " [FAIL] Build failed:" -ForegroundColor Red
        $out | Where-Object { $_ -match "error:|FAILED" } | Select-Object -First 25 | ForEach-Object { Write-Host " $_" -ForegroundColor Red }
    }
} finally {
    Pop-Location
}
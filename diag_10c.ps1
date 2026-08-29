# ============================================================
# DIAGNOSE: Show problematic lines in ClientMovementService
# ============================================================
$ErrorActionPreference = "Continue"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$file = Join-Path $root "src\main\java\com\example\shinobicore\movement\client\ClientMovementService.java"

Write-Host ""
Write-Host "=== DIAGNOSTIC: ClientMovementService.java ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $file)) {
    Write-Host "[FAIL] File not found!" -ForegroundColor Red
    exit 1
}

$lines = [System.IO.File]::ReadAllLines($file, $utf8)
Write-Host "Total lines: $($lines.Count)" -ForegroundColor White
Write-Host ""

# Show lines 120-160 (problem region)
Write-Host "--- Lines 120-160 (problem region) ---" -ForegroundColor Yellow
for ($i = 119; $i -lt [Math]::Min(160, $lines.Count); $i++) {
    $lineNum = $i + 1
    $marker = ""
    if ($lineNum -ge 128 -and $lineNum -le 145) { $marker = " <<<<" }
    Write-Host ("{0,4}: {1}{2}" -f $lineNum, $lines[$i], $marker)
}

Write-Host ""
Write-Host "--- Lines 1-15 (imports + class start) ---" -ForegroundColor Yellow
for ($i = 0; $i -lt [Math]::Min(15, $lines.Count); $i++) {
    Write-Host ("{0,4}: {1}" -f ($i + 1), $lines[$i])
}

Write-Host ""
Write-Host "=== END DIAGNOSTIC ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Please send this output so I can write the exact fix." -ForegroundColor Yellow
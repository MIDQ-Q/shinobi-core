# ============================================================
# DIAGNOSE: KeyBindings.java + ClientMovementService.java:76
# ============================================================
$ErrorActionPreference = "Continue"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"

Write-Host ""
Write-Host "=== DIAGNOSTIC ===" -ForegroundColor Cyan
Write-Host ""

# Show KeyBindings.java
$kbPath = Join-Path $root "src\main\java\com\example\shinobicore\client\input\KeyBindings.java"
if (Test-Path $kbPath) {
    Write-Host "--- KeyBindings.java (full) ---" -ForegroundColor Yellow
    $lines = [System.IO.File]::ReadAllLines($kbPath, $utf8)
    for ($i = 0; $i -lt $lines.Count; $i++) {
        Write-Host ("{0,4}: {1}" -f ($i + 1), $lines[$i])
    }
} else {
    Write-Host "[MISS] KeyBindings.java not found at: $kbPath" -ForegroundColor Red
}

Write-Host ""

# Show ClientMovementService.java lines 70-85
$cmsPath = Join-Path $root "src\main\java\com\example\shinobicore\movement\client\ClientMovementService.java"
if (Test-Path $cmsPath) {
    Write-Host "--- ClientMovementService.java lines 65-90 ---" -ForegroundColor Yellow
    $lines = [System.IO.File]::ReadAllLines($cmsPath, $utf8)
    for ($i = 64; $i -lt [Math]::Min(90, $lines.Count); $i++) {
        $marker = ""
        if (($i + 1) -ge 73 -and ($i + 1) -le 80) { $marker = " <<<<" }
        Write-Host ("{0,4}: {1}{2}" -f ($i + 1), $lines[$i], $marker)
    }
} else {
    Write-Host "[MISS] ClientMovementService.java not found" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== END DIAGNOSTIC ===" -ForegroundColor Cyan
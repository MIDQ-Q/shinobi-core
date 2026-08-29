$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$filePath = Join-Path $root "src\main\java\com\example\shinobicore\movement\client\WaterWalkClient.java"

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host " CHECK: WaterWalkClient FIX 2 status" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $filePath)) {
    Write-Host " [FAIL] WaterWalkClient.java not found!" -ForegroundColor Red
    exit 1
}

$content = [System.IO.File]::ReadAllText($filePath, $utf8)

# Check if FIX 2 is present
$hasFix2Comment = $content.Contains("FIX 2: Allow jumping from water")
$hasJumpHandler = $content.Contains("MovementInputService.wasJumpPressed()")
$hasJumpVelocity = $content.Contains("player.setVelocity(jumpVel.x, 0.42, jumpVel.z)")

Write-Host "FIX 2 comment present:     $hasFix2Comment" -ForegroundColor $(if ($hasFix2Comment) { "Green" } else { "Red" })
Write-Host "Jump handler present:      $hasJumpHandler" -ForegroundColor $(if ($hasJumpHandler) { "Green" } else { "Red" })
Write-Host "Jump velocity present:     $hasJumpVelocity" -ForegroundColor $(if ($hasJumpVelocity) { "Green" } else { "Red" })
Write-Host ""

if ($hasFix2Comment -and $hasJumpHandler -and $hasJumpVelocity) {
    Write-Host " [PASS] FIX 2 is correctly applied!" -ForegroundColor Green
    Write-Host " Water jump should work in-game." -ForegroundColor Cyan
} elseif ($hasJumpHandler -and $hasJumpVelocity) {
    Write-Host " [PARTIAL] FIX 2 partially applied (no comment marker)" -ForegroundColor Yellow
    Write-Host " Water jump may work, but pattern is non-standard." -ForegroundColor Yellow
} else {
    Write-Host " [FAIL] FIX 2 NOT applied correctly!" -ForegroundColor Red
    Write-Host " Need manual fix." -ForegroundColor Red
    Write-Host ""
    Write-Host "Dumping current tick() method area..." -ForegroundColor Yellow
    Write-Host "--------------------------------------------------------------"
    
    # Find and show the active block
    $lines = $content -split "`n"
    $inActiveBlock = $false
    $braceCount = 0
    $shown = 0
    
    for ($i = 0; $i -lt $lines.Count -and $shown -lt 40; $i++) {
        $line = $lines[$i]
        
        if ($line -match "if\s*\(active\)") {
            $inActiveBlock = $true
        }
        
        if ($inActiveBlock) {
            Write-Host ("{0,4}: {1}" -f ($i+1), $line)
            $shown++
            
            # Count braces to find end of block
            $opens = ([regex]::Matches($line, '\{')).Count
            $closes = ([regex]::Matches($line, '\}')).Count
            $braceCount += $opens - $closes
            
            if ($braceCount -le 0 -and $shown -gt 5) {
                break
            }
        }
    }
    
    Write-Host "--------------------------------------------------------------"
}

Write-Host ""
exit 0
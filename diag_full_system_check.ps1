$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcJava = Join-Path $root "src\main\java\com\example\shinobicore"
$reportPath = Join-Path $root "system_check_report.txt"

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host " SHINOBICORE: FULL SYSTEM DIAGNOSTIC CHECK" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

$issues = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]
$ok = New-Object System.Collections.Generic.List[string]

function Read-File([string]$RelativePath) {
    $full = Join-Path $srcJava $RelativePath
    if (-not (Test-Path $full)) { return $null }
    return [System.IO.File]::ReadAllText($full, $utf8)
}

function Check-File([string]$Name, [string]$RelativePath) {
    $full = Join-Path $srcJava $RelativePath
    if (Test-Path $full) {
        $msg = "[OK] " + $Name + " exists: " + $RelativePath
        $script:ok.Add($msg)
        return $true
    } else {
        $msg = "[MISSING] " + $Name + ": " + $RelativePath
        $script:issues.Add($msg)
        return $false
    }
}

Write-Host "[1/7] Checking core files exist..." -ForegroundColor Yellow

Check-File "ClientMovementService" "movement\client\ClientMovementService.java" | Out-Null
Check-File "MovementInputService" "movement\client\MovementInputService.java" | Out-Null
Check-File "WaterWalkClient" "movement\client\WaterWalkClient.java" | Out-Null
Check-File "WallRunClient" "movement\client\WallRunClient.java" | Out-Null
Check-File "SlideClient" "movement\client\SlideClient.java" | Out-Null
Check-File "CrawlClient" "movement\client\CrawlClient.java" | Out-Null
Check-File "RollClient" "movement\client\RollClient.java" | Out-Null
Check-File "DodgeClient" "movement\client\DodgeClient.java" | Out-Null
Check-File "ChargedJumpClient" "movement\client\ChargedJumpClient.java" | Out-Null
Check-File "DoubleJumpClient" "movement\client\DoubleJumpClient.java" | Out-Null
Check-File "EdgeGrabClient" "movement\client\EdgeGrabClient.java" | Out-Null
Check-File "MeditationClient" "movement\client\MeditationClient.java" | Out-Null
Check-File "ChakraClientController" "chakra\client\ChakraClientController.java" | Out-Null
Check-File "ProgressionV3" "progression\v3\ProgressionV3.java" | Out-Null
Check-File "ProgressionHubScreen" "client\gui\screen\ProgressionHubScreen.java" | Out-Null

Write-Host "[2/7] Analyzing WaterWalkClient for jump issues..." -ForegroundColor Yellow
$ww = Read-File "movement\client\WaterWalkClient.java"
if ($ww) {
    if ($ww -match "vel\.y < 0\.0") {
        $ok.Add("[OK] WaterWalkClient: only cancels falling (vel.y < 0)")
    } else {
        $warnings.Add("[WARN] WaterWalkClient: may cancel ALL vertical velocity (check vel.y < 0.0)")
    }
    
    if ($ww -match "player\.setOnGround") {
        $issues.Add("[BUG] WaterWalkClient calls setOnGround() - may break jumping")
    }
    
    if ($ww -match "fallDistance\s*=\s*0") {
        $ok.Add("[OK] WaterWalkClient resets fallDistance")
    }
}

Write-Host "[3/7] Analyzing ChargedJumpClient for teleport issues..." -ForegroundColor Yellow
$cj = Read-File "movement\client\ChargedJumpClient.java"
if ($cj) {
    if ($cj -match "Math\.min\(jumpY,.*1\.5\)") {
        $ok.Add("[OK] ChargedJumpClient: has vertical velocity cap")
    } else {
        $warnings.Add("[WARN] ChargedJumpClient: no hard cap on jump velocity")
    }
    
    if ($cj -match "player\.setVelocity\(velocity\.x, jumpY, velocity\.z\)") {
        $warnings.Add("[WARN] ChargedJumpClient: sets absolute Y velocity - may cause teleport feel")
        $issues.Add("[KNOWN-BUG] ChargedJumpClient 'teleport up': release() sets Y directly instead of addVelocity()")
    }
    
    if ($cj -match "charging.*=.*false") {
        $ok.Add("[OK] ChargedJumpClient: resets charging state")
    }
}

Write-Host "[4/7] Analyzing EdgeGrabClient..." -ForegroundColor Yellow
$eg = Read-File "movement\client\EdgeGrabClient.java"
if ($eg) {
    if ($eg -match "player\.setPosition\(.*position\.y \+ CLIMB_UP_Y") {
        $warnings.Add("[WARN] EdgeGrabClient.climbUp() uses setPosition() - causes instant teleport (no smooth climb)")
    }
    
    if ($eg -match "player\.setVelocity\(0,\s*0,\s*0\)") {
        $ok.Add("[OK] EdgeGrabClient: zeroes velocity on grab")
    }
}

Write-Host "[5/7] Checking ClientMovementService tick order..." -ForegroundColor Yellow
$cms = Read-File "movement\client\ClientMovementService.java"
if ($cms) {
    $waterIdx = $cms.IndexOf("WaterWalkClient.tick")
    $wallIdx = $cms.IndexOf("WallRunClient.tick")
    $rollIdx = $cms.IndexOf("RollClient.tick")
    $meditationIdx = $cms.IndexOf("MeditationClient.tick")
    
    if ($waterIdx -lt $wallIdx -and $wallIdx -lt $rollIdx) {
        $ok.Add("[OK] ClientMovementService: correct tick order (Water -> Wall -> Roll)")
    } else {
        $warnings.Add("[WARN] ClientMovementService: tick order may cause conflicts")
    }
    
    if ($cms -match "client\.currentScreen != null") {
        $ok.Add("[OK] ClientMovementService: skips when screen is open")
    }
    
    if ($cms -match "client\.player\.isDead\(\)") {
        $ok.Add("[OK] ClientMovementService: skips when dead")
    }
}

Write-Host "[6/7] Checking PlayerWaterWalkMixin..." -ForegroundColor Yellow
$mixinPath = Join-Path $srcJava "mixin\PlayerWaterWalkMixin.java"
if (Test-Path $mixinPath) {
    $mx = [System.IO.File]::ReadAllText($mixinPath, $utf8)
    if ($mx -match "isTouchingWater") {
        $warnings.Add("[WARN] PlayerWaterWalkMixin bypasses isTouchingWater() - vanilla water jump will NOT work")
        $issues.Add("[KNOWN-BUG] Cannot jump from water: mixin says 'not in water' but isOnGround=false")
    }
} else {
    $warnings.Add("[MISSING] PlayerWaterWalkMixin.java not found")
}

Write-Host "[7/7] Checking Progression sync..." -ForegroundColor Yellow
$sync = Read-File "progression\v3\ProgressionV3ServerSync.java"
if ($sync) {
    if ($sync -match "FULL_ID") {
        $ok.Add("[OK] ProgressionV3ServerSync: has full sync packet")
    }
    if ($sync -match "statLevels\.size\(\)") {
        $ok.Add("[OK] ProgressionV3ServerSync: sends stat data")
    }
}

$hub = Read-File "client\gui\screen\ProgressionHubScreen.java"
if ($hub) {
    if ($hub -match "ProgressionClientState\.getStatLevels\(\)\.isEmpty\(\)") {
        $warnings.Add("[INFO] ProgressionHubScreen: shows 'No stats yet' if no XP gained")
        $warnings.Add("[INFO] To see stats: use /shinobicore progressionv3 statxp taijutsu 100 then press K")
    }
}

# ============================================================
# Generate report
# ============================================================

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("SHINOBICORE SYSTEM CHECK REPORT")
$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
[void]$sb.AppendLine("Generated: " + $timestamp)
[void]$sb.AppendLine("")
[void]$sb.AppendLine("============================================================")
[void]$sb.AppendLine(" ISSUES (MUST FIX)")
[void]$sb.AppendLine("============================================================")
if ($issues.Count -eq 0) {
    [void]$sb.AppendLine("  No critical issues found.")
} else {
    foreach ($i in $issues) { [void]$sb.AppendLine("  " + $i) }
}

[void]$sb.AppendLine("")
[void]$sb.AppendLine("============================================================")
[void]$sb.AppendLine(" WARNINGS (CHECK MANUALLY)")
[void]$sb.AppendLine("============================================================")
if ($warnings.Count -eq 0) {
    [void]$sb.AppendLine("  No warnings.")
} else {
    foreach ($w in $warnings) { [void]$sb.AppendLine("  " + $w) }
}

[void]$sb.AppendLine("")
[void]$sb.AppendLine("============================================================")
[void]$sb.AppendLine(" OK CHECKS")
[void]$sb.AppendLine("============================================================")
foreach ($o in $ok) { [void]$sb.AppendLine("  " + $o) }

[void]$sb.AppendLine("")
[void]$sb.AppendLine("============================================================")
[void]$sb.AppendLine(" KNOWN BUGS SUMMARY")
[void]$sb.AppendLine("============================================================")
[void]$sb.AppendLine("  1. TELEPORT UP after charged jump:")
[void]$sb.AppendLine("     Cause: ChargedJumpClient.release() uses setVelocity(Y)")
[void]$sb.AppendLine("     Fix:   Replace with addVelocity(0, jumpY - 0.42, 0) and let vanilla add base jump")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("  2. CANNOT JUMP FROM WATER:")
[void]$sb.AppendLine("     Cause: PlayerWaterWalkMixin makes isTouchingWater=false")
[void]$sb.AppendLine("            but isOnGround is also false, so vanilla won't jump")
[void]$sb.AppendLine("     Fix:   Add water-jump mixin or give Y impulse in WaterWalkClient on jump press")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("  3. STATS NOT VISIBLE IN K SCREEN:")
[void]$sb.AppendLine("     Cause: Server only sends stats when XP is gained")
[void]$sb.AppendLine("     Test:  /shinobicore progressionv3 statxp taijutsu 100")
[void]$sb.AppendLine("            Then /shinobicore progressionv3 sync")
[void]$sb.AppendLine("            Then press K")

[System.IO.File]::WriteAllText($reportPath, $sb.ToString(), $utf8)

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Green
Write-Host " DIAGNOSTIC COMPLETE" -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Green
Write-Host ""
Write-Host ("Report saved: " + $reportPath) -ForegroundColor Cyan
Write-Host ""
Write-Host ("ISSUES FOUND: " + $issues.Count) -ForegroundColor Red
Write-Host ("WARNINGS:     " + $warnings.Count) -ForegroundColor Yellow
Write-Host ("OK CHECKS:    " + $ok.Count) -ForegroundColor Green
Write-Host ""

if ($issues.Count -gt 0) {
    Write-Host "Critical issues detected:" -ForegroundColor Red
    foreach ($i in $issues) {
        Write-Host ("  " + $i) -ForegroundColor Red
    }
}

exit 0
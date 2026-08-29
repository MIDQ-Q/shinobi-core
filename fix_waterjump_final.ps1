$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$filePath = Join-Path $root "src\main\java\com\example\shinobicore\movement\client\WaterWalkClient.java"

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host " FIX: WaterWalkClient - Allow Jump From Water (FINAL)" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $filePath)) {
    Write-Host " [FAIL] WaterWalkClient.java not found!" -ForegroundColor Red
    exit 1
}

$content = [System.IO.File]::ReadAllText($filePath, $utf8)
$originalContent = $content

# Normalize line endings
$content = $content.Replace("`r`n", "`n")

# ============================================================
# STRATEGY: Find the velocity stabilization block and inject
# jump handling BEFORE it.
# ============================================================

# Pattern 1: Look for the velocity stabilization comment/line
$patterns = @(
    # Pattern A: Comment-based
    @'
        // Stabilize: prevent sinking below water surface
        Vec3d vel = player.getVelocity();
        if (vel.y < 0.0) {
'@,
    # Pattern B: Direct code without comment
    @'
        Vec3d vel = player.getVelocity();
        if (vel.y < 0.0) {
'@,
    # Pattern C: Alternative variable name
    @'
        Vec3d velocity = player.getVelocity();
        if (velocity.y < 0.0) {
'@
)

$jumpCode = @'
        // FIX: Allow jumping from water
        if (MovementInputService.wasJumpPressed()) {
            Vec3d jumpVel = player.getVelocity();
            player.setVelocity(jumpVel.x, 0.42, jumpVel.z);
            player.velocityModified = true;
            setActive(false);
            ClientMovementState.setPhase(MovementPhase.NORMAL);
            return;
        }

'@

$found = $false
foreach ($pattern in $patterns) {
    $patternNorm = $pattern.Replace("`r`n", "`n")
    if ($content.Contains($patternNorm)) {
        Write-Host " [MATCH] Found pattern:" -ForegroundColor Green
        Write-Host "   $($patternNorm.Split("`n")[0].Trim())" -ForegroundColor Gray
        
        $content = $content.Replace($patternNorm, $jumpCode + $patternNorm)
        $found = $true
        break
    }
}

if (-not $found) {
    Write-Host " [WARN] Exact patterns not found, trying line-by-line injection..." -ForegroundColor Yellow
    
    # Fallback: Find "vel.y < 0.0" or "velocity.y < 0.0" and inject before the line that contains it
    $lines = $content -split "`n"
    $newLines = New-Object System.Collections.Generic.List[string]
    $injected = $false
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        
        # Look for the line that checks Y velocity in water walk context
        if (-not $injected -and ($line -match 'vel\.y\s*<\s*0' -or $line -match 'velocity\.y\s*<\s*0')) {
            # Check if previous lines are in water walk context (look back for getVelocity)
            $isWaterContext = $false
            for ($j = [Math]::Max(0, $i-3); $j -lt $i; $j++) {
                if ($lines[$j] -match 'getVelocity') {
                    $isWaterContext = $true
                    break
                }
            }
            
            if ($isWaterContext) {
                # Inject jump code before the getVelocity line
                # Find the getVelocity line
                for ($k = $i - 1; $k -ge [Math]::Max(0, $i-3); $k--) {
                    if ($lines[$k] -match 'getVelocity') {
                        # Insert jump code before this line
                        $jumpLines = $jumpCode.TrimEnd("`n") -split "`n"
                        foreach ($jl in $jumpLines) {
                            $newLines.Add($jl)
                        }
                        $newLines.Add("")
                        $injected = $true
                        break
                    }
                }
            }
        }
        
        $newLines.Add($line)
    }
    
    if ($injected) {
        $content = $newLines -join "`n"
        Write-Host " [OK] Injected via line-by-line fallback" -ForegroundColor Green
    } else {
        Write-Host " [FAIL] Could not find injection point!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please manually add this code in WaterWalkClient.tick()" -ForegroundColor Yellow
        Write-Host "right before the 'vel.y < 0.0' check:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host $jumpCode -ForegroundColor Cyan
        exit 1
    }
}

# Verify the fix is present
if ($content.Contains("FIX: Allow jumping from water")) {
    Write-Host ""
    Write-Host " [PASS] Jump-from-water code injected successfully!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host " [FAIL] Injection verification failed!" -ForegroundColor Red
    exit 1
}

# Write the file
[System.IO.File]::WriteAllText($filePath, $content, $utf8)
Write-Host " [OK] Saved WaterWalkClient.java" -ForegroundColor Green

# ============================================================
# BUILD
# ============================================================

Write-Host ""
Write-Host "Building project..." -ForegroundColor Yellow

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
        Write-Host "==============================================================" -ForegroundColor Green
        Write-Host " WATER JUMP FIX COMPLETE" -ForegroundColor Green
        Write-Host "==============================================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Test in-game:" -ForegroundColor Yellow
        Write-Host "  1. Enable Chakra Mode (L)" -ForegroundColor White
        Write-Host "  2. Walk onto water" -ForegroundColor White
        Write-Host "  3. Press Space -> should jump off water" -ForegroundColor White
        Write-Host ""
    } else {
        Write-Host " [FAIL] Build failed:" -ForegroundColor Red
        $out | Where-Object { $_ -match "error:" } | Select-Object -First 20 | ForEach-Object { Write-Host " $_" -ForegroundColor Red }
    }
} finally {
    Pop-Location
}

exit 0
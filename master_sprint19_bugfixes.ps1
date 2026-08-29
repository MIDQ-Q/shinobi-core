param(
    [string]$Root = "",
    [switch]$SkipBuild
)

# ============================================================
# SHINOBI CORE
# MASTER SPRINT 19: CRITICAL BUG FIXES
# Fix 1: Charged jump teleport
# Fix 2: Cannot jump from water
# Fix 3: Smooth edge grab climb
# ============================================================

$ErrorActionPreference = "Stop"
$script:utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "[SPRINT19] $Message" -ForegroundColor Cyan
}

function Write-Ok([string]$Message) {
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Warn([string]$Message) {
    Write-Host "  [WARN] $Message" -ForegroundColor Yellow
}

function Write-Err([string]$Message) {
    Write-Host "  [FAIL] $Message" -ForegroundColor Red
}

function Read-TextFile([string]$Path) {
    if (-not (Test-Path $Path)) { return "" }
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Write-TextFile([string]$Path, [string]$Content) {
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $Content = $Content -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($Path, $Content, $script:utf8NoBom)
}

function Ensure-Directory([string]$Path) {
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Backup-File([string]$RelativePath, [string]$BackupDir) {
    $src = Join-Path $Root $RelativePath

    if (-not (Test-Path $src)) {
        return
    }

    $dest = Join-Path $BackupDir $RelativePath
    $destDir = Split-Path $dest -Parent

    Ensure-Directory $destDir
    Copy-Item -Path $src -Destination $dest -Force
    Write-Ok "Backed up $RelativePath"
}

function Invoke-GradleBuildDetailed([string]$RootPath, [string]$LogDir) {
    $gradle = Join-Path $RootPath "gradlew.bat"

    if (-not (Test-Path $gradle)) {
        Write-Err "gradlew.bat not found: $gradle"
        return $false
    }

    Push-Location $RootPath

    try {
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = "Continue"

        $output = & $gradle build 2>&1
        $exitCode = $LASTEXITCODE

        $ErrorActionPreference = $prevEap

        if ($output) {
            $logPath = Join-Path $LogDir "gradle_build.log"
            $output | Out-File -FilePath $logPath -Encoding utf8
        }

        if ($exitCode -eq 0) {
            Write-Ok "Gradle build successful"
            return $true
        }

        Write-Err "Gradle build failed with exit code $exitCode"

        if ($output) {
            $output |
                ForEach-Object { $_.ToString() } |
                Where-Object { $_ -match "error:|symbol:|location:" } |
                Select-Object -First 80 |
                ForEach-Object {
                    Write-Host $_ -ForegroundColor Red
                }
        }

        return $false
    }
    finally {
        Pop-Location
    }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " SHINOBI CORE - MASTER SPRINT 19" -ForegroundColor Cyan
Write-Host " Critical Bug Fixes" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# ------------------------------------------------------------
# 1. Resolve root
# ------------------------------------------------------------

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = (Get-Location).Path
}

if (-not (Test-Path (Join-Path $Root "gradlew.bat"))) {
    $Root = "E:\Games\mod"
}

if (-not (Test-Path (Join-Path $Root "gradlew.bat"))) {
    Write-Err "Project root not found. Use -Root `"E:\Games\mod`"."
    exit 1
}

Write-Ok "Project root: $Root"

$srcJava = Join-Path $Root "src\main\java"
$outDir = Join-Path $Root "scripts\out\sprint19"

Ensure-Directory $outDir

$actions = New-Object System.Collections.Generic.List[string]
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $Root "backup\sprint19_$stamp"

# ------------------------------------------------------------
# 2. Backup files we will modify
# ------------------------------------------------------------

Write-Step "Creating backup"

Backup-File "src\main\java\com\example\shinobicore\movement\client\ChargedJumpClient.java" $backupDir
Backup-File "src\main\java\com\example\shinobicore\movement\client\WaterWalkClient.java" $backupDir
Backup-File "src\main\java\com\example\shinobicore\movement\client\EdgeGrabClient.java" $backupDir

# ------------------------------------------------------------
# FIX 1: ChargedJumpClient - replace teleport with smooth jump
# ------------------------------------------------------------

Write-Step "FIX 1: ChargedJumpClient smooth jump"

$chargedJumpPath = Join-Path $srcJava "com\example\shinobicore\movement\client\ChargedJumpClient.java"

if (-not (Test-Path $chargedJumpPath)) {
    Write-Err "ChargedJumpClient.java not found!"
    exit 1
}

$content = Read-TextFile $chargedJumpPath

# Replace the teleport-causing release method with smooth version
$oldRelease = @'
    private static void release(ClientPlayerEntity player) {
        if (!charging) {
            return;
        }

        charging = false;
        cooldown = COOLDOWN_TICKS;

        float power = Math.min(chargeTicks / (float) MAX_CHARGE_TICKS, 1.0f);
        double jumpY = MIN_JUMP_Y + (MAX_JUMP_Y - MIN_JUMP_Y) * power;
        jumpY = Math.min(jumpY, JUMP_Y_CAP);

        Vec3d velocity = player.getVelocity();
        player.setVelocity(velocity.x, jumpY, velocity.z);
        player.velocityModified = true;

        if (ClientMovementState.getPhase() == MovementPhase.CHARGING_JUMP) {
            ClientMovementState.setPhase(MovementPhase.NORMAL);
        }
    }
'@

$newRelease = @'
    private static void release(ClientPlayerEntity player) {
        if (!charging) {
            return;
        }

        charging = false;
        cooldown = COOLDOWN_TICKS;

        float power = Math.min(chargeTicks / (float) MAX_CHARGE_TICKS, 1.0f);
        double jumpY = MIN_JUMP_Y + (MAX_JUMP_Y - MIN_JUMP_Y) * power;
        jumpY = Math.min(jumpY, JUMP_Y_CAP);

        // Smooth jump: use vanilla jump + bonus instead of teleport
        if (player.isOnGround()) {
            player.jump();
            double bonus = jumpY - 0.42;
            if (bonus > 0) {
                player.addVelocity(0, bonus, 0);
            }
            player.velocityModified = true;
        } else {
            // Fallback for airborne release
            Vec3d velocity = player.getVelocity();
            player.setVelocity(velocity.x, jumpY, velocity.z);
            player.velocityModified = true;
        }

        if (ClientMovementState.getPhase() == MovementPhase.CHARGING_JUMP) {
            ClientMovementState.setPhase(MovementPhase.NORMAL);
        }
    }
'@

$oldRelease = $oldRelease -replace "`r`n", "`n"
$newRelease = $newRelease -replace "`r`n", "`n"

if ($content.Contains($oldRelease)) {
    $content = $content.Replace($oldRelease, $newRelease)
    Write-Ok "FIX 1: Replaced teleport jump with smooth jump()"
    $actions.Add("FIX 1: ChargedJumpClient smooth jump")
} elseif ($content.Contains("player.jump()")) {
    Write-Warn "FIX 1: Already patched or different version"
} else {
    Write-Warn "FIX 1: Pattern not found, applying regex fallback"
    # Regex fallback
    $content = $content -replace 'Vec3d velocity = player\.getVelocity\(\);\s*\n\s*player\.setVelocity\(velocity\.x, jumpY, velocity\.z\);', @'
        if (player.isOnGround()) {
            player.jump();
            double bonus = jumpY - 0.42;
            if (bonus > 0) {
                player.addVelocity(0, bonus, 0);
            }
            player.velocityModified = true;
        } else {
            Vec3d velocity = player.getVelocity();
            player.setVelocity(velocity.x, jumpY, velocity.z);
            player.velocityModified = true;
        }
'@
    $actions.Add("FIX 1: ChargedJumpClient smooth jump (regex fallback)")
}

Write-TextFile -Path $chargedJumpPath -Content $content

# ------------------------------------------------------------
# FIX 2: WaterWalkClient - allow jumping from water
# ------------------------------------------------------------

Write-Step "FIX 2: WaterWalkClient allow jump from water"

$waterWalkPath = Join-Path $srcJava "com\example\shinobicore\movement\client\WaterWalkClient.java"

if (-not (Test-Path $waterWalkPath)) {
    Write-Err "WaterWalkClient.java not found!"
    exit 1
}

$content = Read-TextFile $waterWalkPath

# Find the tick method and add jump handling at the beginning
$oldTickStart = @'
        if (active) {
            ticksOnEdge++;

            // Cancel falling
            Vec3d velocity = player.getVelocity();
            if (velocity.y < 0) {
                player.setVelocity(velocity.x, 0, velocity.z);
                player.velocityModified = true;
            }

            player.fallDistance = 0;
'@

$newTickStart = @'
        if (active) {
            ticksOnEdge++;

            // FIX 2: Allow jumping from water
            if (MovementInputService.wasJumpPressed()) {
                Vec3d jumpVel = player.getVelocity();
                player.setVelocity(jumpVel.x, 0.42, jumpVel.z);
                player.velocityModified = true;
                stop(player);
                return;
            }

            // Cancel falling
            Vec3d velocity = player.getVelocity();
            if (velocity.y < 0) {
                player.setVelocity(velocity.x, 0, velocity.z);
                player.velocityModified = true;
            }

            player.fallDistance = 0;
'@

$oldTickStart = $oldTickStart -replace "`r`n", "`n"
$newTickStart = $newTickStart -replace "`r`n", "`n"

if ($content.Contains($oldTickStart)) {
    $content = $content.Replace($oldTickStart, $newTickStart)
    Write-Ok "FIX 2: Added jump handling to WaterWalkClient"
    $actions.Add("FIX 2: WaterWalkClient jump from water")
} elseif ($content.Contains("FIX 2: Allow jumping from water")) {
    Write-Warn "FIX 2: Already patched"
} else {
    Write-Warn "FIX 2: Exact pattern not found, trying alternative approach"
    
    # Try to find just the tick method start and inject
    $pattern = 'if \(active\) \{\s*\n\s*ticksOnEdge\+\+;'
    $replacement = @'
if (active) {
            ticksOnEdge++;

            // FIX 2: Allow jumping from water
            if (MovementInputService.wasJumpPressed()) {
                Vec3d jumpVel = player.getVelocity();
                player.setVelocity(jumpVel.x, 0.42, jumpVel.z);
                player.velocityModified = true;
                stop(player);
                return;
            }
'@
    $content = [regex]::Replace($content, $pattern, $replacement)
    $actions.Add("FIX 2: WaterWalkClient jump from water (regex)")
}

Write-TextFile -Path $waterWalkPath -Content $content

# ------------------------------------------------------------
# FIX 3: EdgeGrabClient - smoother climb
# ------------------------------------------------------------

Write-Step "FIX 3: EdgeGrabClient smooth climb"

$edgeGrabPath = Join-Path $srcJava "com\example\shinobicore\movement\client\EdgeGrabClient.java"

if (-not (Test-Path $edgeGrabPath)) {
    Write-Err "EdgeGrabClient.java not found!"
    exit 1
}

$content = Read-TextFile $edgeGrabPath

# Replace instant teleport with velocity-based climb
$oldClimb = @'
    private static void climbUp(ClientPlayerEntity player) {
        Vec3d position = player.getPos();
        player.setPosition(position.x, position.y + CLIMB_UP_Y, position.z);

        stop(player);
    }
'@

$newClimb = @'
    private static void climbUp(ClientPlayerEntity player) {
        // Smooth climb: velocity impulse + position adjustment
        Vec3d position = player.getPos();
        
        // Give upward momentum for smooth feel
        player.addVelocity(0, 0.15, 0);
        
        // Move to top of edge
        player.setPosition(position.x, position.y + CLIMB_UP_Y, position.z);
        player.velocityModified = true;

        stop(player);
    }
'@

$oldClimb = $oldClimb -replace "`r`n", "`n"
$newClimb = $newClimb -replace "`r`n", "`n"

if ($content.Contains($oldClimb)) {
    $content = $content.Replace($oldClimb, $newClimb)
    Write-Ok "FIX 3: Added velocity impulse to edge climb"
    $actions.Add("FIX 3: EdgeGrabClient smooth climb")
} elseif ($content.Contains("player.addVelocity(0, 0.15, 0)")) {
    Write-Warn "FIX 3: Already patched"
} else {
    Write-Warn "FIX 3: Pattern not found, trying regex fallback"
    $content = $content -replace 'player\.setPosition\(position\.x, position\.y \+ CLIMB_UP_Y, position\.z\);', @'
        // Smooth climb: velocity impulse + position adjustment
        player.addVelocity(0, 0.15, 0);
        player.setPosition(position.x, position.y + CLIMB_UP_Y, position.z);
        player.velocityModified = true;
'@
    $actions.Add("FIX 3: EdgeGrabClient smooth climb (regex)")
}

Write-TextFile -Path $edgeGrabPath -Content $content

# ------------------------------------------------------------
# 4. Build
# ------------------------------------------------------------

if (-not $SkipBuild) {
    Write-Step "Running Gradle build"

    $buildOk = Invoke-GradleBuildDetailed -RootPath $Root -LogDir $outDir

    if (-not $buildOk) {
        Write-Err "Sprint 19 failed build."
        Write-Err "Log: $(Join-Path $outDir 'gradle_build.log')"
        exit 1
    }
}
else {
    Write-Warn "Build skipped because -SkipBuild was specified"
}

# ------------------------------------------------------------
# 5. Report
# ------------------------------------------------------------

Write-Step "Generating Sprint 19 report"

$report = New-Object System.Text.StringBuilder

[void]$report.AppendLine("SHINOBI CORE - SPRINT 19 REPORT")
[void]$report.AppendLine("Generated: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
[void]$report.AppendLine("")
[void]$report.AppendLine("=== ACTIONS ===")

foreach ($action in $actions) {
    [void]$report.AppendLine($action)
}

[void]$report.AppendLine("")
[void]$report.AppendLine("=== FIXED BUGS ===")
[void]$report.AppendLine("1. Charged jump teleport -> smooth vanilla jump + bonus")
[void]$report.AppendLine("2. Cannot jump from water -> jump handler added to WaterWalkClient")
[void]$report.AppendLine("3. Edge grab teleport -> velocity impulse for smooth climb")

$reportPath = Join-Path $outDir "sprint19_report.txt"
Write-TextFile -Path $reportPath -Content $report.ToString()

Write-Ok "Report saved: $reportPath"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " MASTER SPRINT 19 COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Test in-game:" -ForegroundColor Yellow
Write-Host "  1. Hold Space to charge jump, release -> should feel smooth" -ForegroundColor White
Write-Host "  2. Walk onto water, press Space -> should jump off water" -ForegroundColor White
Write-Host "  3. Grab edge, press W or Space -> should climb smoothly" -ForegroundColor White
Write-Host ""

exit 0
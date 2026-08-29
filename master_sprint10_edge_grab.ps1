param(
    [string]$Root = "",
    [switch]$SkipBuild
)

# ============================================================
# SHINOBI CORE
# MASTER SPRINT 10: EDGE GRAB FOUNDATION
# ============================================================

$ErrorActionPreference = "Stop"
$script:utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "[SPRINT10] $Message" -ForegroundColor Cyan
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
Write-Host " SHINOBI CORE - MASTER SPRINT 10" -ForegroundColor Cyan
Write-Host " Edge Grab foundation" -ForegroundColor Cyan
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
$outDir = Join-Path $Root "scripts\out\sprint10"

Ensure-Directory $outDir

$actions = New-Object System.Collections.Generic.List[string]
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $Root "backup\sprint10_$stamp"

# ------------------------------------------------------------
# 2. Backup files we will overwrite
# ------------------------------------------------------------

Write-Step "Creating backup"

Backup-File "src\main\java\com\example\shinobicore\movement\client\ClientMovementService.java" $backupDir
Backup-File "src\main\java\com\example\shinobicore\movement\client\EdgeGrabClient.java" $backupDir

# ------------------------------------------------------------
# 3. Create EdgeGrabClient
# ------------------------------------------------------------

Write-Step "Creating EdgeGrabClient"

$edgeGrabPath = Join-Path $srcJava "com\example\shinobicore\movement\client\EdgeGrabClient.java"

$edgeGrabContent = @'
// SHINOBICORE:SPRINT10:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.World;

/**
 * SPRINT 10 edge grab foundation.
 *
 * Entry:
 * - player is in air and falling
 * - there is a block edge below at body level
 * - there is headroom above the edge
 *
 * Behavior:
 * - grab edge and stop falling
 * - hold W or press Space to climb up
 * - press S or Shift to release
 * - cooldown after grab
 */
public final class EdgeGrabClient {
    public static final int COOLDOWN_TICKS = 20;
    public static final int MAX_HANG_TICKS = 40;
    public static final double CLIMB_UP_Y = 1.5;

    private static boolean active = false;
    private static int ticksOnEdge = 0;
    private static int cooldown = 0;

    private EdgeGrabClient() {}

    public static boolean isActive() {
        return active;
    }

    public static void tick(ClientPlayerEntity player) {
        if (cooldown > 0) {
            cooldown--;
        }

        if (!FeatureFlags.edgeGrab) {
            stop(player);
            return;
        }

        if (WaterWalkClient.isActive()) {
            stop(player);
            return;
        }

        if (WallRunClient.isActive()) {
            stop(player);
            return;
        }

        if (RollClient.isActive()) {
            stop(player);
            return;
        }

        if (DodgeClient.isActive()) {
            stop(player);
            return;
        }

        if (player.isTouchingWater()) {
            stop(player);
            return;
        }

        if (active) {
            ticksOnEdge++;

            // Cancel falling
            Vec3d velocity = player.getVelocity();
            if (velocity.y < 0) {
                player.setVelocity(velocity.x, 0, velocity.z);
                player.velocityModified = true;
            }

            player.fallDistance = 0;

            // Climb up: hold W or press Space
            if (MovementInputService.isMovingForward(player) || MovementInputService.wasJumpPressed()) {
                climbUp(player);
                return;
            }

            // Release: press S or sneak
            if (MovementInputService.isSneaking(player) || MovementInputService.getForwardInput(player) < -0.1f) {
                stop(player);
                return;
            }

            // Timeout: too long hanging
            if (ticksOnEdge > MAX_HANG_TICKS) {
                stop(player);
                return;
            }

            return;
        }

        if (cooldown > 0) {
            return;
        }

        if (player.isOnGround()) {
            return;
        }

        if (player.getVelocity().y > -0.1) {
            return;
        }

        if (tryGrab(player)) {
            start(player);
        }
    }

    private static boolean tryGrab(ClientPlayerEntity player) {
        Vec3d look = getHorizontalLook(player);

        if (look == null) {
            return false;
        }

        Vec3d feetPos = player.getPos();
        Vec3d checkPos = feetPos.add(look.x * 0.5, -0.5, look.z * 0.5);

        BlockPos blockPos = new BlockPos(checkPos);
        World world = player.getWorld();

        // Block at body level (the edge)
        boolean hasEdge = !world.isAir(blockPos);

        // Headroom above the edge (where player will climb)
        BlockPos headPos = blockPos.up(2);
        boolean hasHeadroom = world.isAir(headPos) || world.isAir(headPos.up(1));

        return hasEdge && hasHeadroom;
    }

    private static void start(ClientPlayerEntity player) {
        active = true;
        ticksOnEdge = 0;
        cooldown = COOLDOWN_TICKS;

        ClientMovementState.setPhase(MovementPhase.EDGE_GRABBING);

        // Stop all movement
        player.setVelocity(0, 0, 0);
        player.velocityModified = true;
        player.fallDistance = 0;
    }

    private static void climbUp(ClientPlayerEntity player) {
        Vec3d position = player.getPos();
        player.setPosition(position.x, position.y + CLIMB_UP_Y, position.z);

        stop(player);
    }

    private static void stop(ClientPlayerEntity player) {
        if (!active) {
            return;
        }

        active = false;
        ticksOnEdge = 0;

        if (ClientMovementState.getPhase() == MovementPhase.EDGE_GRABBING) {
            ClientMovementState.setPhase(MovementPhase.NORMAL);
        }
    }

    private static Vec3d getHorizontalLook(ClientPlayerEntity player) {
        Vec3d rotation = player.getRotationVector();
        Vec3d horizontal = new Vec3d(rotation.x, 0.0, rotation.z);

        if (horizontal.lengthSquared() < 1.0E-6) {
            return null;
        }

        return horizontal.normalize();
    }
}
'@

Write-TextFile -Path $edgeGrabPath -Content $edgeGrabContent
Write-Ok "Created EdgeGrabClient.java"
$actions.Add("Created EdgeGrabClient.java")

# ------------------------------------------------------------
# 4. Rewrite ClientMovementService
# ------------------------------------------------------------

Write-Step "Rewriting ClientMovementService"

$servicePath = Join-Path $srcJava "com\example\shinobicore\movement\client\ClientMovementService.java"

$serviceContent = @'
// SHINOBICORE:SPRINT10:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.common.MovementPhase;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;

/**
 * SPRINT 10 central client movement tick handler.
 */
public final class ClientMovementService {
    private static boolean registered = false;

    private ClientMovementService() {}

    public static void register() {
        if (registered) return;
        registered = true;
        ClientTickEvents.END_CLIENT_TICK.register(ClientMovementService::tickClient);
    }

    private static void tickClient(MinecraftClient client) {
        if (!FeatureFlags.movementV3) return;
        if (client == null || client.player == null || client.world == null) return;
        if (client.isPaused()) return;
        if (client.currentScreen != null) return;
        if (client.player.isDead()) return;

        // Update state timers
        ClientMovementState.tick();

        // Update input edge states
        MovementInputService.update(client.player);
        RollDodgeInputHandler.update(client.player);

        // Jump grace for wall entry
        if (MovementInputService.wasJumpPressed()) {
            ClientMovementState.setJumpGraceTicks(6);
        }

        // Tick subsystems
        WaterWalkClient.tick(client.player);
        WallRunClient.tick(client.player);
        RollClient.tick(client.player);
        DodgeClient.tick(client.player);
        SlideClient.tick(client.player);
        CrawlClient.tick(client.player);
        ChargedJumpClient.tick(client.player);
        DoubleJumpClient.tick(client.player);
        EdgeGrabClient.tick(client.player);

        // If no subsystem is active, reset phase to NORMAL
        if (!WaterWalkClient.isActive()
                && !WallRunClient.isActive()
                && !RollClient.isActive()
                && !DodgeClient.isActive()
                && !SlideClient.isActive()
                && !CrawlClient.isActive()
                && !ChargedJumpClient.isCharging()
                && !EdgeGrabClient.isActive()) {

            if (ClientMovementState.getPhase() != MovementPhase.NORMAL) {
                ClientMovementState.setPhase(MovementPhase.NORMAL);
            }
        }
    }
}
'@

Write-TextFile -Path $servicePath -Content $serviceContent
Write-Ok "Rewrote ClientMovementService.java"
$actions.Add("Rewrote ClientMovementService.java")

# ------------------------------------------------------------
# 5. Build
# ------------------------------------------------------------

if (-not $SkipBuild) {
    Write-Step "Running Gradle build"

    $buildOk = Invoke-GradleBuildDetailed -RootPath $Root -LogDir $outDir

    if (-not $buildOk) {
        Write-Err "Sprint 10 failed build."
        Write-Err "Log: $(Join-Path $outDir 'gradle_build.log')"
        exit 1
    }
}
else {
    Write-Warn "Build skipped because -SkipBuild was specified"
}

# ------------------------------------------------------------
# 6. Report
# ------------------------------------------------------------

Write-Step "Generating Sprint 10 report"

$report = New-Object System.Text.StringBuilder

[void]$report.AppendLine("SHINOBI CORE - SPRINT 10 REPORT")
[void]$report.AppendLine("Generated: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
[void]$report.AppendLine("")
[void]$report.AppendLine("=== ACTIONS ===")

foreach ($action in $actions) {
    [void]$report.AppendLine($action)
}

$reportPath = Join-Path $outDir "sprint10_report.txt"
Write-TextFile -Path $reportPath -Content $report.ToString()

Write-Ok "Report saved: $reportPath"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " MASTER SPRINT 10 COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Test in-game:" -ForegroundColor Yellow
Write-Host "  1. Jump off a ledge and fall toward a wall/edge" -ForegroundColor White
Write-Host "  2. Player should auto-grab the edge" -ForegroundColor White
Write-Host "  3. Hold W or press Space to climb up" -ForegroundColor White
Write-Host "  4. Press S or Shift to release" -ForegroundColor White
Write-Host "  5. Land on ground -> Edge grab resets" -ForegroundColor White
Write-Host ""
Write-Host "Next step: MASTER SPRINT 11 (Meditation + Chakra sync polish)" -ForegroundColor Yellow
Write-Host ""

exit 0
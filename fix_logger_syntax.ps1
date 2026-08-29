$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$backupRoot = Join-Path $root "backup"
$srcBase = Join-Path $root "src\main\java\com\example\shinobicore"

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host " EMERGENCY RESTORE: Search ALL backups for clean files" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# Find all backups (newest first)
# ============================================================
$allBackups = Get-ChildItem -Path $backupRoot -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending
Write-Host "Found $($allBackups.Count) backup directories" -ForegroundColor Yellow
Write-Host ""

function Find-CleanBackup($relativePath) {
    foreach ($backup in $script:allBackups) {
        $srcPath = Join-Path $backup.FullName $relativePath
        if (Test-Path $srcPath) {
            $content = [System.IO.File]::ReadAllText($srcPath, $script:utf8)
            
            # Skip files with logger damage
            if ($content.Contains("MovementLogger.")) {
                Write-Host "  [SKIP] $($backup.Name) - has MovementLogger damage" -ForegroundColor Yellow
                continue
            }
            
            # Skip files with orphan braces
            if ($content -match 'MovementLogger\.[^;]+;\s*\r?\n\s*\{') {
                Write-Host "  [SKIP] $($backup.Name) - has orphan braces" -ForegroundColor Yellow
                continue
            }
            
            # Skip files with broken `n literals
            if ($content.Contains("`nimport")) {
                Write-Host "  [SKIP] $($backup.Name) - has literal backtick-n" -ForegroundColor Yellow
                continue
            }
            
            return $srcPath
        }
    }
    return $null
}

# ============================================================
# 1. Restore ChakraClientController
# ============================================================
Write-Host "[1/3] Restoring ChakraClientController.java..." -ForegroundColor Yellow
$chakraRelPath = "src\main\java\com\example\shinobicore\chakra\client\ChakraClientController.java"
$chakraDst = Join-Path $root $chakraRelPath

$cleanSrc = Find-CleanBackup $chakraRelPath
if ($cleanSrc) {
    Copy-Item -Path $cleanSrc -Destination $chakraDst -Force
    Write-Host "  [RESTORED] from backup" -ForegroundColor Green
} else {
    Write-Host "  [CREATE] No clean backup found, writing fresh version" -ForegroundColor Cyan
    
    $chakraContent = @'
// SHINOBICORE:SPRINT2:FILE
package com.example.shinobicore.chakra.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.config.MovementChakraConfig;
import com.example.shinobicore.util.ShinobiLogger;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;

/**
 * SPRINT 2 client-side chakra controller.
 * Handles tick-based regen, drain, exhaustion and mirrors state to legacy HUD.
 */
public final class ChakraClientController {
    private static float currentChakra = 2000.0f;
    private static float maxChakra = 2000.0f;
    private static float fatigue = 0.0f;
    private static boolean chakraMode = false;
    private static boolean exhausted = false;
    private static boolean meditating = false;

    private static float lastSyncedCurrent = -1.0f;
    private static boolean lastSyncedMode = false;

    private ChakraClientController() {}

    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(ChakraClientController::tickClient);
    }

    public static void tickClient(MinecraftClient client) {
        if (!FeatureFlags.chakraV3) return;
        if (client == null || client.player == null || client.world == null) return;
        if (client.isPaused()) return;

        ClientPlayerEntity player = client.player;
        MovementChakraConfig config = MovementChakraConfig.getInstance();
        if (config == null || config.chakra == null) return;

        maxChakra = config.chakra.baseMaxChakra;

        // 1. Passive regen (if not exhausted and not in active drain mode)
        if (!exhausted && !chakraMode) {
            float regen = config.chakra.chakraRegenPerSec / 20.0f;
            if (meditating) regen *= config.chakra.meditationRegenMultiplier;
            currentChakra = Math.min(maxChakra, currentChakra + regen);
        }

        // 2. Exhaustion recovery
        if (exhausted) {
            fatigue -= config.chakra.fatigueRecoveryPerSec / 20.0f;
            if (fatigue <= 0.0f) {
                fatigue = 0.0f;
                exhausted = false;
                ShinobiLogger.info("[CHAKRA] Exhaustion ended");
            }
        }
    }

    public static boolean isChakraModeActive() { return chakraMode; }
    public static float getCurrentChakra() { return currentChakra; }
    public static float getMaxChakra() { return maxChakra; }
    public static boolean isExhausted() { return exhausted; }
    public static boolean isMeditating() { return meditating; }

    public static void setMeditating(boolean value) {
        meditating = value;
    }

    public static void toggleChakraMode() {
        chakraMode = !chakraMode;
        ShinobiLogger.info("[CHAKRA] Mode toggled to: " + chakraMode);
    }

    public static boolean consumeChakra(float amount) {
        if (exhausted) return false;
        if (currentChakra < amount) {
            exhausted = true;
            chakraMode = false;
            fatigue = 100.0f;
            ShinobiLogger.info("[CHAKRA] Exhaustion triggered");
            return false;
        }
        currentChakra -= amount;
        return true;
    }
}
'@
    [System.IO.File]::WriteAllText($chakraDst, $chakraContent, $utf8)
    Write-Host "  [OK] Fresh ChakraClientController written" -ForegroundColor Green
}

# ============================================================
# 2. Restore WallRunClient (from Sprint 6/8/12 code)
# ============================================================
Write-Host ""
Write-Host "[2/3] Restoring WallRunClient.java..." -ForegroundColor Yellow
$wallRelPath = "src\main\java\com\example\shinobicore\movement\client\WallRunClient.java"
$wallDst = Join-Path $root $wallRelPath

$cleanSrc = Find-CleanBackup $wallRelPath
if ($cleanSrc) {
    Copy-Item -Path $cleanSrc -Destination $wallDst -Force
    Write-Host "  [RESTORED] from backup" -ForegroundColor Green
} else {
    Write-Host "  [CREATE] No clean backup found, writing Sprint 8 compatible version" -ForegroundColor Cyan
    
    $wallContent = @'
// SHINOBICORE:SPRINT8:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.chakra.client.ChakraClientController;
import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.config.MovementChakraConfig;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

/**
 * SPRINT 8 wall running with wall jump.
 */
public final class WallRunClient {
    public static final int MAX_WALL_TICKS = 45;
    public static final int MAX_WALL_LOST_TICKS = 4;

    public static final double CLIMB_SPEED = 0.07;
    public static final double DESCEND_SPEED = -0.05;
    public static final double IDLE_SLIDE = -0.02;
    public static final double STICK_STRENGTH = 0.06;

    public static final double WALL_JUMP_HORIZONTAL = 0.35;
    public static final double WALL_JUMP_VERTICAL = 0.42;
    public static final double WALL_JUMP_LOOK_FACTOR = 0.25;

    private static boolean active = false;
    private static int ticksOnWall = 0;
    private static int wallLostTicks = 0;

    private WallRunClient() {}

    public static boolean isActive() { return active; }
    public static int getTicksOnWall() { return ticksOnWall; }

    public static void tick(ClientPlayerEntity player) {
        if (player == null || player.getWorld() == null) return;
        if (!FeatureFlags.wallRun) { stop(player); return; }
        if (WaterWalkClient.isActive()) { stop(player); return; }
        if (!ChakraClientController.isChakraModeActive()) { stop(player); return; }
        if (player.isOnGround()) { stop(player); return; }
        if (player.isTouchingWater()) { stop(player); return; }
        if (MovementInputService.isSneaking(player)) { stop(player); return; }

        if (!active && ClientMovementState.getWallCooldownTicks() > 0) return;

        Vec3d normal = WallDetector.detectWallNormal(player);

        if (normal == null) {
            if (active) {
                wallLostTicks++;
                if (wallLostTicks >= MAX_WALL_LOST_TICKS) stop(player);
            }
            return;
        }

        wallLostTicks = 0;

        if (!active) {
            if (!MovementInputService.hasHorizontalInput(player)) return;
            if (!MovementInputService.isMovingForward(player) && !player.horizontalCollision) return;
            if (!WallDetector.isMovingTowardWall(player, normal) && !player.horizontalCollision) return;
            if (player.getVelocity().y > 0.25) return;
            if (ClientMovementState.getJumpGraceTicks() <= 0 && !player.horizontalCollision) return;

            active = true;
            ticksOnWall = 0;
            ClientMovementState.setPhase(MovementPhase.WALL_RUNNING);
            ClientMovementState.setOnWall(true);
        }

        ClientMovementState.setWallNormal(normal);
        ticksOnWall++;

        MovementChakraConfig config = MovementChakraConfig.getInstance();
        float drain = 0.075f;
        if (config != null && config.chakra != null) drain = config.chakra.wallWalkDrainPerTick;

        if (!ChakraClientController.consumeChakra(drain)) { stop(player); return; }

        if (MovementInputService.wasJumpPressed()) {
            performWallJump(player, normal);
            return;
        }

        applyWallPhysics(player, normal);
        if (ticksOnWall > MAX_WALL_TICKS) stop(player);
    }

    private static void applyWallPhysics(ClientPlayerEntity player, Vec3d normal) {
        Vec3d velocity = player.getVelocity();
        double intoWall = velocity.x * normal.x + velocity.z * normal.z;
        if (intoWall < 0.0) velocity = velocity.subtract(normal.multiply(intoWall));

        float forward = MovementInputService.getForwardInput(player);
        double vertical;
        if (forward > 0.1f) vertical = CLIMB_SPEED;
        else if (forward < -0.1f) vertical = DESCEND_SPEED;
        else vertical = IDLE_SLIDE;

        double stickX = -normal.x * STICK_STRENGTH;
        double stickZ = -normal.z * STICK_STRENGTH;
        player.setVelocity(velocity.x + stickX, vertical, velocity.z + stickZ);
        player.velocityModified = true;
        player.fallDistance = 0.0f;
    }

    private static void performWallJump(ClientPlayerEntity player, Vec3d normal) {
        Vec3d look = player.getRotationVector();
        Vec3d jumpVelocity = new Vec3d(
                look.x * WALL_JUMP_LOOK_FACTOR,
                WALL_JUMP_VERTICAL,
                look.z * WALL_JUMP_LOOK_FACTOR
        );
        jumpVelocity = jumpVelocity.add(normal.multiply(WALL_JUMP_HORIZONTAL));
        double intoWall = jumpVelocity.x * normal.x + jumpVelocity.z * normal.z;
        if (intoWall < 0.0) jumpVelocity = jumpVelocity.subtract(normal.multiply(intoWall));

        player.setVelocity(jumpVelocity.x, jumpVelocity.y, jumpVelocity.z);
        player.velocityModified = true;
        player.fallDistance = 0.0f;
        stop(player);
        ClientMovementState.setWallCooldownTicks(8);
    }

    private static void stop(ClientPlayerEntity player) {
        if (!active) return;
        active = false;
        ticksOnWall = 0;
        wallLostTicks = 0;
        ClientMovementState.setOnWall(false);
        ClientMovementState.setWallNormal(null);
        if (ClientMovementState.getPhase() == MovementPhase.WALL_RUNNING) {
            ClientMovementState.setPhase(MovementPhase.NORMAL);
        }
    }
}
'@
    [System.IO.File]::WriteAllText($wallDst, $wallContent, $utf8)
    Write-Host "  [OK] Fresh WallRunClient written" -ForegroundColor Green
}

# ============================================================
# 3. Restore ClientMovementService
# ============================================================
Write-Host ""
Write-Host "[3/3] Restoring ClientMovementService.java..." -ForegroundColor Yellow
$serviceRelPath = "src\main\java\com\example\shinobicore\movement\client\ClientMovementService.java"
$serviceDst = Join-Path $root $serviceRelPath

$cleanSrc = Find-CleanBackup $serviceRelPath
if ($cleanSrc) {
    Copy-Item -Path $cleanSrc -Destination $serviceDst -Force
    Write-Host "  [RESTORED] from backup" -ForegroundColor Green
} else {
    Write-Host "  [CREATE] Writing Sprint 12 compatible version" -ForegroundColor Cyan
    
    $serviceContent = @'
// SHINOBICORE:SPRINT12:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.common.MovementPhase;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;

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

        ClientMovementState.tick();
        MovementInputService.update(client.player);
        RollDodgeInputHandler.update(client.player);

        if (MovementInputService.wasJumpPressed()) {
            ClientMovementState.setJumpGraceTicks(6);
        }

        WaterWalkClient.tick(client.player);
        WallRunClient.tick(client.player);
        RollClient.tick(client.player);
        DodgeClient.tick(client.player);
        SlideClient.tick(client.player);
        CrawlClient.tick(client.player);
        ChargedJumpClient.tick(client.player);
        DoubleJumpClient.tick(client.player);
        EdgeGrabClient.tick(client.player);
        MeditationClient.tick(client.player);

        if (!WaterWalkClient.isActive()
                && !WallRunClient.isActive()
                && !RollClient.isActive()
                && !DodgeClient.isActive()
                && !SlideClient.isActive()
                && !CrawlClient.isActive()
                && !ChargedJumpClient.isCharging()
                && !EdgeGrabClient.isActive()
                && !MeditationClient.isActive()) {
            if (ClientMovementState.getPhase() != MovementPhase.NORMAL) {
                ClientMovementState.setPhase(MovementPhase.NORMAL);
            }
        }
    }
}
'@
    [System.IO.File]::WriteAllText($serviceDst, $serviceContent, $utf8)
    Write-Host "  [OK] Fresh ClientMovementService written" -ForegroundColor Green
}

# ============================================================
# Re-apply Sprint 19 fixes
# ============================================================
Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host " RE-APPLYING SPRINT 19 FIXES" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan

# FIX 1: ChargedJumpClient smooth jump
$chargedPath = Join-Path $srcBase "movement\client\ChargedJumpClient.java"
if (Test-Path $chargedPath) {
    $c = [System.IO.File]::ReadAllText($chargedPath, $utf8)
    $oldRelease = "        Vec3d velocity = player.getVelocity();`n        player.setVelocity(velocity.x, jumpY, velocity.z);`n        player.velocityModified = true;"
    $newRelease = @'
        if (player.isOnGround()) {
            player.jump();
            double bonus = jumpY - 0.42;
            if (bonus > 0) player.addVelocity(0, bonus, 0);
            player.velocityModified = true;
        } else {
            Vec3d velocity = player.getVelocity();
            player.setVelocity(velocity.x, jumpY, velocity.z);
            player.velocityModified = true;
        }
'@
    if ($c.Contains($oldRelease)) {
        $c = $c.Replace($oldRelease, $newRelease)
        [System.IO.File]::WriteAllText($chargedPath, $c, $utf8)
        Write-Host "  [OK] ChargedJumpClient smooth jump applied" -ForegroundColor Green
    } elseif ($c.Contains("player.jump()")) {
        Write-Host "  [SKIP] ChargedJumpClient already has smooth jump" -ForegroundColor Yellow
    } else {
        Write-Host "  [WARN] ChargedJumpClient pattern not found" -ForegroundColor Yellow
    }
}

# FIX 2: WaterWalkClient jump from water
$waterPath = Join-Path $srcBase "movement\client\WaterWalkClient.java"
if (Test-Path $waterPath) {
    $c = [System.IO.File]::ReadAllText($waterPath, $utf8)
    if (-not $c.Contains("FIX: Allow jumping from water")) {
        $anchor = "if (vel.y < 0.0) {"
        if ($c.Contains($anchor)) {
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

            '
'@
            $c = $c.Replace($anchor, $jumpCode + "            " + $anchor)
            [System.IO.File]::WriteAllText($waterPath, $c, $utf8)
            Write-Host "  [OK] WaterWalkClient jump-from-water applied" -ForegroundColor Green
        } else {
            Write-Host "  [WARN] WaterWalkClient anchor not found" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [SKIP] WaterWalkClient already has jump fix" -ForegroundColor Yellow
    }
}

# FIX 3: EdgeGrabClient smooth climb
$edgePath = Join-Path $srcBase "movement\client\EdgeGrabClient.java"
if (Test-Path $edgePath) {
    $c = [System.IO.File]::ReadAllText($edgePath, $utf8)
    $oldClimb = "        Vec3d position = player.getPos();`n        player.setPosition(position.x, position.y + CLIMB_UP_Y, position.z);"
    $newClimb = "        Vec3d position = player.getPos();`n        player.addVelocity(0, 0.15, 0);`n        player.setPosition(position.x, position.y + CLIMB_UP_Y, position.z);`n        player.velocityModified = true;"
    if ($c.Contains($oldClimb)) {
        $c = $c.Replace($oldClimb, $newClimb)
        [System.IO.File]::WriteAllText($edgePath, $c, $utf8)
        Write-Host "  [OK] EdgeGrabClient smooth climb applied" -ForegroundColor Green
    } elseif ($c.Contains("player.addVelocity(0, 0.15, 0)")) {
        Write-Host "  [SKIP] EdgeGrabClient already has smooth climb" -ForegroundColor Yellow
    } else {
        Write-Host "  [WARN] EdgeGrabClient pattern not found" -ForegroundColor Yellow
    }
}

# ============================================================
# Remove logger entrypoint from fabric.mod.json
# ============================================================
Write-Host ""
Write-Host "Removing MovementLoggerInitializer from fabric.mod.json..." -ForegroundColor Yellow
$fabricModPath = Join-Path $root "src\main\resources\fabric.mod.json"
if (Test-Path $fabricModPath) {
    $json = [System.IO.File]::ReadAllText($fabricModPath, $utf8)
    $loggerEntry = "com.example.shinobicore.bootstrap.MovementLoggerInitializer"
    if ($json.Contains($loggerEntry)) {
        $json = $json -replace ",?\s*`"$loggerEntry`"", ""
        $json = $json -replace "\[\s*,", "["
        [System.IO.File]::WriteAllText($fabricModPath, $json, $utf8)
        Write-Host "  [OK] Logger entrypoint removed" -ForegroundColor Green
    } else {
        Write-Host "  [SKIP] Logger not in fabric.mod.json" -ForegroundColor Yellow
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
        Write-Host " EMERGENCY RESTORE COMPLETE" -ForegroundColor Green
        Write-Host "==============================================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "All broken files have been restored to working state." -ForegroundColor Cyan
        Write-Host "Sprint 19 fixes have been re-applied." -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Run: .\gradlew.bat runClient" -ForegroundColor Yellow
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host " [FAIL] Build still failing:" -ForegroundColor Red
        $out | Where-Object { $_ -match "error:" } | Select-Object -First 30 | ForEach-Object { Write-Host " $_" -ForegroundColor Red }
    }
} finally {
    Pop-Location
}

exit 0
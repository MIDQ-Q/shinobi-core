param(
    [string]$Root = "",
    [switch]$SkipBuild
)

# ============================================================
# SHINOBI CORE
# MASTER SPRINT 8: ROLL + DODGE FOUNDATION
# ============================================================

$ErrorActionPreference = "Stop"
$script:utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "[SPRINT8] $Message" -ForegroundColor Cyan
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
Write-Host " SHINOBI CORE - MASTER SPRINT 8" -ForegroundColor Cyan
Write-Host " Roll + Dodge foundation" -ForegroundColor Cyan
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
$outDir = Join-Path $Root "scripts\out\sprint8"

Ensure-Directory $outDir

$actions = New-Object System.Collections.Generic.List[string]
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $Root "backup\sprint8_$stamp"

# ------------------------------------------------------------
# 2. Backup files we will overwrite
# ------------------------------------------------------------

Write-Step "Creating backup"

Backup-File "src\main\java\com\example\shinobicore\movement\client\ClientMovementState.java" $backupDir
Backup-File "src\main\java\com\example\shinobicore\movement\client\ClientMovementService.java" $backupDir
Backup-File "src\main\java\com\example\shinobicore\movement\client\SlideClient.java" $backupDir
Backup-File "src\main\java\com\example\shinobicore\movement\client\CrawlClient.java" $backupDir
Backup-File "src\main\java\com\example\shinobicore\movement\client\RollClient.java" $backupDir
Backup-File "src\main\java\com\example\shinobicore\movement\client\DodgeClient.java" $backupDir
Backup-File "src\main\java\com\example\shinobicore\movement\client\RollDodgeInputHandler.java" $backupDir

# ------------------------------------------------------------
# 3. Rewrite ClientMovementState with iframe support
# ------------------------------------------------------------

Write-Step "Rewriting ClientMovementState"

$statePath = Join-Path $srcJava "com\example\shinobicore\movement\client\ClientMovementState.java"

$stateContent = @'
// SHINOBICORE:SPRINT8:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.util.math.Vec3d;

/**
 * SPRINT 8 client-side movement state holder.
 */
public final class ClientMovementState {
    private static MovementPhase phase = MovementPhase.NORMAL;
    private static int ticksInPhase = 0;

    private static boolean onWater = false;
    private static boolean onWall = false;
    private static boolean isCrawling = false;
    private static boolean isSliding = false;
    private static boolean isMeditating = false;

    private static int airJumpsUsed = 0;
    private static int sequenceNumber = 0;

    private static Vec3d wallNormal = null;
    private static int jumpGraceTicks = 0;
    private static int wallCooldownTicks = 0;
    private static int iframeTicks = 0;
    private static int maxAirJumps = 1;

    private ClientMovementState() {}

    public static MovementPhase getPhase() {
        return phase;
    }

    public static int getTicksInPhase() {
        return ticksInPhase;
    }

    public static boolean isOnWater() {
        return onWater;
    }

    public static boolean isOnWall() {
        return onWall;
    }

    public static boolean isCrawling() {
        return isCrawling;
    }

    public static boolean isSliding() {
        return isSliding;
    }

    public static boolean isMeditating() {
        return isMeditating;
    }

    public static int getAirJumpsUsed() {
        return airJumpsUsed;
    }

    public static int getMaxAirJumps() {
        return maxAirJumps;
    }

    public static Vec3d getWallNormal() {
        return wallNormal;
    }

    public static int getJumpGraceTicks() {
        return jumpGraceTicks;
    }

    public static int getWallCooldownTicks() {
        return wallCooldownTicks;
    }

    public static int getIframeTicks() {
        return iframeTicks;
    }

    public static boolean isInvulnerable() {
        return iframeTicks > 0;
    }

    public static int getSequenceNumber() {
        return sequenceNumber;
    }

    public static void setPhase(MovementPhase newPhase) {
        if (phase != newPhase) {
            phase = newPhase;
            ticksInPhase = 0;
        }
    }

    public static void setOnWater(boolean value) {
        onWater = value;
    }

    public static void setOnWall(boolean value) {
        onWall = value;
    }

    public static void setCrawling(boolean value) {
        isCrawling = value;
    }

    public static void setSliding(boolean value) {
        isSliding = value;
    }

    public static void setMeditating(boolean value) {
        isMeditating = value;
    }

    public static void setAirJumpsUsed(int value) {
        airJumpsUsed = value;
    }

    public static void setMaxAirJumps(int value) {
        maxAirJumps = value;
    }

    public static void setWallNormal(Vec3d normal) {
        wallNormal = normal;
    }

    public static void setJumpGraceTicks(int value) {
        jumpGraceTicks = Math.max(0, value);
    }

    public static void setWallCooldownTicks(int value) {
        wallCooldownTicks = Math.max(0, value);
    }

    public static void setIframeTicks(int value) {
        iframeTicks = Math.max(0, value);
    }

    public static void tick() {
        ticksInPhase++;

        if (jumpGraceTicks > 0) {
            jumpGraceTicks--;
        }

        if (wallCooldownTicks > 0) {
            wallCooldownTicks--;
        }

        if (iframeTicks > 0) {
            iframeTicks--;
        }
    }

    public static int nextSequence() {
        return ++sequenceNumber;
    }

    public static void resetAll() {
        phase = MovementPhase.NORMAL;
        ticksInPhase = 0;
        onWater = false;
        onWall = false;
        isCrawling = false;
        isSliding = false;
        isMeditating = false;
        airJumpsUsed = 0;
        wallNormal = null;
        jumpGraceTicks = 0;
        wallCooldownTicks = 0;
        iframeTicks = 0;
    }
}
'@

Write-TextFile -Path $statePath -Content $stateContent
Write-Ok "Rewrote ClientMovementState.java"
$actions.Add("Rewrote ClientMovementState.java")

# ------------------------------------------------------------
# 4. Create RollDodgeInputHandler
# ------------------------------------------------------------

Write-Step "Creating RollDodgeInputHandler"

$inputHandlerPath = Join-Path $srcJava "com\example\shinobicore\movement\client\RollDodgeInputHandler.java"

$inputHandlerContent = @'
// SHINOBICORE:SPRINT8:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.client.input.KeyBindings;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.client.option.KeyBinding;

/**
 * SPRINT 8 input handler for Roll and Dodge keys.
 */
public final class RollDodgeInputHandler {
    private static boolean wasRoll = false;
    private static boolean rollEdge = false;

    private static boolean wasDodgeLeft = false;
    private static boolean dodgeLeftEdge = false;

    private static boolean wasDodgeRight = false;
    private static boolean dodgeRightEdge = false;

    private RollDodgeInputHandler() {}

    public static void update(ClientPlayerEntity player) {
        boolean roll = isKeyDown(KeyBindings.ROLL);
        rollEdge = roll && !wasRoll;
        wasRoll = roll;

        boolean left = isKeyDown(KeyBindings.DODGE_LEFT);
        dodgeLeftEdge = left && !wasDodgeLeft;
        wasDodgeLeft = left;

        boolean right = isKeyDown(KeyBindings.DODGE_RIGHT);
        dodgeRightEdge = right && !wasDodgeRight;
        wasDodgeRight = right;
    }

    public static boolean wasRollPressed() {
        return rollEdge;
    }

    public static boolean wasDodgeLeftPressed() {
        return dodgeLeftEdge;
    }

    public static boolean wasDodgeRightPressed() {
        return dodgeRightEdge;
    }

    private static boolean isKeyDown(KeyBinding key) {
        return key != null && key.isPressed();
    }
}
'@

Write-TextFile -Path $inputHandlerPath -Content $inputHandlerContent
Write-Ok "Created RollDodgeInputHandler.java"
$actions.Add("Created RollDodgeInputHandler.java")

# ------------------------------------------------------------
# 5. Create RollClient
# ------------------------------------------------------------

Write-Step "Creating RollClient"

$rollPath = Join-Path $srcJava "com\example\shinobicore\movement\client\RollClient.java"

$rollContent = @'
// SHINOBICORE:SPRINT8:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

/**
 * SPRINT 8 roll foundation.
 *
 * Key: R
 * Behavior:
 * - forward impulse in look direction
 * - short duration
 * - i-frames flag
 * - cooldown
 */
public final class RollClient {
    public static final int ROLL_DURATION_TICKS = 12;
    public static final int ROLL_COOLDOWN_TICKS = 25;
    public static final int IFRAME_TICKS = 12;

    public static final double ROLL_BOOST = 0.55;
    public static final double ROLL_FRICTION = 0.93;
    public static final double MIN_ROLL_SPEED = 0.08;

    private static boolean active = false;
    private static int ticks = 0;
    private static int cooldown = 0;

    private RollClient() {}

    public static boolean isActive() {
        return active;
    }

    public static void tick(ClientPlayerEntity player) {
        if (cooldown > 0) {
            cooldown--;
        }

        if (!FeatureFlags.roll) {
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

        if (CrawlClient.isActive()) {
            stop(player);
            return;
        }

        if (player.isTouchingWater()) {
            stop(player);
            return;
        }

        if (active) {
            ticks++;

            if (!player.isOnGround()) {
                stop(player);
                return;
            }

            if (ticks > ROLL_DURATION_TICKS) {
                stop(player);
                return;
            }

            Vec3d velocity = player.getVelocity();
            double speed = Math.sqrt(velocity.x * velocity.x + velocity.z * velocity.z);

            if (speed < MIN_ROLL_SPEED) {
                stop(player);
                return;
            }

            player.setVelocity(
                    velocity.x * ROLL_FRICTION,
                    velocity.y,
                    velocity.z * ROLL_FRICTION
            );

            player.velocityModified = true;
            return;
        }

        if (cooldown > 0) {
            return;
        }

        if (!player.isOnGround()) {
            return;
        }

        if (MovementInputService.isSneaking(player)) {
            return;
        }

        if (RollDodgeInputHandler.wasRollPressed()) {
            start(player);
        }
    }

    private static void start(ClientPlayerEntity player) {
        Vec3d look = getHorizontalLook(player);

        if (look == null) {
            return;
        }

        active = true;
        ticks = 0;
        cooldown = ROLL_COOLDOWN_TICKS;

        ClientMovementState.setPhase(MovementPhase.ROLLING);
        ClientMovementState.setIframeTicks(IFRAME_TICKS);

        Vec3d velocity = player.getVelocity();

        player.setVelocity(
                look.x * ROLL_BOOST,
                velocity.y,
                look.z * ROLL_BOOST
        );

        player.velocityModified = true;
    }

    private static void stop(ClientPlayerEntity player) {
        if (!active) {
            return;
        }

        active = false;
        ticks = 0;

        if (ClientMovementState.getPhase() == MovementPhase.ROLLING) {
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

Write-TextFile -Path $rollPath -Content $rollContent
Write-Ok "Created RollClient.java"
$actions.Add("Created RollClient.java")

# ------------------------------------------------------------
# 6. Create DodgeClient
# ------------------------------------------------------------

Write-Step "Creating DodgeClient"

$dodgePath = Join-Path $srcJava "com\example\shinobicore\movement\client\DodgeClient.java"

$dodgeContent = @'
// SHINOBICORE:SPRINT8:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

/**
 * SPRINT 8 dodge foundation.
 *
 * Keys:
 * - Z: dodge left
 * - C: dodge right
 *
 * Behavior:
 * - sideways impulse relative to look direction
 * - small forward assist if W is held
 * - short duration
 * - i-frames flag
 * - cooldown
 */
public final class DodgeClient {
    public static final int DODGE_DURATION_TICKS = 8;
    public static final int DODGE_COOLDOWN_TICKS = 20;
    public static final int IFRAME_TICKS = 8;

    public static final double DODGE_BOOST = 0.48;
    public static final double DODGE_FRICTION = 0.90;
    public static final double MIN_DODGE_SPEED = 0.06;
    public static final double FORWARD_ASSIST = 0.35;

    private static boolean active = false;
    private static int ticks = 0;
    private static int cooldown = 0;

    private DodgeClient() {}

    public static boolean isActive() {
        return active;
    }

    public static void tick(ClientPlayerEntity player) {
        if (cooldown > 0) {
            cooldown--;
        }

        if (!FeatureFlags.dodge) {
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

        if (CrawlClient.isActive()) {
            stop(player);
            return;
        }

        if (player.isTouchingWater()) {
            stop(player);
            return;
        }

        if (active) {
            ticks++;

            if (!player.isOnGround()) {
                stop(player);
                return;
            }

            if (ticks > DODGE_DURATION_TICKS) {
                stop(player);
                return;
            }

            Vec3d velocity = player.getVelocity();
            double speed = Math.sqrt(velocity.x * velocity.x + velocity.z * velocity.z);

            if (speed < MIN_DODGE_SPEED) {
                stop(player);
                return;
            }

            player.setVelocity(
                    velocity.x * DODGE_FRICTION,
                    velocity.y,
                    velocity.z * DODGE_FRICTION
            );

            player.velocityModified = true;
            return;
        }

        if (cooldown > 0) {
            return;
        }

        if (!player.isOnGround()) {
            return;
        }

        if (MovementInputService.isSneaking(player)) {
            return;
        }

        if (RollDodgeInputHandler.wasDodgeLeftPressed()) {
            start(player, -1);
        } else if (RollDodgeInputHandler.wasDodgeRightPressed()) {
            start(player, 1);
        }
    }

    private static void start(ClientPlayerEntity player, int side) {
        Vec3d look = getHorizontalLook(player);

        if (look == null) {
            return;
        }

        Vec3d up = new Vec3d(0.0, 1.0, 0.0);

        // Right vector relative to look direction.
        Vec3d right = look.crossProduct(up);

        Vec3d direction = right.multiply(side);

        float forward = MovementInputService.getForwardInput(player);

        if (forward > 0.1f) {
            direction = direction.add(look.multiply(FORWARD_ASSIST));
        }

        if (direction.lengthSquared() < 1.0E-6) {
            return;
        }

        direction = direction.normalize();

        active = true;
        ticks = 0;
        cooldown = DODGE_COOLDOWN_TICKS;

        ClientMovementState.setPhase(MovementPhase.DODGING);
        ClientMovementState.setIframeTicks(IFRAME_TICKS);

        Vec3d velocity = player.getVelocity();

        player.setVelocity(
                direction.x * DODGE_BOOST,
                velocity.y,
                direction.z * DODGE_BOOST
        );

        player.velocityModified = true;
    }

    private static void stop(ClientPlayerEntity player) {
        if (!active) {
            return;
        }

        active = false;
        ticks = 0;

        if (ClientMovementState.getPhase() == MovementPhase.DODGING) {
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

Write-TextFile -Path $dodgePath -Content $dodgeContent
Write-Ok "Created DodgeClient.java"
$actions.Add("Created DodgeClient.java")

# ------------------------------------------------------------
# 7. Rewrite SlideClient with roll/dodge interruption
# ------------------------------------------------------------

Write-Step "Rewriting SlideClient"

$slidePath = Join-Path $srcJava "com\example\shinobicore\movement\client\SlideClient.java"

$slideContent = @'
// SHINOBICORE:SPRINT8:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

/**
 * SPRINT 8 slide foundation.
 *
 * Entry:
 * - player is on ground
 * - player is sprinting
 * - player is moving forward
 * - sneak key pressed once
 *
 * Behavior:
 * - forward impulse
 * - velocity friction
 * - ends after duration or jump
 *
 * Interrupted by roll/dodge.
 */
public final class SlideClient {
    public static final int SLIDE_DURATION_TICKS = 14;
    public static final int SLIDE_COOLDOWN_TICKS = 20;

    public static final double SLIDE_BOOST = 0.42;
    public static final double SLIDE_FRICTION = 0.92;
    public static final double MIN_SLIDE_SPEED = 0.08;

    private static boolean active = false;
    private static int ticks = 0;
    private static int cooldown = 0;

    private SlideClient() {}

    public static boolean isActive() {
        return active;
    }

    public static void tick(ClientPlayerEntity player) {
        if (cooldown > 0) {
            cooldown--;
        }

        if (!FeatureFlags.slide) {
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

        if (CrawlClient.isActive()) {
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
            ticks++;

            if (!player.isOnGround()) {
                stop(player);
                return;
            }

            if (ticks > SLIDE_DURATION_TICKS) {
                stop(player);
                return;
            }

            if (MovementInputService.wasJumpPressed()) {
                stop(player);
                return;
            }

            Vec3d velocity = player.getVelocity();
            double speed = Math.sqrt(velocity.x * velocity.x + velocity.z * velocity.z);

            if (speed < MIN_SLIDE_SPEED) {
                stop(player);
                return;
            }

            player.setVelocity(
                    velocity.x * SLIDE_FRICTION,
                    velocity.y,
                    velocity.z * SLIDE_FRICTION
            );

            player.velocityModified = true;
            return;
        }

        if (cooldown > 0) {
            return;
        }

        if (!player.isOnGround()) {
            return;
        }

        if (!player.isSprinting()) {
            return;
        }

        if (!MovementInputService.isMovingForward(player)) {
            return;
        }

        if (MovementInputService.wasSneakPressed()) {
            start(player);
        }
    }

    private static void start(ClientPlayerEntity player) {
        Vec3d look = getHorizontalLook(player);

        if (look == null) {
            return;
        }

        active = true;
        ticks = 0;
        cooldown = SLIDE_COOLDOWN_TICKS;

        ClientMovementState.setPhase(MovementPhase.SLIDING);
        ClientMovementState.setSliding(true);

        Vec3d velocity = player.getVelocity();

        player.setVelocity(
                look.x * SLIDE_BOOST,
                velocity.y,
                look.z * SLIDE_BOOST
        );

        player.velocityModified = true;
    }

    private static void stop(ClientPlayerEntity player) {
        if (!active) {
            return;
        }

        active = false;
        ticks = 0;

        ClientMovementState.setSliding(false);

        if (ClientMovementState.getPhase() == MovementPhase.SLIDING) {
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

Write-TextFile -Path $slidePath -Content $slideContent
Write-Ok "Rewrote SlideClient.java"
$actions.Add("Rewrote SlideClient.java")

# ------------------------------------------------------------
# 8. Rewrite CrawlClient with roll/dodge interruption
# ------------------------------------------------------------

Write-Step "Rewriting CrawlClient"

$crawlPath = Join-Path $srcJava "com\example\shinobicore\movement\client\CrawlClient.java"

$crawlContent = @'
// SHINOBICORE:SPRINT8:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

/**
 * SPRINT 8 crawl foundation.
 *
 * Entry/Exit:
 * - double tap Shift on ground
 *
 * Behavior:
 * - forces sneaking pose
 * - disables sprint
 * - limits horizontal speed
 * - suppresses upward jump velocity
 *
 * Interrupted by roll/dodge.
 */
public final class CrawlClient {
    public static final double MAX_CRAWL_SPEED = 0.06;

    private static boolean active = false;

    private CrawlClient() {}

    public static boolean isActive() {
        return active;
    }

    public static void tick(ClientPlayerEntity player) {
        if (!FeatureFlags.crawl) {
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

        if (SlideClient.isActive()) {
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

        if (MovementInputService.wasDoubleSneakPressed() && player.isOnGround()) {
            toggle(player);
            return;
        }

        if (!active) {
            return;
        }

        if (!player.isOnGround()) {
            stop(player);
            return;
        }

        if (!player.isSneaking()) {
            player.setSneaking(true);
        }

        player.setSprinting(false);

        Vec3d velocity = player.getVelocity();
        double speed = Math.sqrt(velocity.x * velocity.x + velocity.z * velocity.z);

        if (speed > MAX_CRAWL_SPEED) {
            double scale = MAX_CRAWL_SPEED / speed;
            velocity = new Vec3d(
                    velocity.x * scale,
                    velocity.y,
                    velocity.z * scale
            );
        }

        if (velocity.y > 0.0) {
            velocity = new Vec3d(velocity.x, 0.0, velocity.z);
        }

        player.setVelocity(velocity.x, velocity.y, velocity.z);
        player.velocityModified = true;

        ClientMovementState.setPhase(MovementPhase.CRAWLING);
    }

    private static void toggle(ClientPlayerEntity player) {
        if (active) {
            stop(player);
        } else {
            start(player);
        }
    }

    private static void start(ClientPlayerEntity player) {
        active = true;

        ClientMovementState.setCrawling(true);
        ClientMovementState.setPhase(MovementPhase.CRAWLING);

        player.setSprinting(false);
        player.setSneaking(true);
    }

    private static void stop(ClientPlayerEntity player) {
        if (!active) {
            return;
        }

        active = false;

        ClientMovementState.setCrawling(false);

        if (ClientMovementState.getPhase() == MovementPhase.CRAWLING) {
            ClientMovementState.setPhase(MovementPhase.NORMAL);
        }

        if (!MovementInputService.isSneakHeld(player)) {
            player.setSneaking(false);
        }
    }
}
'@

Write-TextFile -Path $crawlPath -Content $crawlContent
Write-Ok "Rewrote CrawlClient.java"
$actions.Add("Rewrote CrawlClient.java")

# ------------------------------------------------------------
# 9. Rewrite ClientMovementService
# ------------------------------------------------------------

Write-Step "Rewriting ClientMovementService"

$servicePath = Join-Path $srcJava "com\example\shinobicore\movement\client\ClientMovementService.java"

$serviceContent = @'
// SHINOBICORE:SPRINT8:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.common.MovementPhase;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;

/**
 * SPRINT 8 central client movement tick handler.
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

        // If no subsystem is active, reset phase to NORMAL
        if (!WaterWalkClient.isActive()
                && !WallRunClient.isActive()
                && !RollClient.isActive()
                && !DodgeClient.isActive()
                && !SlideClient.isActive()
                && !CrawlClient.isActive()) {

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
# 10. Build
# ------------------------------------------------------------

if (-not $SkipBuild) {
    Write-Step "Running Gradle build"

    $buildOk = Invoke-GradleBuildDetailed -RootPath $Root -LogDir $outDir

    if (-not $buildOk) {
        Write-Err "Sprint 8 failed build."
        Write-Err "Log: $(Join-Path $outDir 'gradle_build.log')"
        exit 1
    }
}
else {
    Write-Warn "Build skipped because -SkipBuild was specified"
}

# ------------------------------------------------------------
# 11. Report
# ------------------------------------------------------------

Write-Step "Generating Sprint 8 report"

$report = New-Object System.Text.StringBuilder

[void]$report.AppendLine("SHINOBI CORE - SPRINT 8 REPORT")
[void]$report.AppendLine("Generated: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
[void]$report.AppendLine("")
[void]$report.AppendLine("=== ACTIONS ===")

foreach ($action in $actions) {
    [void]$report.AppendLine($action)
}

$reportPath = Join-Path $outDir "sprint8_report.txt"
Write-TextFile -Path $reportPath -Content $report.ToString()

Write-Ok "Report saved: $reportPath"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " MASTER SPRINT 8 COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Test in-game:" -ForegroundColor Yellow
Write-Host "  1. Press R -> Roll forward" -ForegroundColor White
Write-Host "  2. Press Z -> Dodge left" -ForegroundColor White
Write-Host "  3. Press C -> Dodge right" -ForegroundColor White
Write-Host "  4. While sliding, press R -> Roll cancels slide" -ForegroundColor White
Write-Host "  5. While crawling, roll/dodge are blocked until stand up" -ForegroundColor White
Write-Host ""
Write-Host "Next step: MASTER SPRINT 9 (Charged Jump + Double Jump foundation)" -ForegroundColor Yellow
Write-Host ""

exit 0
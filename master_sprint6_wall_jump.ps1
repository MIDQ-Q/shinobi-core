param(
    [string]$Root = "",
    [switch]$SkipBuild
)

# ============================================================
# SHINOBI CORE
# MASTER SPRINT 7: SLIDE + CRAWL FOUNDATION
# ============================================================

$ErrorActionPreference = "Stop"
$script:utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "[SPRINT7] $Message" -ForegroundColor Cyan
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
Write-Host " SHINOBI CORE - MASTER SPRINT 7" -ForegroundColor Cyan
Write-Host " Slide + Crawl foundation" -ForegroundColor Cyan
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
$outDir = Join-Path $Root "scripts\out\sprint7"

Ensure-Directory $outDir

$actions = New-Object System.Collections.Generic.List[string]
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $Root "backup\sprint7_$stamp"

# ------------------------------------------------------------
# 2. Backup files we will overwrite
# ------------------------------------------------------------

Write-Step "Creating backup"

Backup-File "src\main\java\com\example\shinobicore\movement\client\MovementInputService.java" $backupDir
Backup-File "src\main\java\com\example\shinobicore\movement\client\ClientMovementService.java" $backupDir
Backup-File "src\main\java\com\example\shinobicore\movement\client\SlideClient.java" $backupDir
Backup-File "src\main\java\com\example\shinobicore\movement\client\CrawlClient.java" $backupDir

# ------------------------------------------------------------
# 3. Rewrite MovementInputService
# ------------------------------------------------------------

Write-Step "Rewriting MovementInputService"

$inputServicePath = Join-Path $srcJava "com\example\shinobicore\movement\client\MovementInputService.java"

$inputServiceContent = @'
// SHINOBICORE:SPRINT7:FILE
package com.example.shinobicore.movement.client;

import net.minecraft.client.network.ClientPlayerEntity;

/**
 * SPRINT 7 safe input service.
 * Tracks jump, sneak, and double sneak edges.
 */
public final class MovementInputService {
    private static boolean wasJumping = false;
    private static boolean jumpPressedEdge = false;

    private static boolean wasSneaking = false;
    private static boolean sneakPressedEdge = false;
    private static int ticksSinceSneakPress = 1000;
    private static boolean doubleSneakPressedEdge = false;

    private MovementInputService() {}

    public static void update(ClientPlayerEntity player) {
        boolean jumping = player != null
                && player.input != null
                && player.input.jumping;

        jumpPressedEdge = jumping && !wasJumping;
        wasJumping = jumping;

        boolean sneaking = player != null
                && player.input != null
                && player.input.sneaking;

        sneakPressedEdge = sneaking && !wasSneaking;
        wasSneaking = sneaking;

        ticksSinceSneakPress++;
        doubleSneakPressedEdge = false;

        if (sneakPressedEdge) {
            if (ticksSinceSneakPress <= 8) {
                doubleSneakPressedEdge = true;
            }

            ticksSinceSneakPress = 0;
        }
    }

    public static boolean wasJumpPressed() {
        return jumpPressedEdge;
    }

    public static boolean wasSneakPressed() {
        return sneakPressedEdge;
    }

    public static boolean wasDoubleSneakPressed() {
        return doubleSneakPressedEdge;
    }

    public static boolean isJumpHeld(ClientPlayerEntity player) {
        return player != null
                && player.input != null
                && player.input.jumping;
    }

    public static boolean isSneakHeld(ClientPlayerEntity player) {
        return player != null
                && player.input != null
                && player.input.sneaking;
    }

    public static boolean isSneaking(ClientPlayerEntity player) {
        return player != null && player.isSneaking();
    }

    public static boolean isSprinting(ClientPlayerEntity player) {
        return player != null && player.isSprinting();
    }

    public static boolean isMovingForward(ClientPlayerEntity player) {
        return player != null
                && player.input != null
                && player.input.movementForward > 0.1f;
    }

    public static boolean hasHorizontalInput(ClientPlayerEntity player) {
        if (player == null || player.input == null) {
            return false;
        }

        return Math.abs(player.input.movementForward) > 0.1f
                || Math.abs(player.input.movementSideways) > 0.1f;
    }

    public static float getForwardInput(ClientPlayerEntity player) {
        if (player == null || player.input == null) {
            return 0.0f;
        }

        return player.input.movementForward;
    }
}
'@

Write-TextFile -Path $inputServicePath -Content $inputServiceContent
Write-Ok "Rewrote MovementInputService.java"
$actions.Add("Rewrote MovementInputService.java")

# ------------------------------------------------------------
# 4. Create SlideClient
# ------------------------------------------------------------

Write-Step "Creating SlideClient"

$slidePath = Join-Path $srcJava "com\example\shinobicore\movement\client\SlideClient.java"

$slideContent = @'
// SHINOBICORE:SPRINT7:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

/**
 * SPRINT 7 slide foundation.
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
Write-Ok "Created SlideClient.java"
$actions.Add("Created SlideClient.java")

# ------------------------------------------------------------
# 5. Create CrawlClient
# ------------------------------------------------------------

Write-Step "Creating CrawlClient"

$crawlPath = Join-Path $srcJava "com\example\shinobicore\movement\client\CrawlClient.java"

$crawlContent = @'
// SHINOBICORE:SPRINT7:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

/**
 * SPRINT 7 crawl foundation.
 *
 * Entry/Exit:
 * - double tap Shift on ground
 *
 * Behavior:
 * - forces sneaking pose
 * - disables sprint
 * - limits horizontal speed
 * - suppresses upward jump velocity
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
Write-Ok "Created CrawlClient.java"
$actions.Add("Created CrawlClient.java")

# ------------------------------------------------------------
# 6. Rewrite ClientMovementService
# ------------------------------------------------------------

Write-Step "Rewriting ClientMovementService"

$servicePath = Join-Path $srcJava "com\example\shinobicore\movement\client\ClientMovementService.java"

$serviceContent = @'
// SHINOBICORE:SPRINT7:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.common.MovementPhase;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;

/**
 * SPRINT 7 central client movement tick handler.
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

        // Update state timers
        ClientMovementState.tick();

        // Update input edge states
        MovementInputService.update(client.player);

        // Jump grace for wall entry
        if (MovementInputService.wasJumpPressed()) {
            ClientMovementState.setJumpGraceTicks(6);
        }

        // Tick subsystems
        WaterWalkClient.tick(client.player);
        WallRunClient.tick(client.player);
        SlideClient.tick(client.player);
        CrawlClient.tick(client.player);

        // If no subsystem is active, reset phase to NORMAL
        if (!WaterWalkClient.isActive()
                && !WallRunClient.isActive()
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
# 7. Build
# ------------------------------------------------------------

if (-not $SkipBuild) {
    Write-Step "Running Gradle build"

    $buildOk = Invoke-GradleBuildDetailed -RootPath $Root -LogDir $outDir

    if (-not $buildOk) {
        Write-Err "Sprint 7 failed build."
        Write-Err "Log: $(Join-Path $outDir 'gradle_build.log')"
        exit 1
    }
}
else {
    Write-Warn "Build skipped because -SkipBuild was specified"
}

# ------------------------------------------------------------
# 8. Report
# ------------------------------------------------------------

Write-Step "Generating Sprint 7 report"

$report = New-Object System.Text.StringBuilder

[void]$report.AppendLine("SHINOBI CORE - SPRINT 7 REPORT")
[void]$report.AppendLine("Generated: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
[void]$report.AppendLine("")
[void]$report.AppendLine("=== ACTIONS ===")

foreach ($action in $actions) {
    [void]$report.AppendLine($action)
}

$reportPath = Join-Path $outDir "sprint7_report.txt"
Write-TextFile -Path $reportPath -Content $report.ToString()

Write-Ok "Report saved: $reportPath"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " MASTER SPRINT 7 COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Test in-game:" -ForegroundColor Yellow
Write-Host "  1. Sprint forward and tap Shift once -> Slide" -ForegroundColor White
Write-Host "  2. Stand on ground and double-tap Shift -> Crawl" -ForegroundColor White
Write-Host "  3. While crawling, movement should be slow" -ForegroundColor White
Write-Host "  4. Double-tap Shift again -> Stand up" -ForegroundColor White
Write-Host ""
Write-Host "Next step: MASTER SPRINT 8 (Roll + Dodge foundation)" -ForegroundColor Yellow
Write-Host ""

exit 0
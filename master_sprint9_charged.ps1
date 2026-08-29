param(
    [string]$Root = "",
    [switch]$SkipBuild
)

# ============================================================
# SHINOBI CORE
# MASTER SPRINT 9: CHARGED JUMP + DOUBLE JUMP FOUNDATION
# ============================================================

$ErrorActionPreference = "Stop"
$script:utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "[SPRINT9] $Message" -ForegroundColor Cyan
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
Write-Host " SHINOBI CORE - MASTER SPRINT 9" -ForegroundColor Cyan
Write-Host " Charged Jump + Double Jump foundation" -ForegroundColor Cyan
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
$outDir = Join-Path $Root "scripts\out\sprint9"

Ensure-Directory $outDir

$actions = New-Object System.Collections.Generic.List[string]
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $Root "backup\sprint9_$stamp"

# ------------------------------------------------------------
# 2. Backup files we will overwrite
# ------------------------------------------------------------

Write-Step "Creating backup"

Backup-File "src\main\java\com\example\shinobicore\movement\client\ClientMovementService.java" $backupDir
Backup-File "src\main\java\com\example\shinobicore\movement\client\ChargedJumpClient.java" $backupDir
Backup-File "src\main\java\com\example\shinobicore\movement\client\DoubleJumpClient.java" $backupDir

# ------------------------------------------------------------
# 3. Create ChargedJumpClient
# ------------------------------------------------------------

Write-Step "Creating ChargedJumpClient"

$chargedJumpPath = Join-Path $srcJava "com\example\shinobicore\movement\client\ChargedJumpClient.java"

$chargedJumpContent = @'
// SHINOBICORE:SPRINT9:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

/**
 * SPRINT 9 charged jump foundation.
 *
 * Entry:
 * - player is on ground
 * - player holds jump key
 *
 * Behavior:
 * - charge while holding jump
 * - release to jump with power based on charge time
 * - vertical speed capped
 * - phase CHARGING_JUMP
 * - cooldown after release
 */
public final class ChargedJumpClient {
    public static final int MAX_CHARGE_TICKS = 20;
    public static final int COOLDOWN_TICKS = 20;

    public static final double MIN_JUMP_Y = 0.42;
    public static final double MAX_JUMP_Y = 1.0;
    public static final double JUMP_Y_CAP = 1.5;

    private static boolean charging = false;
    private static int chargeTicks = 0;
    private static int cooldown = 0;

    private ChargedJumpClient() {}

    public static boolean isCharging() {
        return charging;
    }

    public static void tick(ClientPlayerEntity player) {
        if (cooldown > 0) {
            cooldown--;
        }

        if (!FeatureFlags.chargedJump) {
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

        if (charging) {
            chargeTicks++;

            if (!player.isOnGround()) {
                release(player);
                return;
            }

            if (chargeTicks > MAX_CHARGE_TICKS) {
                release(player);
                return;
            }

            if (!MovementInputService.isJumpHeld(player)) {
                release(player);
                return;
            }

            // Slow player while charging
            Vec3d velocity = player.getVelocity();
            player.setVelocity(velocity.x * 0.8, velocity.y, velocity.z * 0.8);
            player.velocityModified = true;
            return;
        }

        if (cooldown > 0) {
            return;
        }

        if (!player.isOnGround()) {
            return;
        }

        if (SlideClient.isActive()) {
            return;
        }

        if (RollClient.isActive()) {
            return;
        }

        if (DodgeClient.isActive()) {
            return;
        }

        if (MovementInputService.isJumpHeld(player)) {
            start(player);
        }
    }

    private static void start(ClientPlayerEntity player) {
        charging = true;
        chargeTicks = 0;
        ClientMovementState.setPhase(MovementPhase.CHARGING_JUMP);
    }

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

    private static void stop(ClientPlayerEntity player) {
        if (!charging) {
            return;
        }

        charging = false;
        chargeTicks = 0;

        if (ClientMovementState.getPhase() == MovementPhase.CHARGING_JUMP) {
            ClientMovementState.setPhase(MovementPhase.NORMAL);
        }
    }
}
'@

Write-TextFile -Path $chargedJumpPath -Content $chargedJumpContent
Write-Ok "Created ChargedJumpClient.java"
$actions.Add("Created ChargedJumpClient.java")

# ------------------------------------------------------------
# 4. Create DoubleJumpClient
# ------------------------------------------------------------

Write-Step "Creating DoubleJumpClient"

$doubleJumpPath = Join-Path $srcJava "com\example\shinobicore\movement\client\DoubleJumpClient.java"

$doubleJumpContent = @'
// SHINOBICORE:SPRINT9:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

/**
 * SPRINT 9 double jump foundation.
 *
 * Entry:
 * - player is in air
 * - player presses jump key
 * - air jumps remaining
 *
 * Behavior:
 * - single air jump
 * - resets on ground contact
 */
public final class DoubleJumpClient {
    public static final double DOUBLE_JUMP_Y = 0.42;

    private DoubleJumpClient() {}

    public static void tick(ClientPlayerEntity player) {
        if (!FeatureFlags.doubleJump) {
            return;
        }

        // Reset air jumps on ground contact
        if (player.isOnGround()) {
            ClientMovementState.setAirJumpsUsed(0);
            return;
        }

        if (WaterWalkClient.isActive()) {
            return;
        }

        if (WallRunClient.isActive()) {
            return;
        }

        if (ChargedJumpClient.isCharging()) {
            return;
        }

        if (player.isTouchingWater()) {
            return;
        }

        if (MovementInputService.wasJumpPressed()) {
            int used = ClientMovementState.getAirJumpsUsed();
            int max = ClientMovementState.getMaxAirJumps();

            if (used < max) {
                Vec3d velocity = player.getVelocity();
                player.setVelocity(velocity.x, DOUBLE_JUMP_Y, velocity.z);
                player.velocityModified = true;
                ClientMovementState.setAirJumpsUsed(used + 1);
            }
        }
    }
}
'@

Write-TextFile -Path $doubleJumpPath -Content $doubleJumpContent
Write-Ok "Created DoubleJumpClient.java"
$actions.Add("Created DoubleJumpClient.java")

# ------------------------------------------------------------
# 5. Rewrite ClientMovementService
# ------------------------------------------------------------

Write-Step "Rewriting ClientMovementService"

$servicePath = Join-Path $srcJava "com\example\shinobicore\movement\client\ClientMovementService.java"

$serviceContent = @'
// SHINOBICORE:SPRINT9:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.common.MovementPhase;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;

/**
 * SPRINT 9 central client movement tick handler.
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

        // If no subsystem is active, reset phase to NORMAL
        if (!WaterWalkClient.isActive()
                && !WallRunClient.isActive()
                && !RollClient.isActive()
                && !DodgeClient.isActive()
                && !SlideClient.isActive()
                && !CrawlClient.isActive()
                && !ChargedJumpClient.isCharging()) {

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
# 6. Build
# ------------------------------------------------------------

if (-not $SkipBuild) {
    Write-Step "Running Gradle build"

    $buildOk = Invoke-GradleBuildDetailed -RootPath $Root -LogDir $outDir

    if (-not $buildOk) {
        Write-Err "Sprint 9 failed build."
        Write-Err "Log: $(Join-Path $outDir 'gradle_build.log')"
        exit 1
    }
}
else {
    Write-Warn "Build skipped because -SkipBuild was specified"
}

# ------------------------------------------------------------
# 7. Report
# ------------------------------------------------------------

Write-Step "Generating Sprint 9 report"

$report = New-Object System.Text.StringBuilder

[void]$report.AppendLine("SHINOBI CORE - SPRINT 9 REPORT")
[void]$report.AppendLine("Generated: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
[void]$report.AppendLine("")
[void]$report.AppendLine("=== ACTIONS ===")

foreach ($action in $actions) {
    [void]$report.AppendLine($action)
}

$reportPath = Join-Path $outDir "sprint9_report.txt"
Write-TextFile -Path $reportPath -Content $report.ToString()

Write-Ok "Report saved: $reportPath"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " MASTER SPRINT 9 COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Test in-game:" -ForegroundColor Yellow
Write-Host "  1. Hold Space on ground -> Charge jump" -ForegroundColor White
Write-Host "  2. Release Space -> Jump with power" -ForegroundColor White
Write-Host "  3. Jump into air, then press Space again -> Double jump" -ForegroundColor White
Write-Host "  4. Land on ground -> Air jumps reset" -ForegroundColor White
Write-Host ""
Write-Host "Next step: MASTER SPRINT 10 (Edge Grab foundation)" -ForegroundColor Yellow
Write-Host ""

exit 0
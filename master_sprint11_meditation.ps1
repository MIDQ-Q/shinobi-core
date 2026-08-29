param(
    [string]$Root = "",
    [switch]$SkipBuild
)

# ============================================================
# SHINOBI CORE
# MASTER SPRINT 11: MEDITATION + CHAKRA SYNC POLISH
# ============================================================

$ErrorActionPreference = "Stop"
$script:utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "[SPRINT11] $Message" -ForegroundColor Cyan
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
Write-Host " SHINOBI CORE - MASTER SPRINT 11" -ForegroundColor Cyan
Write-Host " Meditation + Chakra sync polish" -ForegroundColor Cyan
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
$outDir = Join-Path $Root "scripts\out\sprint11"

Ensure-Directory $outDir

$actions = New-Object System.Collections.Generic.List[string]
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $Root "backup\sprint11_$stamp"

# ------------------------------------------------------------
# 2. Backup files we will overwrite
# ------------------------------------------------------------

Write-Step "Creating backup"

Backup-File "src\main\java\com\example\shinobicore\movement\client\ClientMovementService.java" $backupDir
Backup-File "src\main\java\com\example\shinobicore\movement\client\MeditationClient.java" $backupDir

# ------------------------------------------------------------
# 3. Create MeditationClient
# ------------------------------------------------------------

Write-Step "Creating MeditationClient"

$meditationPath = Join-Path $srcJava "com\example\shinobicore\movement\client\MeditationClient.java"

$meditationContent = @'
// SHINOBICORE:SPRINT11:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.chakra.client.ChakraClientController;
import com.example.shinobicore.client.input.KeyBindings;
import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.client.option.KeyBinding;

/**
 * SPRINT 11 meditation foundation.
 *
 * Entry:
 * - player is on ground
 * - player is in chakra mode
 * - player presses M key
 *
 * Behavior:
 * - accelerated chakra regen
 * - player cannot move
 * - interrupted by movement, jump, or M key press
 */
public final class MeditationClient {
    private static boolean active = false;
    private static boolean wasMeditatePressed = false;

    private MeditationClient() {}

    public static boolean isActive() {
        return active;
    }

    public static void tick(ClientPlayerEntity player) {
        boolean meditatePressed = isMeditateKeyDown();
        boolean edge = meditatePressed && !wasMeditatePressed;
        wasMeditatePressed = meditatePressed;

        if (!FeatureFlags.meditation) {
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

        if (SlideClient.isActive()) {
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
            // Interrupt on movement
            if (MovementInputService.hasHorizontalInput(player)) {
                stop(player);
                return;
            }

            // Interrupt on jump
            if (MovementInputService.wasJumpPressed()) {
                stop(player);
                return;
            }

            // Interrupt on M key press
            if (edge) {
                stop(player);
                return;
            }

            // Interrupt if not on ground
            if (!player.isOnGround()) {
                stop(player);
                return;
            }

            // Accelerated chakra regen
            ChakraClientController.setMeditating(true);
            return;
        }

        if (!player.isOnGround()) {
            return;
        }

        if (!ChakraClientController.isChakraModeActive()) {
            return;
        }

        if (edge) {
            start(player);
        }
    }

    private static void start(ClientPlayerEntity player) {
        active = true;
        ClientMovementState.setPhase(MovementPhase.MEDITATING);
        ClientMovementState.setMeditating(true);
        ChakraClientController.setMeditating(true);
    }

    private static void stop(ClientPlayerEntity player) {
        if (!active) {
            return;
        }

        active = false;
        ClientMovementState.setMeditating(false);
        ChakraClientController.setMeditating(false);

        if (ClientMovementState.getPhase() == MovementPhase.MEDITATING) {
            ClientMovementState.setPhase(MovementPhase.NORMAL);
        }
    }

    private static boolean isMeditateKeyDown() {
        KeyBinding key = KeyBindings.MEDITATE;
        return key != null && key.isPressed();
    }
}
'@

Write-TextFile -Path $meditationPath -Content $meditationContent
Write-Ok "Created MeditationClient.java"
$actions.Add("Created MeditationClient.java")

# ------------------------------------------------------------
# 4. Rewrite ClientMovementService
# ------------------------------------------------------------

Write-Step "Rewriting ClientMovementService"

$servicePath = Join-Path $srcJava "com\example\shinobicore\movement\client\ClientMovementService.java"

$serviceContent = @'
// SHINOBICORE:SPRINT11:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.common.MovementPhase;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;

/**
 * SPRINT 11 central client movement tick handler.
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
        MeditationClient.tick(client.player);

        // If no subsystem is active, reset phase to NORMAL
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
        Write-Err "Sprint 11 failed build."
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

Write-Step "Generating Sprint 11 report"

$report = New-Object System.Text.StringBuilder

[void]$report.AppendLine("SHINOBI CORE - SPRINT 11 REPORT")
[void]$report.AppendLine("Generated: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
[void]$report.AppendLine("")
[void]$report.AppendLine("=== ACTIONS ===")

foreach ($action in $actions) {
    [void]$report.AppendLine($action)
}

$reportPath = Join-Path $outDir "sprint11_report.txt"
Write-TextFile -Path $reportPath -Content $report.ToString()

Write-Ok "Report saved: $reportPath"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " MASTER SPRINT 11 COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Test in-game:" -ForegroundColor Yellow
Write-Host "  1. Enable Chakra Mode with L" -ForegroundColor White
Write-Host "  2. Press M to start meditation" -ForegroundColor White
Write-Host "  3. Watch chakra regen accelerate" -ForegroundColor White
Write-Host "  4. Press M again or move to stop meditation" -ForegroundColor White
Write-Host ""
Write-Host "Next step: MASTER SPRINT 12 (Full movement integration test)" -ForegroundColor Yellow
Write-Host ""

exit 0
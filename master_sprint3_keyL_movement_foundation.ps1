param(
    [string]$Root = "",
    [switch]$SkipBuild
)

# ============================================================
# SHINOBI CORE
# MASTER SPRINT 3: KEY L + CHAKRA DRAIN + MOVEMENT FOUNDATION
# ============================================================

$ErrorActionPreference = "Stop"
$script:utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "[SPRINT3] $Message" -ForegroundColor Cyan
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
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $Content = $Content -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($Path, $Content, $script:utf8NoBom)
}

function Ensure-Directory([string]$Path) {
    if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
}

function Backup-File([string]$RelativePath, [string]$BackupDir) {
    $src = Join-Path $Root $RelativePath
    if (-not (Test-Path $src)) { return }
    $dest = Join-Path $BackupDir $RelativePath
    $destDir = Split-Path $dest -Parent
    Ensure-Directory $destDir
    Copy-Item -Path $src -Destination $dest -Force
    Write-Ok "Backed up $RelativePath"
}

function Add-Entrypoint([string]$FabricPath, [string]$Category, [string]$Entrypoint) {
    if (-not (Test-Path $FabricPath)) { return $false }
    $raw = Read-TextFile $FabricPath
    try { $json = $raw | ConvertFrom-Json } catch { return $false }

    if (-not ($json.PSObject.Properties.Name -contains "entrypoints")) {
        Add-Member -InputObject $json -MemberType NoteProperty -Name "entrypoints" -Value ([PSCustomObject]@{})
    }
    $ep = $json.entrypoints
    if (-not ($ep.PSObject.Properties.Name -contains $Category)) {
        Add-Member -InputObject $ep -MemberType NoteProperty -Name $Category -Value @()
    }
    
    $list = @($ep.$Category)
    if ($list -contains $Entrypoint) { return $false }
    
    $list += $Entrypoint
    $ep.$Category = $list
    
    $newJson = $json | ConvertTo-Json -Depth 20
    Write-TextFile -Path $FabricPath -Content $newJson
    return $true
}

function Invoke-GradleBuild([string]$RootPath, [string]$LogDir) {
    $gradle = Join-Path $RootPath "gradlew.bat"
    if (-not (Test-Path $gradle)) { return $false }

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
            $output | Where-Object { $_ -match "error:" } | Select-Object -First 20 | ForEach-Object {
                Write-Host " $_" -ForegroundColor Red
            }
        }
        return $false
    }
    finally { Pop-Location }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " SHINOBI CORE - MASTER SPRINT 3" -ForegroundColor Cyan
Write-Host " Key L handler + chakra drain + movement foundation" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Resolve root
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = (Get-Location).Path }
if (-not (Test-Path (Join-Path $Root "gradlew.bat"))) { $Root = "E:\Games\mod" }
if (-not (Test-Path (Join-Path $Root "gradlew.bat"))) { Write-Err "Project root not found."; exit 1 }

Write-Ok "Project root: $Root"
$srcJava = Join-Path $Root "src\main\java"
$resMain = Join-Path $Root "src\main\resources"
$outDir = Join-Path $Root "scripts\out\sprint3"
Ensure-Directory $outDir

$actions = New-Object System.Collections.Generic.List[string]
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $Root "backup\sprint3_$stamp"

Write-Step "Creating backup"
Backup-File "src\main\resources\fabric.mod.json" $backupDir
Backup-File "src\main\java\com\example\shinobicore\client\KeyBindings.java" $backupDir
Backup-File "src\main\java\com\example\shinobicore\client\ClientNinjaState.java" $backupDir
Backup-File "src\main\java\com\example\shinobicore\chakra\client\ChakraClientController.java" $backupDir
Backup-File "src\main\java\com\example\shinobicore\ShinobiCoreClient.java" $backupDir

# 2. Create MovementPhase enum
Write-Step "Creating MovementPhase enum"
$movementPhasePath = Join-Path $srcJava "com\example\shinobicore\movement\common\MovementPhase.java"
$movementPhaseContent = @'
// SHINOBICORE:SPRINT3:FILE
package com.example.shinobicore.movement.common;

/**
 * SPRINT 3 movement state machine phases.
 * Foundation for Sprint 4 (parkour actions).
 */
public enum MovementPhase {
    NORMAL,
    MEDITATING,
    WATER_WALKING,
    WALL_RUNNING,
    SLIDING,
    CRAWLING,
    ROLLING,
    DODGING,
    CHARGING_JUMP,
    EDGE_GRABBING;

    public boolean isAirborne() {
        return this == CHARGING_JUMP || this == EDGE_GRABBING || this == WALL_RUNNING;
    }

    public boolean isGrounded() {
        return this == NORMAL || this == SLIDING || this == CRAWLING || this == ROLLING || this == MEDITATING;
    }

    public boolean blocksOtherActions() {
        return this != NORMAL && this != MEDITATING;
    }
}
'@
Write-TextFile -Path $movementPhasePath -Content $movementPhaseContent
Write-Ok "Created MovementPhase.java"
$actions.Add("Created MovementPhase.java")

# 3. Create MovementActionType enum
Write-Step "Creating MovementActionType enum"
$actionTypePath = Join-Path $srcJava "com\example\shinobicore\movement\common\MovementActionType.java"
$actionTypeContent = @'
// SHINOBICORE:SPRINT3:FILE
package com.example.shinobicore.movement.common;

/**
 * SPRINT 3 action types sent to server mirror.
 * Foundation for Sprint 4 (parkour actions).
 */
public enum MovementActionType {
    NONE,
    CHAKRA_MODE_ON,
    CHAKRA_MODE_OFF,
    WATER_START,
    WATER_STOP,
    WALL_START,
    WALL_STOP,
    WALL_JUMP,
    SLIDE_START,
    SLIDE_STOP,
    CRAWL_START,
    CRAWL_STOP,
    ROLL_START,
    ROLL_STOP,
    DODGE_LEFT,
    DODGE_RIGHT,
    CHARGED_JUMP_START,
    CHARGED_JUMP_RELEASE,
    DOUBLE_JUMP,
    EDGE_GRAB_START,
    EDGE_GRAB_STOP,
    MEDITATION_START,
    MEDITATION_STOP,
    MOVEMENT_HEARTBEAT,
    RESET
}
'@
Write-TextFile -Path $actionTypePath -Content $actionTypeContent
Write-Ok "Created MovementActionType.java"
$actions.Add("Created MovementActionType.java")

# 4. Create ClientMovementState
Write-Step "Creating ClientMovementState"
$statePath = Join-Path $srcJava "com\example\shinobicore\movement\client\ClientMovementState.java"
$stateContent = @'
// SHINOBICORE:SPRINT3:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.movement.common.MovementPhase;

/**
 * SPRINT 3 client-side movement state holder.
 * Foundation for Sprint 4 (parkour actions).
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

    private ClientMovementState() {}

    public static MovementPhase getPhase() { return phase; }
    public static int getTicksInPhase() { return ticksInPhase; }
    public static boolean isOnWater() { return onWater; }
    public static boolean isOnWall() { return onWall; }
    public static boolean isCrawling() { return isCrawling; }
    public static boolean isSliding() { return isSliding; }
    public static boolean isMeditating() { return isMeditating; }
    public static int getAirJumpsUsed() { return airJumpsUsed; }

    public static void setPhase(MovementPhase newPhase) {
        if (phase != newPhase) {
            phase = newPhase;
            ticksInPhase = 0;
        }
    }

    public static void tick() {
        ticksInPhase++;
    }

    public static void setOnWater(boolean value) { onWater = value; }
    public static void setOnWall(boolean value) { onWall = value; }
    public static void setCrawling(boolean value) { isCrawling = value; }
    public static void setSliding(boolean value) { isSliding = value; }
    public static void setMeditating(boolean value) { isMeditating = value; }
    public static void setAirJumpsUsed(int value) { airJumpsUsed = value; }

    public static int nextSequence() { return ++sequenceNumber; }

    public static void resetAll() {
        phase = MovementPhase.NORMAL;
        ticksInPhase = 0;
        onWater = false;
        onWall = false;
        isCrawling = false;
        isSliding = false;
        isMeditating = false;
        airJumpsUsed = 0;
    }
}
'@
Write-TextFile -Path $statePath -Content $stateContent
Write-Ok "Created ClientMovementState.java"
$actions.Add("Created ClientMovementState.java")

# 5. Update ChakraClientController to add public toggle + config fallback drain
Write-Step "Updating ChakraClientController with public toggle and safe drain"
$controllerPath = Join-Path $srcJava "com\example\shinobicore\chakra\client\ChakraClientController.java"
if (Test-Path $controllerPath) {
    $c = Read-TextFile $controllerPath
    $changed = $false

    # 5a. Make toggleChakraMode public if it was private/default
    if ($c -match "private static void toggleChakraMode\(\)") {
        $c = $c -replace "private static void toggleChakraMode\(\)", "public static void toggleChakraMode()"
        $changed = $true
    }

    # 5b. Ensure public isChakraModeActive getter exists
    if (-not $c.Contains("public static boolean isChakraModeActive()") -and -not $c.Contains("public static boolean isChakraMode()")) {
        $getter = "`n    public static boolean isChakraModeActive() { return chakraMode; }`n"
        $c = $c -replace "(\s*)\}\s*$", "$getter`n}"
        $changed = $true
    }

    # 5c. Replace chakraModeDrainPerSec access with safe fallback
    if ($c.Contains("config.chakra.chakraModeDrainPerSec")) {
        $c = $c -replace "config\.chakra\.chakraModeDrainPerSec", "(config.chakra != null ? config.chakra.chakraModeDrainPerSec : 3.0f)"
        $changed = $true
    }

    if ($changed) {
        Write-TextFile -Path $controllerPath -Content $c
        Write-Ok "Updated ChakraClientController (public toggle + safe drain)"
        $actions.Add("Updated ChakraClientController")
    } else {
        Write-Ok "ChakraClientController already in good state"
    }
} else {
    Write-Err "ChakraClientController.java not found!"
    exit 1
}

# 6. Create ChakraKeyHandler
Write-Step "Creating ChakraKeyHandler (L key listener)"
$keyHandlerPath = Join-Path $srcJava "com\example\shinobicore\chakra\client\ChakraKeyHandler.java"
$keyHandlerContent = @'
// SHINOBICORE:SPRINT3:FILE
package com.example.shinobicore.chakra.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.util.ShinobiLogger;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.option.KeyBinding;

/**
 * SPRINT 3 key handler for Chakra Mode (L key).
 * Uses reflection to safely access legacy KeyBindings.CHAKRA_MODE.
 */
public final class ChakraKeyHandler {
    private static boolean registered = false;
    private static boolean wasPressed = false;

    private ChakraKeyHandler() {}

    public static void register() {
        if (registered) return;
        registered = true;
        ClientTickEvents.END_CLIENT_TICK.register(ChakraKeyHandler::tick);
        ShinobiLogger.info("[SPRINT3] ChakraKeyHandler registered");
    }

    private static void tick(MinecraftClient client) {
        if (!FeatureFlags.chakraV3) return;
        if (client == null || client.player == null || client.world == null) return;
        if (client.isPaused()) return;
        if (client.currentScreen != null) return;

        KeyBinding chakraKey = resolveChakraKey();
        if (chakraKey == null) return;

        boolean pressed = chakraKey.isPressed();
        if (pressed && !wasPressed) {
            ChakraClientController.toggleChakraMode();
            if (ChakraClientController.isChakraMode()) {
                ShinobiLogger.info("[CHAKRA] Mode ON (L pressed)");
            } else {
                ShinobiLogger.info("[CHAKRA] Mode OFF (L pressed)");
            }
        }
        wasPressed = pressed;
    }

    private static KeyBinding resolveChakraKey() {
        try {
            Class<?> kbClass = Class.forName("com.example.shinobicore.client.KeyBindings");
            Object value = kbClass.getField("CHAKRA_MODE").get(null);
            if (value instanceof KeyBinding) return (KeyBinding) value;
        } catch (Throwable ignored) {}

        try {
            Class<?> kbClass = Class.forName("com.example.shinobicore.client.input.KeyBindings");
            Object value = kbClass.getField("CHAKRA_MODE").get(null);
            if (value instanceof KeyBinding) return (KeyBinding) value;
        } catch (Throwable ignored) {}

        return null;
    }
}
'@
Write-TextFile -Path $keyHandlerPath -Content $keyHandlerContent
Write-Ok "Created ChakraKeyHandler.java"
$actions.Add("Created ChakraKeyHandler.java")

# 7. Create MovementCommands (server-side /shinobicore movement state)
Write-Step "Creating MovementCommands"
$cmdPath = Join-Path $srcJava "com\example\shinobicore\command\MovementCommands.java"
$cmdContent = @'
// SHINOBICORE:SPRINT3:FILE
package com.example.shinobicore.command;

import com.example.shinobicore.chakra.server.ServerChakraMirror;
import com.example.shinobicore.config.FeatureFlags;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.context.CommandContext;
import net.fabricmc.fabric.api.command.v2.CommandRegistrationCallback;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import net.minecraft.util.Formatting;

/**
 * SPRINT 3 movement debug commands.
 * Foundation for Sprint 4 diagnostics.
 */
public final class MovementCommands {
    private static boolean registered = false;

    private MovementCommands() {}

    public static void register() {
        if (registered) return;
        registered = true;
        if (!FeatureFlags.movementV3) return;

        CommandRegistrationCallback.EVENT.register((dispatcher, registryAccess, environment) -> {
            registerCommands(dispatcher);
        });
    }

    private static void registerCommands(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(CommandManager.literal("shinobicore")
                .then(CommandManager.literal("movement")
                        .requires(source -> source.hasPermissionLevel(2))
                        .then(CommandManager.literal("state")
                                .executes(ctx -> showState(ctx)))
                        .then(CommandManager.literal("reset")
                                .executes(ctx -> resetState(ctx)))
                )
        );
    }

    private static int showState(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) {
            ctx.getSource().sendError(Text.literal("Player required").formatted(Formatting.RED));
            return 0;
        }

        ServerChakraMirror.Data chakra = ServerChakraMirror.get(player.getUuid());

        ctx.getSource().sendFeedback(() -> Text.literal("=== Movement State ===").formatted(Formatting.GOLD), false);
        ctx.getSource().sendFeedback(() -> Text.literal("Chakra: " + chakra.current + " / " + chakra.max).formatted(Formatting.AQUA), false);
        ctx.getSource().sendFeedback(() -> Text.literal("Mode: " + (chakra.chakraMode ? "ON" : "OFF")).formatted(chakra.chakraMode ? Formatting.GREEN : Formatting.RED), false);
        ctx.getSource().sendFeedback(() -> Text.literal("Fatigue: " + chakra.fatigue).formatted(Formatting.WHITE), false);
        ctx.getSource().sendFeedback(() -> Text.literal("[SPRINT3] Movement foundation ready for Sprint 4").formatted(Formatting.GRAY), false);
        return 1;
    }

    private static int resetState(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) {
            ctx.getSource().sendError(Text.literal("Player required").formatted(Formatting.RED));
            return 0;
        }

        ServerChakraMirror.reset(player.getUuid());
        ctx.getSource().sendFeedback(() -> Text.literal("Movement state reset").formatted(Formatting.YELLOW), false);
        return 1;
    }
}
'@
Write-TextFile -Path $cmdPath -Content $cmdContent
Write-Ok "Created MovementCommands.java"
$actions.Add("Created MovementCommands.java")

# 8. Create Sprint3Bootstrap (main)
Write-Step "Creating Sprint3Bootstrap (main)"
$bootstrapPath = Join-Path $srcJava "com\example\shinobicore\bootstrap\Sprint3Bootstrap.java"
$bootstrapContent = @'
// SHINOBICORE:SPRINT3:FILE
package com.example.shinobicore.bootstrap;

import com.example.shinobicore.command.MovementCommands;
import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.util.ShinobiLogger;
import net.fabricmc.api.ModInitializer;

/**
 * SPRINT 3 server-side bootstrap.
 * Registers movement commands and future parkour systems.
 */
public class Sprint3Bootstrap implements ModInitializer {
    private static boolean initialized = false;

    @Override
    public void onInitialize() {
        if (initialized) return;
        initialized = true;

        try {
            if (!FeatureFlags.movementV3) {
                ShinobiLogger.info("[SPRINT3] movementV3 flag disabled, skipping bootstrap");
                return;
            }

            MovementCommands.register();
            ShinobiLogger.info("[SPRINT3] Movement foundation bootstrap initialized");
        } catch (Throwable t) {
            ShinobiLogger.error("[SPRINT3] Bootstrap failed: " + t.getMessage());
        }
    }
}
'@
Write-TextFile -Path $bootstrapPath -Content $bootstrapContent
Write-Ok "Created Sprint3Bootstrap.java"
$actions.Add("Created Sprint3Bootstrap.java")

# 9. Create Sprint3ClientBootstrap (client)
Write-Step "Creating Sprint3ClientBootstrap (client)"
$clientBootstrapPath = Join-Path $srcJava "com\example\shinobicore\bootstrap\Sprint3ClientBootstrap.java"
$clientBootstrapContent = @'
// SHINOBICORE:SPRINT3:FILE
package com.example.shinobicore.bootstrap;

import com.example.shinobicore.chakra.client.ChakraKeyHandler;
import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.util.ShinobiLogger;
import net.fabricmc.api.ClientModInitializer;

/**
 * SPRINT 3 client-side bootstrap.
 * Registers key handlers and future parkour client systems.
 */
public class Sprint3ClientBootstrap implements ClientModInitializer {
    @Override
    public void onInitializeClient() {
        if (!FeatureFlags.movementV3) {
            ShinobiLogger.info("[SPRINT3] movementV3 flag disabled, skipping client bootstrap");
            return;
        }

        ChakraKeyHandler.register();
        ShinobiLogger.info("[SPRINT3] Client key handler registered (L = chakra mode toggle)");
    }
}
'@
Write-TextFile -Path $clientBootstrapPath -Content $clientBootstrapContent
Write-Ok "Created Sprint3ClientBootstrap.java"
$actions.Add("Created Sprint3ClientBootstrap.java")

# 10. Register entrypoints in fabric.mod.json
Write-Step "Registering entrypoints in fabric.mod.json"
$fmjPath = Join-Path $resMain "fabric.mod.json"

$mainAdded = Add-Entrypoint -FabricPath $fmjPath -Category "main" -Entrypoint "com.example.shinobicore.bootstrap.Sprint3Bootstrap"
if ($mainAdded) {
    Write-Ok "Registered Sprint3Bootstrap (main)"
    $actions.Add("Registered Sprint3Bootstrap (main)")
} else {
    Write-Ok "Sprint3Bootstrap already registered"
}

$clientAdded = Add-Entrypoint -FabricPath $fmjPath -Category "client" -Entrypoint "com.example.shinobicore.bootstrap.Sprint3ClientBootstrap"
if ($clientAdded) {
    Write-Ok "Registered Sprint3ClientBootstrap (client)"
    $actions.Add("Registered Sprint3ClientBootstrap (client)")
} else {
    Write-Ok "Sprint3ClientBootstrap already registered"
}

# 11. Build
if (-not $SkipBuild) {
    Write-Step "Running Gradle build"
    $buildOk = Invoke-GradleBuild -RootPath $Root -LogDir $outDir
    if (-not $buildOk) {
        Write-Err "Sprint 3 failed build."
        exit 1
    }
}

# 12. Report
Write-Step "Generating Sprint 3 report"
$report = New-Object System.Text.StringBuilder
[void]$report.AppendLine("SHINOBI CORE - SPRINT 3 REPORT")
[void]$report.AppendLine("Generated: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
[void]$report.AppendLine("")
[void]$report.AppendLine("=== ACTIONS ===")
foreach ($a in $actions) { [void]$report.AppendLine($a) }

$reportPath = Join-Path $outDir "sprint3_report.txt"
Write-TextFile -Path $reportPath -Content $report.ToString()
Write-Ok "Report saved: $reportPath"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " MASTER SPRINT 3 COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Test in-game:" -ForegroundColor Yellow
Write-Host "  1. Press L to toggle Chakra Mode" -ForegroundColor White
Write-Host "  2. Watch chakra drain while mode is ON" -ForegroundColor White
Write-Host "  3. /shinobicore movement state" -ForegroundColor White
Write-Host "  4. /shinobicore chakra info" -ForegroundColor White
Write-Host ""
Write-Host "Next step: MASTER SPRINT 4 (Water walk + Wall run foundation)" -ForegroundColor Yellow
Write-Host ""

exit 0
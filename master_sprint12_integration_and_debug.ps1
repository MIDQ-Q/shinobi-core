param(
    [string]$Root = "",
    [switch]$SkipBuild
)

# ============================================================
# SHINOBI CORE
# MASTER SPRINT 12: INTEGRATION TEST & DEBUG HUD
# ============================================================

$ErrorActionPreference = "Stop"
$script:utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "[SPRINT12] $Message" -ForegroundColor Cyan
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
    if (-not (Test-Path $src)) { return }
    $dest = Join-Path $BackupDir $RelativePath
    $destDir = Split-Path $dest -Parent
    Ensure-Directory $destDir
    Copy-Item -Path $src -Destination $dest -Force
    Write-Ok "Backed up $RelativePath"
}

function Add-ClientEntrypoint([string]$FabricPath, [string]$Entrypoint) {
    if (-not (Test-Path $FabricPath)) { return $false }
    $raw = Read-TextFile $FabricPath
    try { $json = $raw | ConvertFrom-Json } catch { return $false }

    if (-not ($json.PSObject.Properties.Name -contains "entrypoints")) {
        Add-Member -InputObject $json -MemberType NoteProperty -Name "entrypoints" -Value ([PSCustomObject]@{})
    }
    $ep = $json.entrypoints
    if (-not ($ep.PSObject.Properties.Name -contains "client")) {
        Add-Member -InputObject $ep -MemberType NoteProperty -Name "client" -Value @()
    }
    
    $list = @($ep.client)
    if ($list -contains $Entrypoint) { return $false }
    
    $list += $Entrypoint
    $ep.client = $list
    
    $newJson = $json | ConvertTo-Json -Depth 20
    Write-TextFile -Path $FabricPath -Content $newJson
    return $true
}

function Invoke-GradleBuildDetailed([string]$RootPath, [string]$LogDir) {
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
            $output | ForEach-Object { $_.ToString() } | Where-Object { $_ -match "error:|symbol:|location:" } | Select-Object -First 80 | ForEach-Object { Write-Host $_ -ForegroundColor Red }
        }
        return $false
    }
    finally { Pop-Location }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " SHINOBI CORE - MASTER SPRINT 12" -ForegroundColor Cyan
Write-Host " Integration Test & Debug HUD" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = (Get-Location).Path }
if (-not (Test-Path (Join-Path $Root "gradlew.bat"))) { $Root = "E:\Games\mod" }
if (-not (Test-Path (Join-Path $Root "gradlew.bat"))) { Write-Err "Project root not found."; exit 1 }

Write-Ok "Project root: $Root"
$srcJava = Join-Path $Root "src\main\java"
$resMain = Join-Path $Root "src\main\resources"
$outDir = Join-Path $Root "scripts\out\sprint12"
Ensure-Directory $outDir

$actions = New-Object System.Collections.Generic.List[string]
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $Root "backup\sprint12_$stamp"

Write-Step "Creating backup"
Backup-File "src\main\resources\fabric.mod.json" $backupDir
Backup-File "src\main\java\com\example\shinobicore\config\FeatureFlags.java" $backupDir

# ------------------------------------------------------------
# 1. Enable debugMovement flag
# ------------------------------------------------------------
Write-Step "Enabling debugMovement flag"
$flagsPath = Join-Path $srcJava "com\example\shinobicore\config\FeatureFlags.java"
if (Test-Path $flagsPath) {
    $c = Read-TextFile $flagsPath
    if ($c -match "public static boolean debugMovement = false;") {
        $c = $c -replace "public static boolean debugMovement = false;", "public static boolean debugMovement = true;"
        Write-TextFile -Path $flagsPath -Content $c
        Write-Ok "Set debugMovement = true"
        $actions.Add("Enabled debugMovement flag")
    } else {
        Write-Ok "debugMovement already enabled or custom"
    }
}

# ------------------------------------------------------------
# 2. Create MovementPhaseHud
# ------------------------------------------------------------
Write-Step "Creating MovementPhaseHud"
$hudPath = Join-Path $srcJava "com\example\shinobicore\movement\client\MovementPhaseHud.java"
$hudContent = @'
// SHINOBICORE:SPRINT12:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.chakra.client.ChakraClientController;
import com.example.shinobicore.config.FeatureFlags;
import net.fabricmc.fabric.api.client.rendering.v1.HudRenderCallback;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;

/**
 * SPRINT 12 debug HUD.
 * Renders current movement phase, iframes, and chakra on screen.
 */
public final class MovementPhaseHud {
    private MovementPhaseHud() {}

    public static void register() {
        HudRenderCallback.EVENT.register(MovementPhaseHud::render);
    }

    private static void render(DrawContext context, float tickDelta) {
        if (!FeatureFlags.debugMovement) return;
        
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null || client.options.hudHidden) return;

        String phase = ClientMovementState.getPhase().name();
        String iframes = ClientMovementState.isInvulnerable() ? " [IFRAMES]" : "";
        String chakra = String.format("Chakra: %.0f / %.0f", ChakraClientController.getCurrentChakra(), ChakraClientController.getMaxChakra());
        String mode = ChakraClientController.isChakraModeActive() ? " [MODE ON]" : "";
        String meditating = MeditationClient.isActive() ? " [MEDITATING]" : "";

        context.drawText(client.textRenderer, phase + iframes, 10, 10, 0xFFFFFF, true);
        context.drawText(client.textRenderer, chakra + mode + meditating, 10, 20, 0x00FFFF, true);
    }
}
'@
Write-TextFile -Path $hudPath -Content $hudContent
Write-Ok "Created MovementPhaseHud.java"
$actions.Add("Created MovementPhaseHud.java")

# ------------------------------------------------------------
# 3. Create MovementDebugCommand
# ------------------------------------------------------------
Write-Step "Creating MovementDebugCommand"
$cmdPath = Join-Path $srcJava "com\example\shinobicore\command\MovementDebugCommand.java"
$cmdContent = @'
// SHINOBICORE:SPRINT12:FILE
package com.example.shinobicore.command;

import com.example.shinobicore.chakra.client.ChakraClientController;
import com.example.shinobicore.movement.client.ClientMovementState;
import net.fabricmc.fabric.api.client.command.v2.ClientCommandManager;
import net.fabricmc.fabric.api.client.command.v2.ClientCommandRegistrationCallback;
import net.fabricmc.fabric.api.client.command.v2.FabricClientCommandSource;
import net.minecraft.text.Text;
import net.minecraft.util.Formatting;

/**
 * SPRINT 12 client-side debug command.
 * Usage: /shinobicore movement state
 */
public final class MovementDebugCommand {
    private MovementDebugCommand() {}

    public static void register() {
        ClientCommandRegistrationCallback.EVENT.register((dispatcher, registryAccess) -> {
            dispatcher.register(ClientCommandManager.literal("shinobicore")
                .then(ClientCommandManager.literal("movement")
                    .then(ClientCommandManager.literal("state")
                        .executes(ctx -> {
                            FabricClientCommandSource src = ctx.getSource();
                            src.sendFeedback(Text.literal("=== Client Movement State ===").formatted(Formatting.GOLD));
                            src.sendFeedback(Text.literal("Phase: " + ClientMovementState.getPhase().name()).formatted(Formatting.AQUA));
                            src.sendFeedback(Text.literal("Invulnerable: " + ClientMovementState.isInvulnerable()).formatted(Formatting.WHITE));
                            src.sendFeedback(Text.literal("On Wall: " + ClientMovementState.isOnWall()).formatted(Formatting.WHITE));
                            src.sendFeedback(Text.literal("On Water: " + ClientMovementState.isOnWater()).formatted(Formatting.WHITE));
                            src.sendFeedback(Text.literal("Air Jumps: " + ClientMovementState.getAirJumpsUsed() + " / " + ClientMovementState.getMaxAirJumps()).formatted(Formatting.WHITE));
                            src.sendFeedback(Text.literal("Chakra: " + String.format("%.0f / %.0f", ChakraClientController.getCurrentChakra(), ChakraClientController.getMaxChakra())).formatted(Formatting.GREEN));
                            src.sendFeedback(Text.literal("Mode: " + ChakraClientController.isChakraModeActive()).formatted(Formatting.YELLOW));
                            return 1;
                        }))));
        });
    }
}
'@
Write-TextFile -Path $cmdPath -Content $cmdContent
Write-Ok "Created MovementDebugCommand.java"
$actions.Add("Created MovementDebugCommand.java")

# ------------------------------------------------------------
# 4. Create Sprint12ClientBootstrap
# ------------------------------------------------------------
Write-Step "Creating Sprint12ClientBootstrap"
$bootstrapPath = Join-Path $srcJava "com\example\shinobicore\bootstrap\Sprint12ClientBootstrap.java"
$bootstrapContent = @'
// SHINOBICORE:SPRINT12:FILE
package com.example.shinobicore.bootstrap;

import com.example.shinobicore.command.MovementDebugCommand;
import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.client.MovementPhaseHud;
import com.example.shinobicore.util.ShinobiLogger;
import net.fabricmc.api.ClientModInitializer;

/**
 * SPRINT 12 client-side bootstrap.
 * Registers debug HUD and client commands.
 */
public class Sprint12ClientBootstrap implements ClientModInitializer {
    @Override
    public void onInitializeClient() {
        if (!FeatureFlags.movementV3) return;

        MovementDebugCommand.register();
        MovementPhaseHud.register();

        ShinobiLogger.info("[SPRINT12] Debug command and HUD registered");
    }
}
'@
Write-TextFile -Path $bootstrapPath -Content $bootstrapContent
Write-Ok "Created Sprint12ClientBootstrap.java"
$actions.Add("Created Sprint12ClientBootstrap.java")

# ------------------------------------------------------------
# 5. Register client entrypoint
# ------------------------------------------------------------
Write-Step "Registering Sprint12ClientBootstrap in fabric.mod.json"
$fmjPath = Join-Path $resMain "fabric.mod.json"
if (Add-ClientEntrypoint -FabricPath $fmjPath -Entrypoint "com.example.shinobicore.bootstrap.Sprint12ClientBootstrap") {
    Write-Ok "Registered Sprint12ClientBootstrap"
    $actions.Add("Registered Sprint12ClientBootstrap")
} else {
    Write-Ok "Sprint12ClientBootstrap already registered"
}

# ------------------------------------------------------------
# 6. Build
# ------------------------------------------------------------
if (-not $SkipBuild) {
    Write-Step "Running Gradle build"
    $buildOk = Invoke-GradleBuildDetailed -RootPath $Root -LogDir $outDir
    if (-not $buildOk) {
        Write-Err "Sprint 12 failed build."
        exit 1
    }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " MASTER SPRINT 12 COMPLETE" -ForegroundColor Green
Write-Host " MOVEMENT V3 FOUNDATION IS OFFICIALLY FINISHED" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Test in-game:" -ForegroundColor Yellow
Write-Host "  1. Look at the top-left corner -> Debug HUD" -ForegroundColor White
Write-Host "  2. Type /shinobicore movement state -> Chat output" -ForegroundColor White
Write-Host "  3. Test all moves: Water, Wall, Slide, Crawl, Roll, Dodge, Jump, Edge, Meditate" -ForegroundColor White
Write-Host ""
Write-Host "Next step: MASTER SPRINT 13 (Progression & Stats integration)" -ForegroundColor Yellow
Write-Host ""

exit 0
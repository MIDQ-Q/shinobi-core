param(
    [string]$Root = "",
    [switch]$SkipBuild
)

# ============================================================
# SHINOBI CORE
# MASTER SPRINT 1: CONFIG + FEATURE FLAGS + CHAKRA FOUNDATION
# ============================================================

$ErrorActionPreference = "Stop"

$script:utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "[SPRINT1] $Message" -ForegroundColor Cyan
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
    if (-not (Test-Path $Path)) {
        return ""
    }

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

function Add-FeatureFlag([string]$Name, [bool]$Value) {
    $path = Join-Path $srcJava "com\example\shinobicore\config\FeatureFlags.java"

    if (-not (Test-Path $path)) {
        return $false
    }

    $content = Read-TextFile $path

    $pattern = "public\s+static\s+boolean\s+" + [regex]::Escape($Name) + "\s*="

    if ($content -match $pattern) {
        return $false
    }

    $defaultValue = "false"
    if ($Value) {
        $defaultValue = "true"
    }

    $line = "    public static boolean " + $Name + " = " + $defaultValue + ";`n"

    $lastBrace = $content.LastIndexOf("}")

    if ($lastBrace -lt 0) {
        return $false
    }

    $newContent = $content.Substring(0, $lastBrace) + $line + $content.Substring($lastBrace)
    Write-TextFile -Path $path -Content $newContent

    return $true
}

function Add-MainEntrypoint([string]$FabricPath, [string]$Entrypoint) {
    if (-not (Test-Path $FabricPath)) {
        return $false
    }

    $raw = Read-TextFile $FabricPath

    try {
        $json = $raw | ConvertFrom-Json
    }
    catch {
        return $false
    }

    if (-not ($json.PSObject.Properties.Name -contains "entrypoints")) {
        Add-Member -InputObject $json -MemberType NoteProperty -Name "entrypoints" -Value ([PSCustomObject]@{})
    }
    elseif ($null -eq $json.entrypoints) {
        $json.entrypoints = [PSCustomObject]@{}
    }

    $ep = $json.entrypoints

    if (-not ($ep.PSObject.Properties.Name -contains "main")) {
        Add-Member -InputObject $ep -MemberType NoteProperty -Name "main" -Value @()
    }
    elseif ($null -eq $ep.main) {
        $ep.main = @()
    }

    $main = @($ep.main)

    if ($main -contains $Entrypoint) {
        return $false
    }

    $main += $Entrypoint
    $ep.main = $main

    $newJson = $json | ConvertTo-Json -Depth 20
    Write-TextFile -Path $FabricPath -Content $newJson

    return $true
}

function Invoke-GradleBuild([string]$RootPath, [string]$LogDir) {
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
        Write-Host ""
        Write-Host "Last output lines:" -ForegroundColor Red

        if ($output) {
            $output | Select-Object -Last 40 | ForEach-Object {
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
Write-Host " SHINOBI CORE - MASTER SPRINT 1" -ForegroundColor Cyan
Write-Host " Config, feature flags, chakra foundation" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# ------------------------------------------------------------
# 1. Resolve root
# ------------------------------------------------------------

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = (Get-Location).Path
}

if (-not (Test-Path (Join-Path $Root "gradlew.bat"))) {
    $candidate = "E:\Games\mod"

    if (Test-Path (Join-Path $candidate "gradlew.bat")) {
        $Root = $candidate
    }
}

if (-not (Test-Path (Join-Path $Root "gradlew.bat"))) {
    Write-Err "Project root not found. Use -Root `"E:\Games\mod`" or run from project root."
    exit 1
}

Write-Ok "Project root: $Root"

$srcJava = Join-Path $Root "src\main\java"
$resMain = Join-Path $Root "src\main\resources"
$outDir = Join-Path $Root "scripts\out\sprint1"

Ensure-Directory $outDir

$actions = New-Object System.Collections.Generic.List[string]
$issues = New-Object System.Collections.Generic.List[string]

# ------------------------------------------------------------
# 2. Backup
# ------------------------------------------------------------

Write-Step "Creating backup before Sprint 1"

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $Root "backup\sprint1_$stamp"

Backup-File "src\main\resources\fabric.mod.json" $backupDir
Backup-File "src\main\java\com\example\shinobicore\config\FeatureFlags.java" $backupDir
Backup-File "src\main\java\com\example\shinobicore\bootstrap\Sprint1Bootstrap.java" $backupDir
Backup-File "src\main\java\com\example\shinobicore\command\ChakraCommands.java" $backupDir
Backup-File "src\main\java\com\example\shinobicore\chakra\server\ServerChakraMirror.java" $backupDir
Backup-File "src\main\java\com\example\shinobicore\config\MovementChakraConfig.java" $backupDir

$actions.Add("Backup created at $backupDir")

# ------------------------------------------------------------
# 3. Ensure FeatureFlags exists
# ------------------------------------------------------------

Write-Step "Ensuring FeatureFlags.java exists"

$featureFlagsPath = Join-Path $srcJava "com\example\shinobicore\config\FeatureFlags.java"

$featureFlagsContent = @'
// SHINOBICORE:SPRINT1:FILE
package com.example.shinobicore.config;

/**
 * SPRINT 1 feature flags.
 *
 * Generated/maintained by master_sprint1_config_chakra_foundation.ps1
 */
public final class FeatureFlags {
    private FeatureFlags() {}

    public static boolean movementV3 = true;
    public static boolean chakraV3 = true;
    public static boolean progression = true;
    public static boolean combatV3 = false;

    public static boolean waterWalk = true;
    public static boolean wallRun = true;
    public static boolean slide = true;
    public static boolean crawl = true;
    public static boolean roll = true;
    public static boolean dodge = true;
    public static boolean chargedJump = true;
    public static boolean doubleJump = true;
    public static boolean edgeGrab = true;
    public static boolean meditation = true;

    public static boolean debugMovement = false;
    public static boolean debugChakra = false;
    public static boolean debugServerMirror = false;

    public static boolean chakraCommands = true;
    public static boolean chakraConfig = true;
    public static boolean serverChakraMirror = true;
}
'@

if (-not (Test-Path $featureFlagsPath)) {
    Write-TextFile -Path $featureFlagsPath -Content $featureFlagsContent
    Write-Ok "Created FeatureFlags.java"
    $actions.Add("Created FeatureFlags.java")
}
else {
    Write-Ok "FeatureFlags.java already exists"
}

# ------------------------------------------------------------
# 4. Add missing feature flags
# ------------------------------------------------------------

Write-Step "Adding missing feature flags"

$flagsToAdd = @(
    @("movementV3", $true),
    @("chakraV3", $true),
    @("progression", $true),
    @("combatV3", $false),
    @("waterWalk", $true),
    @("wallRun", $true),
    @("slide", $true),
    @("crawl", $true),
    @("roll", $true),
    @("dodge", $true),
    @("chargedJump", $true),
    @("doubleJump", $true),
    @("edgeGrab", $true),
    @("meditation", $true),
    @("debugMovement", $false),
    @("debugChakra", $false),
    @("debugServerMirror", $false),
    @("chakraCommands", $true),
    @("chakraConfig", $true),
    @("serverChakraMirror", $true)
)

foreach ($pair in $flagsToAdd) {
    $flagName = $pair[0]
    $flagValue = $pair[1]

    if (Add-FeatureFlag -Name $flagName -Value $flagValue) {
        Write-Ok "Added feature flag: $flagName"
        $actions.Add("Added feature flag: $flagName")
    }
    else {
        Write-Ok "Feature flag already present: $flagName"
    }
}

# ------------------------------------------------------------
# 5. Create ServerChakraMirror
# ------------------------------------------------------------

Write-Step "Creating server chakra mirror"

$serverMirrorPath = Join-Path $srcJava "com\example\shinobicore\chakra\server\ServerChakraMirror.java"

$serverMirrorContent = @'
// SHINOBICORE:SPRINT1:FILE
package com.example.shinobicore.chakra.server;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * SPRINT 1 safe server-side chakra mirror.
 *
 * This is not yet an authoritative anti-cheat.
 * It stores a server-side snapshot for debugging and future sync.
 */
public final class ServerChakraMirror {
    public static final float DEFAULT_MAX_CHAKRA = 2000.0f;

    private static final Map<UUID, Data> DATA = new ConcurrentHashMap<>();

    private ServerChakraMirror() {}

    public static class Data {
        public float current = DEFAULT_MAX_CHAKRA;
        public float max = DEFAULT_MAX_CHAKRA;
        public float fatigue = 0.0f;
        public boolean chakraMode = false;
    }

    public static Data get(UUID uuid) {
        return DATA.computeIfAbsent(uuid, id -> new Data());
    }

    public static void set(UUID uuid, float value) {
        Data data = get(uuid);
        data.current = clamp(value, 0.0f, data.max);
    }

    public static void add(UUID uuid, float amount) {
        Data data = get(uuid);
        data.current = clamp(data.current + amount, 0.0f, data.max);
    }

    public static void reset(UUID uuid) {
        DATA.remove(uuid);
    }

    public static void resetAll() {
        DATA.clear();
    }

    private static float clamp(float value, float min, float max) {
        return Math.max(min, Math.min(max, value));
    }
}
'@

Write-TextFile -Path $serverMirrorPath -Content $serverMirrorContent
Write-Ok "Wrote ServerChakraMirror.java"
$actions.Add("Wrote ServerChakraMirror.java")

# ------------------------------------------------------------
# 6. Create MovementChakraConfig
# ------------------------------------------------------------

Write-Step "Creating movement/chakra config"

$movementConfigPath = Join-Path $srcJava "com\example\shinobicore\config\MovementChakraConfig.java"

$movementConfigContent = @'
// SHINOBICORE:SPRINT1:FILE
package com.example.shinobicore.config;

import com.example.shinobicore.util.ShinobiLogger;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import net.fabricmc.loader.api.FabricLoader;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

/**
 * SPRINT 1 independent movement/chakra config.
 *
 * File:
 * config/shinobicore/movement_chakra.json
 */
public final class MovementChakraConfig {
    private static final Gson GSON = new GsonBuilder().setPrettyPrinting().create();
    private static MovementChakraConfig instance;

    public ChakraSection chakra = new ChakraSection();
    public MovementSection movement = new MovementSection();
    public LoggingSection logging = new LoggingSection();

    public MovementChakraConfig() {}

    public static synchronized MovementChakraConfig getInstance() {
        if (instance == null) {
            instance = new MovementChakraConfig();
        }

        return instance;
    }

    public static Path getPath() {
        return FabricLoader.getInstance()
                .getConfigDir()
                .resolve("shinobicore")
                .resolve("movement_chakra.json");
    }

    public static synchronized void load() {
        Path path = getPath();

        try {
            if (Files.exists(path)) {
                String json = new String(Files.readAllBytes(path), StandardCharsets.UTF_8);
                MovementChakraConfig parsed = GSON.fromJson(json, MovementChakraConfig.class);

                if (parsed == null) {
                    parsed = new MovementChakraConfig();
                }

                parsed.normalize();
                instance = parsed;
                ShinobiLogger.info("[SPRINT1] Loaded movement_chakra.json");
            } else {
                instance = new MovementChakraConfig();
                save();
                ShinobiLogger.info("[SPRINT1] Created default movement_chakra.json");
            }
        } catch (Exception e) {
            ShinobiLogger.error("[SPRINT1] Failed to load movement_chakra.json: " + e.getMessage());
            instance = new MovementChakraConfig();

            try {
                save();
            } catch (Exception ignored) {
            }
        }
    }

    public static synchronized void save() {
        try {
            Path path = getPath();

            if (path.getParent() != null) {
                Files.createDirectories(path.getParent());
            }

            String json = GSON.toJson(getInstance());
            Files.write(path, json.getBytes(StandardCharsets.UTF_8));
        } catch (Exception e) {
            ShinobiLogger.error("[SPRINT1] Failed to save movement_chakra.json: " + e.getMessage());
        }
    }

    public static synchronized void reload() {
        instance = null;
        load();
        ShinobiLogger.info("[SPRINT1] movement_chakra.json reloaded");
    }

    private void normalize() {
        if (chakra == null) chakra = new ChakraSection();
        if (movement == null) movement = new MovementSection();
        if (logging == null) logging = new LoggingSection();
    }

    public static class ChakraSection {
        public float baseMaxChakra = 2000.0f;
        public float chakraRegenPerSec = 2.0f;
        public float chakraModeDrainPerSec = 3.0f;
        public float waterWalkDrainPerTick = 0.05f;
        public float wallWalkDrainPerTick = 0.075f;
        public float meditationRegenMultiplier = 3.0f;
    }

    public static class MovementSection {
        public boolean waterWalk = true;
        public boolean wallRun = true;
        public boolean slide = true;
        public boolean crawl = true;
        public boolean roll = true;
        public boolean dodge = true;
        public boolean chargedJump = true;
        public boolean doubleJump = true;
        public boolean edgeGrab = true;
        public boolean meditation = true;
    }

    public static class LoggingSection {
        public boolean chakra = false;
        public boolean movement = false;
        public boolean serverMirror = false;
    }
}
'@

Write-TextFile -Path $movementConfigPath -Content $movementConfigContent
Write-Ok "Wrote MovementChakraConfig.java"
$actions.Add("Wrote MovementChakraConfig.java")

# ------------------------------------------------------------
# 7. Create ChakraCommands
# ------------------------------------------------------------

Write-Step "Creating chakra commands"

$chakraCommandsPath = Join-Path $srcJava "com\example\shinobicore\command\ChakraCommands.java"

$chakraCommandsContent = @'
// SHINOBICORE:SPRINT1:FILE
package com.example.shinobicore.command;

import com.example.shinobicore.chakra.server.ServerChakraMirror;
import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.config.MovementChakraConfig;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.context.CommandContext;
import net.fabricmc.fabric.api.command.v2.CommandRegistrationCallback;
import net.minecraft.command.argument.FloatArgumentType;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import net.minecraft.util.Formatting;

/**
 * SPRINT 1 chakra debug/foundation commands.
 *
 * Commands:
 * /shinobicore chakra info
 * /shinobicore chakra set <value>
 * /shinobicore chakra add <value>
 * /shinobicore chakra reset
 * /shinobicore chakra config reload
 */
public final class ChakraCommands {
    private static boolean registered = false;

    private ChakraCommands() {}

    public static void register() {
        if (registered) {
            return;
        }

        registered = true;

        if (!FeatureFlags.chakraCommands) {
            return;
        }

        CommandRegistrationCallback.EVENT.register((dispatcher, registryAccess, environment) -> {
            registerCommands(dispatcher);
        });
    }

    private static void registerCommands(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(CommandManager.literal("shinobicore")
                .then(CommandManager.literal("chakra")
                        .requires(source -> source.hasPermissionLevel(2))
                        .then(CommandManager.literal("info")
                                .executes(ctx -> info(ctx)))
                        .then(CommandManager.literal("set")
                                .then(CommandManager.argument("value", FloatArgumentType.floatArg(0.0f, 1000000.0f))
                                        .executes(ctx -> set(ctx))))
                        .then(CommandManager.literal("add")
                                .then(CommandManager.argument("value", FloatArgumentType.floatArg(-1000000.0f, 1000000.0f))
                                        .executes(ctx -> add(ctx))))
                        .then(CommandManager.literal("reset")
                                .executes(ctx -> reset(ctx)))
                        .then(CommandManager.literal("config")
                                .then(CommandManager.literal("reload")
                                        .executes(ctx -> configReload(ctx))))
                )
        );
    }

    private static int info(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();

        if (player == null) {
            ctx.getSource().sendError(Text.literal("Player required").formatted(Formatting.RED));
            return 0;
        }

        ServerChakraMirror.Data data = ServerChakraMirror.get(player.getUuid());

        ctx.getSource().sendFeedback(() -> Text.literal(
                "Chakra: " + data.current + " / " + data.max +
                " | Fatigue: " + data.fatigue +
                " | Mode: " + (data.chakraMode ? "ON" : "OFF")
        ).formatted(Formatting.AQUA), false);

        return 1;
    }

    private static int set(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();

        if (player == null) {
            ctx.getSource().sendError(Text.literal("Player required").formatted(Formatting.RED));
            return 0;
        }

        float value = FloatArgumentType.getFloat(ctx, "value");
        ServerChakraMirror.set(player.getUuid(), value);

        ServerChakraMirror.Data data = ServerChakraMirror.get(player.getUuid());

        ctx.getSource().sendFeedback(() -> Text.literal(
                "Set chakra to " + data.current + " / " + data.max
        ).formatted(Formatting.GREEN), false);

        return 1;
    }

    private static int add(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();

        if (player == null) {
            ctx.getSource().sendError(Text.literal("Player required").formatted(Formatting.RED));
            return 0;
        }

        float value = FloatArgumentType.getFloat(ctx, "value");
        ServerChakraMirror.add(player.getUuid(), value);

        ServerChakraMirror.Data data = ServerChakraMirror.get(player.getUuid());

        ctx.getSource().sendFeedback(() -> Text.literal(
                "Added " + value + " chakra. Current: " + data.current + " / " + data.max
        ).formatted(Formatting.GREEN), false);

        return 1;
    }

    private static int reset(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();

        if (player == null) {
            ctx.getSource().sendError(Text.literal("Player required").formatted(Formatting.RED));
            return 0;
        }

        ServerChakraMirror.reset(player.getUuid());

        ctx.getSource().sendFeedback(() -> Text.literal(
                "Reset chakra mirror for " + player.getName().getString()
        ).formatted(Formatting.YELLOW), false);

        return 1;
    }

    private static int configReload(CommandContext<ServerCommandSource> ctx) {
        MovementChakraConfig.reload();

        ctx.getSource().sendFeedback(() -> Text.literal(
                "Movement/chakra config reloaded"
        ).formatted(Formatting.GREEN), false);

        return 1;
    }
}
'@

Write-TextFile -Path $chakraCommandsPath -Content $chakraCommandsContent
Write-Ok "Wrote ChakraCommands.java"
$actions.Add("Wrote ChakraCommands.java")

# ------------------------------------------------------------
# 8. Create Sprint1Bootstrap
# ------------------------------------------------------------

Write-Step "Creating Sprint1Bootstrap"

$bootstrapPath = Join-Path $srcJava "com\example\shinobicore\bootstrap\Sprint1Bootstrap.java"

$bootstrapContent = @'
// SHINOBICORE:SPRINT1:FILE
package com.example.shinobicore.bootstrap;

import com.example.shinobicore.command.ChakraCommands;
import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.config.MovementChakraConfig;
import com.example.shinobicore.util.ShinobiLogger;
import net.fabricmc.api.ModInitializer;

/**
 * SPRINT 1 safe bootstrap.
 *
 * Registered as an additional main entrypoint.
 */
public class Sprint1Bootstrap implements ModInitializer {
    private static boolean initialized = false;

    @Override
    public void onInitialize() {
        if (initialized) {
            return;
        }

        initialized = true;

        try {
            if (!FeatureFlags.chakraV3) {
                ShinobiLogger.info("[SPRINT1] chakraV3 flag disabled, skipping bootstrap");
                return;
            }

            if (FeatureFlags.chakraConfig) {
                MovementChakraConfig.load();
            }

            if (FeatureFlags.chakraCommands) {
                ChakraCommands.register();
            }

            ShinobiLogger.info("[SPRINT1] Chakra foundation bootstrap initialized");
        } catch (Throwable t) {
            ShinobiLogger.error("[SPRINT1] Bootstrap failed: " + t.getMessage());
        }
    }
}
'@

Write-TextFile -Path $bootstrapPath -Content $bootstrapContent
Write-Ok "Wrote Sprint1Bootstrap.java"
$actions.Add("Wrote Sprint1Bootstrap.java")

# ------------------------------------------------------------
# 9. Register Sprint1Bootstrap in fabric.mod.json
# ------------------------------------------------------------

Write-Step "Registering Sprint1Bootstrap in fabric.mod.json"

$fmjPath = Join-Path $resMain "fabric.mod.json"
$entrypoint = "com.example.shinobicore.bootstrap.Sprint1Bootstrap"

if (-not (Test-Path $fmjPath)) {
    Write-Err "fabric.mod.json not found: $fmjPath"
    exit 1
}

$rawFmj = Read-TextFile $fmjPath

if ($rawFmj.Contains($entrypoint)) {
    Write-Ok "Sprint1Bootstrap already registered"
}
else {
    $added = Add-MainEntrypoint -FabricPath $fmjPath -Entrypoint $entrypoint

    if ($added) {
        Write-Ok "Registered Sprint1Bootstrap in fabric.mod.json"
        $actions.Add("Registered Sprint1Bootstrap in fabric.mod.json")
    }
    else {
        Write-Err "Failed to register Sprint1Bootstrap in fabric.mod.json"
        $issues.Add("Failed to register Sprint1Bootstrap in fabric.mod.json")
        exit 1
    }
}

# ------------------------------------------------------------
# 10. Report
# ------------------------------------------------------------

Write-Step "Generating Sprint 1 report"

$report = New-Object System.Text.StringBuilder

[void]$report.AppendLine("SHINOBI CORE - SPRINT 1 REPORT")
[void]$report.AppendLine("Generated: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
[void]$report.AppendLine("Root: " + $Root)
[void]$report.AppendLine("")
[void]$report.AppendLine("=== ACTIONS ===")

if ($actions.Count -eq 0) {
    [void]$report.AppendLine("No actions performed.")
}
else {
    foreach ($action in $actions) {
        [void]$report.AppendLine($action)
    }
}

[void]$report.AppendLine("")
[void]$report.AppendLine("=== ISSUES ===")

if ($issues.Count -eq 0) {
    [void]$report.AppendLine("No issues detected.")
}
else {
    foreach ($issue in $issues) {
        [void]$report.AppendLine($issue)
    }
}

$reportPath = Join-Path $outDir "sprint1_report.txt"
Write-TextFile -Path $reportPath -Content $report.ToString()

Write-Ok "Sprint 1 report saved: $reportPath"

# ------------------------------------------------------------
# 11. Build
# ------------------------------------------------------------

if (-not $SkipBuild) {
    Write-Step "Running Gradle build"

    $buildOk = Invoke-GradleBuild -RootPath $Root -LogDir $outDir

    if (-not $buildOk) {
        Write-Err "Sprint 1 master script finished with BUILD FAILURE."
        Write-Err "See log: $(Join-Path $outDir 'gradle_build.log')"
        exit 1
    }
}
else {
    Write-Warn "Build skipped because -SkipBuild was specified"
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " MASTER SPRINT 1 COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Report: $reportPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "After launching client/server, test:" -ForegroundColor Yellow
Write-Host "  /shinobicore chakra info" -ForegroundColor White
Write-Host "  /shinobicore chakra set 1500" -ForegroundColor White
Write-Host "  /shinobicore chakra add 250" -ForegroundColor White
Write-Host "  /shinobicore chakra reset" -ForegroundColor White
Write-Host "  /shinobicore chakra config reload" -ForegroundColor White
Write-Host ""
Write-Host "Next step: MASTER SPRINT 2 - client chakra controller + sync foundation" -ForegroundColor Yellow
Write-Host ""

exit 0
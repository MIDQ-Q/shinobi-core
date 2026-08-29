param(
    [string]$Root = "",
    [switch]$SkipBuild
)

# ============================================================
# SHINOBI CORE
# MASTER SPRINT 13 + 14:
# PROGRESSION FOUNDATION + COMBAT V3 FOUNDATION
# ============================================================

$ErrorActionPreference = "Stop"
$script:utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "[SPRINT13/14] $Message" -ForegroundColor Cyan
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

function Add-Entrypoint([string]$FabricPath, [string]$Category, [string]$Entrypoint) {
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

    $ep = $json.entrypoints

    if (-not ($ep.PSObject.Properties.Name -contains $Category)) {
        Add-Member -InputObject $ep -MemberType NoteProperty -Name $Category -Value @()
    }

    $list = @($ep.$Category)

    if ($list -contains $Entrypoint) {
        return $false
    }

    $list += $Entrypoint
    $ep.$Category = $list

    $newJson = $json | ConvertTo-Json -Depth 20
    Write-TextFile -Path $FabricPath -Content $newJson

    return $true
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
                Select-Object -First 100 |
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
Write-Host " SHINOBI CORE - MASTER SPRINT 13 + 14" -ForegroundColor Cyan
Write-Host " Progression foundation + Combat V3 foundation" -ForegroundColor Cyan
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
$resMain = Join-Path $Root "src\main\resources"
$outDir = Join-Path $Root "scripts\out\sprint13_14"

Ensure-Directory $outDir

$actions = New-Object System.Collections.Generic.List[string]
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $Root "backup\sprint13_14_$stamp"

# ------------------------------------------------------------
# 2. Backup
# ------------------------------------------------------------

Write-Step "Creating backup"

Backup-File "src\main\resources\fabric.mod.json" $backupDir
Backup-File "src\main\java\com\example\shinobicore\config\FeatureFlags.java" $backupDir

# ------------------------------------------------------------
# 3. Enable progression and combatV3 flags
# ------------------------------------------------------------

Write-Step "Enabling progression and combatV3 flags"

$flagsPath = Join-Path $srcJava "com\example\shinobicore\config\FeatureFlags.java"

if (Test-Path $flagsPath) {
    $flagsContent = Read-TextFile $flagsPath

    $flagsContent = [regex]::Replace(
        $flagsContent,
        'public\s+static\s+boolean\s+progression\s*=\s*false\s*;',
        'public static boolean progression = true;'
    )

    $flagsContent = [regex]::Replace(
        $flagsContent,
        'public\s+static\s+boolean\s+combatV3\s*=\s*false\s*;',
        'public static boolean combatV3 = true;'
    )

    Write-TextFile -Path $flagsPath -Content $flagsContent
    Write-Ok "FeatureFlags updated"
    $actions.Add("Enabled progression and combatV3 flags")
}
else {
    Write-Warn "FeatureFlags.java not found"
}

# ------------------------------------------------------------
# 4. Progression V3 server core
# ------------------------------------------------------------

Write-Step "Creating Progression V3 server core"

$progressionCorePath = Join-Path $srcJava "com\example\shinobicore\progression\v3\ProgressionV3.java"

$progressionCoreContent = @'
// SHINOBICORE:SPRINT13:FILE
package com.example.shinobicore.progression.v3;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * SPRINT 13 safe server-side progression foundation.
 *
 * This is an in-memory foundation.
 * Later it will be synced to components / persistent data.
 */
public final class ProgressionV3 {
    private static final Map<UUID, Data> DATA = new ConcurrentHashMap<>();

    private ProgressionV3() {}

    public static class Data {
        public int level = 1;
        public int xp = 0;
        public int sp = 0;

        public final Map<String, Integer> statLevels = new ConcurrentHashMap<>();
        public final Map<String, Integer> statXp = new ConcurrentHashMap<>();
    }

    public static Data get(UUID uuid) {
        return DATA.computeIfAbsent(uuid, id -> new Data());
    }

    public static int getXpForNextLevel(int level) {
        return 100 + (level - 1) * 50;
    }

    public static int getStatXpForNextLevel(int level) {
        return 80 + (level - 1) * 40;
    }

    public static void addXp(UUID uuid, int amount) {
        if (amount <= 0) {
            return;
        }

        Data data = get(uuid);
        data.xp += amount;

        while (data.xp >= getXpForNextLevel(data.level)) {
            data.xp -= getXpForNextLevel(data.level);
            data.level++;
            data.sp++;
        }
    }

    public static void addSp(UUID uuid, int amount) {
        Data data = get(uuid);
        data.sp = Math.max(0, data.sp + amount);
    }

    public static void addStatXp(UUID uuid, String stat, int amount) {
        if (stat == null || stat.isEmpty() || amount <= 0) {
            return;
        }

        Data data = get(uuid);

        int xp = data.statXp.getOrDefault(stat, 0) + amount;
        int level = data.statLevels.getOrDefault(stat, 1);

        while (xp >= getStatXpForNextLevel(level)) {
            xp -= getStatXpForNextLevel(level);
            level++;
        }

        data.statXp.put(stat, xp);
        data.statLevels.put(stat, level);
    }

    public static void reset(UUID uuid) {
        DATA.remove(uuid);
    }

    public static void resetAll() {
        DATA.clear();
    }
}
'@

Write-TextFile -Path $progressionCorePath -Content $progressionCoreContent
Write-Ok "Created ProgressionV3.java"
$actions.Add("Created ProgressionV3.java")

# ------------------------------------------------------------
# 5. Progression V3 commands
# ------------------------------------------------------------

Write-Step "Creating Progression V3 commands"

$progressionCommandsPath = Join-Path $srcJava "com\example\shinobicore\progression\v3\ProgressionV3Commands.java"

$progressionCommandsContent = @'
// SHINOBICORE:SPRINT13:FILE
package com.example.shinobicore.progression.v3;

import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.arguments.IntegerArgumentType;
import com.mojang.brigadier.arguments.StringArgumentType;
import com.mojang.brigadier.context.CommandContext;
import net.fabricmc.fabric.api.command.v2.CommandRegistrationCallback;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import net.minecraft.util.Formatting;

/**
 * SPRINT 13 progression debug commands.
 *
 * Commands:
 * /shinobicore progressionv3 info
 * /shinobicore progressionv3 addxp <amount>
 * /shinobicore progressionv3 addsp <amount>
 * /shinobicore progressionv3 statxp <stat> <amount>
 * /shinobicore progressionv3 reset
 */
public final class ProgressionV3Commands {
    private static boolean registered = false;

    private ProgressionV3Commands() {}

    public static void register() {
        if (registered) {
            return;
        }

        registered = true;

        CommandRegistrationCallback.EVENT.register((dispatcher, registryAccess, environment) -> {
            registerCommands(dispatcher);
        });
    }

    private static void registerCommands(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(CommandManager.literal("shinobicore")
                .then(CommandManager.literal("progressionv3")
                        .requires(source -> source.hasPermissionLevel(2))
                        .then(CommandManager.literal("info")
                                .executes(ctx -> info(ctx)))
                        .then(CommandManager.literal("addxp")
                                .then(CommandManager.argument("amount", IntegerArgumentType.integer(0, 1000000))
                                        .executes(ctx -> addXp(ctx))))
                        .then(CommandManager.literal("addsp")
                                .then(CommandManager.argument("amount", IntegerArgumentType.integer(0, 100000))
                                        .executes(ctx -> addSp(ctx))))
                        .then(CommandManager.literal("statxp")
                                .then(CommandManager.argument("stat", StringArgumentType.word())
                                        .then(CommandManager.argument("amount", IntegerArgumentType.integer(0, 1000000))
                                                .executes(ctx -> addStatXp(ctx)))))
                        .then(CommandManager.literal("reset")
                                .executes(ctx -> reset(ctx)))
                )
        );
    }

    private static int info(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();

        if (player == null) {
            ctx.getSource().sendError(Text.literal("Player required").formatted(Formatting.RED));
            return 0;
        }

        ProgressionV3.Data data = ProgressionV3.get(player.getUuid());

        ctx.getSource().sendFeedback(() -> Text.literal("=== Progression V3 ===").formatted(Formatting.GOLD), false);
        ctx.getSource().sendFeedback(() -> Text.literal(
                "Level: " + data.level +
                " | XP: " + data.xp +
                " | Next: " + ProgressionV3.getXpForNextLevel(data.level) +
                " | SP: " + data.sp
        ).formatted(Formatting.AQUA), false);

        return 1;
    }

    private static int addXp(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();

        if (player == null) {
            ctx.getSource().sendError(Text.literal("Player required").formatted(Formatting.RED));
            return 0;
        }

        int amount = IntegerArgumentType.getInteger(ctx, "amount");
        ProgressionV3.addXp(player.getUuid(), amount);

        ctx.getSource().sendFeedback(() -> Text.literal("Added " + amount + " XP").formatted(Formatting.GREEN), false);

        return 1;
    }

    private static int addSp(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();

        if (player == null) {
            ctx.getSource().sendError(Text.literal("Player required").formatted(Formatting.RED));
            return 0;
        }

        int amount = IntegerArgumentType.getInteger(ctx, "amount");
        ProgressionV3.addSp(player.getUuid(), amount);

        ctx.getSource().sendFeedback(() -> Text.literal("Added " + amount + " SP").formatted(Formatting.GREEN), false);

        return 1;
    }

    private static int addStatXp(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();

        if (player == null) {
            ctx.getSource().sendError(Text.literal("Player required").formatted(Formatting.RED));
            return 0;
        }

        String stat = StringArgumentType.getString(ctx, "stat");
        int amount = IntegerArgumentType.getInteger(ctx, "amount");

        ProgressionV3.addStatXp(player.getUuid(), stat, amount);

        ctx.getSource().sendFeedback(() -> Text.literal(
                "Added " + amount + " XP to stat: " + stat
        ).formatted(Formatting.GREEN), false);

        return 1;
    }

    private static int reset(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();

        if (player == null) {
            ctx.getSource().sendError(Text.literal("Player required").formatted(Formatting.RED));
            return 0;
        }

        ProgressionV3.reset(player.getUuid());

        ctx.getSource().sendFeedback(() -> Text.literal("Progression V3 reset").formatted(Formatting.YELLOW), false);

        return 1;
    }
}
'@

Write-TextFile -Path $progressionCommandsPath -Content $progressionCommandsContent
Write-Ok "Created ProgressionV3Commands.java"
$actions.Add("Created ProgressionV3Commands.java")

# ------------------------------------------------------------
# 6. Progression client state
# ------------------------------------------------------------

Write-Step "Creating Progression client state"

$progressionClientStatePath = Join-Path $srcJava "com\example\shinobicore\progression\v3\ProgressionClientState.java"

$progressionClientStateContent = @'
// SHINOBICORE:SPRINT13:FILE
package com.example.shinobicore.progression.v3;

/**
 * SPRINT 13 client-side progression cache.
 *
 * Later this will be synced from server.
 */
public final class ProgressionClientState {
    private static int level = 1;
    private static int xp = 0;
    private static int sp = 0;

    private ProgressionClientState() {}

    public static int getLevel() {
        return level;
    }

    public static int getXp() {
        return xp;
    }

    public static int getSp() {
        return sp;
    }

    public static void setLevel(int value) {
        level = Math.max(1, value);
    }

    public static void setXp(int value) {
        xp = Math.max(0, value);
    }

    public static void setSp(int value) {
        sp = Math.max(0, value);
    }
}
'@

Write-TextFile -Path $progressionClientStatePath -Content $progressionClientStateContent
Write-Ok "Created ProgressionClientState.java"
$actions.Add("Created ProgressionClientState.java")

# ------------------------------------------------------------
# 7. Progression screen
# ------------------------------------------------------------

Write-Step "Creating Progression V3 screen"

$progressionScreenPath = Join-Path $srcJava "com\example\shinobicore\client\gui\screen\ProgressionV3Screen.java"

$progressionScreenContent = @'
// SHINOBICORE:SPRINT13:FILE
package com.example.shinobicore.client.gui.screen;

import com.example.shinobicore.progression.v3.ProgressionClientState;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.gui.screen.Screen;
import net.minecraft.text.Text;

/**
 * SPRINT 13 minimal progression screen.
 * Opened with K key.
 */
public class ProgressionV3Screen extends Screen {

    public ProgressionV3Screen() {
        super(Text.literal("Progression V3"));
    }

    @Override
    public void render(DrawContext context, int mouseX, int mouseY, float delta) {
        context.fill(0, 0, this.width, this.height, 0xC0101010);

        context.drawCenteredTextWithShadow(
                this.textRenderer,
                this.title,
                this.width / 2,
                20,
                0xFFFFFF
        );

        context.drawText(
                this.textRenderer,
                "Level: " + ProgressionClientState.getLevel(),
                20,
                45,
                0xFFFF55,
                false
        );

        context.drawText(
                this.textRenderer,
                "XP: " + ProgressionClientState.getXp(),
                20,
                57,
                0x55FFFF,
                false
        );

        context.drawText(
                this.textRenderer,
                "SP: " + ProgressionClientState.getSp(),
                20,
                69,
                0x55FF55,
                false
        );

        context.drawText(
                this.textRenderer,
                "Sprint 13 foundation. Server sync will be added later.",
                20,
                90,
                0xAAAAAA,
                false
        );

        super.render(context, mouseX, mouseY, delta);
    }
}
'@

Write-TextFile -Path $progressionScreenPath -Content $progressionScreenContent
Write-Ok "Created ProgressionV3Screen.java"
$actions.Add("Created ProgressionV3Screen.java")

# ------------------------------------------------------------
# 8. Progression input handler
# ------------------------------------------------------------

Write-Step "Creating Progression input handler"

$progressionInputPath = Join-Path $srcJava "com\example\shinobicore\client\input\ProgressionInputHandler.java"

$progressionInputContent = @'
// SHINOBICORE:SPRINT13:FILE
package com.example.shinobicore.client.input;

import com.example.shinobicore.client.gui.screen.ProgressionV3Screen;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.option.KeyBinding;

/**
 * SPRINT 13 progression key handler.
 * Opens ProgressionV3Screen with K key.
 */
public final class ProgressionInputHandler {
    private static boolean registered = false;
    private static boolean wasPressed = false;

    private ProgressionInputHandler() {}

    public static void register() {
        if (registered) {
            return;
        }

        registered = true;
        ClientTickEvents.END_CLIENT_TICK.register(ProgressionInputHandler::tick);
    }

    private static void tick(MinecraftClient client) {
        KeyBinding key = KeyBindings.PROGRESSION;

        boolean pressed = key != null && key.isPressed();

        if (pressed && !wasPressed) {
            if (client != null && client.player != null && client.currentScreen == null) {
                client.setScreen(new ProgressionV3Screen());
            }
        }

        wasPressed = pressed;
    }
}
'@

Write-TextFile -Path $progressionInputPath -Content $progressionInputContent
Write-Ok "Created ProgressionInputHandler.java"
$actions.Add("Created ProgressionInputHandler.java")

# ------------------------------------------------------------
# 9. Combat V3 compatibility checker
# ------------------------------------------------------------

Write-Step "Creating Combat V3 compatibility checker"

$combatCompatPath = Join-Path $srcJava "com\example\shinobicore\combat\v3\CombatCompatibilityChecker.java"

$combatCompatContent = @'
// SHINOBICORE:SPRINT14:FILE
package com.example.shinobicore.combat.v3;

import net.fabricmc.loader.api.FabricLoader;

/**
 * SPRINT 14 combat compatibility checker.
 */
public final class CombatCompatibilityChecker {
    private static boolean betterCombat = false;
    private static boolean playerAnimator = false;
    private static boolean geckoLib = false;
    private static boolean clothConfig = false;

    private CombatCompatibilityChecker() {}

    public static void init() {
        FabricLoader loader = FabricLoader.getInstance();

        betterCombat = loader.isModLoaded("bettercombat");
        playerAnimator = loader.isModLoaded("player-animator");
        geckoLib = loader.isModLoaded("geckolib");
        clothConfig = loader.isModLoaded("cloth-config");
    }

    public static boolean hasBetterCombat() {
        return betterCombat;
    }

    public static boolean hasPlayerAnimator() {
        return playerAnimator;
    }

    public static boolean hasGeckoLib() {
        return geckoLib;
    }

    public static boolean hasClothConfig() {
        return clothConfig;
    }

    public static String getReport() {
        return "BetterCombat=" + betterCombat +
                ", PlayerAnimator=" + playerAnimator +
                ", GeckoLib=" + geckoLib +
                ", ClothConfig=" + clothConfig;
    }
}
'@

Write-TextFile -Path $combatCompatPath -Content $combatCompatContent
Write-Ok "Created CombatCompatibilityChecker.java"
$actions.Add("Created CombatCompatibilityChecker.java")

# ------------------------------------------------------------
# 10. Combat formula
# ------------------------------------------------------------

Write-Step "Creating Combat formula"

$combatFormulaPath = Join-Path $srcJava "com\example\shinobicore\combat\v3\CombatFormula.java"

$combatFormulaContent = @'
// SHINOBICORE:SPRINT14:FILE
package com.example.shinobicore.combat.v3;

/**
 * SPRINT 14 combat formula foundation.
 */
public final class CombatFormula {
    private CombatFormula() {}

    public static float calculateMeleeDamage(
            float baseDamage,
            float strengthLevel,
            float taijutsuLevel,
            float comboMultiplier
    ) {
        return baseDamage
                * (1.0f + strengthLevel * 0.02f + taijutsuLevel * 0.03f)
                * comboMultiplier;
    }
}
'@

Write-TextFile -Path $combatFormulaPath -Content $combatFormulaContent
Write-Ok "Created CombatFormula.java"
$actions.Add("Created CombatFormula.java")

# ------------------------------------------------------------
# 11. Combo tracker
# ------------------------------------------------------------

Write-Step "Creating ComboTracker"

$comboTrackerPath = Join-Path $srcJava "com\example\shinobicore\combat\v3\ComboTracker.java"

$comboTrackerContent = @'
// SHINOBICORE:SPRINT14:FILE
package com.example.shinobicore.combat.v3;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * SPRINT 14 combo tracker foundation.
 */
public final class ComboTracker {
    private static final Map<UUID, ComboState> COMBOS = new ConcurrentHashMap<>();

    private ComboTracker() {}

    public static class ComboState {
        public int step = 0;
        public long lastHitMs = 0;
    }

    public static ComboState get(UUID uuid) {
        return COMBOS.computeIfAbsent(uuid, id -> new ComboState());
    }

    public static void registerHit(UUID uuid, long nowMs, int comboWindowMs) {
        ComboState state = get(uuid);

        if (nowMs - state.lastHitMs <= comboWindowMs) {
            state.step++;
        } else {
            state.step = 1;
        }

        state.lastHitMs = nowMs;
    }

    public static int getStep(UUID uuid) {
        return get(uuid).step;
    }

    public static void reset(UUID uuid) {
        COMBOS.remove(uuid);
    }

    public static void resetAll() {
        COMBOS.clear();
    }
}
'@

Write-TextFile -Path $comboTrackerPath -Content $comboTrackerContent
Write-Ok "Created ComboTracker.java"
$actions.Add("Created ComboTracker.java")

# ------------------------------------------------------------
# 12. Combat V3 commands
# ------------------------------------------------------------

Write-Step "Creating Combat V3 commands"

$combatCommandsPath = Join-Path $srcJava "com\example\shinobicore\combat\v3\CombatV3Commands.java"

$combatCommandsContent = @'
// SHINOBICORE:SPRINT14:FILE
package com.example.shinobicore.combat.v3;

import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.arguments.FloatArgumentType;
import com.mojang.brigadier.context.CommandContext;
import net.fabricmc.fabric.api.command.v2.CommandRegistrationCallback;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.text.Text;
import net.minecraft.util.Formatting;

/**
 * SPRINT 14 combat debug commands.
 *
 * Commands:
 * /shinobicore combatv3 systems
 * /shinobicore combatv3 formula <baseDamage>
 */
public final class CombatV3Commands {
    private static boolean registered = false;

    private CombatV3Commands() {}

    public static void register() {
        if (registered) {
            return;
        }

        registered = true;

        CommandRegistrationCallback.EVENT.register((dispatcher, registryAccess, environment) -> {
            registerCommands(dispatcher);
        });
    }

    private static void registerCommands(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(CommandManager.literal("shinobicore")
                .then(CommandManager.literal("combatv3")
                        .requires(source -> source.hasPermissionLevel(2))
                        .then(CommandManager.literal("systems")
                                .executes(ctx -> systems(ctx)))
                        .then(CommandManager.literal("formula")
                                .then(CommandManager.argument("base", FloatArgumentType.floatArg(0.0f, 10000.0f))
                                        .executes(ctx -> formula(ctx))))
                )
        );
    }

    private static int systems(CommandContext<ServerCommandSource> ctx) {
        ctx.getSource().sendFeedback(() -> Text.literal("=== Combat V3 Systems ===").formatted(Formatting.GOLD), false);
        ctx.getSource().sendFeedback(() -> Text.literal("Module initialized: " + CombatV3Module.isInitialized()).formatted(Formatting.AQUA), false);
        ctx.getSource().sendFeedback(() -> Text.literal("Compat: " + CombatCompatibilityChecker.getReport()).formatted(Formatting.WHITE), false);

        return 1;
    }

    private static int formula(CommandContext<ServerCommandSource> ctx) {
        float base = FloatArgumentType.getFloat(ctx, "base");

        float damage = CombatFormula.calculateMeleeDamage(
                base,
                10.0f,
                10.0f,
                1.0f
        );

        ctx.getSource().sendFeedback(() -> Text.literal(
                "Formula sample: base " + base + " -> " + damage
        ).formatted(Formatting.GREEN), false);

        return 1;
    }
}
'@

Write-TextFile -Path $combatCommandsPath -Content $combatCommandsContent
Write-Ok "Created CombatV3Commands.java"
$actions.Add("Created CombatV3Commands.java")

# ------------------------------------------------------------
# 13. Combat V3 module
# ------------------------------------------------------------

Write-Step "Creating Combat V3 module"

$combatModulePath = Join-Path $srcJava "com\example\shinobicore\combat\v3\CombatV3Module.java"

$combatModuleContent = @'
// SHINOBICORE:SPRINT14:FILE
package com.example.shinobicore.combat.v3;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.util.ShinobiLogger;

/**
 * SPRINT 14 combat module foundation.
 */
public final class CombatV3Module {
    private static boolean initialized = false;

    private CombatV3Module() {}

    public static void init() {
        if (!FeatureFlags.combatV3) {
            ShinobiLogger.info("[COMBAT-V3] disabled by flag");
            return;
        }

        if (initialized) {
            return;
        }

        initialized = true;

        CombatCompatibilityChecker.init();
        CombatV3Commands.register();

        ShinobiLogger.info("[COMBAT-V3] Foundation initialized");
        ShinobiLogger.info("[COMBAT-V3] " + CombatCompatibilityChecker.getReport());
    }

    public static boolean isInitialized() {
        return initialized;
    }
}
'@

Write-TextFile -Path $combatModulePath -Content $combatModuleContent
Write-Ok "Created CombatV3Module.java"
$actions.Add("Created CombatV3Module.java")

# ------------------------------------------------------------
# 14. Sprint 13/14 main bootstrap
# ------------------------------------------------------------

Write-Step "Creating Sprint1314Bootstrap"

$bootstrapPath = Join-Path $srcJava "com\example\shinobicore\bootstrap\Sprint1314Bootstrap.java"

$bootstrapContent = @'
// SHINOBICORE:SPRINT13/14:FILE
package com.example.shinobicore.bootstrap;

import com.example.shinobicore.combat.v3.CombatV3Module;
import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.progression.v3.ProgressionV3Commands;
import com.example.shinobicore.util.ShinobiLogger;
import net.fabricmc.api.ModInitializer;

/**
 * SPRINT 13/14 server-side bootstrap.
 */
public class Sprint1314Bootstrap implements ModInitializer {
    private static boolean initialized = false;

    @Override
    public void onInitialize() {
        if (initialized) {
            return;
        }

        initialized = true;

        try {
            if (FeatureFlags.progression) {
                ProgressionV3Commands.register();
                ShinobiLogger.info("[SPRINT13] Progression V3 commands registered");
            }

            CombatV3Module.init();

            ShinobiLogger.info("[SPRINT13/14] Progression + Combat foundation bootstrap complete");
        } catch (Throwable t) {
            ShinobiLogger.error("[SPRINT13/14] Bootstrap failed: " + t.getMessage());
        }
    }
}
'@

Write-TextFile -Path $bootstrapPath -Content $bootstrapContent
Write-Ok "Created Sprint1314Bootstrap.java"
$actions.Add("Created Sprint1314Bootstrap.java")

# ------------------------------------------------------------
# 15. Sprint 13/14 client bootstrap
# ------------------------------------------------------------

Write-Step "Creating Sprint1314ClientBootstrap"

$clientBootstrapPath = Join-Path $srcJava "com\example\shinobicore\bootstrap\Sprint1314ClientBootstrap.java"

$clientBootstrapContent = @'
// SHINOBICORE:SPRINT13/14:FILE
package com.example.shinobicore.bootstrap;

import com.example.shinobicore.client.input.ProgressionInputHandler;
import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.util.ShinobiLogger;
import net.fabricmc.api.ClientModInitializer;

/**
 * SPRINT 13/14 client-side bootstrap.
 */
public class Sprint1314ClientBootstrap implements ClientModInitializer {
    @Override
    public void onInitializeClient() {
        try {
            if (FeatureFlags.progression) {
                ProgressionInputHandler.register();
                ShinobiLogger.info("[SPRINT13] Progression input handler registered (K opens screen)");
            }
        } catch (Throwable t) {
            ShinobiLogger.error("[SPRINT13/14] Client bootstrap failed: " + t.getMessage());
        }
    }
}
'@

Write-TextFile -Path $clientBootstrapPath -Content $clientBootstrapContent
Write-Ok "Created Sprint1314ClientBootstrap.java"
$actions.Add("Created Sprint1314ClientBootstrap.java")

# ------------------------------------------------------------
# 16. Register entrypoints
# ------------------------------------------------------------

Write-Step "Registering entrypoints in fabric.mod.json"

$fmjPath = Join-Path $resMain "fabric.mod.json"

$mainAdded = Add-Entrypoint `
    -FabricPath $fmjPath `
    -Category "main" `
    -Entrypoint "com.example.shinobicore.bootstrap.Sprint1314Bootstrap"

if ($mainAdded) {
    Write-Ok "Registered Sprint1314Bootstrap (main)"
    $actions.Add("Registered Sprint1314Bootstrap (main)")
}
else {
    Write-Ok "Sprint1314Bootstrap already registered"
}

$clientAdded = Add-Entrypoint `
    -FabricPath $fmjPath `
    -Category "client" `
    -Entrypoint "com.example.shinobicore.bootstrap.Sprint1314ClientBootstrap"

if ($clientAdded) {
    Write-Ok "Registered Sprint1314ClientBootstrap (client)"
    $actions.Add("Registered Sprint1314ClientBootstrap (client)")
}
else {
    Write-Ok "Sprint1314ClientBootstrap already registered"
}

# ------------------------------------------------------------
# 17. Build
# ------------------------------------------------------------

if (-not $SkipBuild) {
    Write-Step "Running Gradle build"

    $buildOk = Invoke-GradleBuildDetailed -RootPath $Root -LogDir $outDir

    if (-not $buildOk) {
        Write-Err "Sprint 13/14 failed build."
        Write-Err "Log: $(Join-Path $outDir 'gradle_build.log')"
        exit 1
    }
}
else {
    Write-Warn "Build skipped because -SkipBuild was specified"
}

# ------------------------------------------------------------
# 18. Report
# ------------------------------------------------------------

Write-Step "Generating Sprint 13/14 report"

$report = New-Object System.Text.StringBuilder

[void]$report.AppendLine("SHINOBI CORE - SPRINT 13/14 REPORT")
[void]$report.AppendLine("Generated: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
[void]$report.AppendLine("")
[void]$report.AppendLine("=== ACTIONS ===")

foreach ($action in $actions) {
    [void]$report.AppendLine($action)
}

$reportPath = Join-Path $outDir "sprint13_14_report.txt"
Write-TextFile -Path $reportPath -Content $report.ToString()

Write-Ok "Report saved: $reportPath"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " MASTER SPRINT 13 + 14 FOUNDATION COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Progression commands:" -ForegroundColor Yellow
Write-Host "  /shinobicore progressionv3 info" -ForegroundColor White
Write-Host "  /shinobicore progressionv3 addxp 100" -ForegroundColor White
Write-Host "  /shinobicore progressionv3 addsp 5" -ForegroundColor White
Write-Host "  /shinobicore progressionv3 statxp taijutsu 200" -ForegroundColor White
Write-Host "  /shinobicore progressionv3 reset" -ForegroundColor White
Write-Host ""
Write-Host "Combat commands:" -ForegroundColor Yellow
Write-Host "  /shinobicore combatv3 systems" -ForegroundColor White
Write-Host "  /shinobicore combatv3 formula 5" -ForegroundColor White
Write-Host ""
Write-Host "Client:" -ForegroundColor Yellow
Write-Host "  Press K to open Progression V3 screen" -ForegroundColor White
Write-Host ""
Write-Host "Next: sync progression with components + combat adapters" -ForegroundColor Cyan
Write-Host ""

exit 0
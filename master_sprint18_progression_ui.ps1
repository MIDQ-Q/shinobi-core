param(
    [string]$Root = "",
    [switch]$SkipBuild
)

# ============================================================
# SHINOBI CORE
# MASTER SPRINT 18:
# Progression UI Expansion + SP Spending + Stat Screen
# ============================================================

$ErrorActionPreference = "Stop"
$script:utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "[SPRINT18] $Message" -ForegroundColor Cyan
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
                Select-Object -First 120 |
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
Write-Host " SHINOBI CORE - MASTER SPRINT 18" -ForegroundColor Cyan
Write-Host " Progression UI + SP Spending + Stat Screen" -ForegroundColor Cyan
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
$outDir = Join-Path $Root "scripts\out\sprint18"

Ensure-Directory $outDir

$actions = New-Object System.Collections.Generic.List[string]
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $Root "backup\sprint18_$stamp"

# ------------------------------------------------------------
# 2. Backup
# ------------------------------------------------------------

Write-Step "Creating backup"

Backup-File "src\main\resources\fabric.mod.json" $backupDir
Backup-File "src\main\java\com\example\shinobicore\progression\v3\ProgressionV3.java" $backupDir
Backup-File "src\main\java\com\example\shinobicore\progression\v3\ProgressionV3Commands.java" $backupDir
Backup-File "src\main\java\com\example\shinobicore\progression\v3\ProgressionV3ServerSync.java" $backupDir
Backup-File "src\main\java\com\example\shinobicore\client\network\ProgressionV3ClientSync.java" $backupDir
Backup-File "src\main\java\com\example\shinobicore\progression\v3\ProgressionClientState.java" $backupDir
Backup-File "src\main\java\com\example\shinobicore\client\input\ProgressionInputHandler.java" $backupDir
Backup-File "src\main\java\com\example\shinobicore\client\gui\screen\ProgressionV3Screen.java" $backupDir

# ------------------------------------------------------------
# 3. Rewrite ProgressionClientState with stat maps
# ------------------------------------------------------------

Write-Step "Rewriting ProgressionClientState"

$clientStatePath = Join-Path $srcJava "com\example\shinobicore\progression\v3\ProgressionClientState.java"

$clientStateContent = @'
// SHINOBICORE:SPRINT18:FILE
package com.example.shinobicore.progression.v3;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * SPRINT 18 client-side progression cache.
 */
public final class ProgressionClientState {
    private static int level = 1;
    private static int xp = 0;
    private static int sp = 0;

    private static final Map<String, Integer> STAT_LEVELS = new LinkedHashMap<>();
    private static final Map<String, Integer> STAT_XP = new LinkedHashMap<>();

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

    public static Map<String, Integer> getStatLevels() {
        return STAT_LEVELS;
    }

    public static Map<String, Integer> getStatXp() {
        return STAT_XP;
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

    public static void clearStats() {
        STAT_LEVELS.clear();
        STAT_XP.clear();
    }

    public static void setStat(String stat, int statLevel, int statXp) {
        if (stat == null || stat.isEmpty()) {
            return;
        }

        STAT_LEVELS.put(stat, Math.max(1, statLevel));
        STAT_XP.put(stat, Math.max(0, statXp));
    }
}
'@

Write-TextFile -Path $clientStatePath -Content $clientStateContent
Write-Ok "Rewrote ProgressionClientState.java"
$actions.Add("Rewrote ProgressionClientState.java")

# ------------------------------------------------------------
# 4. Rewrite ProgressionV3ServerSync with full sync
# ------------------------------------------------------------

Write-Step "Rewriting ProgressionV3ServerSync"

$serverSyncPath = Join-Path $srcJava "com\example\shinobicore\progression\v3\ProgressionV3ServerSync.java"

$serverSyncContent = @'
// SHINOBICORE:SPRINT18:FILE
package com.example.shinobicore.progression.v3;

import net.fabricmc.fabric.api.networking.v1.PacketByteBufs;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.Identifier;

import java.util.Map;

/**
 * SPRINT 18 server-to-client progression sync.
 */
public final class ProgressionV3ServerSync {
    public static final Identifier ID =
            new Identifier("shinobicore", "progression_v3_sync");

    public static final Identifier FULL_ID =
            new Identifier("shinobicore", "progression_v3_full_sync");

    private ProgressionV3ServerSync() {}

    public static boolean send(ServerPlayerEntity player, ProgressionV3.Data data) {
        if (player == null || data == null) {
            return false;
        }

        if (!ServerPlayNetworking.canSend(player, ID)) {
            return false;
        }

        PacketByteBuf buf = PacketByteBufs.create();

        buf.writeInt(data.level);
        buf.writeInt(data.xp);
        buf.writeInt(data.sp);

        ServerPlayNetworking.send(player, ID, buf);

        return true;
    }

    public static boolean sendFull(ServerPlayerEntity player, ProgressionV3.Data data) {
        if (player == null || data == null) {
            return false;
        }

        if (!ServerPlayNetworking.canSend(player, FULL_ID)) {
            return false;
        }

        PacketByteBuf buf = PacketByteBufs.create();

        buf.writeInt(data.level);
        buf.writeInt(data.xp);
        buf.writeInt(data.sp);

        buf.writeVarInt(data.statLevels.size());

        for (Map.Entry<String, Integer> entry : data.statLevels.entrySet()) {
            String stat = entry.getKey();
            int statLevel = entry.getValue();
            int statXp = data.statXp.getOrDefault(stat, 0);

            buf.writeString(stat);
            buf.writeVarInt(statLevel);
            buf.writeVarInt(statXp);
        }

        ServerPlayNetworking.send(player, FULL_ID, buf);

        return true;
    }
}
'@

Write-TextFile -Path $serverSyncPath -Content $serverSyncContent
Write-Ok "Rewrote ProgressionV3ServerSync.java"
$actions.Add("Rewrote ProgressionV3ServerSync.java")

# ------------------------------------------------------------
# 5. Rewrite ProgressionV3ClientSync with full receiver
# ------------------------------------------------------------

Write-Step "Rewriting ProgressionV3ClientSync"

$clientSyncPath = Join-Path $srcJava "com\example\shinobicore\client\network\ProgressionV3ClientSync.java"

$clientSyncContent = @'
// SHINOBICORE:SPRINT18:FILE
package com.example.shinobicore.client.network;

import com.example.shinobicore.progression.v3.ProgressionClientState;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.networking.v1.PacketSender;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayNetworkHandler;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.util.Identifier;

/**
 * SPRINT 18 client receiver for progression sync.
 */
public final class ProgressionV3ClientSync {
    private static boolean registered = false;

    private static final Identifier OLD_ID =
            new Identifier("shinobicore", "progression_v3_sync");

    private static final Identifier FULL_ID =
            new Identifier("shinobicore", "progression_v3_full_sync");

    private ProgressionV3ClientSync() {}

    public static void register() {
        if (registered) {
            return;
        }

        registered = true;

        ClientPlayNetworking.registerGlobalReceiver(
                OLD_ID,
                (MinecraftClient client,
                 ClientPlayNetworkHandler handler,
                 PacketByteBuf buf,
                 PacketSender responseSender) -> {

                    int level = buf.readInt();
                    int xp = buf.readInt();
                    int sp = buf.readInt();

                    client.execute(() -> {
                        ProgressionClientState.setLevel(level);
                        ProgressionClientState.setXp(xp);
                        ProgressionClientState.setSp(sp);
                    });
                }
        );

        ClientPlayNetworking.registerGlobalReceiver(
                FULL_ID,
                (MinecraftClient client,
                 ClientPlayNetworkHandler handler,
                 PacketByteBuf buf,
                 PacketSender responseSender) -> {

                    int level = buf.readInt();
                    int xp = buf.readInt();
                    int sp = buf.readInt();

                    int count = buf.readVarInt();

                    java.util.LinkedHashMap<String, int[]> stats = new java.util.LinkedHashMap<>();

                    for (int i = 0; i < count; i++) {
                        String stat = buf.readString();
                        int statLevel = buf.readVarInt();
                        int statXp = buf.readVarInt();

                        stats.put(stat, new int[]{statLevel, statXp});
                    }

                    client.execute(() -> {
                        ProgressionClientState.setLevel(level);
                        ProgressionClientState.setXp(xp);
                        ProgressionClientState.setSp(sp);

                        ProgressionClientState.clearStats();

                        for (java.util.Map.Entry<String, int[]> entry : stats.entrySet()) {
                            ProgressionClientState.setStat(
                                    entry.getKey(),
                                    entry.getValue()[0],
                                    entry.getValue()[1]
                            );
                        }
                    });
                }
        );
    }
}
'@

Write-TextFile -Path $clientSyncPath -Content $clientSyncContent
Write-Ok "Rewrote ProgressionV3ClientSync.java"
$actions.Add("Rewrote ProgressionV3ClientSync.java")

# ------------------------------------------------------------
# 6. Create client C2S packet helper
# ------------------------------------------------------------

Write-Step "Creating ProgressionV3ClientPackets"

$clientPacketsPath = Join-Path $srcJava "com\example\shinobicore\client\network\ProgressionV3ClientPackets.java"

$clientPacketsContent = @'
// SHINOBICORE:SPRINT18:FILE
package com.example.shinobicore.client.network;

import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.networking.v1.PacketByteBufs;
import net.minecraft.client.MinecraftClient;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.util.Identifier;

/**
 * SPRINT 18 client-to-server progression packets.
 */
public final class ProgressionV3ClientPackets {
    public static final Identifier SPEND_STAT_ID =
            new Identifier("shinobicore", "progression_v3_spend_stat");

    private ProgressionV3ClientPackets() {}

    public static void sendSpendStat(String stat) {
        if (stat == null || stat.isEmpty()) {
            return;
        }

        if (MinecraftClient.getInstance().player == null) {
            return;
        }

        if (!ClientPlayNetworking.canSend(SPEND_STAT_ID)) {
            return;
        }

        PacketByteBuf buf = PacketByteBufs.create();
        buf.writeString(stat);

        ClientPlayNetworking.send(SPEND_STAT_ID, buf);
    }
}
'@

Write-TextFile -Path $clientPacketsPath -Content $clientPacketsContent
Write-Ok "Created ProgressionV3ClientPackets.java"
$actions.Add("Created ProgressionV3ClientPackets.java")

# ------------------------------------------------------------
# 7. Create server C2S handler
# ------------------------------------------------------------

Write-Step "Creating ProgressionV3ServerHandler"

$serverHandlerPath = Join-Path $srcJava "com\example\shinobicore\progression\v3\ProgressionV3ServerHandler.java"

$serverHandlerContent = @'
// SHINOBICORE:SPRINT18:FILE
package com.example.shinobicore.progression.v3;

import net.fabricmc.fabric.api.networking.v1.PacketSender;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.Identifier;

/**
 * SPRINT 18 server handler for progression C2S packets.
 */
public final class ProgressionV3ServerHandler {
    public static final Identifier SPEND_STAT_ID =
            new Identifier("shinobicore", "progression_v3_spend_stat");

    private static boolean registered = false;

    private ProgressionV3ServerHandler() {}

    public static void register() {
        if (registered) {
            return;
        }

        registered = true;

        ServerPlayNetworking.registerGlobalReceiver(
                SPEND_STAT_ID,
                (MinecraftServer server,
                 ServerPlayerEntity player,
                 PacketByteBuf buf,
                 PacketSender responseSender) -> {

                    String stat = buf.readString();

                    server.execute(() -> {
                        ProgressionV3.spendSpOnStat(player, stat);
                    });
                }
        );
    }
}
'@

Write-TextFile -Path $serverHandlerPath -Content $serverHandlerContent
Write-Ok "Created ProgressionV3ServerHandler.java"
$actions.Add("Created ProgressionV3ServerHandler.java")

# ------------------------------------------------------------
# 8. Rewrite ProgressionV3 core with SP spending
# ------------------------------------------------------------

Write-Step "Rewriting ProgressionV3 core"

$corePath = Join-Path $srcJava "com\example\shinobicore\progression\v3\ProgressionV3.java"

$coreContent = @'
// SHINOBICORE:SPRINT18:FILE
package com.example.shinobicore.progression.v3;

import net.minecraft.server.network.ServerPlayerEntity;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * SPRINT 18 server-side progression core.
 */
public final class ProgressionV3 {
    private static final Map<UUID, Data> DATA = new ConcurrentHashMap<>();

    private ProgressionV3() {}

    public static class Data {
        public int level = 1;
        public int xp = 0;
        public int sp = 0;

        public Map<String, Integer> statLevels = new ConcurrentHashMap<>();
        public Map<String, Integer> statXp = new ConcurrentHashMap<>();
    }

    public static Data get(UUID uuid) {
        return DATA.computeIfAbsent(uuid, id -> new Data());
    }

    public static Data get(ServerPlayerEntity player) {
        ensureLoaded(player);
        return DATA.computeIfAbsent(player.getUuid(), id -> new Data());
    }

    public static void ensureLoaded(ServerPlayerEntity player) {
        UUID uuid = player.getUuid();

        if (DATA.containsKey(uuid)) {
            return;
        }

        Data loaded = null;

        if (player.getServer() != null) {
            loaded = ProgressionV3Storage.load(player.getServer(), uuid);
        }

        if (loaded == null) {
            loaded = new Data();
        }

        DATA.put(uuid, loaded);
    }

    public static int getXpForNextLevel(int level) {
        return 100 + (level - 1) * 50;
    }

    public static int getStatXpForNextLevel(int level) {
        return 80 + (level - 1) * 40;
    }

    public static void addXp(ServerPlayerEntity player, int amount) {
        if (player == null || amount <= 0) {
            return;
        }

        ensureLoaded(player);
        Data data = get(player.getUuid());

        data.xp += amount;

        while (data.xp >= getXpForNextLevel(data.level)) {
            data.xp -= getXpForNextLevel(data.level);
            data.level++;
            data.sp++;
        }

        if (player.getServer() != null) {
            ProgressionV3Storage.save(player.getServer(), player.getUuid(), data);
        }

        ProgressionV3ServerSync.sendFull(player, data);
    }

    public static void addSp(ServerPlayerEntity player, int amount) {
        if (player == null) {
            return;
        }

        ensureLoaded(player);
        Data data = get(player.getUuid());

        data.sp = Math.max(0, data.sp + amount);

        if (player.getServer() != null) {
            ProgressionV3Storage.save(player.getServer(), player.getUuid(), data);
        }

        ProgressionV3ServerSync.sendFull(player, data);
    }

    public static void addStatXp(ServerPlayerEntity player, String stat, int amount) {
        if (player == null || stat == null || stat.isEmpty() || amount <= 0) {
            return;
        }

        ensureLoaded(player);
        Data data = get(player.getUuid());

        int xp = data.statXp.getOrDefault(stat, 0) + amount;
        int level = data.statLevels.getOrDefault(stat, 1);

        while (xp >= getStatXpForNextLevel(level)) {
            xp -= getStatXpForNextLevel(level);
            level++;
        }

        data.statXp.put(stat, xp);
        data.statLevels.put(stat, level);

        if (player.getServer() != null) {
            ProgressionV3Storage.save(player.getServer(), player.getUuid(), data);
        }

        ProgressionV3ServerSync.sendFull(player, data);
    }

    public static boolean spendSpOnStat(ServerPlayerEntity player, String stat) {
        if (player == null || stat == null || stat.isEmpty()) {
            return false;
        }

        ensureLoaded(player);
        Data data = get(player.getUuid());

        if (data.sp <= 0) {
            return false;
        }

        data.sp--;

        int newLevel = data.statLevels.getOrDefault(stat, 1) + 1;
        data.statLevels.put(stat, newLevel);

        if (player.getServer() != null) {
            ProgressionV3Storage.save(player.getServer(), player.getUuid(), data);
        }

        ProgressionV3ServerSync.sendFull(player, data);

        return true;
    }

    public static void reset(ServerPlayerEntity player) {
        if (player == null) {
            return;
        }

        DATA.remove(player.getUuid());

        if (player.getServer() != null) {
            ProgressionV3Storage.delete(player.getServer(), player.getUuid());
        }

        ensureLoaded(player);
        ProgressionV3ServerSync.sendFull(player, get(player.getUuid()));
    }
}
'@

Write-TextFile -Path $corePath -Content $coreContent
Write-Ok "Rewrote ProgressionV3.java"
$actions.Add("Rewrote ProgressionV3.java")

# ------------------------------------------------------------
# 9. Rewrite ProgressionV3Commands with spend command
# ------------------------------------------------------------

Write-Step "Rewriting ProgressionV3Commands"

$commandsPath = Join-Path $srcJava "com\example\shinobicore\progression\v3\ProgressionV3Commands.java"

$commandsContent = @'
// SHINOBICORE:SPRINT18:FILE
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

import java.util.Map;

/**
 * SPRINT 18 progression commands.
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
                        .then(CommandManager.literal("sync")
                                .executes(ctx -> sync(ctx)))
                        .then(CommandManager.literal("statinfo")
                                .executes(ctx -> statInfo(ctx)))
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
                        .then(CommandManager.literal("spend")
                                .then(CommandManager.argument("stat", StringArgumentType.word())
                                        .executes(ctx -> spend(ctx))))
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

        ProgressionV3.Data data = ProgressionV3.get(player);

        ctx.getSource().sendFeedback(() -> Text.literal("=== Progression V3 ===").formatted(Formatting.GOLD), false);
        ctx.getSource().sendFeedback(() -> Text.literal(
                "Level: " + data.level +
                " | XP: " + data.xp +
                " | Next: " + ProgressionV3.getXpForNextLevel(data.level) +
                " | SP: " + data.sp
        ).formatted(Formatting.AQUA), false);

        return 1;
    }

    private static int sync(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();

        if (player == null) {
            ctx.getSource().sendError(Text.literal("Player required").formatted(Formatting.RED));
            return 0;
        }

        ProgressionV3.ensureLoaded(player);
        boolean sent = ProgressionV3ServerSync.sendFull(player, ProgressionV3.get(player.getUuid()));

        if (sent) {
            ctx.getSource().sendFeedback(() -> Text.literal("Progression synced to client").formatted(Formatting.GREEN), false);
        } else {
            ctx.getSource().sendFeedback(() -> Text.literal("Client cannot receive progression sync yet").formatted(Formatting.RED), false);
        }

        return 1;
    }

    private static int statInfo(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();

        if (player == null) {
            ctx.getSource().sendError(Text.literal("Player required").formatted(Formatting.RED));
            return 0;
        }

        ProgressionV3.Data data = ProgressionV3.get(player);

        ctx.getSource().sendFeedback(() -> Text.literal("=== Progression V3 Stats ===").formatted(Formatting.GOLD), false);

        if (data.statLevels.isEmpty()) {
            ctx.getSource().sendFeedback(() -> Text.literal("No stat data yet.").formatted(Formatting.GRAY), false);
            return 1;
        }

        for (Map.Entry<String, Integer> entry : data.statLevels.entrySet()) {
            String stat = entry.getKey();
            int level = entry.getValue();
            int xp = data.statXp.getOrDefault(stat, 0);
            int next = ProgressionV3.getStatXpForNextLevel(level);

            ctx.getSource().sendFeedback(() -> Text.literal(
                    stat + ": Lv " + level + " | XP " + xp + "/" + next
            ).formatted(Formatting.WHITE), false);
        }

        return 1;
    }

    private static int addXp(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();

        if (player == null) {
            ctx.getSource().sendError(Text.literal("Player required").formatted(Formatting.RED));
            return 0;
        }

        int amount = IntegerArgumentType.getInteger(ctx, "amount");
        ProgressionV3.addXp(player, amount);

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
        ProgressionV3.addSp(player, amount);

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

        ProgressionV3.addStatXp(player, stat, amount);

        ctx.getSource().sendFeedback(() -> Text.literal(
                "Added " + amount + " XP to stat: " + stat
        ).formatted(Formatting.GREEN), false);

        return 1;
    }

    private static int spend(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();

        if (player == null) {
            ctx.getSource().sendError(Text.literal("Player required").formatted(Formatting.RED));
            return 0;
        }

        String stat = StringArgumentType.getString(ctx, "stat");
        boolean success = ProgressionV3.spendSpOnStat(player, stat);

        if (success) {
            ctx.getSource().sendFeedback(() -> Text.literal(
                    "Spent 1 SP on stat: " + stat
            ).formatted(Formatting.GREEN), false);
        } else {
            ctx.getSource().sendFeedback(() -> Text.literal(
                    "Not enough SP or invalid stat"
            ).formatted(Formatting.RED), false);
        }

        return 1;
    }

    private static int reset(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();

        if (player == null) {
            ctx.getSource().sendError(Text.literal("Player required").formatted(Formatting.RED));
            return 0;
        }

        ProgressionV3.reset(player);

        ctx.getSource().sendFeedback(() -> Text.literal("Progression V3 reset").formatted(Formatting.YELLOW), false);

        return 1;
    }
}
'@

Write-TextFile -Path $commandsPath -Content $commandsContent
Write-Ok "Rewrote ProgressionV3Commands.java"
$actions.Add("Rewrote ProgressionV3Commands.java")

# ------------------------------------------------------------
# 10. Create ProgressionHubScreen
# ------------------------------------------------------------

Write-Step "Creating ProgressionHubScreen"

$hubScreenPath = Join-Path $srcJava "com\example\shinobicore\client\gui\screen\ProgressionHubScreen.java"

$hubScreenContent = @'
// SHINOBICORE:SPRINT18:FILE
package com.example.shinobicore.client.gui.screen;

import com.example.shinobicore.client.network.ProgressionV3ClientPackets;
import com.example.shinobicore.progression.v3.ProgressionClientState;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.gui.screen.Screen;
import net.minecraft.client.gui.widget.ButtonWidget;
import net.minecraft.text.Text;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * SPRINT 18 progression hub screen.
 * Tabs: Stats, Tree, Attunement, Settings.
 */
public class ProgressionHubScreen extends Screen {
    private int selectedTab = 0;

    private final List<ButtonWidget> statButtons = new ArrayList<>();

    public ProgressionHubScreen() {
        super(Text.literal("Progression"));
    }

    @Override
    protected void init() {
        this.clearChildren();
        this.statButtons.clear();

        int centerX = this.width / 2;

        addDrawableChild(ButtonWidget.builder(Text.literal("Stats"), button -> {
                    selectedTab = 0;
                })
                .dimensions(centerX - 152, 18, 72, 20)
                .build());

        addDrawableChild(ButtonWidget.builder(Text.literal("Tree"), button -> {
                    selectedTab = 1;
                })
                .dimensions(centerX - 76, 18, 72, 20)
                .build());

        addDrawableChild(ButtonWidget.builder(Text.literal("Attunement"), button -> {
                    selectedTab = 2;
                })
                .dimensions(centerX, 18, 72, 20)
                .build());

        addDrawableChild(ButtonWidget.builder(Text.literal("Settings"), button -> {
                    selectedTab = 3;
                })
                .dimensions(centerX + 76, 18, 72, 20)
                .build());

        int y = 80;

        for (String stat : new ArrayList<>(ProgressionClientState.getStatLevels().keySet())) {
            ButtonWidget button = ButtonWidget.builder(Text.literal("+"), b -> {
                        ProgressionV3ClientPackets.sendSpendStat(stat);
                    })
                    .dimensions(centerX + 110, y - 2, 20, 16)
                    .build();

            statButtons.add(button);
            addDrawableChild(button);

            y += 18;
        }
    }

    @Override
    public void render(DrawContext context, int mouseX, int mouseY, float delta) {
        context.fill(0, 0, this.width, this.height, 0xC8100C08);

        context.drawCenteredTextWithShadow(
                this.textRenderer,
                this.title,
                this.width / 2,
                6,
                0xFFF0E6C8
        );

        for (ButtonWidget button : statButtons) {
            button.visible = selectedTab == 0;
            button.active = ProgressionClientState.getSp() > 0;
        }

        int x = 24;
        int y = 50;

        if (selectedTab == 0) {
            context.drawText(this.textRenderer, "Level: " + ProgressionClientState.getLevel(), x, y, 0xFFFF55, false);
            context.drawText(this.textRenderer, "XP: " + ProgressionClientState.getXp(), x, y + 12, 0x55FFFF, false);
            context.drawText(this.textRenderer, "SP: " + ProgressionClientState.getSp(), x, y + 24, 0x55FF55, false);

            y += 46;

            if (ProgressionClientState.getStatLevels().isEmpty()) {
                context.drawText(this.textRenderer, "No stats yet. Fight, move, or meditate to gain XP.", x, y, 0xAAAAAA, false);
            } else {
                for (Map.Entry<String, Integer> entry : ProgressionClientState.getStatLevels().entrySet()) {
                    String stat = entry.getKey();
                    int level = entry.getValue();
                    int xp = ProgressionClientState.getStatXp().getOrDefault(stat, 0);

                    context.drawText(
                            this.textRenderer,
                            stat + " Lv." + level + "  XP: " + xp,
                            x,
                            y,
                            0xFFE8DCC0,
                            false
                    );

                    y += 18;
                }
            }
        } else if (selectedTab == 1) {
            context.drawText(this.textRenderer, "Skill Tree", x, y, 0xFFF0E6C8, false);
            context.drawText(this.textRenderer, "Coming in a future sprint.", x, y + 14, 0xAAAAAA, false);
        } else if (selectedTab == 2) {
            context.drawText(this.textRenderer, "Attunement", x, y, 0xFFF0E6C8, false);
            context.drawText(this.textRenderer, "Element alignment coming in a future sprint.", x, y + 14, 0xAAAAAA, false);
        } else if (selectedTab == 3) {
            context.drawText(this.textRenderer, "Settings", x, y, 0xFFF0E6C8, false);
            context.drawText(this.textRenderer, "Progression UI settings coming in a future sprint.", x, y + 14, 0xAAAAAA, false);
        }

        super.render(context, mouseX, mouseY, delta);
    }

    @Override
    public boolean shouldPause() {
        return false;
    }
}
'@

Write-TextFile -Path $hubScreenPath -Content $hubScreenContent
Write-Ok "Created ProgressionHubScreen.java"
$actions.Add("Created ProgressionHubScreen.java")

# ------------------------------------------------------------
# 11. Rewrite ProgressionInputHandler to open hub screen
# ------------------------------------------------------------

Write-Step "Rewriting ProgressionInputHandler"

$inputHandlerPath = Join-Path $srcJava "com\example\shinobicore\client\input\ProgressionInputHandler.java"

$inputHandlerContent = @'
// SHINOBICORE:SPRINT18:FILE
package com.example.shinobicore.client.input;

import com.example.shinobicore.client.gui.screen.ProgressionHubScreen;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.option.KeyBinding;

/**
 * SPRINT 18 progression key handler.
 * Opens ProgressionHubScreen with K key.
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
                client.setScreen(new ProgressionHubScreen());
            }
        }

        wasPressed = pressed;
    }
}
'@

Write-TextFile -Path $inputHandlerPath -Content $inputHandlerContent
Write-Ok "Rewrote ProgressionInputHandler.java"
$actions.Add("Rewrote ProgressionInputHandler.java")

# ------------------------------------------------------------
# 12. Create Sprint18Bootstrap
# ------------------------------------------------------------

Write-Step "Creating Sprint18Bootstrap"

$bootstrapPath = Join-Path $srcJava "com\example\shinobicore\bootstrap\Sprint18Bootstrap.java"

$bootstrapContent = @'
// SHINOBICORE:SPRINT18:FILE
package com.example.shinobicore.bootstrap;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.progression.v3.ProgressionV3ServerHandler;
import com.example.shinobicore.util.ShinobiLogger;
import net.fabricmc.api.ModInitializer;

/**
 * SPRINT 18 server-side bootstrap.
 */
public class Sprint18Bootstrap implements ModInitializer {
    private static boolean initialized = false;

    @Override
    public void onInitialize() {
        if (initialized) {
            return;
        }

        initialized = true;

        try {
            if (FeatureFlags.progression) {
                ProgressionV3ServerHandler.register();
                ShinobiLogger.info("[SPRINT18] Progression server handler registered");
            }
        } catch (Throwable t) {
            ShinobiLogger.error("[SPRINT18] Bootstrap failed: " + t.getMessage());
        }
    }
}
'@

Write-TextFile -Path $bootstrapPath -Content $bootstrapContent
Write-Ok "Created Sprint18Bootstrap.java"
$actions.Add("Created Sprint18Bootstrap.java")

# ------------------------------------------------------------
# 13. Register entrypoint
# ------------------------------------------------------------

Write-Step "Registering Sprint18Bootstrap in fabric.mod.json"

$fmjPath = Join-Path $resMain "fabric.mod.json"

$mainAdded = Add-Entrypoint `
    -FabricPath $fmjPath `
    -Category "main" `
    -Entrypoint "com.example.shinobicore.bootstrap.Sprint18Bootstrap"

if ($mainAdded) {
    Write-Ok "Registered Sprint18Bootstrap (main)"
    $actions.Add("Registered Sprint18Bootstrap (main)")
}
else {
    Write-Ok "Sprint18Bootstrap already registered"
}

# ------------------------------------------------------------
# 14. Build
# ------------------------------------------------------------

if (-not $SkipBuild) {
    Write-Step "Running Gradle build"

    $buildOk = Invoke-GradleBuildDetailed -RootPath $Root -LogDir $outDir

    if (-not $buildOk) {
        Write-Err "Sprint 18 failed build."
        Write-Err "Log: $(Join-Path $outDir 'gradle_build.log')"
        exit 1
    }
}
else {
    Write-Warn "Build skipped because -SkipBuild was specified"
}

# ------------------------------------------------------------
# 15. Report
# ------------------------------------------------------------

Write-Step "Generating Sprint 18 report"

$report = New-Object System.Text.StringBuilder

[void]$report.AppendLine("SHINOBI CORE - SPRINT 18 REPORT")
[void]$report.AppendLine("Generated: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
[void]$report.AppendLine("")
[void]$report.AppendLine("=== ACTIONS ===")

foreach ($action in $actions) {
    [void]$report.AppendLine($action)
}

$reportPath = Join-Path $outDir "sprint18_report.txt"
Write-TextFile -Path $reportPath -Content $report.ToString()

Write-Ok "Report saved: $reportPath"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " MASTER SPRINT 18 COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Test in-game:" -ForegroundColor Yellow
Write-Host "  1. /shinobicore progressionv3 addsp 5" -ForegroundColor White
Write-Host "  2. /shinobicore progressionv3 statxp taijutsu 200" -ForegroundColor White
Write-Host "  3. Press K" -ForegroundColor White
Write-Host "  4. Use + buttons to spend SP" -ForegroundColor White
Write-Host "  5. /shinobicore progressionv3 spend movement" -ForegroundColor White
Write-Host ""

exit 0
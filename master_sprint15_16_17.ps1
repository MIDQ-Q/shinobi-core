param(
    [string]$Root = "",
    [switch]$SkipBuild
)

# ============================================================
# SHINOBI CORE
# MASTER SPRINT 15 + 16 + 17
# Progression sync + persistent storage
# XP sources
# Combat adapters
# ============================================================

$ErrorActionPreference = "Stop"
$script:utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "[SPRINT15-17] $Message" -ForegroundColor Cyan
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
Write-Host " SHINOBI CORE - MASTER SPRINT 15 + 16 + 17" -ForegroundColor Cyan
Write-Host " Progression sync + XP sources + Combat adapters" -ForegroundColor Cyan
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
$outDir = Join-Path $Root "scripts\out\sprint15_16_17"

Ensure-Directory $outDir

$actions = New-Object System.Collections.Generic.List[string]
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $Root "backup\sprint15_16_17_$stamp"

# ------------------------------------------------------------
# 2. Backup
# ------------------------------------------------------------

Write-Step "Creating backup"

Backup-File "src\main\resources\fabric.mod.json" $backupDir
Backup-File "src\main\java\com\example\shinobicore\progression\v3\ProgressionV3.java" $backupDir
Backup-File "src\main\java\com\example\shinobicore\progression\v3\ProgressionV3Commands.java" $backupDir

# ------------------------------------------------------------
# 3. Rewrite ProgressionV3 with persistence and sync hooks
# ------------------------------------------------------------

Write-Step "Rewriting ProgressionV3 core"

$progressionCorePath = Join-Path $srcJava "com\example\shinobicore\progression\v3\ProgressionV3.java"

$progressionCoreContent = @'
// SHINOBICORE:SPRINT15:FILE
package com.example.shinobicore.progression.v3;

import net.minecraft.server.network.ServerPlayerEntity;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * SPRINT 15 server-side progression core.
 *
 * Loads from world storage and syncs to client.
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

        ProgressionV3ServerSync.send(player, data);
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

        ProgressionV3ServerSync.send(player, data);
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
        ProgressionV3ServerSync.send(player, get(player.getUuid()));
    }
}
'@

Write-TextFile -Path $progressionCorePath -Content $progressionCoreContent
Write-Ok "Rewrote ProgressionV3.java"
$actions.Add("Rewrote ProgressionV3.java")

# ------------------------------------------------------------
# 4. Create ProgressionV3Storage
# ------------------------------------------------------------

Write-Step "Creating ProgressionV3Storage"

$storagePath = Join-Path $srcJava "com\example\shinobicore\progression\v3\ProgressionV3Storage.java"

$storageContent = @'
// SHINOBICORE:SPRINT15:FILE
package com.example.shinobicore.progression.v3;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import net.minecraft.server.MinecraftServer;
import net.minecraft.util.WorldSavePath;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * SPRINT 15 persistent storage for progression.
 *
 * Location:
 * <world>/shinobicore/progression/<uuid>.json
 */
public final class ProgressionV3Storage {
    private static final Gson GSON = new GsonBuilder().setPrettyPrinting().create();

    private ProgressionV3Storage() {}

    public static Path getDirectory(MinecraftServer server) {
        return server.getSavePath(WorldSavePath.ROOT)
                .resolve("shinobicore")
                .resolve("progression");
    }

    public static Path getFile(MinecraftServer server, UUID uuid) {
        return getDirectory(server).resolve(uuid.toString() + ".json");
    }

    public static ProgressionV3.Data load(MinecraftServer server, UUID uuid) {
        Path path = getFile(server, uuid);

        if (!Files.exists(path)) {
            return null;
        }

        try {
            String json = new String(Files.readAllBytes(path), StandardCharsets.UTF_8);
            ProgressionV3.Data data = GSON.fromJson(json, ProgressionV3.Data.class);
            return normalize(data);
        } catch (Exception e) {
            try {
                Path bad = path.resolveSibling(uuid.toString() + ".json.bad");
                Files.move(path, bad, StandardCopyOption.REPLACE_EXISTING);
            } catch (Exception ignored) {
            }

            return null;
        }
    }

    public static void save(MinecraftServer server, UUID uuid, ProgressionV3.Data data) {
        try {
            Path dir = getDirectory(server);
            Files.createDirectories(dir);

            Path path = getFile(server, uuid);
            String json = GSON.toJson(normalize(data));

            Files.write(path, json.getBytes(StandardCharsets.UTF_8));
        } catch (Exception ignored) {
        }
    }

    public static void delete(MinecraftServer server, UUID uuid) {
        try {
            Files.deleteIfExists(getFile(server, uuid));
        } catch (Exception ignored) {
        }
    }

    private static ProgressionV3.Data normalize(ProgressionV3.Data data) {
        if (data == null) {
            data = new ProgressionV3.Data();
        }

        if (data.statLevels == null) {
            data.statLevels = new ConcurrentHashMap<>();
        } else if (!(data.statLevels instanceof ConcurrentHashMap)) {
            data.statLevels = new ConcurrentHashMap<>(data.statLevels);
        }

        if (data.statXp == null) {
            data.statXp = new ConcurrentHashMap<>();
        } else if (!(data.statXp instanceof ConcurrentHashMap)) {
            data.statXp = new ConcurrentHashMap<>(data.statXp);
        }

        return data;
    }
}
'@

Write-TextFile -Path $storagePath -Content $storageContent
Write-Ok "Created ProgressionV3Storage.java"
$actions.Add("Created ProgressionV3Storage.java")

# ------------------------------------------------------------
# 5. Create ProgressionV3ServerSync
# ------------------------------------------------------------

Write-Step "Creating ProgressionV3ServerSync"

$serverSyncPath = Join-Path $srcJava "com\example\shinobicore\progression\v3\ProgressionV3ServerSync.java"

$serverSyncContent = @'
// SHINOBICORE:SPRINT15:FILE
package com.example.shinobicore.progression.v3;

import net.fabricmc.fabric.api.networking.v1.PacketByteBufs;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.Identifier;

/**
 * SPRINT 15 server-to-client progression sync.
 */
public final class ProgressionV3ServerSync {
    public static final Identifier ID =
            new Identifier("shinobicore", "progression_v3_sync");

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
}
'@

Write-TextFile -Path $serverSyncPath -Content $serverSyncContent
Write-Ok "Created ProgressionV3ServerSync.java"
$actions.Add("Created ProgressionV3ServerSync.java")

# ------------------------------------------------------------
# 6. Create ProgressionV3ClientSync
# ------------------------------------------------------------

Write-Step "Creating ProgressionV3ClientSync"

$clientSyncPath = Join-Path $srcJava "com\example\shinobicore\client\network\ProgressionV3ClientSync.java"

$clientSyncContent = @'
// SHINOBICORE:SPRINT15:FILE
package com.example.shinobicore.client.network;

import com.example.shinobicore.progression.v3.ProgressionClientState;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.networking.v1.PacketSender;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayNetworkHandler;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.util.Identifier;

/**
 * SPRINT 15 client receiver for progression sync.
 */
public final class ProgressionV3ClientSync {
    private static boolean registered = false;

    private ProgressionV3ClientSync() {}

    public static void register() {
        if (registered) {
            return;
        }

        registered = true;

        ClientPlayNetworking.registerGlobalReceiver(
                new Identifier("shinobicore", "progression_v3_sync"),
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
    }
}
'@

Write-TextFile -Path $clientSyncPath -Content $clientSyncContent
Write-Ok "Created ProgressionV3ClientSync.java"
$actions.Add("Created ProgressionV3ClientSync.java")

# ------------------------------------------------------------
# 7. Create ProgressionJoinHandler
# ------------------------------------------------------------

Write-Step "Creating ProgressionJoinHandler"

$joinHandlerPath = Join-Path $srcJava "com\example\shinobicore\progression\v3\ProgressionJoinHandler.java"

$joinHandlerContent = @'
// SHINOBICORE:SPRINT15:FILE
package com.example.shinobicore.progression.v3;

import net.fabricmc.fabric.api.networking.v1.ServerPlayConnectionEvents;
import net.minecraft.server.network.ServerPlayerEntity;

/**
 * SPRINT 15 join handler.
 * Loads progression and sends it to the client.
 */
public final class ProgressionJoinHandler {
    private static boolean registered = false;

    private ProgressionJoinHandler() {}

    public static void register() {
        if (registered) {
            return;
        }

        registered = true;

        ServerPlayConnectionEvents.JOIN.register((handler, sender, server) -> {
            ServerPlayerEntity player = handler.getPlayer();

            ProgressionV3.ensureLoaded(player);
            ProgressionV3ServerSync.send(player, ProgressionV3.get(player.getUuid()));
        });
    }
}
'@

Write-TextFile -Path $joinHandlerPath -Content $joinHandlerContent
Write-Ok "Created ProgressionJoinHandler.java"
$actions.Add("Created ProgressionJoinHandler.java")

# ------------------------------------------------------------
# 8. Rewrite ProgressionV3Commands
# ------------------------------------------------------------

Write-Step "Rewriting ProgressionV3Commands"

$commandsPath = Join-Path $srcJava "com\example\shinobicore\progression\v3\ProgressionV3Commands.java"

$commandsContent = @'
// SHINOBICORE:SPRINT15:FILE
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
 * SPRINT 15 progression commands.
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
        boolean sent = ProgressionV3ServerSync.send(player, ProgressionV3.get(player.getUuid()));

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
# 9. Create XpSourceService
# ------------------------------------------------------------

Write-Step "Creating XpSourceService"

$xpSourcePath = Join-Path $srcJava "com\example\shinobicore\event\XpSourceService.java"

$xpSourceContent = @'
// SHINOBICORE:SPRINT16:FILE
package com.example.shinobicore.event;

import com.example.shinobicore.chakra.server.ServerChakraMirror;
import com.example.shinobicore.progression.v3.ProgressionV3;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.fabricmc.fabric.api.event.player.AttackEntityCallback;
import net.minecraft.entity.Entity;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.ActionResult;
import net.minecraft.util.Hand;
import net.minecraft.util.hit.EntityHitResult;
import net.minecraft.world.World;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * SPRINT 16 XP sources foundation.
 *
 * Combat XP:
 * - attacking entities grants taijutsu/physical XP
 *
 * Chakra mode XP:
 * - idle in chakra mode grants meditation XP
 * - sprinting in chakra mode grants movement XP
 */
public final class XpSourceService {
    private static boolean registered = false;
    private static int tickCounter = 0;

    private static final Map<UUID, Long> LAST_COMBAT_XP = new ConcurrentHashMap<>();

    private XpSourceService() {}

    public static void register() {
        if (registered) {
            return;
        }

        registered = true;

        ServerTickEvents.END_SERVER_TICK.register(XpSourceService::onServerTick);

        AttackEntityCallback.EVENT.register((PlayerEntity player,
                                             World world,
                                             Hand hand,
                                             Entity entity,
                                             EntityHitResult entityHitResult) -> {

            if (!world.isClient() && player instanceof ServerPlayerEntity serverPlayer) {
                long now = System.currentTimeMillis();
                Long last = LAST_COMBAT_XP.get(serverPlayer.getUuid());

                if (last == null || now - last > 1000L) {
                    LAST_COMBAT_XP.put(serverPlayer.getUuid(), now);

                    ProgressionV3.addStatXp(serverPlayer, "taijutsu", 2);
                    ProgressionV3.addStatXp(serverPlayer, "physical", 1);
                    ProgressionV3.addXp(serverPlayer, 1);
                }
            }

            return ActionResult.PASS;
        });
    }

    private static void onServerTick(MinecraftServer server) {
        tickCounter++;

        if (tickCounter % 200 != 0) {
            return;
        }

        for (ServerPlayerEntity player : server.getPlayerManager().getPlayerList()) {
            if (player.isDead()) {
                continue;
            }

            ServerChakraMirror.Data chakra = ServerChakraMirror.get(player.getUuid());

            if (!chakra.chakraMode) {
                continue;
            }

            double vx = player.getVelocity().x;
            double vz = player.getVelocity().z;

            boolean idle = (vx * vx + vz * vz) < 0.01 && player.isOnGround();

            if (idle) {
                ProgressionV3.addStatXp(player, "meditation", 1);
                ProgressionV3.addXp(player, 1);
            } else if (player.isSprinting()) {
                ProgressionV3.addStatXp(player, "movement", 1);
                ProgressionV3.addXp(player, 1);
            }
        }
    }
}
'@

Write-TextFile -Path $xpSourcePath -Content $xpSourceContent
Write-Ok "Created XpSourceService.java"
$actions.Add("Created XpSourceService.java")

# ------------------------------------------------------------
# 10. Create combat adapters
# ------------------------------------------------------------

Write-Step "Creating combat adapters"

$betterCombatAdapterPath = Join-Path $srcJava "com\example\shinobicore\combat\v3\adapter\BetterCombatAdapter.java"

$betterCombatAdapterContent = @'
// SHINOBICORE:SPRINT17:FILE
package com.example.shinobicore.combat.v3.adapter;

import net.fabricmc.loader.api.FabricLoader;

/**
 * SPRINT 17 Better Combat adapter foundation.
 */
public final class BetterCombatAdapter {
    private static boolean enabled = false;
    private static String status = "not initialized";

    private BetterCombatAdapter() {}

    public static void init() {
        if (FabricLoader.getInstance().isModLoaded("bettercombat")) {
            enabled = true;
            status = "loaded";
        } else {
            enabled = false;
            status = "not installed";
        }
    }

    public static boolean isEnabled() {
        return enabled;
    }

    public static String getStatus() {
        return status;
    }
}
'@

Write-TextFile -Path $betterCombatAdapterPath -Content $betterCombatAdapterContent
Write-Ok "Created BetterCombatAdapter.java"
$actions.Add("Created BetterCombatAdapter.java")

$playerAnimatorAdapterPath = Join-Path $srcJava "com\example\shinobicore\combat\v3\adapter\PlayerAnimatorAdapter.java"

$playerAnimatorAdapterContent = @'
// SHINOBICORE:SPRINT17:FILE
package com.example.shinobicore.combat.v3.adapter;

import net.fabricmc.loader.api.FabricLoader;

/**
 * SPRINT 17 Player Animator adapter foundation.
 */
public final class PlayerAnimatorAdapter {
    private static boolean enabled = false;
    private static String status = "not initialized";

    private PlayerAnimatorAdapter() {}

    public static void init() {
        if (FabricLoader.getInstance().isModLoaded("player-animator")) {
            enabled = true;
            status = "loaded";
        } else {
            enabled = false;
            status = "not installed";
        }
    }

    public static boolean isEnabled() {
        return enabled;
    }

    public static String getStatus() {
        return status;
    }
}
'@

Write-TextFile -Path $playerAnimatorAdapterPath -Content $playerAnimatorAdapterContent
Write-Ok "Created PlayerAnimatorAdapter.java"
$actions.Add("Created PlayerAnimatorAdapter.java")

$geckoLibAdapterPath = Join-Path $srcJava "com\example\shinobicore\combat\v3\adapter\GeckoLibAdapter.java"

$geckoLibAdapterContent = @'
// SHINOBICORE:SPRINT17:FILE
package com.example.shinobicore.combat.v3.adapter;

import net.fabricmc.loader.api.FabricLoader;

/**
 * SPRINT 17 GeckoLib adapter foundation.
 */
public final class GeckoLibAdapter {
    private static boolean enabled = false;
    private static String status = "not initialized";

    private GeckoLibAdapter() {}

    public static void init() {
        if (FabricLoader.getInstance().isModLoaded("geckolib")) {
            enabled = true;
            status = "loaded";
        } else {
            enabled = false;
            status = "not installed";
        }
    }

    public static boolean isEnabled() {
        return enabled;
    }

    public static String getStatus() {
        return status;
    }
}
'@

Write-TextFile -Path $geckoLibAdapterPath -Content $geckoLibAdapterContent
Write-Ok "Created GeckoLibAdapter.java"
$actions.Add("Created GeckoLibAdapter.java")

$clothConfigAdapterPath = Join-Path $srcJava "com\example\shinobicore\combat\v3\adapter\ClothConfigAdapter.java"

$clothConfigAdapterContent = @'
// SHINOBICORE:SPRINT17:FILE
package com.example.shinobicore.combat.v3.adapter;

import net.fabricmc.loader.api.FabricLoader;

/**
 * SPRINT 17 Cloth Config adapter foundation.
 */
public final class ClothConfigAdapter {
    private static boolean enabled = false;
    private static String status = "not initialized";

    private ClothConfigAdapter() {}

    public static void init() {
        if (FabricLoader.getInstance().isModLoaded("cloth-config")) {
            enabled = true;
            status = "loaded";
        } else {
            enabled = false;
            status = "not installed";
        }
    }

    public static boolean isEnabled() {
        return enabled;
    }

    public static String getStatus() {
        return status;
    }
}
'@

Write-TextFile -Path $clothConfigAdapterPath -Content $clothConfigAdapterContent
Write-Ok "Created ClothConfigAdapter.java"
$actions.Add("Created ClothConfigAdapter.java")

$adapterManagerPath = Join-Path $srcJava "com\example\shinobicore\combat\v3\adapter\CombatAdapterManager.java"

$adapterManagerContent = @'
// SHINOBICORE:SPRINT17:FILE
package com.example.shinobicore.combat.v3.adapter;

import com.example.shinobicore.util.ShinobiLogger;

/**
 * SPRINT 17 combat adapter manager.
 */
public final class CombatAdapterManager {
    private static boolean initialized = false;

    private CombatAdapterManager() {}

    public static void init() {
        if (initialized) {
            return;
        }

        initialized = true;

        BetterCombatAdapter.init();
        PlayerAnimatorAdapter.init();
        GeckoLibAdapter.init();
        ClothConfigAdapter.init();

        ShinobiLogger.info("[COMBAT-V3] Adapters: " + getReport());
    }

    public static String getReport() {
        return "BetterCombat=" + BetterCombatAdapter.getStatus()
                + ", PlayerAnimator=" + PlayerAnimatorAdapter.getStatus()
                + ", GeckoLib=" + GeckoLibAdapter.getStatus()
                + ", ClothConfig=" + ClothConfigAdapter.getStatus();
    }
}
'@

Write-TextFile -Path $adapterManagerPath -Content $adapterManagerContent
Write-Ok "Created CombatAdapterManager.java"
$actions.Add("Created CombatAdapterManager.java")

# ------------------------------------------------------------
# 11. Create Sprint1517Bootstrap
# ------------------------------------------------------------

Write-Step "Creating Sprint1517Bootstrap"

$bootstrapPath = Join-Path $srcJava "com\example\shinobicore\bootstrap\Sprint1517Bootstrap.java"

$bootstrapContent = @'
// SHINOBICORE:SPRINT15-17:FILE
package com.example.shinobicore.bootstrap;

import com.example.shinobicore.combat.v3.adapter.CombatAdapterManager;
import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.event.XpSourceService;
import com.example.shinobicore.progression.v3.ProgressionJoinHandler;
import com.example.shinobicore.util.ShinobiLogger;
import net.fabricmc.api.ModInitializer;

/**
 * SPRINT 15/16/17 server-side bootstrap.
 */
public class Sprint1517Bootstrap implements ModInitializer {
    private static boolean initialized = false;

    @Override
    public void onInitialize() {
        if (initialized) {
            return;
        }

        initialized = true;

        try {
            if (FeatureFlags.progression) {
                ProgressionJoinHandler.register();
                XpSourceService.register();
                ShinobiLogger.info("[SPRINT15/16] Progression sync + XP sources registered");
            }

            if (FeatureFlags.combatV3) {
                CombatAdapterManager.init();
                ShinobiLogger.info("[SPRINT17] Combat adapters initialized");
            }
        } catch (Throwable t) {
            ShinobiLogger.error("[SPRINT15-17] Bootstrap failed: " + t.getMessage());
        }
    }
}
'@

Write-TextFile -Path $bootstrapPath -Content $bootstrapContent
Write-Ok "Created Sprint1517Bootstrap.java"
$actions.Add("Created Sprint1517Bootstrap.java")

# ------------------------------------------------------------
# 12. Create Sprint1517ClientBootstrap
# ------------------------------------------------------------

Write-Step "Creating Sprint1517ClientBootstrap"

$clientBootstrapPath = Join-Path $srcJava "com\example\shinobicore\bootstrap\Sprint1517ClientBootstrap.java"

$clientBootstrapContent = @'
// SHINOBICORE:SPRINT15-17:FILE
package com.example.shinobicore.bootstrap;

import com.example.shinobicore.client.network.ProgressionV3ClientSync;
import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.util.ShinobiLogger;
import net.fabricmc.api.ClientModInitializer;

/**
 * SPRINT 15/16/17 client-side bootstrap.
 */
public class Sprint1517ClientBootstrap implements ClientModInitializer {
    @Override
    public void onInitializeClient() {
        try {
            if (FeatureFlags.progression) {
                ProgressionV3ClientSync.register();
                ShinobiLogger.info("[SPRINT15] Progression client sync registered");
            }
        } catch (Throwable t) {
            ShinobiLogger.error("[SPRINT15-17] Client bootstrap failed: " + t.getMessage());
        }
    }
}
'@

Write-TextFile -Path $clientBootstrapPath -Content $clientBootstrapContent
Write-Ok "Created Sprint1517ClientBootstrap.java"
$actions.Add("Created Sprint1517ClientBootstrap.java")

# ------------------------------------------------------------
# 13. Register entrypoints
# ------------------------------------------------------------

Write-Step "Registering entrypoints in fabric.mod.json"

$fmjPath = Join-Path $resMain "fabric.mod.json"

$mainAdded = Add-Entrypoint `
    -FabricPath $fmjPath `
    -Category "main" `
    -Entrypoint "com.example.shinobicore.bootstrap.Sprint1517Bootstrap"

if ($mainAdded) {
    Write-Ok "Registered Sprint1517Bootstrap (main)"
    $actions.Add("Registered Sprint1517Bootstrap (main)")
}
else {
    Write-Ok "Sprint1517Bootstrap already registered"
}

$clientAdded = Add-Entrypoint `
    -FabricPath $fmjPath `
    -Category "client" `
    -Entrypoint "com.example.shinobicore.bootstrap.Sprint1517ClientBootstrap"

if ($clientAdded) {
    Write-Ok "Registered Sprint1517ClientBootstrap (client)"
    $actions.Add("Registered Sprint1517ClientBootstrap (client)")
}
else {
    Write-Ok "Sprint1517ClientBootstrap already registered"
}

# ------------------------------------------------------------
# 14. Build
# ------------------------------------------------------------

if (-not $SkipBuild) {
    Write-Step "Running Gradle build"

    $buildOk = Invoke-GradleBuildDetailed -RootPath $Root -LogDir $outDir

    if (-not $buildOk) {
        Write-Err "Sprint 15/16/17 failed build."
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

Write-Step "Generating Sprint 15/16/17 report"

$report = New-Object System.Text.StringBuilder

[void]$report.AppendLine("SHINOBI CORE - SPRINT 15/16/17 REPORT")
[void]$report.AppendLine("Generated: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
[void]$report.AppendLine("")
[void]$report.AppendLine("=== ACTIONS ===")

foreach ($action in $actions) {
    [void]$report.AppendLine($action)
}

$reportPath = Join-Path $outDir "sprint15_16_17_report.txt"
Write-TextFile -Path $reportPath -Content $report.ToString()

Write-Ok "Report saved: $reportPath"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " MASTER SPRINT 15 + 16 + 17 FOUNDATION COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Progression commands:" -ForegroundColor Yellow
Write-Host "  /shinobicore progressionv3 info" -ForegroundColor White
Write-Host "  /shinobicore progressionv3 sync" -ForegroundColor White
Write-Host "  /shinobicore progressionv3 statinfo" -ForegroundColor White
Write-Host "  /shinobicore progressionv3 addxp 100" -ForegroundColor White
Write-Host "  /shinobicore progressionv3 addsp 5" -ForegroundColor White
Write-Host "  /shinobicore progressionv3 statxp taijutsu 200" -ForegroundColor White
Write-Host "  /shinobicore progressionv3 reset" -ForegroundColor White
Write-Host ""
Write-Host "Client:" -ForegroundColor Yellow
Write-Host "  Press K to open progression screen after syncing" -ForegroundColor White
Write-Host ""
Write-Host "XP sources:" -ForegroundColor Yellow
Write-Host "  Attack entities -> taijutsu/physical XP" -ForegroundColor White
Write-Host "  Stand still in chakra mode -> meditation XP" -ForegroundColor White
Write-Host "  Sprint in chakra mode -> movement XP" -ForegroundColor White
Write-Host ""
Write-Host "Combat adapters:" -ForegroundColor Yellow
Write-Host "  /shinobicore combatv3 systems" -ForegroundColor White
Write-Host ""

exit 0
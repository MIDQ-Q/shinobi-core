# Setup-JutsuSprint2.ps1
# Мастер-скрипт для создания Behaviors, Packets и Commands модуля Jutsu (Sprint 1, Step 3)
# Требует запуска из корневой директории мода (где находится build.gradle)

$ErrorActionPreference = "Stop"
$rootPath = Get-Location

Write-Host "=== ShinobiCore: Jutsu Module Sprint 2 Setup ===" -ForegroundColor Cyan

# 1. Создание структуры директорий
$dirs = @(
    "src\main\java\com\example\shinobicore\modules\jutsu\behavior",
    "src\main\java\com\example\shinobicore\modules\jutsu\network",
    "src\main\java\com\example\shinobicore\modules\jutsu\command"
)

foreach ($dir in $dirs) {
    $fullPath = Join-Path $rootPath $dir
    if (!(Test-Path $fullPath)) {
        New-Item -ItemType Directory -Force -Path $fullPath | Out-Null
        Write-Host "[OK] Created directory: $dir" -ForegroundColor Green
    } else {
        Write-Host "[SKIP] Directory already exists: $dir" -ForegroundColor Yellow
    }
}

# 2. Функция для безопасной записи файлов (UTF-8 без BOM)
function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText((Join-Path $rootPath $Path), $Content, $utf8NoBom)
    Write-Host "[OK] Written: $Path" -ForegroundColor Green
}

# 3. Создание Java файлов (Behavior)
Write-Host "`n--- Creating Java Classes (Behavior) ---" -ForegroundColor Cyan

$jutsuBehaviorJava = @'
package com.example.shinobicore.modules.jutsu.behavior;

import com.example.shinobicore.modules.jutsu.cast.BehaviorContext;

public interface JutsuBehavior {
    String id();
    void onRelease(BehaviorContext ctx);
    default void onTick(BehaviorContext ctx) {}
    default void onExpire(BehaviorContext ctx) {}
    default boolean shouldInterrupt(BehaviorContext ctx) { return false; }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\behavior\JutsuBehavior.java" $jutsuBehaviorJava

$behaviorContextJava = @'
package com.example.shinobicore.modules.jutsu.behavior;

import com.example.shinobicore.modules.jutsu.data.JutsuDefinition;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.world.ServerWorld;
import org.jetbrains.annotations.Nullable;

public final class BehaviorContext {
    public final LivingEntity caster;
    public final String jutsuId;
    public final JutsuDefinition definition;
    public final JsonObject behaviorData;
    public final @Nullable Entity target;
    public final int casterLevel;
    public final float chargeMultiplier;
    public final ServerWorld world;

    public BehaviorContext(LivingEntity caster, String jutsuId, JutsuDefinition definition,
                           JsonObject behaviorData, @Nullable Entity target, int casterLevel,
                           float chargeMultiplier, ServerWorld world) {
        this.caster = caster;
        this.jutsuId = jutsuId;
        this.definition = definition;
        this.behaviorData = behaviorData;
        this.target = target;
        this.casterLevel = casterLevel;
        this.chargeMultiplier = chargeMultiplier;
        this.world = world;
    }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\behavior\BehaviorContext.java" $behaviorContextJava

$behaviorRegistryJava = @'
package com.example.shinobicore.modules.jutsu.behavior;

import com.example.shinobicore.core.log.ShinobiLogger;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

public final class BehaviorRegistry {
    private static final Map<String, JutsuBehavior> BEHAVIORS = new ConcurrentHashMap<>();

    public static void register(JutsuBehavior behavior) {
        if (behavior != null && behavior.id() != null) {
            BEHAVIORS.put(behavior.id(), behavior);
        }
    }

    public static Optional<JutsuBehavior> get(String id) {
        return Optional.ofNullable(BEHAVIORS.get(id));
    }

    public static boolean isRegistered(String id) {
        return BEHAVIORS.containsKey(id);
    }

    public static void registerDefaults() {
        register(new ProjectileBehavior());
        register(new DashBehavior());
        // В будущем: AoeBehavior, WallBehavior, GenjutsuBehavior, UtilityBehavior, MeleeBufferBehavior
        ShinobiLogger.module("jutsu", "Default behaviors registered.");
    }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\behavior\BehaviorRegistry.java" $behaviorRegistryJava

$projectileBehaviorJava = @'
package com.example.shinobicore.modules.jutsu.behavior;

import com.example.shinobicore.core.log.ShinobiLogger;
import net.minecraft.entity.projectile.FireballEntity;
import net.minecraft.util.math.Vec3d;

public final class ProjectileBehavior implements JutsuBehavior {
    public static final String ID = "projectile";

    @Override
    public String id() { return ID; }

    @Override
    public void onRelease(BehaviorContext ctx) {
        float speed = ctx.behaviorData().has("projectileSpeed") ? ctx.behaviorData().get("projectileSpeed").getAsFloat() : 1.5f;
        float damage = ctx.behaviorData().has("projectileDamage") ? ctx.behaviorData().get("projectileDamage").getAsFloat() : 4.0f;
        
        // Scaling
        damage += ctx.casterLevel * ctx.definition().scaling().damagePerLevel();
        damage *= ctx.chargeMultiplier();

        Vec3d dir = ctx.caster().getRotationVec(1.0f);
        FireballEntity fireball = new FireballEntity(ctx.world(), ctx.caster(), dir.x * speed, dir.y * speed, dir.z * speed, 1); // 1 = минимальный vanilla урон, реальный урон обрабатывается через события
        
        fireball.setPos(
            ctx.caster().getX() + dir.x * 1.5,
            ctx.caster().getEyeY() - 0.1,
            ctx.caster().getZ() + dir.z * 1.5
        );
        
        ctx.world().spawnEntity(fireball);
        ShinobiLogger.module("jutsu", "Spawned projectile for " + ctx.jutsuId + " with calculated damage: " + damage);
        // TODO: Привязать кастомный урон через CoreEvents или кастомную сущность в Sprint 2
    }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\behavior\ProjectileBehavior.java" $projectileBehaviorJava

$dashBehaviorJava = @'
package com.example.shinobicore.modules.jutsu.behavior;

import com.example.shinobicore.core.log.ShinobiLogger;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.util.math.Vec3d;

public final class DashBehavior implements JutsuBehavior {
    public static final String ID = "dash";

    @Override
    public String id() { return ID; }

    @Override
    public void onRelease(BehaviorContext ctx) {
        float distance = ctx.behaviorData().has("dashDistance") ? ctx.behaviorData().get("dashDistance").getAsFloat() : 5.0f;
        int iFrames = ctx.behaviorData().has("iFramesTicks") ? ctx.behaviorData().get("iFramesTicks").getAsInt() : 4;

        Vec3d dir = ctx.caster().getRotationVec(1.0f);
        Vec3d velocity = dir.multiply(distance * 1.5); // Множитель для резкости рывка
        
        ctx.caster().addVelocity(velocity.x, velocity.y, velocity.z);
        ctx.caster().velocityModified = true;
        
        // I-frames через vanilla эффект (упрощенно для теста)
        ctx.caster().addStatusEffect(new StatusEffectInstance(StatusEffects.RESISTANCE, iFrames, 255, false, false));
        
        ShinobiLogger.module("jutsu", "Executed dash for " + ctx.caster().getName().getString() + " distance: " + distance);
    }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\behavior\DashBehavior.java" $dashBehaviorJava

# 4. Создание Java файлов (Network / Packets)
Write-Host "`n--- Creating Java Classes (Network) ---" -ForegroundColor Cyan

$jutsuPacketsJava = @'
package com.example.shinobicore.modules.jutsu.network;

import com.example.shinobicore.core.log.ShinobiLogger;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.util.Identifier;

public final class JutsuPackets {
    public static final Identifier CAST_REQUEST = new Identifier("shinobicore", "jutsu_cast_request");
    public static final Identifier CAST_CANCEL = new Identifier("shinobicore", "jutsu_cast_cancel");
    public static final Identifier SLOT_CHANGE = new Identifier("shinobicore", "jutsu_slot_change");

    public static void registerServer() {
        ServerPlayNetworking.registerGlobalReceiver(CAST_REQUEST, JutsuCastRequestPacket::handle);
        ServerPlayNetworking.registerGlobalReceiver(CAST_CANCEL, JutsuCastCancelPacket::handle);
        ServerPlayNetworking.registerGlobalReceiver(SLOT_CHANGE, JutsuSlotChangePacket::handle);
        ShinobiLogger.module("jutsu", "Server packets registered.");
    }

    public static void registerClient() {
        // Клиентские обработчики (server -> client) будут добавлены при реализации JutsuStateSyncPacket
        ShinobiLogger.module("jutsu", "Client packets registered.");
    }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\network\JutsuPackets.java" $jutsuPacketsJava

$jutsuCastRequestPacketJava = @'
package com.example.shinobicore.modules.jutsu.network;

import com.example.shinobicore.modules.jutsu.cast.JutsuCastService;
import com.example.shinobicore.modules.jutsu.slot.JutsuSlotService;
import net.fabricmc.fabric.api.networking.v1.PacketSender;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayNetworkHandler;
import net.minecraft.server.network.ServerPlayerEntity;

public final class JutsuCastRequestPacket {
    public static void handle(MinecraftServer server, ServerPlayerEntity player, ServerPlayNetworkHandler handler, PacketByteBuf buf, PacketSender responseSender) {
        // STEP 1: Read ALL data from buffer FIRST (CRITICAL RULE)
        final int slot = buf.readInt();
        final long pressTimestampMs = buf.readLong();
        final float yaw = buf.readFloat();
        final float pitch = buf.readFloat();

        // STEP 2: Execute on server thread
        server.execute(() -> {
            String jutsuId = JutsuSlotService.getLoadout(player).getSlot(slot);
            if (jutsuId != null) {
                JutsuCastService.instance().requestCast(player, jutsuId, slot, pressTimestampMs, yaw, pitch);
            }
        });
    }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\network\JutsuCastRequestPacket.java" $jutsuCastRequestPacketJava

$jutsuCastCancelPacketJava = @'
package com.example.shinobicore.modules.jutsu.network;

import com.example.shinobicore.modules.jutsu.cast.JutsuCastService;
import net.fabricmc.fabric.api.networking.v1.PacketSender;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayNetworkHandler;
import net.minecraft.server.network.ServerPlayerEntity;

public final class JutsuCastCancelPacket {
    public static void handle(MinecraftServer server, ServerPlayerEntity player, ServerPlayNetworkHandler handler, PacketByteBuf buf, PacketSender responseSender) {
        // STEP 1: Read ALL data from buffer FIRST
        final String reason = buf.readString(32); // Limit string length for safety

        // STEP 2: Execute on server thread
        server.execute(() -> {
            JutsuCastService.instance().cancelCast(player, reason);
        });
    }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\network\JutsuCastCancelPacket.java" $jutsuCastCancelPacketJava

$jutsuSlotChangePacketJava = @'
package com.example.shinobicore.modules.jutsu.network;

import com.example.shinobicore.modules.jutsu.slot.JutsuSlotService;
import net.fabricmc.fabric.api.networking.v1.PacketSender;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayNetworkHandler;
import net.minecraft.server.network.ServerPlayerEntity;

public final class JutsuSlotChangePacket {
    public static void handle(MinecraftServer server, ServerPlayerEntity player, ServerPlayNetworkHandler handler, PacketByteBuf buf, PacketSender responseSender) {
        // STEP 1: Read ALL data from buffer FIRST
        final int action = buf.readInt(); // 0 = select, 1 = assign
        final int slotIndex = buf.readInt();
        final String jutsuId = action == 1 ? buf.readString(64) : null;

        // STEP 2: Execute on server thread
        server.execute(() -> {
            if (action == 0) {
                JutsuSlotService.selectSlot(player, slotIndex);
            } else if (action == 1 && jutsuId != null) {
                JutsuSlotService.assignJutsu(player, slotIndex, jutsuId);
            }
        });
    }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\network\JutsuSlotChangePacket.java" $jutsuSlotChangePacketJava

# 5. Создание Java файлов (Commands)
Write-Host "`n--- Creating Java Classes (Commands) ---" -ForegroundColor Cyan

$jutsuCommandsJava = @'
package com.example.shinobicore.modules.jutsu.command;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.jutsu.cast.JutsuCastService;
import com.example.shinobicore.modules.jutsu.data.JutsuDefinition;
import com.example.shinobicore.modules.jutsu.data.JutsuJsonValidator;
import com.example.shinobicore.modules.jutsu.data.JutsuLoader;
import com.example.shinobicore.modules.jutsu.data.JutsuRegistry;
import com.example.shinobicore.modules.jutsu.slot.JutsuSlotService;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.arguments.IntegerArgumentType;
import com.mojang.brigadier.arguments.StringArgumentType;
import com.mojang.brigadier.context.CommandContext;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import net.minecraft.util.Formatting;

public final class JutsuCommands {
    public static void register(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(CommandManager.literal("shinobicore")
            .then(CommandManager.literal("jutsu").requires(src -> src.hasPermissionLevel(2))
                .then(CommandManager.literal("list").executes(JutsuCommands::cmdList))
                .then(CommandManager.literal("info").then(CommandManager.argument("id", StringArgumentType.string()).executes(JutsuCommands::cmdInfo)))
                .then(CommandManager.literal("select").then(CommandManager.argument("slot", IntegerArgumentType.integer(0, 2)).executes(JutsuCommands::cmdSelect)))
                .then(CommandManager.literal("assign").then(CommandManager.argument("slot", IntegerArgumentType.integer(0, 2))
                    .then(CommandManager.argument("id", StringArgumentType.string()).executes(JutsuCommands::cmdAssign))))
                .then(CommandManager.literal("cast").then(CommandManager.argument("slot", IntegerArgumentType.integer(0, 2)).executes(JutsuCommands::cmdCast)))
                .then(CommandManager.literal("validate").executes(JutsuCommands::cmdValidate))
                .then(CommandManager.literal("reload").executes(JutsuCommands::cmdReload))
            )
        );
    }

    private static int cmdList(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource src = ctx.getSource();
        src.sendFeedback(() -> Text.literal("=== Registered Jutsu ===").formatted(Formatting.GOLD), false);
        for (JutsuDefinition def : JutsuRegistry.all()) {
            src.sendFeedback(() -> Text.literal("- " + def.id() + " (" + def.behaviorId() + ")").formatted(Formatting.WHITE), false);
        }
        return 1;
    }

    private static int cmdInfo(CommandContext<ServerCommandSource> ctx) {
        String id = StringArgumentType.getString(ctx, "id");
        JutsuRegistry.get(id).ifPresentOrElse(def -> {
            ctx.getSource().sendFeedback(() -> Text.literal("Jutsu: " + def.name() + " | Cost: " + def.baseCost() + " | CD: " + def.cooldownTicks()).formatted(Formatting.AQUA), false);
        }, () -> {
            ctx.getSource().sendError(Text.literal("Jutsu not found: " + id));
        });
        return 1;
    }

    private static int cmdSelect(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) return 0;
        int slot = IntegerArgumentType.getInteger(ctx, "slot");
        JutsuSlotService.selectSlot(player, slot);
        ctx.getSource().sendFeedback(() -> Text.literal("Selected slot " + slot).formatted(Formatting.GREEN), false);
        return 1;
    }

    private static int cmdAssign(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) return 0;
        int slot = IntegerArgumentType.getInteger(ctx, "slot");
        String id = StringArgumentType.getString(ctx, "id");
        boolean success = JutsuSlotService.assignJutsu(player, slot, id);
        if (success) {
            ctx.getSource().sendFeedback(() -> Text.literal("Assigned " + id + " to slot " + slot).formatted(Formatting.GREEN), false);
        } else {
            ctx.getSource().sendError(Text.literal("Failed to assign jutsu. Check logs."));
        }
        return success ? 1 : 0;
        }

    private static int cmdCast(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) return 0;
        int slot = IntegerArgumentType.getInteger(ctx, "slot");
        String id = JutsuSlotService.getLoadout(player).getSlot(slot);
        if (id != null) {
            JutsuCastService.instance().requestCast(player, id, slot, System.currentTimeMillis(), player.getYaw(), player.getPitch());
            ctx.getSource().sendFeedback(() -> Text.literal("Force casting " + id).formatted(Formatting.YELLOW), false);
        }
        return 1;
    }

    private static int cmdValidate(CommandContext<ServerCommandSource> ctx) {
        JutsuJsonValidator.validateAll();
        ctx.getSource().sendFeedback(() -> Text.literal("Validation complete. Check logs/shinobicore/jutsu-1.log").formatted(Formatting.AQUA), false);
        return 1;
    }

    private static int cmdReload(CommandContext<ServerCommandSource> ctx) {
        JutsuLoader.load();
        JutsuJsonValidator.validateAll();
        ctx.getSource().sendFeedback(() -> Text.literal("Jutsu definitions reloaded.").formatted(Formatting.GREEN), false);
        return 1;
    }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\command\JutsuCommands.java" $jutsuCommandsJava

# 6. Обновление существующих файлов для интеграции
Write-Host "`n--- Updating JutsuCastService & JutsuModule ---" -ForegroundColor Cyan

$jutsuCastServiceUpdatedJava = @'
package com.example.shinobicore.modules.jutsu.cast;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.jutsu.data.JutsuRegistry;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

public final class JutsuCastService {
    private static final JutsuCastService INSTANCE = new JutsuCastService();
    private final Map<UUID, JutsuCastSession> activeSessions = new ConcurrentHashMap<>();

    public static JutsuCastService instance() { return INSTANCE; }

    public void requestCast(ServerPlayerEntity player, String jutsuId, int slot, long pressTimestampMs, float yaw, float pitch) {
        if (!JutsuRegistry.get(jutsuId).isPresent()) {
            ShinobiLogger.error("jutsu", "Attempted to cast unknown jutsu: " + jutsuId, null);
            return;
        }

        UUID uuid = player.getUuid();
        JutsuCastSession current = activeSessions.get(uuid);

        if (current != null && !current.isFinished()) {
            current.queueNext(jutsuId);
            ShinobiLogger.module("jutsu", "Queued jutsu " + jutsuId + " for player " + uuid);
            return;
        }

        JutsuCastSession newSession = new JutsuCastSession(uuid, jutsuId, slot, yaw, pitch);
        activeSessions.put(uuid, newSession);
        ShinobiLogger.module("jutsu", "Started cast: " + jutsuId + " for player " + uuid);
    }

    public void cancelCast(ServerPlayerEntity player, String reason) {
        JutsuCastSession session = activeSessions.get(player.getUuid());
        if (session != null) {
            session.cancel(reason);
        }
    }

    public void serverTick(MinecraftServer server) {
        activeSessions.entrySet().removeIf(entry -> {
            ServerPlayerEntity player = server.getPlayerManager().getPlayer(entry.getKey());
            if (player == null) return true;

            JutsuCastSession session = entry.getValue();
            session.tick(player);
            
            return session.isFinished();
        });
    }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\cast\JutsuCastService.java" $jutsuCastServiceUpdatedJava

$jutsuCastSessionUpdatedJava = @'
package com.example.shinobicore.modules.jutsu.cast;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.core.service.CoreServices;
import com.example.shinobicore.modules.jutsu.behavior.BehaviorContext;
import com.example.shinobicore.modules.jutsu.behavior.BehaviorRegistry;
import com.example.shinobicore.modules.jutsu.behavior.JutsuBehavior;
import com.example.shinobicore.modules.jutsu.data.JutsuDefinition;
import com.example.shinobicore.modules.jutsu.data.JutsuRegistry;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;

import java.util.UUID;

public final class JutsuCastSession {
    private final UUID playerId;
    private final String jutsuId;
    private final JutsuDefinition def;
    private final int slot;
    private final float yaw;
    private final float pitch;
    
    private CastPhase phase = CastPhase.PREPARE;
    private int ticksInPhase = 0;
    private float chargeMultiplier = 1.0f;
    private boolean isHoldingCast = true;
    private String queuedJutsuId = null;

    public JutsuCastSession(UUID playerId, String jutsuId, int slot, float yaw, float pitch) {
        this.playerId = playerId;
        this.jutsuId = jutsuId;
        this.slot = slot;
        this.yaw = yaw;
        this.pitch = pitch;
        this.def = JutsuRegistry.get(jutsuId).orElseThrow();
    }

    public void tick(ServerPlayerEntity player) {
        if (player == null || player.isDead()) {
            cancel("player_dead");
            return;
        }

        ticksInPhase++;
        switch (phase) {
            case PREPARE -> {
                if (ticksInPhase >= def.prepareTicks()) {
                    phase = CastPhase.CHARGE;
                    ticksInPhase = 0;
                }
            }
            case CHARGE -> {
                if (!isHoldingCast || ticksInPhase >= def.chargeTicks()) {
                    phase = CastPhase.RELEASE;
                    ticksInPhase = 0;
                } else {
                    chargeMultiplier = 1.0f + ((float) ticksInPhase / def.chargeTicks()) * (def.maxChargeMultiplier() - 1.0f);
                }
            }
            case RELEASE -> {
                if (ticksInPhase == 1) {
                    executeRelease(player);
                }
                if (ticksInPhase >= def.releaseTicks()) {
                    phase = CastPhase.COOLDOWN;
                    ticksInPhase = 0;
                }
            }
            case COOLDOWN -> {
                if (ticksInPhase >= def.cooldownTicks()) {
                    finish(player);
                }
            }
        }
    }

    private void executeRelease(ServerPlayerEntity player) {
        CoreServices.get(com.example.shinobicore.core.api.ChakraApi.class).ifPresentOrElse(chakra -> {
            float cost = def.baseCost() * chargeMultiplier;
            if (!chakra.trySpend(player, cost)) {
                cancel("insufficient_chakra_at_release");
            } else {
                BehaviorRegistry.get(def.behaviorId()).ifPresent(behavior -> {
                    BehaviorContext ctx = new BehaviorContext(
                        player, jutsuId, def, def.behaviorData(), null, 1, chargeMultiplier, (ServerWorld) player.getWorld()
                    );
                    behavior.onRelease(ctx);
                });
            }
        }, () -> {
            ShinobiLogger.module("jutsu", "ChakraApi missing, allowing cast for testing (graceful degradation).");
            BehaviorRegistry.get(def.behaviorId()).ifPresent(behavior -> {
                BehaviorContext ctx = new BehaviorContext(
                    player, jutsuId, def, def.behaviorData(), null, 1, chargeMultiplier, (ServerWorld) player.getWorld()
                );
                behavior.onRelease(ctx);
            });
        });
    }

    public void cancel(String reason) {
        phase = CastPhase.IDLE;
        ShinobiLogger.module("jutsu", "Cast cancelled for " + playerId + ". Reason: " + reason);
    }

    private void finish(ServerPlayerEntity player) {
        phase = CastPhase.IDLE;
        if (queuedJutsuId != null) {
            JutsuCastService.instance().requestCast(player, queuedJutsuId, slot, System.currentTimeMillis(), player.getYaw(), player.getPitch());
        }
    }

    public void setHoldingCast(boolean holding) { this.isHoldingCast = holding; }
    public CastPhase getPhase() { return phase; }
    public boolean isFinished() { return phase == CastPhase.IDLE; }
    public void queueNext(String nextJutsuId) { this.queuedJutsuId = nextJutsuId; }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\cast\JutsuCastSession.java" $jutsuCastSessionUpdatedJava

$jutsuModuleUpdatedJava = @'
package com.example.shinobicore.modules.jutsu;

import com.example.shinobicore.core.api.ClientAwareModule;
import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.jutsu.behavior.BehaviorRegistry;
import com.example.shinobicore.modules.jutsu.cast.JutsuCastService;
import com.example.shinobicore.modules.jutsu.command.JutsuCommands;
import com.example.shinobicore.modules.jutsu.data.JutsuJsonValidator;
import com.example.shinobicore.modules.jutsu.data.JutsuLoader;
import com.example.shinobicore.modules.jutsu.data.JutsuRegistry;
import com.example.shinobicore.modules.jutsu.network.JutsuPackets;
import com.mojang.brigadier.CommandDispatcher;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.command.ServerCommandSource;

public class JutsuModule implements ClientAwareModule {
    public static final String ID = "jutsu";

    @Override
    public String id() { return ID; }

    @Override
    public void onRegister(ModuleContext ctx) {
        ShinobiLogger.module(ID, "Registering Jutsu components...");
    }

    @Override
    public void onEnable(ModuleContext ctx) {
        ShinobiLogger.module(ID, "Enabling Jutsu module...");
        
        BehaviorRegistry.registerDefaults();
        JutsuLoader.load();
        JutsuJsonValidator.validateAll(); 
        
        JutsuPackets.registerServer();
        
        ShinobiLogger.module(ID, "Loaded " + JutsuRegistry.size() + " jutsu definitions.");
    }

    @Override
    public void onDisable(ModuleContext ctx) {
        ShinobiLogger.module(ID, "Jutsu module disabled.");
    }

    @Override
    public void registerCommands(ModuleContext ctx, CommandDispatcher<ServerCommandSource> dispatcher) {
        JutsuCommands.register(dispatcher);
    }

    @Override
    public void onServerTick(ModuleContext ctx, MinecraftServer server) {
        JutsuCastService.instance().serverTick(server);
    }
    
    @Override
    public void onClientInit(ModuleContext ctx) {
        JutsuPackets.registerClient();
    }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\JutsuModule.java" $jutsuModuleUpdatedJava

Write-Host "`n=== Setup Complete! ===" -ForegroundColor Green
Write-Host "Next step: Run '.\gradlew.bat build' to verify compilation." -ForegroundColor Yellow
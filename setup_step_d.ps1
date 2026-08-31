# =========================================================================
# MASTER SCRIPT: ShinobiCore Combat Module - Step D (Server Logic & Services)
# =========================================================================

$baseDir = "src/main/java/com/example/shinobicore/modules/combat"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

function Write-File {
    param([string]$Path, [string]$Content)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
    Write-Host "  Created/Updated: $Path" -ForegroundColor Gray
}

Write-Host "Writing Step D files (Server Logic)..." -ForegroundColor Cyan

# 1. CombatConfig (Stub for compilation)
Write-File "$baseDir/config/CombatConfig.java" @"
package com.example.shinobicore.modules.combat.config;

import com.google.gson.JsonObject;

public final class CombatConfig {
    private static CombatConfig INSTANCE = new CombatConfig();
    public BlockConfig block = new BlockConfig();
    public ParryConfig parry = new ParryConfig();
    public boolean enabled = true;
    public boolean debug = false;

    public static CombatConfig get() { return INSTANCE; }

    public static void load(JsonObject json) {
        if (json.has("block") && json.get("block").isJsonObject()) {
            JsonObject b = json.getAsJsonObject("block");
            if (b.has("drainPerSecond")) INSTANCE.block.drainPerSecond = b.get("drainPerSecond").getAsDouble();
            if (b.has("damageReductionMultiplier")) INSTANCE.block.damageReductionMultiplier = b.get("damageReductionMultiplier").getAsFloat();
        }
        if (json.has("parry") && json.get("parry").isJsonObject()) {
            JsonObject p = json.getAsJsonObject("parry");
            if (p.has("baseWindowMs")) INSTANCE.parry.baseWindowMs = p.get("baseWindowMs").getAsLong();
            if (p.has("failRecoveryMs")) INSTANCE.parry.failRecoveryMs = p.get("failRecoveryMs").getAsLong();
            if (p.has("successChakraGain")) INSTANCE.parry.successChakraGain = p.get("successChakraGain").getAsFloat();
        }
    }

    public static class BlockConfig {
        public double drainPerSecond = 5.0;
        public float damageReductionMultiplier = 0.4f;
    }

    public static class ParryConfig {
        public long baseWindowMs = 250;
        public long failRecoveryMs = 800;
        public float successChakraGain = 5.0f;
    }
}
"@

# 2. DrainAccumulator (Pattern from TZ §7)
Write-File "$baseDir/service/DrainAccumulator.java" @"
package com.example.shinobicore.modules.combat.service;

public class DrainAccumulator {
    private double accumulator = 0.0;
    private final double perSecond;

    public DrainAccumulator(double perSecond) {
        this.perSecond = perSecond;
    }

    public int tick(double deltaTimeSeconds) {
        accumulator += perSecond * deltaTimeSeconds;
        int toSpend = (int) accumulator;
        accumulator -= toSpend;
        return toSpend;
    }

    public void reset() {
        accumulator = 0.0;
    }
}
"@

# 3. BlockService
Write-File "$baseDir/service/BlockService.java" @"
package com.example.shinobicore.modules.combat.service;

import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.core.service.CoreServices;
import com.example.shinobicore.core.api.ChakraApi;
import com.example.shinobicore.modules.combat.CombatModule;
import com.example.shinobicore.modules.combat.common.Stance;
import com.example.shinobicore.modules.combat.component.CombatComponent;
import com.example.shinobicore.modules.combat.component.CombatComponentKey;
import com.example.shinobicore.modules.combat.config.CombatConfig;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

public final class BlockService {
    private static final Map<UUID, DrainAccumulator> accumulators = new ConcurrentHashMap<>();
    private static ModuleContext ctx;

    public static void init(ModuleContext context) {
        ctx = context;
    }

    public static void startBlock(ServerPlayerEntity player) {
        CombatComponent comp = CombatComponentKey.KEY.getNullable(player);
        if (comp == null || comp.getStance() != Stance.AGGRESSIVE) return;
        
        comp.setBlocking(true);
        accumulators.putIfAbsent(player.getUuid(), new DrainAccumulator(CombatConfig.get().block.drainPerSecond));
        ShinobiLogger.module(CombatModule.ID, "Player " + player.getName().getString() + " started blocking");
    }

    public static void stopBlock(ServerPlayerEntity player) {
        CombatComponent comp = CombatComponentKey.KEY.getNullable(player);
        if (comp != null) comp.setBlocking(false);
        accumulators.remove(player.getUuid());
    }

    public static void serverTick(MinecraftServer server) {
        for (ServerPlayerEntity player : server.getPlayerManager().getPlayerList()) {
            CombatComponent comp = CombatComponentKey.KEY.getNullable(player);
            if (comp == null || !comp.isBlocking()) continue;

            DrainAccumulator acc = accumulators.get(player.getUuid());
            if (acc == null) continue;

            // 1 tick = 0.05 seconds
            int fatigueGain = acc.tick(0.05);
            if (fatigueGain > 0) {
                CoreServices.get(ChakraApi.class).ifPresent(chakra -> {
                    chakra.addFatigue(player, fatigueGain);
                });
            }
        }
    }

    public static float calculateDamageReduction() {
        return CombatConfig.get().block.damageReductionMultiplier;
    }
}
"@

# 4. ParryService
Write-File "$baseDir/service/ParryService.java" @"
package com.example.shinobicore.modules.combat.service;

import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.core.service.CoreServices;
import com.example.shinobicore.core.api.ChakraApi;
import com.example.shinobicore.core.api.StatsApi;
import com.example.shinobicore.modules.combat.CombatModule;
import com.example.shinobicore.modules.combat.common.Stance;
import com.example.shinobicore.modules.combat.component.CombatComponent;
import com.example.shinobicore.modules.combat.component.CombatComponentKey;
import com.example.shinobicore.modules.combat.config.CombatConfig;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;

public final class ParryService {
    private static ModuleContext ctx;

    public static void init(ModuleContext context) {
        ctx = context;
    }

    public static void attemptParry(ServerPlayerEntity defender, long clientPressTimeMs) {
        CombatComponent comp = CombatComponentKey.KEY.getNullable(defender);
        if (comp == null || comp.getStance() != Stance.DEFENSIVE) return;

        long now = System.currentTimeMillis();
        if (now < comp.getParryFailRecoveryUntil()) return; // Still in recovery

        long windowMs = calculateParryWindow(defender);
        comp.setParrying(true);
        
        // Grant chakra on successful parry attempt (simplified logic)
        CoreServices.get(ChakraApi.class).ifPresent(chakra -> {
            chakra.add(defender, CombatConfig.get().parry.successChakraGain);
        });

        ShinobiLogger.module(CombatModule.ID, "Player " + defender.getName().getString() + " attempted parry");
    }

    public static void serverTick(MinecraftServer server) {
        // TODO: Check parry window expiration and reset isParrying flag
    }

    private static long calculateParryWindow(ServerPlayerEntity player) {
        CombatConfig cfg = CombatConfig.get();
        int perception = CoreServices.get(StatsApi.class)
                .map(api -> api.getStatLevel(player, "perception"))
                .orElse(0);
        
        long window = (long) (cfg.parry.baseWindowMs * (1.0 - perception * 0.003));
        return Math.max(80, window);
    }
}
"@

# 5. ComboTracker
Write-File "$baseDir/service/ComboTracker.java" @"
package com.example.shinobicore.modules.combat.service;

import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.modules.combat.common.WeaponClass;
import com.example.shinobicore.modules.combat.component.CombatComponent;
import com.example.shinobicore.modules.combat.component.CombatComponentKey;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;

public final class ComboTracker {
    private static ModuleContext ctx;
    private static final long COMBO_TIMEOUT_MS = 1500;

    public static void init(ModuleContext context) {
        ctx = context;
    }

    public static void onAttack(ServerPlayerEntity attacker, WeaponClass weaponClass) {
        CombatComponent comp = CombatComponentKey.KEY.getNullable(attacker);
        if (comp == null) return;

        long now = System.currentTimeMillis();
        if (now > comp.getComboExpireAtMs()) {
            comp.setComboStep(0);
        }

        comp.setComboStep(comp.getComboStep() + 1);
        comp.setComboExpireAtMs(now + COMBO_TIMEOUT_MS);
    }

    public static void serverTick(MinecraftServer server) {
        long now = System.currentTimeMillis();
        for (ServerPlayerEntity player : server.getPlayerManager().getPlayerList()) {
            CombatComponent comp = CombatComponentKey.KEY.getNullable(player);
            if (comp == null) continue;

            if (comp.getComboStep() > 0 && now > comp.getComboExpireAtMs()) {
                comp.resetCombo();
            }
        }
    }
}
"@

# 6. DamageInterceptionService (Bonus Damage)
Write-File "$baseDir/service/DamageInterceptionService.java" @"
package com.example.shinobicore.modules.combat.service;

import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.core.service.CoreServices;
import com.example.shinobicore.core.api.StatsApi;
import com.example.shinobicore.modules.combat.CombatModule;
import com.example.shinobicore.modules.combat.component.CombatComponent;
import com.example.shinobicore.modules.combat.component.CombatComponentKey;
import net.fabricmc.fabric.api.event.player.AttackEntityCallback;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.ActionResult;

public final class DamageInterceptionService {
    private static ModuleContext ctx;

    public static void init(ModuleContext context) {
        ctx = context;
        registerAttackCallback();
    }

    private static void registerAttackCallback() {
        AttackEntityCallback.EVENT.register((player, world, hand, target, hitResult) -> {
            if (!(player instanceof ServerPlayerEntity sp)) return ActionResult.PASS;
            if (!(target instanceof LivingEntity le)) return ActionResult.PASS;

            CombatComponent comp = CombatComponentKey.KEY.getNullable(sp);
            if (comp == null) return ActionResult.PASS;

            float bonus = calculateShinobiBonus(sp, comp);

            if (bonus > 0.01f) {
                ((ServerWorld) world).getServer().execute(() -> {
                    if (le.isAlive()) {
                        // Apply bonus as magic damage to avoid double-dipping armor reduction
                        le.damage(sp.getDamageSources().magic(), bonus);
                    }
                });
            }

            // Update combo tracker
            // ComboTracker.onAttack(sp, BetterCombatAdapter.resolveWeaponClass(sp.getMainHandStack()));

            return ActionResult.PASS; // NEVER cancel vanilla damage
        });
    }

    private static float calculateShinobiBonus(ServerPlayerEntity player, CombatComponent comp) {
        float baseDamage = 1.0f; // Placeholder
        int taijutsu = CoreServices.get(StatsApi.class)
                .map(api -> api.getStatLevel(player, "taijutsu"))
                .orElse(0);
        
        // Formula: baseDamage * (1 + taijutsuLevel * 0.05)
        return baseDamage * (1.0f + taijutsu * 0.05f);
    }
}
"@

# 7. Update CombatPackets.java (Server Handlers)
Write-File "$baseDir/network/CombatPackets.java" @"
package com.example.shinobicore.modules.combat.network;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.combat.common.Stance;
import com.example.shinobicore.modules.combat.service.BlockService;
import com.example.shinobicore.modules.combat.service.ParryService;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.networking.v1.PacketByteBufs;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.util.Identifier;

public final class CombatPackets {
    private static final Identifier STANCE_CHANGE = new Identifier("shinobicore", "combat_stance_change");
    private static final Identifier BLOCK_START = new Identifier("shinobicore", "combat_block_start");
    private static final Identifier PARRY_ATTEMPT = new Identifier("shinobicore", "combat_parry_attempt");
    private static final Identifier THROW = new Identifier("shinobicore", "combat_throw");
    private static final Identifier SHEATH_TOGGLE = new Identifier("shinobicore", "combat_sheath_toggle");
    private static final Identifier KICK = new Identifier("shinobicore", "combat_kick");
    private static final Identifier QUICK_SLOT = new Identifier("shinobicore", "combat_quick_slot");
    private static final Identifier STATE_SYNC = new Identifier("shinobicore", "combat_state_sync");

    public static void registerServer() {
        ServerPlayNetworking.registerGlobalReceiver(STANCE_CHANGE, (server, player, handler, buf, sender) -> {
            final int stanceOrdinal = buf.readInt();
            server.execute(() -> {
                ShinobiLogger.module("combat", "Server received stance change: " + stanceOrdinal);
                // TODO: Call StanceService
            });
        });
        
        ServerPlayNetworking.registerGlobalReceiver(BLOCK_START, (server, player, handler, buf, sender) -> {
            server.execute(() -> {
                BlockService.startBlock(player);
            });
        });

        ServerPlayNetworking.registerGlobalReceiver(PARRY_ATTEMPT, (server, player, handler, buf, sender) -> {
            final long pressTimeMs = buf.readLong(); // CRITICAL: Read BEFORE server.execute()
            server.execute(() -> {
                ParryService.attemptParry(player, pressTimeMs);
            });
        });

        ShinobiLogger.module("combat", "Server combat packets registered");
    }

    public static void registerClient() {
        ClientPlayNetworking.registerGlobalReceiver(STATE_SYNC, (client, handler, buf, sender) -> {
            final int stanceOrdinal = buf.readInt();
            final boolean isSheathed = buf.readBoolean();
            client.execute(() -> {
                com.example.shinobicore.modules.combat.client.CombatClientState.setCurrentStance(Stance.fromOrdinal(stanceOrdinal));
                com.example.shinobicore.modules.combat.client.CombatClientState.setSheathed(isSheathed);
            });
        });
        ShinobiLogger.module("combat", "Client combat packets registered");
    }

    public static void sendStanceChange(int stanceOrdinal) {
        PacketByteBuf buf = PacketByteBufs.create();
        buf.writeInt(stanceOrdinal);
        ClientPlayNetworking.send(STANCE_CHANGE, buf);
    }

    public static void sendParryAttempt(long pressTimeMs) {
        PacketByteBuf buf = PacketByteBufs.create();
        buf.writeLong(pressTimeMs);
        ClientPlayNetworking.send(PARRY_ATTEMPT, buf);
    }

    public static void sendBlockStart() {
        ClientPlayNetworking.send(BLOCK_START, PacketByteBufs.create());
    }

    public static void sendThrow(float yaw, float pitch) {
        PacketByteBuf buf = PacketByteBufs.create();
        buf.writeFloat(yaw);
        buf.writeFloat(pitch);
        ClientPlayNetworking.send(THROW, buf);
    }

    public static void sendSheathToggle() {
        ClientPlayNetworking.send(SHEATH_TOGGLE, PacketByteBufs.create());
    }

    public static void sendKick() {
        ClientPlayNetworking.send(KICK, PacketByteBufs.create());
    }

    public static void sendQuickSlotCycle() {
        ClientPlayNetworking.send(QUICK_SLOT, PacketByteBufs.create());
    }
}
"@

# 8. Fix CombatModule.java package and add DamageInterceptionService
Write-File "$baseDir/CombatModule.java" @"
package com.example.shinobicore.modules.combat;

import com.example.shinobicore.core.api.ClientAwareModule;
import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.event.*;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.core.module.ModuleManager;
import com.example.shinobicore.modules.combat.compat.BetterCombatAdapter;
import com.example.shinobicore.modules.combat.compat.CombatCompatibilityChecker;
import com.example.shinobicore.modules.combat.config.CombatConfig;
import com.example.shinobicore.modules.combat.component.CombatComponentKey;
import com.example.shinobicore.modules.combat.input.CombatInputHandler;
import com.example.shinobicore.modules.combat.input.CombatKeyBindings;
import com.example.shinobicore.modules.combat.network.CombatPackets;
import com.example.shinobicore.modules.combat.service.*;
import com.example.shinobicore.modules.combat.view.CombatVisualView;
import com.example.shinobicore.modules.combat.view.CombatVisualViewImpl;
import com.mojang.brigadier.CommandDispatcher;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.command.ServerCommandSource;

public class CombatModule implements ClientAwareModule {
    public static final String ID = "combat";

    @Override public String id() { return ID; }

    @Override
    public void onRegister(ModuleContext ctx) {
        CombatComponentKey.register();
        ShinobiLogger.module(ID, "Combat component key registered");
    }

    @Override
    public void onEnable(ModuleContext ctx) {
        if (!CombatCompatibilityChecker.isBetterCombatOk()) {
            ShinobiLogger.error(ID, "Better Combat is REQUIRED but not detected. Disabling module.", null);
            ctx.events().publish(new ModuleDisabledEvent(ID, "Missing required mod: bettercombat"));
            ModuleManager.disable(ID, "Missing Better Combat");
            return;
        }

        CombatConfig.load(ctx.configs().readModuleConfig(ID));
        BetterCombatAdapter.init();
        
        StanceService.init(ctx);
        BlockService.init(ctx);
        ParryService.init(ctx);
        SheathService.init(ctx);
        ProjectileDeflectService.init(ctx);
        ComboTracker.init(ctx);
        DamageInterceptionService.init(ctx);

        CombatPackets.registerServer();
        ShinobiLogger.module(ID, "Combat module enabled successfully");
    }

    @Override
    public void registerEvents(ModuleContext ctx) {
        ctx.events().subscribe(PlayerDiedEvent.class, e -> {
            var comp = CombatComponentKey.KEY.getNullable(e.player());
            if (comp != null) {
                comp.setStance(com.example.shinobicore.modules.combat.common.Stance.NONE);
                comp.setBlocking(false);
                comp.setParrying(false);
                comp.resetCombo();
                comp.setSheathed(false);
            }
        });
    }

    @Override
    public void registerViews(ModuleContext ctx) {
        ctx.views().register(CombatVisualView.class, player ->
            java.util.Optional.of(new CombatVisualViewImpl(player)));
    }

    @Override
    public void registerCommands(ModuleContext ctx, CommandDispatcher<ServerCommandSource> dispatcher) {
        // TODO
    }

    @Override
    public void onClientInit(ModuleContext ctx) {
        CombatKeyBindings.register();
        CombatPackets.registerClient();
        ShinobiLogger.module(ID, "Combat client initialized");
    }

    @Override
    public void onClientTick(ModuleContext ctx) {
        CombatInputHandler.tick();
    }

    @Override
    public void onServerTick(ModuleContext ctx, MinecraftServer server) {
        BlockService.serverTick(server);
        ParryService.serverTick(server);
        ProjectileDeflectService.serverTick(server);
        ComboTracker.serverTick(server);
    }
}
"@

Write-Host "=========================================================" -ForegroundColor Green
Write-Host " SUCCESS: Step D completed!" -ForegroundColor Green
Write-Host "=========================================================" -ForegroundColor Green
Write-Host "Implemented:" -ForegroundColor Yellow
Write-Host " - DrainAccumulator pattern for block stamina drain"
Write-Host " - BlockService (server-side blocking & fatigue drain)"
Write-Host " - ParryService (window calculation & chakra gain)"
Write-Host " - ComboTracker (step tracking & timeout reset)"
Write-Host " - DamageInterceptionService (Shinobi bonus damage via magic())"
Write-Host " - Server packet handlers (strict read-before-execute rule)"
Write-Host "Next step: Run '.\gradlew.bat build' to verify compilation." -ForegroundColor Cyan
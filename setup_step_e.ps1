# =========================================================================
# MASTER SCRIPT: ShinobiCore Combat Module - Step E (Mechanics, Events, Commands)
# FIXED: Added directory creation to prevent PathNotFoundException
# =========================================================================

$baseDir = "src/main/java/com/example/shinobicore/modules/combat"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

# FIX: Ensure all required directories exist
Write-Host "Ensuring directory structure exists..." -ForegroundColor Cyan
$dirs = @(
    "$baseDir/common", "$baseDir/compat", "$baseDir/component",
    "$baseDir/service", "$baseDir/input", "$baseDir/client",
    "$baseDir/network", "$baseDir/view", "$baseDir/config",
    "$baseDir/data", "$baseDir/render", "$baseDir/audio",
    "$baseDir/event", "$baseDir/command"
)
foreach ($dir in $dirs) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }

function Write-File {
    param([string]$Path, [string]$Content)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
    Write-Host "  Created/Updated: $Path" -ForegroundColor Gray
}

Write-Host "Writing Step E files (Mechanics, Events, Commands)..." -ForegroundColor Cyan

# 1. Combat Events (Records)
Write-File "$baseDir/event/CombatEvents.java" @"
package com.example.shinobicore.modules.combat.event;

import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.network.ServerPlayerEntity;

public final class CombatEvents {
    private CombatEvents() {}

    public record AttackEvent(ServerPlayerEntity attacker, Entity target, float totalDamage, int comboStep) {}
    public record HitEvent(ServerPlayerEntity attacker, LivingEntity target, float damage) {}
    public record BlockedEvent(ServerPlayerEntity blocker, Entity attacker, float reducedDamage) {}
    public record ParriedEvent(ServerPlayerEntity parrier, Entity attacker, boolean reflected) {}
    public record KickEvent(ServerPlayerEntity kicker, Entity target, float damage) {}
    public record StanceChangedEvent(ServerPlayerEntity player, String oldStance, String newStance) {}
    public record ComboChangedEvent(ServerPlayerEntity player, int oldStep, int newStep, String weaponClass) {}
    public record ThrowableThrownEvent(ServerPlayerEntity thrower, Entity projectile, String weaponId) {}
    public record WeaponSheathedEvent(ServerPlayerEntity player, boolean sheathed, String itemId) {}
    public record WeaponDrawnEvent(ServerPlayerEntity player, String itemId) {}
    public record ProjectileDeflectedEvent(ServerPlayerEntity defender, Entity projectile) {}
}
"@

# 2. ThrowableService (Throwing mechanics)
Write-File "$baseDir/service/ThrowableService.java" @"
package com.example.shinobicore.modules.combat.service;

import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.core.service.CoreServices;
import com.example.shinobicore.core.api.StatsApi;
import com.example.shinobicore.modules.combat.CombatModule;
import com.example.shinobicore.modules.combat.config.CombatConfig;
import com.example.shinobicore.modules.combat.event.CombatEvents;
import net.minecraft.entity.projectile.TridentEntity;
import net.minecraft.item.ItemStack;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;

public final class ThrowableService {
    private static ModuleContext ctx;

    public static void init(ModuleContext context) {
        ctx = context;
    }

    public static void throwWeapon(ServerPlayerEntity player, float yaw, float pitch) {
        ItemStack stack = player.getMainHandStack();
        if (stack.isEmpty()) return;

        String itemId = stack.getItem().getTranslationKey();
        if (!itemId.contains("shuriken") && !itemId.contains("kunai")) return;

        ServerWorld world = (ServerWorld) player.getWorld();
        
        TridentEntity projectile = new TridentEntity(world, player, stack);
        projectile.setPosition(player.getEyePos());
        
        Vec3d direction = player.getRotationVec(1.0f);
        
        int perception = CoreServices.get(StatsApi.class)
                .map(api -> api.getStatLevel(player, "perception"))
                .orElse(0);
        float spreadReduction = perception * CombatConfig.get().thrown.perceptionSpreadReductionPerLevel;
        float spread = Math.max(0.0f, 1.0f - spreadReduction);
        
        double speed = CombatConfig.get().thrown.speed;
        projectile.setVelocity(direction.x, direction.y, direction.z, (float)speed, spread);
        
        world.spawnEntity(projectile);
        
        if (!player.getAbilities().creativeMode) {
            stack.decrement(1);
        }

        ctx.events().publish(new CombatEvents.ThrowableThrownEvent(player, projectile, itemId));
        ShinobiLogger.module(CombatModule.ID, "Player " + player.getName().getString() + " threw " + itemId);
    }
}
"@

# 3. KickService
Write-File "$baseDir/service/KickService.java" @"
package com.example.shinobicore.modules.combat.service;

import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.core.service.CoreServices;
import com.example.shinobicore.core.api.ChakraApi;
import com.example.shinobicore.core.api.StatsApi;
import com.example.shinobicore.modules.combat.CombatModule;
import com.example.shinobicore.modules.combat.config.CombatConfig;
import com.example.shinobicore.modules.combat.event.CombatEvents;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import java.util.List;

public final class KickService {
    private static ModuleContext ctx;

    public static void init(ModuleContext context) {
        ctx = context;
    }

    public static void performKick(ServerPlayerEntity player) {
        CombatConfig.KickConfig cfg = CombatConfig.get().kick;
        if (!cfg.enabled) return;

        boolean hasStamina = CoreServices.get(ChakraApi.class)
                .map(api -> api.getCurrent(player) >= cfg.staminaCost)
                .orElse(true);
        
        if (!hasStamina) {
            ShinobiLogger.module(CombatModule.ID, "Player " + player.getName().getString() + " failed kick: not enough stamina");
            return;
        }

        CoreServices.get(ChakraApi.class).ifPresent(api -> api.trySpend(player, cfg.staminaCost));

        Vec3d pos = player.getPos();
        Vec3d look = player.getRotationVec(1.0f);
        Box searchBox = new Box(pos.add(-1.5, -1, -1.5), pos.add(1.5, 2, 1.5));
        searchBox = searchBox.offset(look.multiply(1.5));

        List<LivingEntity> targets = player.getWorld().getEntitiesByClass(LivingEntity.class, searchBox, e -> e != player && e.isAlive());
        
        int taijutsu = CoreServices.get(StatsApi.class)
                .map(api -> api.getStatLevel(player, "taijutsu"))
                .orElse(0);

        float damage = (float) (cfg.baseDamage * (1.0 + taijutsu * cfg.taijutsuPerLevel));

        for (LivingEntity target : targets) {
            target.damage(player.getDamageSources().playerAttack(player), damage);
            
            Vec3d knockback = look.multiply(cfg.knockbackStrength).add(0, 0.2, 0);
            target.addVelocity(knockback.x, knockback.y, knockback.z);
            target.velocityModified = true;

            ctx.events().publish(new CombatEvents.KickEvent(player, target, damage));
        }

        ShinobiLogger.module(CombatModule.ID, "Player " + player.getName().getString() + " performed kick, hitting " + targets.size() + " targets");
    }
}
"@

# 4. SheathService
Write-File "$baseDir/service/SheathService.java" @"
package com.example.shinobicore.modules.combat.service;

import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.combat.CombatModule;
import com.example.shinobicore.modules.combat.component.CombatComponent;
import com.example.shinobicore.modules.combat.component.CombatComponentKey;
import com.example.shinobicore.modules.combat.event.CombatEvents;
import net.minecraft.item.ItemStack;
import net.minecraft.server.network.ServerPlayerEntity;

public final class SheathService {
    private static ModuleContext ctx;

    public static void init(ModuleContext context) {
        ctx = context;
    }

    public static void toggleSheath(ServerPlayerEntity player) {
        CombatComponent comp = CombatComponentKey.KEY.getNullable(player);
        if (comp == null) return;

        ItemStack mainHand = player.getMainHandStack();
        String itemId = mainHand.getItem().getTranslationKey();
        
        if (!itemId.contains("katana") && !comp.isSheathed()) {
            ShinobiLogger.module(CombatModule.ID, "Player tried to sheath non-katana item");
            return;
        }

        boolean newState = !comp.isSheathed();
        comp.setSheathed(newState);

        if (newState) {
            ctx.events().publish(new CombatEvents.WeaponSheathedEvent(player, true, itemId));
            ShinobiLogger.module(CombatModule.ID, "Player " + player.getName().getString() + " sheathed weapon");
        } else {
            ctx.events().publish(new CombatEvents.WeaponDrawnEvent(player, itemId));
            ShinobiLogger.module(CombatModule.ID, "Player " + player.getName().getString() + " drew weapon");
        }
    }
}
"@

# 5. QuickWeaponSlotService
Write-File "$baseDir/service/QuickWeaponSlotService.java" @"
package com.example.shinobicore.modules.combat.service;

import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.combat.CombatModule;
import net.minecraft.entity.player.PlayerInventory;
import net.minecraft.item.ItemStack;
import net.minecraft.server.network.ServerPlayerEntity;

public final class QuickWeaponSlotService {
    private static ModuleContext ctx;
    private static final String[] CYCLE_ORDER = {"katana", "kunai", "shuriken"};

    public static void init(ModuleContext context) {
        ctx = context;
    }

    public static void cycleWeapon(ServerPlayerEntity player) {
        PlayerInventory inv = player.getInventory();
        ItemStack current = player.getMainHandStack();
        String currentId = current.getItem().getTranslationKey();
        
        int currentIndex = -1;
        for (int i = 0; i < CYCLE_ORDER.length; i++) {
            if (currentId.contains(CYCLE_ORDER[i])) {
                currentIndex = i;
                break;
            }
        }

        for (int i = 1; i <= CYCLE_ORDER.length; i++) {
            int nextIndex = (currentIndex + i) % CYCLE_ORDER.length;
            String targetName = CYCLE_ORDER[nextIndex];
            
            for (int slot = 0; slot < inv.size(); slot++) {
                ItemStack stack = inv.getStack(slot);
                if (!stack.isEmpty() && stack.getItem().getTranslationKey().contains(targetName)) {
                    inv.selectedSlot = slot < 9 ? slot : inv.selectedSlot;
                    if (slot >= 9) {
                        inv.swapSlotWithHotbar(slot);
                    }
                    ShinobiLogger.module(CombatModule.ID, "Player " + player.getName().getString() + " quick-swapped to " + targetName);
                    return;
                }
            }
        }
        
        ShinobiLogger.module(CombatModule.ID, "No other combat weapons found in inventory for " + player.getName().getString());
    }
}
"@

# 6. Update CombatPackets.java (Add new handlers)
Write-File "$baseDir/network/CombatPackets.java" @"
package com.example.shinobicore.modules.combat.network;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.combat.common.Stance;
import com.example.shinobicore.modules.combat.service.*;
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
            server.execute(() -> ShinobiLogger.module("combat", "Server received stance change: " + stanceOrdinal));
        });
        
        ServerPlayNetworking.registerGlobalReceiver(BLOCK_START, (server, player, handler, buf, sender) -> {
            server.execute(() -> BlockService.startBlock(player));
        });

        ServerPlayNetworking.registerGlobalReceiver(PARRY_ATTEMPT, (server, player, handler, buf, sender) -> {
            final long pressTimeMs = buf.readLong();
            server.execute(() -> ParryService.attemptParry(player, pressTimeMs));
        });

        ServerPlayNetworking.registerGlobalReceiver(THROW, (server, player, handler, buf, sender) -> {
            final float yaw = buf.readFloat();
            final float pitch = buf.readFloat();
            server.execute(() -> ThrowableService.throwWeapon(player, yaw, pitch));
        });

        ServerPlayNetworking.registerGlobalReceiver(SHEATH_TOGGLE, (server, player, handler, buf, sender) -> {
            server.execute(() -> SheathService.toggleSheath(player));
        });

        ServerPlayNetworking.registerGlobalReceiver(KICK, (server, player, handler, buf, sender) -> {
            server.execute(() -> KickService.performKick(player));
        });

        ServerPlayNetworking.registerGlobalReceiver(QUICK_SLOT, (server, player, handler, buf, sender) -> {
            server.execute(() -> QuickWeaponSlotService.cycleWeapon(player));
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
        PacketByteBuf buf = PacketByteBufs.create(); buf.writeInt(stanceOrdinal);
        ClientPlayNetworking.send(STANCE_CHANGE, buf);
    }
    public static void sendParryAttempt(long pressTimeMs) {
        PacketByteBuf buf = PacketByteBufs.create(); buf.writeLong(pressTimeMs);
        ClientPlayNetworking.send(PARRY_ATTEMPT, buf);
    }
    public static void sendBlockStart() { ClientPlayNetworking.send(BLOCK_START, PacketByteBufs.create()); }
    public static void sendThrow(float yaw, float pitch) {
        PacketByteBuf buf = PacketByteBufs.create(); buf.writeFloat(yaw); buf.writeFloat(pitch);
        ClientPlayNetworking.send(THROW, buf);
    }
    public static void sendSheathToggle() { ClientPlayNetworking.send(SHEATH_TOGGLE, PacketByteBufs.create()); }
    public static void sendKick() { ClientPlayNetworking.send(KICK, PacketByteBufs.create()); }
    public static void sendQuickSlotCycle() { ClientPlayNetworking.send(QUICK_SLOT, PacketByteBufs.create()); }
}
"@

# 7. CombatCommands
Write-File "$baseDir/command/CombatCommands.java" @"
package com.example.shinobicore.modules.combat.command;

import com.example.shinobicore.modules.combat.common.Stance;
import com.example.shinobicore.modules.combat.component.CombatComponent;
import com.example.shinobicore.modules.combat.component.CombatComponentKey;
import com.example.shinobicore.modules.combat.service.SheathService;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.context.CommandContext;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import net.minecraft.util.Formatting;

public final class CombatCommands {
    private CombatCommands() {}

    public static void register(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(CommandManager.literal("shinobicore")
            .then(CommandManager.literal("combat")
                .then(CommandManager.literal("info").executes(CombatCommands::cmdInfo))
                .then(CommandManager.literal("reset").executes(CombatCommands::cmdReset))
                .then(CommandManager.literal("sheath")
                    .then(CommandManager.literal("toggle").executes(CombatCommands::cmdSheathToggle)))
                .then(CommandManager.literal("stance")
                    .then(CommandManager.literal("set")
                        .then(CommandManager.literal("aggressive").executes(ctx -> cmdSetStance(ctx, Stance.AGGRESSIVE)))
                        .then(CommandManager.literal("defensive").executes(ctx -> cmdSetStance(ctx, Stance.DEFENSIVE)))
                    )
                )
            )
        );
    }

    private static int cmdInfo(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        CombatComponent comp = CombatComponentKey.KEY.getNullable(player);
        if (comp == null) {
            ctx.getSource().sendFeedback(() -> Text.literal("No combat component found").formatted(Formatting.RED), false);
            return 1;
        }
        
        String info = String.format("Stance: %s | Blocking: %b | Parrying: %b | Combo: %d | Sheathed: %b",
                comp.getStance(), comp.isBlocking(), comp.isParrying(), comp.getComboStep(), comp.isSheathed());
        
        ctx.getSource().sendFeedback(() -> Text.literal(info).formatted(Formatting.GOLD), false);
        return 1;
    }

    private static int cmdReset(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        CombatComponent comp = CombatComponentKey.KEY.getNullable(player);
        if (comp != null) {
            comp.setStance(Stance.NONE);
            comp.setBlocking(false);
            comp.setParrying(false);
            comp.resetCombo();
            comp.setSheathed(false);
        }
        ctx.getSource().sendFeedback(() -> Text.literal("Combat state reset").formatted(Formatting.GREEN), false);
        return 1;
    }

    private static int cmdSheathToggle(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        SheathService.toggleSheath(player);
        ctx.getSource().sendFeedback(() -> Text.literal("Sheath toggled").formatted(Formatting.GREEN), false);
        return 1;
    }

    private static int cmdSetStance(CommandContext<ServerCommandSource> ctx, Stance stance) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        CombatComponent comp = CombatComponentKey.KEY.getNullable(player);
        if (comp != null) {
            comp.setStance(stance);
            ctx.getSource().sendFeedback(() -> Text.literal("Stance set to " + stance).formatted(Formatting.GREEN), false);
        }
        return 1;
    }
}
"@

# 8. Update CombatModule.java (Add new services and commands)
Write-File "$baseDir/CombatModule.java" @"
package com.example.shinobicore.modules.combat;

import com.example.shinobicore.core.api.ClientAwareModule;
import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.event.*;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.core.module.ModuleManager;
import com.example.shinobicore.modules.combat.command.CombatCommands;
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
        ThrowableService.init(ctx);
        KickService.init(ctx);
        QuickWeaponSlotService.init(ctx);

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
        CombatCommands.register(dispatcher);
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
Write-Host " SUCCESS: Step E completed!" -ForegroundColor Green
Write-Host "=========================================================" -ForegroundColor Green
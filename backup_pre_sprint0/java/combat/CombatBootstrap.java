package com.example.shinobicore.combat;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.combat.bettercombat.BetterCombatIntegration;
import com.example.shinobicore.command.CombatCommands;
import com.example.shinobicore.item.ModItems;
import com.example.shinobicore.stat.component.IChakraComponent;
import com.example.shinobicore.stat.component.ICombatComponent;
import com.example.shinobicore.stat.component.IStatsComponent;
import com.example.shinobicore.stat.component.NinjaComponents;
import net.fabricmc.fabric.api.command.v2.CommandRegistrationCallback;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.fabricmc.fabric.api.event.player.AttackEntityCallback;
import net.fabricmc.fabric.api.networking.v1.ServerPlayConnectionEvents;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.Entity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.ActionResult;
import net.minecraft.util.Identifier;

/**
* Sprint 2 wiring: EF detection, items, commands, damage layer,
* stance maintenance, wall-run ticks, disconnect cleanup, block state.
* HLD: Section 4
*/
public final class CombatBootstrap {
    private CombatBootstrap() {}

    public static void init() {
        BetterCombatIntegration.detect();
        ModItems.init();
        
        CommandRegistrationCallback.EVENT.register((dispatcher, registryAccess, environment) -> {
            CombatCommands.register(dispatcher);
        });

        // Damage layer (HLD 4.5): never cancel base damage, ADD scaled magic damage.
        AttackEntityCallback.EVENT.register((player, world, hand, target, hitResult) -> {
            if (player instanceof ServerPlayerEntity sp) {
                onMeleeHit(sp, target);
            }
            return ActionResult.PASS;
        });

        ServerTickEvents.END_SERVER_TICK.register(server -> {
            boolean secondTick = server.getTicks() % 20 == 0;
            for (ServerPlayerEntity p : server.getPlayerManager().getPlayerList()) {
                if (secondTick) {
                    StanceManager.tickMaintain(p);
                }
                WallRunManager.tickPlayer(p);
            }
        });

        // RULES: static maps must be cleaned on disconnect
        ServerPlayConnectionEvents.DISCONNECT.register((handler, server) -> {
            WallRunManager.clear(handler.getPlayer().getUuid());
        });

        // === S2-03: BLOCK STATE PACKET RECEIVER ===
        ServerPlayNetworking.registerGlobalReceiver(new Identifier("shinobicore", "block_state"), (server, player, handler, buf, sender) -> {
            // CRITICAL: Read buf BEFORE server.execute()!
            boolean blocking = buf.readBoolean();
            server.execute(() -> {
                ICombatComponent combat = NinjaComponents.getCombat(player);
                if (combat != null) {
                    combat.setBlocking(blocking);
                }
            });
        });

        ShinobiCore.LOGGER.info("Combat system bootstrapped (Sprint 2)");
    }

    private static void onMeleeHit(ServerPlayerEntity player, Entity target) {
        IStatsComponent stats = NinjaComponents.getStats(player);
        ICombatComponent combat = NinjaComponents.getCombat(player);
        IChakraComponent chakra = NinjaComponents.getChakra(player);
        if (stats == null || combat == null || chakra == null) {
            return;
        }
        combat.incrementCombo();
        combat.setLastAttackMs(player.getWorld().getTime());
        float mult = NinjaFormula.getMeleeMultiplier(stats, combat, chakra);
        boolean katana = player.getMainHandStack().isOf(ModItems.KATANA);
        float extra = 4.0f * Math.max(0.0f, mult - 1.0f);
        if (katana) {
            extra *= 1.5f;
        }
        if (extra > 0.01f && target instanceof LivingEntity le) {
            le.damage(player.getDamageSources().magic(), extra);
        }
    }
}
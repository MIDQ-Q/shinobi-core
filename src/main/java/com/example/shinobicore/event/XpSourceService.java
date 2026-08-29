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
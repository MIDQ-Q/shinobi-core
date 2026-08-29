package com.example.shinobicore.parkour;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.stat.component.IParkourComponent;
import com.example.shinobicore.stat.component.NinjaComponents;
import net.fabricmc.fabric.api.entity.event.v1.ServerLivingEntityEvents;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.minecraft.server.network.ServerPlayerEntity;

public class ParkourBootstrap {
    public static void init() {
        // I-Frames: Cancel damage if player is dodging
        ServerLivingEntityEvents.ALLOW_DAMAGE.register((entity, source, amount) -> {
            if (entity instanceof ServerPlayerEntity player) {
                IParkourComponent parkour = NinjaComponents.getParkour(player);
                if (parkour != null && parkour.hasIframes()) {
                    // Allow fall damage so chakra mode isn't completely invincible to pits
                    if (source.getName().equals("fall")) return true; 
                    return false; // I-Frames active!
                }
            }
            return true;
        });

        // Tick handler for cooldowns and pose resets
        ServerTickEvents.END_SERVER_TICK.register(server -> {
            for (ServerPlayerEntity p : server.getPlayerManager().getPlayerList()) {
                ParkourServerHandler.tick(p);
            }
        });

        ShinobiCore.LOGGER.info("ParkourBootstrap initialized (I-Frames & Ticks)");
    }
}
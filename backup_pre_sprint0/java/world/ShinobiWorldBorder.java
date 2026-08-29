package com.example.shinobicore.world;

import com.example.shinobicore.ShinobiCore;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerLifecycleEvents;
import net.minecraft.server.MinecraftServer;
import net.minecraft.world.border.WorldBorder;

/**
 * World boundary via the VANILLA WorldBorder (square).
 * Engine-enforced: blocks players AND all entities, shows the
 * red wall, and costs us zero per-tick code.
 *
 * Size = 48000 (the larger map side). The map becomes a 48000x48000
 * square; the ~32000x16000 continent sits centered with ocean margin,
 * and the extra Z range is simply more ocean.
 *
 * HLD Section 9 (World).
 */
public final class ShinobiWorldBorder {

    public static final double SQUARE_SIZE = 48000.0;

    private ShinobiWorldBorder() {}

    public static void init() {
        ServerLifecycleEvents.SERVER_STARTED.register(ShinobiWorldBorder::apply);
        ShinobiCore.LOGGER.info("ShinobiWorldBorder initialized (vanilla square " + (int) SQUARE_SIZE + ")");
    }

    private static void apply(MinecraftServer server) {
        WorldBorder border = server.getOverworld().getWorldBorder();
        border.setCenter(0.0, 0.0);
        border.setSize(SQUARE_SIZE);
        border.setSafeZone(5.0);      // safe distance before damage/push
        border.setWarningBlocks(32);  // visual warning distance (blocks)
    }
}
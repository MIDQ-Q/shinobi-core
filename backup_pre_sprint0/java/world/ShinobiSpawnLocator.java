package com.example.shinobicore.world;

import com.example.shinobicore.ShinobiCore;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerLifecycleEvents;
import net.minecraft.registry.RegistryKeys;
import net.minecraft.registry.tag.TagKey;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.Heightmap;
import net.minecraft.world.gen.structure.Structure;

/**
 * Sets the world spawn point at the nearest village so the player
 * starts inside a settlement instead of random wilderness.
 *
 * Uses ServerWorld.locateStructure() with vanilla tag #minecraft:village.
 * In Yarn 1.20.1, locateStructure returns BlockPos (nullable).
 *
 * HLD Section 9 (World).
 */
public final class ShinobiSpawnLocator {

    private ShinobiSpawnLocator() {}

    public static void init() {
        ServerLifecycleEvents.SERVER_STARTED.register(ShinobiSpawnLocator::apply);
        ShinobiCore.LOGGER.info("ShinobiSpawnLocator initialized (spawn at village)");
    }

    private static void apply(MinecraftServer server) {
        try {
            ServerWorld overworld = server.getOverworld();

            TagKey<Structure> villageTag = TagKey.of(
                RegistryKeys.STRUCTURE,
                new Identifier("minecraft", "village"));

            BlockPos found = overworld.locateStructure(
                villageTag, BlockPos.ORIGIN, 2000, false);

            if (found != null) {
                int y = overworld.getTopY(Heightmap.Type.MOTION_BLOCKING, found.getX(), found.getZ());
                overworld.setSpawnPos(new BlockPos(found.getX(), y + 1, found.getZ()), 90.0f);
                ShinobiCore.LOGGER.info("ShinobiSpawnLocator: world spawn set to village at {}, {}",
                    found.getX(), found.getZ());
            } else {
                ShinobiCore.LOGGER.warn("ShinobiSpawnLocator: no village found within 2000 blocks");
            }
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("ShinobiSpawnLocator failed: {}", e.getMessage());
        }
    }
}
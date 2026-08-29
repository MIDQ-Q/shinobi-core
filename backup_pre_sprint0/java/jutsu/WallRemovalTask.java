package com.example.shinobicore.jutsu;

import com.example.shinobicore.ShinobiCore;
import net.minecraft.block.Blocks;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.BlockPos;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

public class WallRemovalTask {
    // === ИСПРАВЛЕНО: String ключ вместо UUID ===
    private static final Map<String, List<PendingWall>> pendingWalls = new ConcurrentHashMap<>();

    public static void schedule(ServerWorld world, List<BlockPos> blocks, int lifetimeTicks) {
        // Используем registry key как строковый ключ
        String worldId = world.getRegistryKey().getValue().toString();
        pendingWalls.computeIfAbsent(worldId, k -> new ArrayList<>())
                .add(new PendingWall(blocks, lifetimeTicks));
    }

    // Вызывается из NinjaTickHandler каждую секунду (20 тиков)
    public static void tick(ServerWorld world) {
        String worldId = world.getRegistryKey().getValue().toString();
        List<PendingWall> walls = pendingWalls.get(worldId);
        if (walls == null || walls.isEmpty()) return;

        List<PendingWall> toRemove = new ArrayList<>();
        for (PendingWall wall : walls) {
            wall.ticksRemaining -= 20; // Вычитаем 20 тиков (1 секунду)
            if (wall.ticksRemaining <= 0) {
                // Удаляем стену
                for (BlockPos pos : wall.blocks) {
                    if (world.isChunkLoaded(pos)) {
                        world.setBlockState(pos, Blocks.AIR.getDefaultState(), 3);
                    }
                }
                toRemove.add(wall);
                ShinobiCore.LOGGER.debug("[Wall] Removed wall with {} blocks", wall.blocks.size());
            }
        }
        walls.removeAll(toRemove);
    }

    private static class PendingWall {
        final List<BlockPos> blocks;
        int ticksRemaining;

        PendingWall(List<BlockPos> blocks, int lifetimeTicks) {
            this.blocks = new ArrayList<>(blocks);
            this.ticksRemaining = lifetimeTicks;
        }
    }
}
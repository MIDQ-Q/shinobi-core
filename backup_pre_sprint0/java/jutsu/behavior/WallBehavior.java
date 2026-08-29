package com.example.shinobicore.jutsu.behavior;
import com.example.shinobicore.progression.JutsuCastNotifier;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.jutsu.data.JutsuDefinition;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.block.Block;
import net.minecraft.block.BlockState;
import net.minecraft.registry.Registries;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.Identifier;
import net.minecraft.util.JsonHelper;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;

import java.util.ArrayList;
import java.util.List;

/**
 * Builds a temporary wall in front of the player.
 * Blocks are restored after duration via TickScheduler.
 * HLD: Section 2.2
 */
public class WallBehavior implements JutsuBehavior {

    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, JsonObject params, float damage) {
        JutsuCastNotifier.fire(player, "wall", "chakraControl");

        int width = JsonHelper.getInt(params, "width", 5);
        int height = JsonHelper.getInt(params, "height", 3);
        int duration = JsonHelper.getInt(params, "duration", 200);
        String blockId = JsonHelper.getString(params, "block", "minecraft:stone");

        Block block = Registries.BLOCK.get(new Identifier(blockId));
        if (block == null) {
            ShinobiCore.LOGGER.warn("[WARN] WallBehavior unknown block: {}", blockId);
            return;
        }
        BlockState state = block.getDefaultState();

        Vec3d look = player.getRotationVector();
        Vec3d dir = new Vec3d(look.x, 0.0, look.z);
        if (dir.lengthSquared() < 0.001) {
            dir = new Vec3d(0.0, 0.0, 1.0);
        }
        dir = dir.normalize();
        Vec3d side = new Vec3d(-dir.z, 0.0, dir.x);

        BlockPos base = player.getBlockPos().add(
            (int) Math.round(dir.x * 2.0), 0, (int) Math.round(dir.z * 2.0)
        );

        List<BlockPos> placed = new ArrayList<>();
        List<BlockState> previous = new ArrayList<>();

        int half = width / 2;
        for (int w = -half; w <= half; w++) {
            for (int h = 0; h < height; h++) {
                BlockPos pos = base.add(
                    (int) Math.round(side.x * w), h, (int) Math.round(side.z * w)
                );
                BlockState old = player.getWorld().getBlockState(pos);
                if (!old.isAir()) {
                    continue;
                }
                player.getWorld().setBlockState(pos, state);
                placed.add(pos);
                previous.add(old);
            }
        }

        if (placed.isEmpty()) {
            return;
        }

        TickScheduler.schedule(duration, () -> {
            for (int i = 0; i < placed.size(); i++) {
                BlockPos pos = placed.get(i);
                if (player.getWorld().isChunkLoaded(pos)) {
                    player.getWorld().setBlockState(pos, previous.get(i));
                }
            }
        });
    }
}
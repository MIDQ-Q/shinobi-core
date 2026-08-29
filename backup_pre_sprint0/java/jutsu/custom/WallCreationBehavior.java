package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.jutsu.WallRemovalTask;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.block.Blocks;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;
import java.util.ArrayList;
import java.util.List;

public class WallCreationBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float range = params.has("range") ? params.get("range").getAsFloat() : 6f;
        int width = params.has("width") ? params.get("width").getAsInt() : 5;
        int height = params.has("height") ? params.get("height").getAsInt() : 3;
        int lifetime = params.has("lifetime") ? params.get("lifetime").getAsInt() : 100;
        String blockType = params.has("blockType") ? params.get("blockType").getAsString() : "water";
        Vec3d center = player.getPos().add(player.getRotationVector().multiply(range));
        BlockPos c = BlockPos.ofFloored(center);
        List<BlockPos> placed = new ArrayList<>();
        float yaw = player.getYaw() * ((float)Math.PI / 180f);
        float rightX = (float)Math.cos(yaw + Math.PI/2);
        float rightZ = (float)Math.sin(yaw + Math.PI/2);
        for (int dx = -width/2; dx <= width/2; dx++) {
            for (int dy = 0; dy < height; dy++) {
                BlockPos p = c.add((int)(rightX * dx), dy, (int)(rightZ * dx));
                if (world.getBlockState(p).isAir()) {
                    if (blockType.equals("water")) world.setBlockState(p, Blocks.WATER.getDefaultState(), 3);
                    else if (blockType.equals("ice")) world.setBlockState(p, Blocks.ICE.getDefaultState(), 3);
                    else if (blockType.equals("dirt")) world.setBlockState(p, Blocks.DIRT.getDefaultState(), 3);
                    else if (blockType.equals("iron")) world.setBlockState(p, Blocks.IRON_BLOCK.getDefaultState(), 3);
                    else if (blockType.equals("stone")) world.setBlockState(p, Blocks.STONE.getDefaultState(), 3);
                    placed.add(p);
                }
            }
        }
        if (!placed.isEmpty()) WallRemovalTask.schedule(world, placed, lifetime);
        JutsuLogger.logBehavior("wall_creation", "placed=" + placed.size());
    }
}
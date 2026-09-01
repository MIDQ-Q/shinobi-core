package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.jutsu.WallRemovalTask;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.block.Blocks;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import java.util.ArrayList;
import java.util.List;

public class RunningFireBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float distance = params.has("distance") ? params.get("distance").getAsFloat() : 8f;
        Vec3d start = player.getPos();
        Vec3d dir = player.getRotationVector().multiply(0.5);
        List<BlockPos> fireBlocks = new ArrayList<>();
        int steps = (int)(distance / 0.5);
        for (int i = 0; i < steps; i++) {
            final int step = i;
            TickScheduler.schedule(world, i * 2, 2, 1, w -> {
                Vec3d pos = start.add(dir.multiply(step));
                BlockPos bp = BlockPos.ofFloored(pos);
                if (w.getBlockState(bp).isAir()) {
                    w.setBlockState(bp, Blocks.FIRE.getDefaultState(), 3);
                    fireBlocks.add(bp);
                }
                for (LivingEntity e : w.getEntitiesByClass(LivingEntity.class, new Box(bp, bp).expand(1), t -> t != player && t.isAlive())) {
                    e.setOnFireFor(3);
                    e.damage(player.getDamageSources().inFire(), damage * 0.3f);
                }
            });
        }
        TickScheduler.schedule(world, steps * 2 + 200, 200, 1, w -> {
            for (BlockPos bp : fireBlocks) {
                if (w.getBlockState(bp).isOf(Blocks.FIRE)) w.removeBlock(bp, false);
            }
        });
        JutsuLogger.logBehavior("running_fire", "distance=" + distance);
    }
}
package com.example.shinobicore.ai.v2;

import net.minecraft.entity.mob.MobEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.RaycastContext;

public class AiEnvironmentScanner {
    
    public static Vec3d findCover(ServerWorld world, MobEntity entity, ServerPlayerEntity target) {
        Vec3d entityPos = entity.getPos();
        Vec3d targetPos = target.getPos();
        
        for (int i = 0; i < 8; i++) {
            double angle = i * Math.PI / 4;
            double dist = 5.0;
            Vec3d checkPos = entityPos.add(Math.cos(angle) * dist, 0, Math.sin(angle) * dist);
            
            if (hasLineOfSight(world, entity, checkPos.add(0, 1, 0), targetPos.add(0, 1, 0))) {
                continue; 
            }
            
            BlockPos blockPos = BlockPos.ofFloored(checkPos);
            if (world.getBlockState(blockPos).isSolidBlock(world, blockPos) || 
                world.getBlockState(blockPos.up()).isSolidBlock(world, blockPos.up())) {
                return checkPos;
            }
        }
        return null;
    }

    public static boolean hasLineOfSight(ServerWorld world, MobEntity entity, Vec3d from, Vec3d to) {
        RaycastContext context = new RaycastContext(from, to, 
            RaycastContext.ShapeType.COLLIDER, RaycastContext.FluidHandling.NONE, entity);
        return world.raycast(context).getType() == net.minecraft.util.hit.HitResult.Type.MISS;
    }
}
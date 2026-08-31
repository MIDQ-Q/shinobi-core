package com.example.shinobicore.modules.movement.client.util;

import com.example.shinobicore.core.log.ShinobiLogger;
import net.minecraft.block.BlockState;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.hit.BlockHitResult;
import net.minecraft.util.hit.HitResult;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.RaycastContext;
import net.minecraft.world.World;

public final class WallDetector {
    private WallDetector() {}

    public static Vec3d getWallNormal(ClientPlayerEntity player) {
        if (player == null) {
            return null;
        }
        World world = player.getWorld();
        if (world == null || world.isClient() == false) {
            return null;
        }

        Vec3d feet = player.getPos().add(0, 0.2, 0);
        Vec3d body = player.getPos().add(0, 1.0, 0);

        Vec3d[] dirs = {
            new Vec3d(1, 0, 0), new Vec3d(-1, 0, 0),
            new Vec3d(0, 0, 1), new Vec3d(0, 0, -1)
        };

        for (Vec3d dir : dirs) {
            if (hitsWall(world, feet, dir, player) && hitsWall(world, body, dir, player)) {
                return dir.negate();
            }
        }
        return null;
    }

    private static boolean hitsWall(World world, Vec3d origin, Vec3d dir, ClientPlayerEntity player) {
        if (world == null || origin == null || dir == null || player == null) {
            return false;
        }
        Vec3d target = origin.add(dir.multiply(0.6));
        try {
            RaycastContext ctx = new RaycastContext(
                origin, target,
                RaycastContext.ShapeType.COLLIDER,
                RaycastContext.FluidHandling.NONE,
                player
            );
            BlockHitResult result = world.raycast(ctx);
            if (result == null) return false;
            if (result.getType() != HitResult.Type.BLOCK) return false;
            BlockPos bp = result.getBlockPos();
            BlockState state = world.getBlockState(bp);
            return state != null && !state.isAir() && state.blocksMovement();
        } catch (Throwable t) {
            return false;
        }
    }
}
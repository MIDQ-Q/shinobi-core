package com.example.shinobicore.client.parkour.util;

import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.hit.BlockHitResult;
import net.minecraft.util.hit.HitResult;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.RaycastContext;
import net.minecraft.world.World;

public class WallDetector {

    public static Vec3d getWallNormal(ClientPlayerEntity player) {
        World world = player.getWorld();
        Vec3d eye = player.getEyePos();
        int[][] dirs = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}};

        for (int[] d : dirs) {
            Vec3d dir = new Vec3d(d[0], 0, d[1]).normalize();
            Vec3d end = eye.add(dir.multiply(0.4));

            BlockHitResult hit = world.raycast(new RaycastContext(
                eye, end,
                RaycastContext.ShapeType.OUTLINE,
                RaycastContext.FluidHandling.NONE,
                player
            ));

            if (hit.getType() == HitResult.Type.BLOCK) {
                BlockPos pos = hit.getBlockPos();
                if (world.getBlockState(pos).isSolidBlock(world, pos)) {
                    return new Vec3d(-d[0], 0, -d[1]).normalize();
                }
            }
        }
        return null;
    }

    public static boolean isNearWall(ClientPlayerEntity player) {
        return getWallNormal(player) != null;
    }

    public static BlockPos getLedgeAbove(ClientPlayerEntity player) {
        World world = player.getWorld();
        BlockPos head = player.getBlockPos().up();
        int[][] dirs = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}};

        for (int[] d : dirs) {
            BlockPos wallPos = head.add(d[0], 0, d[1]);
            BlockPos aboveWall = wallPos.up();

            boolean wallSolid = world.getBlockState(wallPos).isSolidBlock(world, wallPos);
            boolean aboveWallEmpty = !world.getBlockState(aboveWall).isSolidBlock(world, aboveWall);
            boolean headEmpty = !world.getBlockState(head).isSolidBlock(world, head);

            if (wallSolid && aboveWallEmpty && headEmpty) {
                return aboveWall;
            }
        }
        return null;
    }
}
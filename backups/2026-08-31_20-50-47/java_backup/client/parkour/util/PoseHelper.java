package com.example.shinobicore.client.parkour.util;

import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.entity.EntityPose;
import net.minecraft.util.math.Box;
import net.minecraft.world.World;

public class PoseHelper {

    public static boolean cannotStand(ClientPlayerEntity player) {
        World w = player.getWorld();
        Box current = player.getBoundingBox();
        Box standingBox = new Box(
            current.minX, current.minY, current.minZ,
            current.maxX, current.minY + 1.8, current.maxZ
        ).contract(0.05, 0, 0.05);
        return w.getBlockCollisions(player, standingBox).iterator().hasNext();
    }

    public static void forceLowPose(ClientPlayerEntity player) {
        if (player.getPose() != EntityPose.SWIMMING) {
            player.setPose(EntityPose.SWIMMING);
            player.calculateDimensions();
        }
    }

    public static void releasePose(ClientPlayerEntity player) {
        if (player.getPose() == EntityPose.SWIMMING && !cannotStand(player)) {
            player.setPose(EntityPose.STANDING);
            player.calculateDimensions();
        }
    }
}
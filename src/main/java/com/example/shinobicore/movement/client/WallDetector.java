// SHINOBICORE:SPRINT6:FILE
package com.example.shinobicore.movement.client;

import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.hit.BlockHitResult;
import net.minecraft.util.hit.HitResult;
import net.minecraft.util.math.Direction;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.RaycastContext;

/**
 * SPRINT 6 wall detector.
 *
 * Checks four horizontal directions at two heights.
 * Returns wall normal pointing AWAY from the wall.
 */
public final class WallDetector {
    public static final double WALL_REACH = 0.75;

    private static final int[][] DIRS = {
            {1, 0},
            {-1, 0},
            {0, 1},
            {0, -1}
    };

    private WallDetector() {}

    public static Vec3d detectWallNormal(ClientPlayerEntity player) {
        if (player == null || player.getWorld() == null) {
            return null;
        }

        Vec3d preferred = getPreferredDirection(player);

        Vec3d feet = player.getPos().add(0.0, 0.5, 0.0);
        Vec3d body = player.getPos().add(0.0, 1.2, 0.0);

        Vec3d bestNormal = null;
        double bestScore = -999.0;

        for (int[] d : DIRS) {
            Vec3d dir = new Vec3d(d[0], 0.0, d[1]);

            boolean hit = checkAt(player, feet, dir)
                    || checkAt(player, body, dir);

            if (!hit) {
                continue;
            }

            // Normal points away from wall, toward player.
            Vec3d normal = dir.multiply(-1.0);

            double score = 0.0;

            if (preferred != null) {
                score += preferred.dotProduct(dir);
            }

            if (player.horizontalCollision) {
                score += 0.1;
            }

            if (score > bestScore) {
                bestScore = score;
                bestNormal = normal;
            }
        }

        return bestNormal;
    }

    public static boolean isMovingTowardWall(ClientPlayerEntity player, Vec3d wallNormal) {
        if (wallNormal == null) {
            return false;
        }

        Vec3d velocity = player.getVelocity();
        double dot = velocity.x * wallNormal.x + velocity.z * wallNormal.z;

        // Normal points away from wall.
        // Moving toward wall means negative dot.
        return dot < -0.02 || player.horizontalCollision;
    }

    private static Vec3d getPreferredDirection(ClientPlayerEntity player) {
        Direction movementDir = player.getMovementDirection();

        if (movementDir == null) {
            return null;
        }

        Vec3d direction = new Vec3d(
                movementDir.getOffsetX(),
                0.0,
                movementDir.getOffsetZ()
        );

        if (direction.lengthSquared() < 1.0E-6) {
            return null;
        }

        return direction.normalize();
    }

    private static boolean checkAt(ClientPlayerEntity player, Vec3d start, Vec3d dir) {
        Vec3d end = start.add(dir.multiply(WALL_REACH));

        BlockHitResult hit = player.getWorld().raycast(new RaycastContext(
                start,
                end,
                RaycastContext.ShapeType.COLLIDER,
                RaycastContext.FluidHandling.NONE,
                player
        ));

        if (hit == null || hit.getType() != HitResult.Type.BLOCK) {
            return false;
        }

        Vec3d sideNormal = new Vec3d(
                hit.getSide().getOffsetX(),
                hit.getSide().getOffsetY(),
                hit.getSide().getOffsetZ()
        );

        // Only vertical walls.
        return Math.abs(sideNormal.y) <= 0.01;
    }
}
// SHINOBICORE:SPRINT5-FIX:FILE
package com.example.shinobicore.movement.client;

import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.hit.BlockHitResult;
import net.minecraft.util.hit.HitResult;
import net.minecraft.util.math.Direction;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.RaycastContext;

/**
 * SPRINT 5 wall detector.
 * Performs a short horizontal raycast in the player's movement direction.
 *
 * FIX: In Yarn 1.20.1, Entity.getMovementDirection() returns Direction,
 * not Vec3d. We convert it manually.
 */
public final class WallDetector {
    public static final double WALL_REACH = 0.7;

    private WallDetector() {}

    public static Vec3d detectWallNormal(ClientPlayerEntity player) {
        if (player == null || player.getWorld() == null) {
            return null;
        }

        Direction movementDir = player.getMovementDirection();
        if (movementDir == null) {
            return null;
        }

        // Convert Direction to horizontal Vec3d
        Vec3d look = new Vec3d(
                movementDir.getOffsetX(),
                0.0,
                movementDir.getOffsetZ()
        );

        if (look.lengthSquared() < 1.0E-6) {
            return null;
        }

        look = look.normalize();

        Vec3d start = player.getPos().add(0.0, 0.25, 0.0);
        Vec3d end = start.add(look.multiply(WALL_REACH));

        BlockHitResult hit = player.getWorld().raycast(new RaycastContext(
                start,
                end,
                RaycastContext.ShapeType.COLLIDER,
                RaycastContext.FluidHandling.NONE,
                player
        ));

        if (hit == null || hit.getType() != HitResult.Type.BLOCK) {
            return null;
        }

        Vec3d normal = new Vec3d(
                hit.getSide().getOffsetX(),
                hit.getSide().getOffsetY(),
                hit.getSide().getOffsetZ()
        );

        // Ignore floors/ceilings; only vertical wall surfaces.
        if (Math.abs(normal.y) > 0.01) {
            return null;
        }

        return normal;
    }
}
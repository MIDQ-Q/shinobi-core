package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.movement.common.ClientMovementState;
import com.example.shinobicore.movement.common.MovementPhase;
import com.example.shinobicore.movement.common.MovementInputService;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;
import net.minecraft.util.math.Direction;
import net.minecraft.block.BlockState;

public final class WallRunClient {
    private static boolean active = false;
    private static int ticksOnWall = 0;
    private static int cooldown = 0;
    private static Vec3d cachedWallNormal = null;
    
    public static boolean isActive() { return active; }
    
    public static void tick(ClientPlayerEntity player) {
        if (cooldown > 0) cooldown--;
        ClientMovementState.tickWallCooldown();
        if (!FeatureFlags.wallRun) { stop(player); return; }
        
        boolean chakra = ClientNinjaState.chakraMode && ClientNinjaState.currentChakra > 0;
        
        if (active) {
            ticksOnWall++;
            
            // Re-verify wall presence
            Vec3d normal = detectWallNormal(player);
            if (normal == null || player.isOnGround() || ticksOnWall > 40 || !player.input.pressingForward) {
                stop(player);
                return;
            }
            
            cachedWallNormal = normal;
            ClientMovementState.setWallNormal(normal);
            
            Vec3d v = player.getVelocity();
            // Reduced gravity while wall running (Ver 1 style)
            if (v.y < 0.0) {
                player.setVelocity(v.x, Math.max(v.y, -0.02), v.z);
                player.velocityModified = true;
            }
            player.fallDistance = 0;
            
            // Wall Jump (Ver 1 style)
            if (MovementInputService.wasJumpPressed()) {
                player.addVelocity(normal.x * 0.6, 0.45, normal.z * 0.6);
                player.velocityModified = true;
                ClientMovementState.resetAirJumps();
                stop(player);
                cooldown = 8;
                ClientMovementState.setWallCooldownTicks(8);
            }
            return;
        }
        
        // Entry conditions
        if (cooldown > 0 || player.isOnGround() || !chakra || !player.input.pressingForward) return;
        
        // Use vanilla horizontalCollision + block check
        if (player.horizontalCollision) {
            Vec3d horiz = new Vec3d(player.getVelocity().x, 0, player.getVelocity().z);
            if (horiz.length() >= 0.15) {
                Vec3d normal = detectWallNormal(player);
                if (normal != null) {
                    active = true;
                    ticksOnWall = 0;
                    cachedWallNormal = normal;
                    ClientMovementState.setPhase(MovementPhase.WALL_RUNNING);
                    ClientMovementState.setWallNormal(normal);
                }
            }
        }
    }
    
    // Inline wall normal detection - no external WallDetector needed
    private static Vec3d detectWallNormal(ClientPlayerEntity player) {
        BlockPos playerPos = player.getBlockPos();
        
        // Check 4 cardinal directions for solid blocks
        Direction[] dirs = { Direction.NORTH, Direction.SOUTH, Direction.EAST, Direction.WEST };
        for (Direction dir : dirs) {
            BlockPos checkPos = playerPos.offset(dir);
            BlockState state = player.getWorld().getBlockState(checkPos);
            if (state.isSolidBlock(player.getWorld(), checkPos)) {
                // Also check block at head level
                BlockPos headCheck = checkPos.up();
                BlockState headState = player.getWorld().getBlockState(headCheck);
                if (headState.isSolidBlock(player.getWorld(), headCheck) || headState.isAir()) {
                    return new Vec3d(dir.getOpposite().getOffsetX(), 0, dir.getOpposite().getOffsetZ());
                }
            }
        }
        return null;
    }
    
    private static void stop(ClientPlayerEntity player) {
        active = false;
        ticksOnWall = 0;
        cachedWallNormal = null;
        ClientMovementState.setWallNormal(null);
        if (ClientMovementState.getPhase() == MovementPhase.WALL_RUNNING) {
            ClientMovementState.setPhase(MovementPhase.NORMAL);
        }
    }
}
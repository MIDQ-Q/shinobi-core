package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.common.ClientMovementState;
import com.example.shinobicore.movement.common.MovementPhase;
import com.example.shinobicore.movement.common.MovementInputService;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;
import net.minecraft.block.BlockState;
import net.minecraft.util.math.Direction;

public final class EdgeGrabClient {
    private static boolean active = false;
    private static int ticksOnEdge = 0;
    private static int cooldown = 0;
    private static BlockPos ledgePos = null;
    
    public static boolean isActive() { return active; }
    
    public static void tick(ClientPlayerEntity player) {
        if (cooldown > 0) cooldown--;
        if (!FeatureFlags.edgeGrab) { stop(player); return; }
        
        if (active) {
            ticksOnEdge++;
            player.setVelocity(0, 0, 0);
            player.velocityModified = true;
            player.fallDistance = 0;
            
            if (MovementInputService.isMovingForward(player) || MovementInputService.wasJumpPressed()) {
                // Smooth climb
                player.addVelocity(0, 0.15, 0);
                if (ledgePos != null) {
                    player.setPosition(player.getX(), ledgePos.getY() + 0.001, player.getZ());
                }
                player.velocityModified = true;
                player.setOnGround(true);
                stop(player);
                return;
            }
            
            if (MovementInputService.isSneaking(player) || ticksOnEdge > 40) {
                stop(player);
                return;
            }
            return;
        }
        
        if (cooldown > 0 || player.isOnGround() || player.getVelocity().y > -0.1) return;
        
        // Simple inline ledge detection
        BlockPos playerPos = player.getBlockPos();
        Direction facing = Direction.fromRotation(player.getYaw());
        
        BlockPos wallPos = playerPos.offset(facing);
        BlockPos aboveWall = wallPos.up();
        BlockPos abovePlayer = playerPos.up();
        
        BlockState wallState = player.getWorld().getBlockState(wallPos);
        BlockState aboveWallState = player.getWorld().getBlockState(aboveWall);
        BlockState abovePlayerState = player.getWorld().getBlockState(abovePlayer);
        
        if (wallState.isSolidBlock(player.getWorld(), wallPos) && 
            aboveWallState.isAir() && 
            abovePlayerState.isAir()) {
            
            active = true;
            ticksOnEdge = 0;
            ledgePos = aboveWall;
            ClientMovementState.setPhase(MovementPhase.EDGE_GRABBING);
        }
    }
    
    private static void stop(ClientPlayerEntity player) {
        active = false;
        ticksOnEdge = 0;
        ledgePos = null;
        cooldown = 20;
        if (ClientMovementState.getPhase() == MovementPhase.EDGE_GRABBING) {
            ClientMovementState.setPhase(MovementPhase.NORMAL);
        }
    }
}
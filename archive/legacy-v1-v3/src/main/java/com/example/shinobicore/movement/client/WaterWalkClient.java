package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.movement.common.ClientMovementState;
import com.example.shinobicore.movement.common.MovementPhase;
import com.example.shinobicore.movement.common.MovementInputService;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;
import net.minecraft.fluid.FluidState;
import net.minecraft.registry.tag.FluidTags;
import net.minecraft.util.math.BlockPos;

public final class WaterWalkClient {
    private static boolean active = false;
    
    public static boolean isActive() { return active; }
    
    public static void tick(ClientPlayerEntity player) {
        if (!FeatureFlags.waterWalk) { stop(player); return; }
        
        boolean chakraMode = ClientNinjaState.chakraMode;
        boolean hasChakra = ClientNinjaState.currentChakra > 0; // Adjust to your Chakra API
        
        if (!chakraMode || !hasChakra || player.isTouchingWater() || player.isSneaking()) {
            if (active) stop(player);
            return;
        }
        
        BlockPos feet = player.getBlockPos().down();
        FluidState fs = player.getWorld().getFluidState(feet);
        boolean onWaterSurface = fs.isIn(FluidTags.WATER) && player.getY() >= feet.getY() + 0.8;
        
        if (onWaterSurface) {
            if (!active) {
                active = true;
                ClientMovementState.setPhase(MovementPhase.WATER_WALKING);
                ClientMovementState.setOnWater(true);
                ClientMovementState.resetAirJumps();
            }
            
            Vec3d v = player.getVelocity();
            if (v.y < 0.0) {
                player.setVelocity(v.x, 0.0, v.z);
                player.velocityModified = true;
            }
            player.fallDistance = 0.0f;
            
            // Jump from water
            if (MovementInputService.wasJumpPressed()) {
                player.setVelocity(v.x, 0.42, v.z);
                player.velocityModified = true;
                stop(player);
            }
        } else {
            if (active) stop(player);
        }
    }
    
    private static void stop(ClientPlayerEntity player) {
        active = false;
        ClientMovementState.setOnWater(false);
        if (ClientMovementState.getPhase() == MovementPhase.WATER_WALKING) {
            ClientMovementState.setPhase(MovementPhase.NORMAL);
        }
    }
}
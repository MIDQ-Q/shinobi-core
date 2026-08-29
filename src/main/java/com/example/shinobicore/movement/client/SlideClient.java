package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.movement.common.ClientMovementState;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.entity.EntityPose;
import net.minecraft.util.math.Vec3d;

public final class SlideClient {
    private static boolean active = false;
    private static int ticks = 0;
    
    public static boolean isActive() { return active; }
    
    public static void tick(ClientPlayerEntity player) {
        if (!FeatureFlags.slide) { stop(player); return; }
        
        if (active) {
            ticks++;
            int maxTicks = ClientNinjaState.chakraMode ? 25 : 15;
            if (ticks > maxTicks || !player.isOnGround() || MovementInputService.wasJumpPressed()) {
                stop(player);
                return;
            }
            player.setPose(EntityPose.SWIMMING);
            return;
        }
        
        if (player.isOnGround() && player.isSprinting() && MovementInputService.isSneaking(player) && !CrawlClient.isActive()) {
            active = true;
            ticks = 0;
            ClientMovementState.setPhase(MovementPhase.SLIDING);
            
            float rad = (float)Math.toRadians(player.getYaw());
            float boost = ClientNinjaState.chakraMode ? 0.81f : 0.45f;
            
            Vec3d v = player.getVelocity();
            player.setVelocity(v.x + (-Math.sin(rad) * boost), 0.0, v.z + (Math.cos(rad) * boost));
            player.velocityModified = true;
        }
    }
    
    private static void stop(ClientPlayerEntity player) {
        active = false;
        ticks = 0;
        if (player != null && !CrawlClient.isActive()) player.setPose(EntityPose.STANDING);
        if (ClientMovementState.getPhase() == MovementPhase.SLIDING) {
            ClientMovementState.setPhase(MovementPhase.NORMAL);
        }
    }
}
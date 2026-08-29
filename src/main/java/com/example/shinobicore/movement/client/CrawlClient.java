package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.common.ClientMovementState;
import com.example.shinobicore.movement.common.MovementPhase;
import com.example.shinobicore.movement.common.MovementInputService;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.entity.EntityPose;

public final class CrawlClient {
    private static boolean active = false;
    private static long lastShiftTime = 0;
    
    public static boolean isActive() { return active; }
    
    public static void tick(ClientPlayerEntity player) {
        if (!FeatureFlags.crawl) { stop(player); return; }
        
        boolean shift = MovementInputService.isSneaking(player);
        long now = System.currentTimeMillis();
        
        if (shift && (now - lastShiftTime) < 250) {
            toggle(player);
            lastShiftTime = 0;
        } else if (shift) {
            lastShiftTime = now;
        }
        
        if (active) {
            player.setPose(EntityPose.SWIMMING);
            if (!player.isOnGround()) stop(player);
        }
    }
    
    private static void toggle(ClientPlayerEntity player) {
        if (active) {
            if (player.getWorld().isSpaceEmpty(player, player.getBoundingBox().expand(0, 0.9, 0))) {
                stop(player);
            }
        } else {
            if (player.isOnGround()) {
                active = true;
                ClientMovementState.setPhase(MovementPhase.CRAWLING);
            }
        }
    }
    
    private static void stop(ClientPlayerEntity player) {
        active = false;
        if (player != null) player.setPose(EntityPose.STANDING);
        if (ClientMovementState.getPhase() == MovementPhase.CRAWLING) {
            ClientMovementState.setPhase(MovementPhase.NORMAL);
        }
    }
}
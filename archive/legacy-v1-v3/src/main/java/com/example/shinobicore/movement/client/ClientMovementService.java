package com.example.shinobicore.movement.client;

import com.example.shinobicore.movement.common.ClientMovementState;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;

public final class ClientMovementService {
    public static void tick(MinecraftClient client) {
        ClientPlayerEntity player = client.player;
        if (player == null) return;
        
        ClientMovementState.tickIframes();
        MovementInputService.update(player);
        
        // Input
        RollDodgeInputHandler.tick(player);
        
        // Environment
        WaterWalkClient.tick(player);
        WallRunClient.tick(player);
        EdgeGrabClient.tick(player);
        
        // Jumps
        ChargedJumpClient.tick(player);
        DoubleJumpClient.tick(player);
        
        // Actions
        DodgeClient.tick(player);
        SlideClient.tick(player);
        CrawlClient.tick(player);
        MeditationClient.tick(player);
        
        // Fallback Phase Reset
        if (!WaterWalkClient.isActive() && !WallRunClient.isActive() && 
            !EdgeGrabClient.isActive() && !ChargedJumpClient.isCharging() && 
            !DodgeClient.isActive() && !SlideClient.isActive() && 
            !CrawlClient.isActive() && !MeditationClient.isActive()) {
            if (ClientMovementState.getPhase() != MovementPhase.NORMAL) {
                ClientMovementState.setPhase(MovementPhase.NORMAL);
            }
        }
    }
}
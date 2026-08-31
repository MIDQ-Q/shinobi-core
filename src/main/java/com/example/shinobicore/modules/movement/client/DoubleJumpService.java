package com.example.shinobicore.modules.movement.client;

import com.example.shinobicore.modules.movement.common.MovementActions;
import com.example.shinobicore.modules.movement.common.events.DoubleJumpedEvent;
import com.example.shinobicore.modules.movement.config.MovementConfig;
import com.example.shinobicore.modules.movement.network.MovementPackets;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

public final class DoubleJumpService {
    private DoubleJumpService() {}

    public static void tryJump(ClientPlayerEntity player) {
        int charges = ClientMovementState.getDoubleJumpCharges();
        if (charges <= 0) return;
        
        ClientMovementState.setDoubleJumpCharges(charges - 1);
        
        Vec3d vel = player.getVelocity();
        player.setVelocity(vel.x, MovementConfig.DOUBLE_JUMP_BOOST, vel.z);
        player.velocityModified = true;
        
        ClientMovementController.events().publish(new DoubleJumpedEvent(player));
        MovementPackets.sendActionToServer(MovementActions.DOUBLE_JUMP, player.getYaw(), vel.x, vel.z);
    }

    public static void resetOnGround(ClientPlayerEntity player) {
        if (player.isOnGround()) {
            ClientMovementState.setDoubleJumpCharges(MovementConfig.DOUBLE_JUMP_MAX_CHARGES);
        }
    }
}
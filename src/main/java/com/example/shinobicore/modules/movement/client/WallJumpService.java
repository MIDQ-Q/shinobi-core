package com.example.shinobicore.modules.movement.client;

import com.example.shinobicore.modules.movement.common.MovementActions;
import com.example.shinobicore.modules.movement.common.MovementPose;
import com.example.shinobicore.modules.movement.common.events.WallJumpedEvent;
import com.example.shinobicore.modules.movement.config.MovementConfig;
import com.example.shinobicore.modules.movement.network.MovementPackets;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

public final class WallJumpService {
    private WallJumpService() {}

    public static void tryJump(ClientPlayerEntity player) {
        if (ClientMovementState.getPose() != MovementPose.WALL_RUNNING) return;
        
        Vec3d normal = WallRunService.getCurrentNormal();
        if (normal == null) return;

        Vec3d vel = player.getVelocity();
        double pushX = normal.x * MovementConfig.WALL_JUMP_PUSH + vel.x * 0.2;
        double pushZ = normal.z * MovementConfig.WALL_JUMP_PUSH + vel.z * 0.2;
        double pushY = MovementConfig.WALL_JUMP_UP;

        player.setVelocity(pushX, pushY, pushZ);
        player.velocityModified = true;
        
        ClientMovementState.setPose(MovementPose.NORMAL);
        ClientMovementState.setWallRunCooldown(MovementConfig.WALL_JUMP_COOLDOWN);
        
        ClientMovementController.events().publish(new WallJumpedEvent(player, normal));
        MovementPackets.sendActionToServer(MovementActions.WALL_JUMP, player.getYaw(), pushX, pushZ);
    }
}
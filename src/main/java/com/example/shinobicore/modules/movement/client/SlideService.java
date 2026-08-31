package com.example.shinobicore.modules.movement.client;

import com.example.shinobicore.modules.movement.common.MovementActions;
import com.example.shinobicore.modules.movement.common.MovementPose;
import com.example.shinobicore.modules.movement.common.events.SlideStartedEvent;
import com.example.shinobicore.modules.movement.common.events.SlideStoppedEvent;
import com.example.shinobicore.modules.movement.config.MovementConfig;
import com.example.shinobicore.modules.movement.network.MovementPackets;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

public final class SlideService {
    private static int slideTicks = 0;

    private SlideService() {}

    public static void start(ClientPlayerEntity player) {
        if (slideTicks > 0) return;
        slideTicks = MovementConfig.SLIDE_DURATION;
        ClientMovementState.setPose(MovementPose.SLIDING);
        player.setSwimming(true);
        ClientMovementController.events().publish(new SlideStartedEvent(player));
        MovementPackets.sendActionToServer(MovementActions.START_SLIDE, player.getYaw(), 0, 0);
    }

    public static void tick(ClientPlayerEntity player) {
        if (slideTicks <= 0) return;

        slideTicks--;
        Vec3d vel = player.getVelocity();
        player.setVelocity(vel.x * MovementConfig.SLIDE_FRICTION, vel.y, vel.z * MovementConfig.SLIDE_FRICTION);
        
        if (slideTicks <= 0 || player.isSneaking()) {
            stop(player);
        }
    }

    public static void stop(ClientPlayerEntity player) {
        if (slideTicks > 0 || ClientMovementState.getPose() == MovementPose.SLIDING) {
            slideTicks = 0;
            if (ClientMovementState.getPose() == MovementPose.SLIDING) {
                ClientMovementState.setPose(MovementPose.NORMAL);
            }
            player.setSwimming(false);
            ClientMovementController.events().publish(new SlideStoppedEvent(player));
            MovementPackets.sendActionToServer(MovementActions.STOP_SLIDE, player.getYaw(), 0, 0);
        }
    }
}
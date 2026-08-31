package com.example.shinobicore.modules.movement.client;

import com.example.shinobicore.modules.movement.common.MovementActions;
import com.example.shinobicore.modules.movement.common.MovementPose;
import com.example.shinobicore.modules.movement.common.events.RollStartedEvent;
import com.example.shinobicore.modules.movement.common.events.RollStoppedEvent;
import com.example.shinobicore.modules.movement.config.MovementConfig;
import com.example.shinobicore.modules.movement.network.MovementPackets;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

public final class RollService {
    private static int rollTicks = 0;
    private static int cooldown = 0;

    private RollService() {}

    public static void start(ClientPlayerEntity player) {
        if (rollTicks > 0 || cooldown > 0) return;
        
        rollTicks = MovementConfig.ROLL_DURATION;
        ClientMovementState.setPose(MovementPose.ROLLING);
        ClientMovementState.setIFrames(MovementConfig.ROLL_IFRAMES);
        
        Vec3d look = player.getRotationVector();
        Vec3d dash = look.multiply(MovementConfig.ROLL_DISTANCE / MovementConfig.ROLL_DURATION);
        player.setVelocity(dash.x, 0.1, dash.z);
        
        ClientMovementController.events().publish(new RollStartedEvent(player));
        MovementPackets.sendActionToServer(MovementActions.START_ROLL, player.getYaw(), dash.x, dash.z);
    }

    public static void tick(ClientPlayerEntity player) {
        if (cooldown > 0) cooldown--;
        if (rollTicks <= 0) return;

        rollTicks--;
        if (rollTicks <= 0) {
            ClientMovementState.setPose(MovementPose.NORMAL);
            cooldown = MovementConfig.ROLL_COOLDOWN;
            ClientMovementController.events().publish(new RollStoppedEvent(player));
            MovementPackets.sendActionToServer(MovementActions.STOP_ROLL, player.getYaw(), 0, 0);
        }
    }
}
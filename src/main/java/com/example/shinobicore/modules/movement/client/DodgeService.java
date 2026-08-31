package com.example.shinobicore.modules.movement.client;

import com.example.shinobicore.core.api.ChakraApi;
import com.example.shinobicore.core.service.CoreServices;
import com.example.shinobicore.modules.movement.common.MovementActions;
import com.example.shinobicore.modules.movement.common.MovementPose;
import com.example.shinobicore.modules.movement.common.events.DodgeEvent;
import com.example.shinobicore.modules.movement.config.MovementConfig;
import com.example.shinobicore.modules.movement.network.MovementPackets;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

public final class DodgeService {
    private static int cooldown = 0;

    private DodgeService() {}

    public static void start(ClientPlayerEntity player) {
        if (cooldown > 0) return;
        
        boolean hasChakra = CoreServices.get(ChakraApi.class).map(c -> 
            c.isChakraModeActive(player) && c.trySpend(player, (float) MovementConfig.DODGE_CHAKRA_COST)
        ).orElse(false);
        
        if (!hasChakra) return;

        cooldown = MovementConfig.DODGE_COOLDOWN;
        ClientMovementState.setPose(MovementPose.DODGING);
        ClientMovementState.setIFrames(MovementConfig.DODGE_IFRAMES);
        
        Vec3d look = player.getRotationVector();
        Vec3d dash = look.multiply(MovementConfig.DODGE_STRENGTH);
        player.setVelocity(dash.x, 0.0, dash.z);
        player.velocityModified = true;

        ClientMovementController.events().publish(new DodgeEvent(player, dash));
        MovementPackets.sendActionToServer(MovementActions.DODGE, player.getYaw(), dash.x, dash.z);
    }

    public static void tick(ClientPlayerEntity player) {
        if (cooldown > 0) cooldown--;
        if (ClientMovementState.getPose() == MovementPose.DODGING && cooldown < MovementConfig.DODGE_COOLDOWN - 4) {
            ClientMovementState.setPose(MovementPose.NORMAL);
        }
    }
}
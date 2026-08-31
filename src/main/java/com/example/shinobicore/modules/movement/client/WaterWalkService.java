package com.example.shinobicore.modules.movement.client;

import com.example.shinobicore.core.api.ChakraApi;
import com.example.shinobicore.core.service.CoreServices;
import com.example.shinobicore.modules.movement.client.util.WaterSurfaceDetector;
import com.example.shinobicore.modules.movement.common.MovementActions;
import com.example.shinobicore.modules.movement.common.MovementPose;
import com.example.shinobicore.modules.movement.common.events.WaterWalkStartedEvent;
import com.example.shinobicore.modules.movement.common.events.WaterWalkStoppedEvent;
import com.example.shinobicore.modules.movement.config.MovementConfig;
import com.example.shinobicore.modules.movement.network.MovementPackets;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

import java.util.Optional;

public final class WaterWalkService {
    private static boolean wasWalking = false;

    private WaterWalkService() {}

    public static void tick(ClientPlayerEntity player) {
        if (!MovementConfig.ENABLED) return;

        boolean canWalk = checkConditions(player);
        Optional<Double> surfaceY = WaterSurfaceDetector.getSurfaceY(player);

        if (canWalk && surfaceY.isPresent()) {
            if (!wasWalking) {
                wasWalking = true;
                ClientMovementState.setPose(MovementPose.WATER_WALKING);
                ClientMovementController.events().publish(new WaterWalkStartedEvent(player));
                MovementPackets.sendActionToServer(MovementActions.START_WATER_WALK, player.getYaw(), player.getVelocity().x, player.getVelocity().z);
            }

            double targetY = surfaceY.get() + MovementConfig.WATER_WALK_SURFACE_OFFSET;
            Vec3d vel = player.getVelocity();
            
            player.setVelocity(vel.x, 0.0, vel.z);
            player.setPosition(player.getX(), targetY, player.getZ());
            player.fallDistance = 0.0f;
            player.setSwimming(false);
        } else {
            if (wasWalking) {
                wasWalking = false;
                if (ClientMovementState.getPose() == MovementPose.WATER_WALKING) {
                    ClientMovementState.setPose(MovementPose.NORMAL);
                }
                ClientMovementController.events().publish(new WaterWalkStoppedEvent(player));
                MovementPackets.sendActionToServer(MovementActions.STOP_WATER_WALK, player.getYaw(), 0, 0);
            }
        }
    }

    private static boolean checkConditions(ClientPlayerEntity player) {
        if (player.isSneaking() || player.isSwimming() || player.isTouchingWater()) return false;
        
        return CoreServices.get(ChakraApi.class).map(chakra -> 
            chakra.isChakraModeActive(player) && 
            chakra.getCurrent(player) > 0 && 
            !chakra.isExhausted(player)
        ).orElse(false);
    }
}
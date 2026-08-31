package com.example.shinobicore.modules.movement.client;

import com.example.shinobicore.core.api.ChakraApi;
import com.example.shinobicore.core.service.CoreServices;
import com.example.shinobicore.modules.movement.common.MovementActions;
import com.example.shinobicore.modules.movement.common.MovementPose;
import com.example.shinobicore.modules.movement.common.events.EdgeGrabStartedEvent;
import com.example.shinobicore.modules.movement.common.events.EdgeGrabStoppedEvent;
import com.example.shinobicore.modules.movement.config.MovementConfig;
import com.example.shinobicore.modules.movement.network.MovementPackets;
import net.minecraft.block.BlockState;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.hit.BlockHitResult;
import net.minecraft.util.hit.HitResult;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.World;

public final class EdgeGrabService {
    private static boolean isGrabbing = false;

    private EdgeGrabService() {}

    public static void tick(ClientPlayerEntity player) {
        if (isGrabbing) {
            player.setVelocity(0, 0, 0);
            return;
        }

        if (player.getVelocity().y >= 0 || player.isOnGround()) return;

        World world = player.getWorld();
        Vec3d eyePos = player.getEyePos();
        Vec3d look = player.getRotationVector();
        Vec3d end = eyePos.add(look.multiply(MovementConfig.EDGE_GRAB_REACH));

        BlockHitResult hit = world.raycast(new net.minecraft.world.RaycastContext(
            eyePos, end,
            net.minecraft.world.RaycastContext.ShapeType.COLLIDER,
            net.minecraft.world.RaycastContext.FluidHandling.NONE,
            player
        ));

        if (hit.getType() == HitResult.Type.BLOCK) {
            BlockPos hitPos = hit.getBlockPos();
            BlockPos above = hitPos.up();
            BlockState aboveState = world.getBlockState(above);
            
            if (aboveState.isAir()) {
                boolean hasChakra = CoreServices.get(ChakraApi.class).map(c -> 
                    c.isChakraModeActive(player) && c.trySpend(player, (float) MovementConfig.EDGE_GRAB_CHAKRA_COST)
                ).orElse(false);

                if (hasChakra) {
                    isGrabbing = true;
                    ClientMovementState.setPose(MovementPose.EDGE_GRABBING);
                    ClientMovementController.events().publish(new EdgeGrabStartedEvent(player));
                    MovementPackets.sendActionToServer(MovementActions.START_EDGE_GRAB, player.getYaw(), 0, 0);
                }
            }
        }
    }

    public static void climb(ClientPlayerEntity player) {
        if (!isGrabbing) return;
        isGrabbing = false;
        ClientMovementState.setPose(MovementPose.NORMAL);
        
        Vec3d vel = player.getVelocity();
        player.setVelocity(vel.x, MovementConfig.EDGE_GRAB_CLIMB_BOOST, vel.z);
        player.velocityModified = true;
        
        ClientMovementController.events().publish(new EdgeGrabStoppedEvent(player));
        MovementPackets.sendActionToServer(MovementActions.STOP_EDGE_GRAB, player.getYaw(), 0, 0);
    }

    public static void drop(ClientPlayerEntity player) {
        if (!isGrabbing) return;
        isGrabbing = false;
        ClientMovementState.setPose(MovementPose.NORMAL);
        ClientMovementController.events().publish(new EdgeGrabStoppedEvent(player));
        MovementPackets.sendActionToServer(MovementActions.STOP_EDGE_GRAB, player.getYaw(), 0, 0);
    }
}
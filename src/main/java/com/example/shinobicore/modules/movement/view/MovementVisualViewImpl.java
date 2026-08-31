package com.example.shinobicore.modules.movement.view;

import com.example.shinobicore.modules.movement.client.ClientMovementState;
import com.example.shinobicore.modules.movement.common.MovementPose;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.util.math.Vec3d;

public final class MovementVisualViewImpl implements MovementVisualView {
    private final PlayerEntity player;

    public MovementVisualViewImpl(PlayerEntity player) {
        this.player = player;
    }

    private boolean is(MovementPose pose) {
        return ClientMovementState.getPose() == pose;
    }

    @Override public boolean isWaterWalking() { return is(MovementPose.WATER_WALKING); }
    @Override public boolean isWallRunning() { return is(MovementPose.WALL_RUNNING); }
    @Override public boolean isSliding() { return is(MovementPose.SLIDING); }
    @Override public boolean isCrawling() { return is(MovementPose.CRAWLING); }
    @Override public boolean isRolling() { return is(MovementPose.ROLLING); }
    @Override public boolean isDodging() { return is(MovementPose.DODGING); }
    @Override public boolean isChargingJump() { return is(MovementPose.CHARGING_JUMP); }
    @Override public boolean isEdgeGrabbing() { return is(MovementPose.EDGE_GRABBING); }
    
    @Override public float getMoveSpeed() { return player.isSprinting() ? 1.3f : 1.0f; }
    @Override public float getActionProgress() { return 0.0f; }
    @Override public Vec3d getWallNormal() { return com.example.shinobicore.modules.movement.client.WallRunService.getCurrentNormal(); }
}
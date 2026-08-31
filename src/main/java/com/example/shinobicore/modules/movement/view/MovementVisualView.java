package com.example.shinobicore.modules.movement.view;

import net.minecraft.util.math.Vec3d;

public interface MovementVisualView {
    boolean isWaterWalking();
    boolean isWallRunning();
    boolean isSliding();
    boolean isCrawling();
    boolean isRolling();
    boolean isDodging();
    boolean isChargingJump();
    boolean isEdgeGrabbing();
    float getMoveSpeed();
    float getActionProgress();
    Vec3d getWallNormal();
}
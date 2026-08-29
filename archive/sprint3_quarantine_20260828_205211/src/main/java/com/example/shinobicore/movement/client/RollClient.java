// SHINOBICORE MOVEMENT V3 FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.chakra.client.ClientChakraController;
import com.example.shinobicore.config.ShinobiCoreConfig;
import com.example.shinobicore.movement.common.MovementActionType;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.entity.EntityPose;
import net.minecraft.util.math.Vec3d;

/**
* Roll mechanic: R key -> short impulse + i-frames + low pose.
*
* Entry: R key pressed, on ground, not crawling, not in cooldown
* Behavior: impulse in movement/look direction, low pose, i-frames
* Exit: after timer expires
*/
public final class RollClient {

private RollClient() {}

private static int rollTicksLeft = 0;

/**
* Try to start rolling.
*/
public static boolean tryStart(ClientPlayerEntity player) {
ShinobiCoreConfig.RollSection cfg = ShinobiCoreConfig.getInstance().roll;
if (!cfg.enabled) return false;

// Must be on ground
if (!player.isOnGround()) return false;

// Must not be crawling
if (ClientMovementState.isCrawling()) return false;

// Must not be in active phase
MovementPhase phase = ClientMovementState.getPhase();
if (phase != MovementPhase.NORMAL) return false;

// Cooldown check
if (ClientMovementState.getRollCooldown() > 0) return false;

// Pay costs
ClientChakraController.addFatigue(cfg.fatigueCost);
if (ClientChakraController.isChakraModeActive()) {
if (!ClientChakraController.spendChakra(cfg.chakraCost)) {
return false; // Can't afford
}
}

// Start roll
rollTicksLeft = cfg.durationTicks;
ClientMovementState.setPhase(MovementPhase.ROLLING);
ClientMovementState.setRolling(true);
ClientMovementState.setRollCooldown(cfg.cooldownTicks);

// Apply impulse in movement direction
Vec3d impulse = getRollDirection(player, cfg.boost);
player.setVelocity(impulse.x, 0.1, impulse.z);
player.velocityModified = true;

// Set low pose
player.setPose(EntityPose.SWIMMING);

// Send packet
ClientMovementService.sendAction(player, MovementActionType.ROLL_START);

return true;
}

/**
* Get roll direction based on movement or look.
*/
private static Vec3d getRollDirection(ClientPlayerEntity player, float boost) {
// If moving, roll in movement direction
float moveX = player.input.movementSideways;
float moveZ = player.input.movementForward;

if (Math.abs(moveX) > 0.01 || Math.abs(moveZ) > 0.01) {
// Movement direction
float yaw = player.getYaw() * 0.017453292F;
float cos = (float) Math.cos(yaw);
float sin = (float) Math.sin(yaw);
double dirX = (moveX * cos - moveZ * sin) * boost;
double dirZ = (moveZ * cos + moveX * sin) * boost;
return new Vec3d(dirX, 0, dirZ);
}

// Otherwise, roll in look direction
Vec3d look = player.getRotationVector();
return new Vec3d(look.x * boost, 0, look.z * boost);
}

/**
* Tick roll logic.
*/
public static void tick(ClientPlayerEntity player) {
rollTicksLeft--;

// Check exit conditions
if (rollTicksLeft <= 0) {
stop(player);
return;
}

// Stop if not on ground anymore
if (!player.isOnGround()) {
stop(player);
return;
}

// Maintain low pose
if (player.getPose() != EntityPose.SWIMMING) {
player.setPose(EntityPose.SWIMMING);
}

// Apply slight friction
Vec3d vel = player.getVelocity();
player.setVelocity(vel.x * 0.9, vel.y, vel.z * 0.9);
player.velocityModified = true;

// I-frames: reduce fall damage
player.fallDistance = 0f;
}

/**
* Stop rolling.
*/
public static void stop(ClientPlayerEntity player) {
if (ClientMovementState.getPhase() != MovementPhase.ROLLING) return;

ClientMovementState.setPhase(MovementPhase.NORMAL);
ClientMovementState.setRolling(false);
rollTicksLeft = 0;

// Restore standing pose
player.setPose(EntityPose.STANDING);

// Send packet
ClientMovementService.sendAction(player, MovementActionType.ROLL_STOP);
}

public static int getRollTicksLeft() {
return rollTicksLeft;
}
}
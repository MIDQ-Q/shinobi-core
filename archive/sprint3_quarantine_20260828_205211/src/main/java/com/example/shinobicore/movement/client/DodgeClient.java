// SHINOBICORE MOVEMENT V3 FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.chakra.client.ClientChakraController;
import com.example.shinobicore.config.ShinobiCoreConfig;
import com.example.shinobicore.movement.common.MovementActionType;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

/**
* Dodge mechanic: Q/E keys -> left/right impulse + i-frames.
*
* Entry: Q/E key pressed, not in cooldown
* Behavior: sharp impulse left/right relative to look, short i-frames
* Exit: after timer expires (very short duration)
*/
public final class DodgeClient {

private DodgeClient() {}

private static int dodgeTicksLeft = 0;

/**
* Try to start dodging left.
*/
public static boolean tryDodgeLeft(ClientPlayerEntity player) {
return tryDodge(player, true);
}

/**
* Try to start dodging right.
*/
public static boolean tryDodgeRight(ClientPlayerEntity player) {
return tryDodge(player, false);
}

/**
* Try to start dodging.
*/
private static boolean tryDodge(ClientPlayerEntity player, boolean left) {
ShinobiCoreConfig.DodgeSection cfg = ShinobiCoreConfig.getInstance().dodge;
if (!cfg.enabled) return false;

// Must not be in active phase
MovementPhase phase = ClientMovementState.getPhase();
if (phase != MovementPhase.NORMAL) return false;

// Cooldown check
if (ClientMovementState.getDodgeCooldown() > 0) return false;

// Pay costs
ClientChakraController.addFatigue(cfg.fatigueCost);
if (ClientChakraController.isChakraModeActive()) {
if (!ClientChakraController.spendChakra(cfg.chakraCost)) {
return false; // Can't afford
}
}

// Start dodge
dodgeTicksLeft = cfg.iFrameTicks; // Dodge is very short
ClientMovementState.setPhase(MovementPhase.DODGING);
ClientMovementState.setDodging(true);
ClientMovementState.setDodgeCooldown(cfg.cooldownTicks);

// Apply impulse left or right relative to look
Vec3d look = player.getRotationVector();
Vec3d right = new Vec3d(-look.z, 0, look.x).normalize();

Vec3d impulse;
if (left) {
impulse = right.multiply(-cfg.boost); // Left is negative right
} else {
impulse = right.multiply(cfg.boost); // Right is positive right
}

player.setVelocity(impulse.x, player.getVelocity().y, impulse.z);
player.velocityModified = true;

// Send packet
MovementActionType action = left ? MovementActionType.DODGE_LEFT : MovementActionType.DODGE_RIGHT;
ClientMovementService.sendAction(player, action);

return true;
}

/**
* Tick dodge logic.
*/
public static void tick(ClientPlayerEntity player) {
dodgeTicksLeft--;

// Check exit conditions
if (dodgeTicksLeft <= 0) {
stop(player);
return;
}

// I-frames: reduce fall damage
player.fallDistance = 0f;
}

/**
* Stop dodging.
*/
public static void stop(ClientPlayerEntity player) {
if (ClientMovementState.getPhase() != MovementPhase.DODGING) return;

ClientMovementState.setPhase(MovementPhase.NORMAL);
ClientMovementState.setDodging(false);
dodgeTicksLeft = 0;

// Send packet
ClientMovementService.sendAction(player, MovementActionType.ROLL_STOP); // Reuse ROLL_STOP for dodge end
}

public static int getDodgeTicksLeft() {
return dodgeTicksLeft;
}
}
// SHINOBICORE MOVEMENT V3 FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.chakra.client.ClientChakraController;
import com.example.shinobicore.config.ShinobiCoreConfig;
import com.example.shinobicore.movement.common.MovementActionType;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

/**
* Charged Jump: hold Space on ground to charge, release to jump.
*
* Limits:
* - Max charge ticks
* - Max vertical velocity
* - Max horizontal boost
*/
public final class ChargedJumpClient {

private ChargedJumpClient() {}

private static int chargeTicks = 0;
private static boolean charging = false;

/**
* Try to start charging.
* Called from ClientMovementService when jump held on ground.
*/
public static boolean tryStartCharge(ClientPlayerEntity player) {
ShinobiCoreConfig.ChargedJumpSection cfg = ShinobiCoreConfig.getInstance().chargedJump;
if (!cfg.enabled) return false;

// Must be on ground
if (!player.isOnGround()) return false;

// Must NOT be in water
if (player.isTouchingWater()) return false;

// Must NOT be in active phase
MovementPhase phase = ClientMovementState.getPhase();
if (phase != MovementPhase.NORMAL) return false;

// Check chakra mode or config allows without
boolean chakraMode = ClientChakraController.isChakraModeActive();
if (!chakraMode && !cfg.allowWithoutChakraMode) return false;

// Start charging
chargeTicks = 0;
charging = true;
ClientMovementState.setPhase(MovementPhase.CHARGING_JUMP);
ClientMovementState.setChargingJump(true);

// Send packet
ClientMovementService.sendAction(player, MovementActionType.CHARGED_JUMP_START);

return true;
}

/**
* Tick charge accumulation.
* Called from ClientMovementService when in CHARGING_JUMP phase.
*/
public static void tickCharge(ClientPlayerEntity player) {
ShinobiCoreConfig.ChargedJumpSection cfg = ShinobiCoreConfig.getInstance().chargedJump;

if (!charging) return;

chargeTicks++;

// Cap charge
if (chargeTicks > cfg.maxChargeTicks) {
chargeTicks = cfg.maxChargeTicks;
}

// Visual feedback: particles or HUD (optional)

// Check if player released jump
if (!MovementInputService.isJumpHeld()) {
releaseCharge(player);
}

// Cancel if player starts moving significantly
if (player.isSneaking()) {
cancelCharge(player);
}
}

/**
* Release charge and perform boosted jump.
*/
public static void releaseCharge(ClientPlayerEntity player) {
ShinobiCoreConfig.ChargedJumpSection cfg = ShinobiCoreConfig.getInstance().chargedJump;

if (!charging) return;

charging = false;
ClientMovementState.setPhase(MovementPhase.NORMAL);
ClientMovementState.setChargingJump(false);

// Check minimum charge
if (chargeTicks < cfg.minChargeTicks) {
// Too short - just do normal jump
player.jump();
chargeTicks = 0;
return;
}

// Calculate charge multiplier
float t = (float)(chargeTicks - cfg.minChargeTicks) / (float)(cfg.maxChargeTicks - cfg.minChargeTicks);
t = Math.max(0.0f, Math.min(1.0f, t));
float multiplier = cfg.baseMultiplier + t * (cfg.maxMultiplier - cfg.baseMultiplier);

// Pay costs
float chakraCost = cfg.chakraCost * multiplier;
float fatigueCost = cfg.fatigueCost * multiplier;

ClientChakraController.addFatigue(fatigueCost);
if (ClientChakraController.isChakraModeActive()) {
if (!ClientChakraController.spendChakra(chakraCost)) {
// Not enough chakra - cancel charge
chargeTicks = 0;
return;
}
}

// Calculate jump velocity
// Vertical: base * multiplier, capped
double verticalVel = cfg.baseVerticalVelocity * multiplier;
verticalVel = Math.min(verticalVel, cfg.maxVerticalVelocity);

// Horizontal: boost in look direction, capped
Vec3d look = player.getRotationVector();
double horizontalBoost = cfg.baseHorizontalBoost * multiplier;
horizontalBoost = Math.min(horizontalBoost, cfg.maxHorizontalBoost);

double newX = look.x * horizontalBoost;
double newZ = look.z * horizontalBoost;

// If moving forward, boost in movement direction
if (player.input.movementForward > 0) {
float rad = player.getYaw() * 0.017453292F;
newX = -Math.sin(rad) * horizontalBoost;
newZ = Math.cos(rad) * horizontalBoost;
}

player.setVelocity(newX, verticalVel, newZ);
player.velocityModified = true;
player.fallDistance = 0f;

// Reset charge
chargeTicks = 0;

// Send packet
ClientMovementService.sendAction(player, MovementActionType.CHARGED_JUMP_RELEASE);
}

/**
* Cancel charge without jumping.
*/
public static void cancelCharge(ClientPlayerEntity player) {
if (!charging) return;
charging = false;
chargeTicks = 0;
ClientMovementState.setPhase(MovementPhase.NORMAL);
ClientMovementState.setChargingJump(false);
}

/**
* Stop charge completely.
*/
public static void stop() {
charging = false;
chargeTicks = 0;
ClientMovementState.setChargingJump(false);
}

public static boolean isCharging() { return charging; }
public static int getChargeTicks() { return chargeTicks; }
public static float getChargeProgress() {
ShinobiCoreConfig.ChargedJumpSection cfg = ShinobiCoreConfig.getInstance().chargedJump;
if (cfg.maxChargeTicks <= 0) return 0;
return (float) chargeTicks / cfg.maxChargeTicks;
}
}
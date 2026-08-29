// SHINOBICORE MOVEMENT V3 FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.chakra.client.ClientChakraController;
import com.example.shinobicore.config.ShinobiCoreConfig;
import com.example.shinobicore.movement.common.MovementActionType;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

/**
* Double Jump: press Space in air to jump again.
* CRITICAL: preserves horizontal inertia (never zeroes vel.x/vel.z).
*
* Conditions:
* - Chakra mode active
* - Player in air
* - Player NOT on water
* - Player NOT on wall
* - Air jump limit not exhausted
* - Has enough chakra
*
* Counter reset on: landing, water entry, wall entry, edge grab
*/
public final class DoubleJumpClient {

private DoubleJumpClient() {}

/**
* Try to perform double jump.
* Called from ClientMovementService when jump pressed in air.
*/
public static boolean tryDoubleJump(ClientPlayerEntity player) {
ShinobiCoreConfig.DoubleJumpSection cfg = ShinobiCoreConfig.getInstance().doubleJump;
if (!cfg.enabled) return false;

// Must have chakra mode
if (!ClientChakraController.isChakraModeActive()) return false;

// Must be in air
if (player.isOnGround()) return false;

// Must NOT be on water
if (ClientMovementState.isOnWater()) return false;

// Must NOT be on wall
if (ClientMovementState.getPhase() == MovementPhase.WALL_RUNNING) return false;

// Must NOT be in temporary state
MovementPhase phase = ClientMovementState.getPhase();
if (phase == MovementPhase.ROLLING || phase == MovementPhase.DODGING) return false;

// Check air jump limit
if (ClientMovementState.getAirJumpsUsed() >= cfg.maxAirJumps) return false;

// Check cooldown
if (ClientMovementState.getChargedJumpCooldown() > 0) return false;

// Check chakra cost
float chakraCost = cfg.chakraCost;
if (ClientChakraController.isChakraModeActive() && ClientChakraController.getCurrentChakra() < chakraCost) return false;

// Pay costs
ClientChakraController.addFatigue(cfg.fatigueCost);
if (ClientChakraController.isChakraModeActive()) {
if (!ClientChakraController.spendChakra(chakraCost)) return false;
}

// Perform double jump
// CRITICAL: preserve horizontal inertia
Vec3d currentVel = player.getVelocity();
double newX = currentVel.x;
double newZ = currentVel.z;

// If preserveInertia is enabled, keep some horizontal speed
if (cfg.preserveInertia) {
// Slightly boost in movement direction if player is moving forward
if (player.input.movementForward > 0) {
float rad = player.getYaw() * 0.017453292F;
double boost = 0.1;
newX += -Math.sin(rad) * boost;
newZ += Math.cos(rad) * boost;
}
}

player.setVelocity(newX, cfg.verticalVelocity, newZ);
player.velocityModified = true;
player.fallDistance = 0f;

// Increment counter
ClientMovementState.setAirJumpsUsed(ClientMovementState.getAirJumpsUsed() + 1);

// Set cooldown
ClientMovementState.setChargedJumpCooldown(cfg.cooldownTicks);

// Send packet
ClientMovementService.sendAction(player, MovementActionType.DOUBLE_JUMP);

return true;
}

/**
* Reset air jump counter.
* Called on: landing, water entry, wall entry, edge grab
*/
public static void resetAirJumps() {
ClientMovementState.setAirJumpsUsed(0);
}
}
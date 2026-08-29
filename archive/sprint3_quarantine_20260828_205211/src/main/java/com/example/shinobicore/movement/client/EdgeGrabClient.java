// SHINOBICORE MOVEMENT V3 FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.chakra.client.ClientChakraController;
import com.example.shinobicore.config.ShinobiCoreConfig;
import com.example.shinobicore.movement.common.MovementActionType;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.hit.BlockHitResult;
import net.minecraft.util.hit.HitResult;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.RaycastContext;

/**
* Edge Grab: grab a ledge in air, hang, climb up.
*
* Conditions:
* - Player in air
* - Player moving toward block
* - Wall/obstacle ahead
* - Ledge above to grab
* - Player NOT on wall
* - Has enough chakra/fatigue
*
* Behavior:
* - Grab ledge, stop falling
* - Space/W to climb up
*/
public final class EdgeGrabClient {

private EdgeGrabClient() {}

private static BlockPos grabbedLedge = null;
private static int grabTicks = 0;

/**
* Try to grab edge.
* Called from ClientMovementService when in air and near ledge.
*/
public static boolean tryGrab(ClientPlayerEntity player) {
ShinobiCoreConfig.EdgeGrabSection cfg = ShinobiCoreConfig.getInstance().edgeGrab;
if (!cfg.enabled) return false;

// Must be in air
if (player.isOnGround()) return false;

// Must NOT be on water
if (ClientMovementState.isOnWater()) return false;

// Must NOT be on wall
if (ClientMovementState.getPhase() == MovementPhase.WALL_RUNNING) return false;

// Must NOT be in temporary state
MovementPhase phase = ClientMovementState.getPhase();
if (phase == MovementPhase.ROLLING || phase == MovementPhase.DODGING) return false;

// Check cooldown
if (ClientMovementState.getEdgeGrabCooldown() > 0) return false;

// Auto grab check
if (!cfg.autoGrab) return false;

// Find ledge
BlockPos ledge = findLedge(player, cfg.reach);
if (ledge == null) return false;

// Check costs
ClientChakraController.addFatigue(cfg.fatigueCost);
if (ClientChakraController.isChakraModeActive()) {
if (!ClientChakraController.spendChakra(cfg.chakraCost)) return false;
}

// Grab!
grabbedLedge = ledge;
grabTicks = 0;
ClientMovementState.setPhase(MovementPhase.EDGE_GRABBING);
ClientMovementState.setEdgeGrabbing(true);
ClientMovementState.setEdgeGrabCooldown(cfg.cooldownTicks);

// Reset air jumps
DoubleJumpClient.resetAirJumps();

// Stop falling
player.setVelocity(player.getVelocity().x, 0, player.getVelocity().z);
player.velocityModified = true;
player.fallDistance = 0f;

// Send packet
ClientMovementService.sendAction(player, MovementActionType.EDGE_GRAB_START);

return true;
}

/**
* Tick edge grab.
* Called from ClientMovementService when in EDGE_GRABBING phase.
*/
public static void tickGrab(ClientPlayerEntity player) {
ShinobiCoreConfig.EdgeGrabSection cfg = ShinobiCoreConfig.getInstance().edgeGrab;

if (grabbedLedge == null) {
stop(player);
return;
}

grabTicks++;

// Check if player wants to climb up
if (MovementInputService.wasJumpPressed() || player.input.movementForward > 0.5f) {
climbUp(player, cfg);
return;
}

// Check if player released (pressed sneak)
if (player.isSneaking()) {
stop(player);
return;
}

// Hang: reduce gravity to near zero
player.setVelocity(player.getVelocity().x, -0.01, player.getVelocity().z);
player.velocityModified = true;
player.fallDistance = 0f;

// Auto release if hanging too long (10 seconds)
if (grabTicks > 200) {
stop(player);
}
}

/**
* Climb up onto the ledge.
*/
public static void climbUp(ClientPlayerEntity player, ShinobiCoreConfig.EdgeGrabSection cfg) {
if (grabbedLedge == null) return;

// Teleport player to top of ledge
double targetY = grabbedLedge.getY() + 0.001;
player.setPosition(player.getX(), targetY, player.getZ());
player.velocityModified = true;
player.setOnGround(true);
player.fallDistance = 0f;

// Reset
grabbedLedge = null;
grabTicks = 0;
ClientMovementState.setPhase(MovementPhase.NORMAL);
ClientMovementState.setEdgeGrabbing(false);

// Send packet
ClientMovementService.sendAction(player, MovementActionType.EDGE_GRAB_STOP);
}

/**
* Stop grabbing (release or fall).
*/
public static void stop(ClientPlayerEntity player) {
if (ClientMovementState.getPhase() != MovementPhase.EDGE_GRABBING) return;

grabbedLedge = null;
grabTicks = 0;
ClientMovementState.setPhase(MovementPhase.NORMAL);
ClientMovementState.setEdgeGrabbing(false);

// Send packet
ClientMovementService.sendAction(player, MovementActionType.EDGE_GRAB_STOP);
}

/**
* Find a grabbable ledge ahead of player.
*/
private static BlockPos findLedge(ClientPlayerEntity player, double reach) {
Vec3d eye = player.getEyePos();
Vec3d look = player.getRotationVector();

// Raycast forward
Vec3d end = eye.add(look.multiply(reach));
BlockHitResult hit = player.getWorld().raycast(new RaycastContext(
eye, end,
RaycastContext.ShapeType.COLLIDER,
RaycastContext.FluidHandling.NONE,
player
));

if (hit.getType() != HitResult.Type.BLOCK) return null;

BlockPos wallPos = hit.getBlockPos();

// Check block above wall
BlockPos aboveWall = wallPos.up();
boolean wallSolid = player.getWorld().getBlockState(wallPos).isSolidBlock(player.getWorld(), wallPos);
boolean aboveWallEmpty = !player.getWorld().getBlockState(aboveWall).isSolidBlock(player.getWorld(), aboveWall);
boolean aboveAboveWallEmpty = !player.getWorld().getBlockState(aboveWall.up()).isSolidBlock(player.getWorld(), aboveWall.up());

if (wallSolid && aboveWallEmpty && aboveAboveWallEmpty) {
return aboveWall;
}

return null;
}

public static boolean isGrabbing() { return grabbedLedge != null; }
public static BlockPos getGrabbedLedge() { return grabbedLedge; }
}
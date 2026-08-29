// SHINOBICORE MOVEMENT V3 FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.movement.client.DoubleJumpClient;
import com.example.shinobicore.movement.client.ChargedJumpClient;
import com.example.shinobicore.movement.client.EdgeGrabClient;

import com.example.shinobicore.chakra.client.ClientChakraController;
import com.example.shinobicore.config.ShinobiCoreConfig;
import com.example.shinobicore.movement.common.MovementActionType;
import com.example.shinobicore.movement.common.MovementPhase;
import com.example.shinobicore.network.ModPackets;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.networking.v1.PacketByteBufs;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.util.math.Vec3d;

/**
 * Central orchestrator for all client-side movement logic.
 * Each subsystem (water, wall, slide, etc.) is called from here.
 * 
 * Priority order:
 * 1. Dead/menu/vehicle/flying -> reset
 * 2. Meditation -> blocks most actions
 * 3. Wall -> if active, water is not active
 * 4. Water -> if active, wall can only start from jump + exit
 * 5. Slide/roll/dodge -> temporary states
 * 6. Crawl -> persistent pose
 * 7. Normal
 */
public final class ClientMovementService {

    private ClientMovementService() {}

    private static boolean registered = false;

    public static void register() {
        if (registered) return;
        registered = true;
        net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents.END_CLIENT_TICK.register(
            ClientMovementService::tickClient
        );
    }

    public static void tickClient(MinecraftClient client) {
        ClientPlayerEntity player = client.player;
        if (player == null) {
            ClientMovementState.resetAll();
            return;
        }

        if (!MovementInputService.canPerformActions(client)) {
            resetAll(player);
            return;
        }

        // Tick input detection
        MovementInputService.tick(client);

        // Handle roll key
        if (client.options.attackKey.isPressed()) {
            // Check for roll key (R)
            if (com.example.shinobicore.client.input.KeyBindings.ROLL.wasPressed()) {
                RollClient.tryStart(player);
            }
            // Check for dodge keys (Q/E)
            if (com.example.shinobicore.client.input.KeyBindings.DODGE_LEFT.wasPressed()) {
                DodgeClient.tryDodgeLeft(player);
            }
            if (com.example.shinobicore.client.input.KeyBindings.DODGE_RIGHT.wasPressed()) {
                DodgeClient.tryDodgeRight(player);
            }
            // Check for meditate key (M)
            if (com.example.shinobicore.client.input.KeyBindings.MEDITATE.wasPressed()) {
                MeditationClient.toggle(player);
            }
        }

        // Tick state cooldowns
        ClientMovementState.tick();

        // === Priority-based state machine ===
        MovementPhase phase = ClientMovementState.getPhase();

        switch (phase) {
            case MEDITATING -> tickMeditation(player);
            case WATER_WALKING -> tickWaterWalk(player);
            case WALL_RUNNING -> tickWallRun(player);
            case SLIDING -> tickSlide(player);
            case CRAWLING -> tickCrawl(player);
            case ROLLING -> RollClient.tick(player);
            case DODGING -> DodgeClient.tick(player);
            case CHARGING_JUMP -> ChargedJumpClient.tickCharge(player);
            case EDGE_GRABBING -> EdgeGrabClient.tickGrab(player);
            case NORMAL -> tickNormal(player);
        }

        // Heartbeat for server mirror
        sendHeartbeatIfNeeded(player);
    }

    // === NORMAL ===
    private static void tickNormal(ClientPlayerEntity player) {
        // Check for water walk entry
        WaterWalkClient.tryStart(player);

        // Check for wall run entry (needs jump grace)
        WallRunClient.tryStart(player);

        // Check for slide entry
        // Check for roll entry
        // Check for dodge entry
        // Check for charged jump entry
        // Check for double jump
        // Check for edge grab

        // Reset air jumps on landing
        if (player.isOnGround()) {
            ClientMovementState.setAirJumpsUsed(0);
            // Stop charged jump if on ground
            if (ClientMovementState.isChargingJump()) {
                ChargedJumpClient.stop();
            }
        }

        // Track jump grace ticks
        if (MovementInputService.wasJumpPressed()) {
            ShinobiCoreConfig.WallRunSection cfg = ShinobiCoreConfig.getInstance().wallRun;
            ClientMovementState.setJumpGraceTicks(cfg.jumpGraceTicks);
        }

        // Double jump: Space in air
        if (MovementInputService.wasJumpPressed() && !player.isOnGround()) {
            DoubleJumpClient.tryDoubleJump(player);
        }

        // Charged jump: hold Space on ground
        if (MovementInputService.isJumpHeld() && player.isOnGround()) {
            ChargedJumpClient.tryStartCharge(player);
        }

        // Edge grab: auto grab in air
        if (!player.isOnGround()) {
            EdgeGrabClient.tryGrab(player);
        }
    }

    // === MEDITATION ===
    private static void tickMeditation(ClientPlayerEntity player) {
        MeditationClient.tick(player);
    }

    // === WATER WALK ===
    private static void tickWaterWalk(ClientPlayerEntity player) {
        WaterWalkClient.tick(player);
    }

    // === WALL RUN ===
    private static void tickWallRun(ClientPlayerEntity player) {
        WallRunClient.tick(player);
    }

    // === SLIDE ===
    private static void tickSlide(ClientPlayerEntity player) {
        SlideClient.tick(player);
    }

    // === CRAWL ===
    private static void tickCrawl(ClientPlayerEntity player) {
        CrawlClient.tick(player);
    }

    // === ROLL ===
    private static void tickRoll(ClientPlayerEntity player) {
        // Placeholder - Script 10B will implement
    }

    // === DODGE ===
    private static void tickDodge(ClientPlayerEntity player) {
        // Placeholder - Script 10B will implement
    }

    // === CHARGED JUMP ===
    private static void tickChargedJump(ClientPlayerEntity player) {
        // Placeholder - Script 10C will implement
    }

    // === EDGE GRAB ===
    private static void tickEdgeGrab(ClientPlayerEntity player) {
        // Placeholder - Script 10C will implement
    }

    // === PUBLIC API (called by InputService) ===

    public static void tryStartSlide(ClientPlayerEntity player) {
        SlideClient.tryStart(player);
    }

    public static void toggleCrawl(ClientPlayerEntity player) {
        CrawlClient.toggle(player);
    }

    public static void startCrawl(ClientPlayerEntity player) {
        CrawlClient.startCrawl(player);
    }

    public static void stopCrawl(ClientPlayerEntity player) {
        CrawlClient.stopCrawl(player);
    }

    public static void startMeditation(ClientPlayerEntity player) {
        if (ClientMovementState.getPhase() != MovementPhase.NORMAL) return;
        if (!player.isOnGround()) return;
        if (isPlayerMoving(player)) return;
        ClientMovementState.setPhase(MovementPhase.MEDITATING);
        ClientMovementState.setMeditating(true);
        ClientChakraController.setMeditating(true);
        sendAction(player, MovementActionType.MEDITATION_START);
    }

    public static void stopMeditation(ClientPlayerEntity player) {
        if (ClientMovementState.getPhase() != MovementPhase.MEDITATING) return;
        ClientMovementState.setPhase(MovementPhase.NORMAL);
        ClientMovementState.setMeditating(false);
        ClientChakraController.setMeditating(false);
        sendAction(player, MovementActionType.MEDITATION_STOP);
    }

    public static void resetAll(ClientPlayerEntity player) {
        ClientMovementState.resetAll();
        ClientChakraController.setMeditating(false);
    }

    // === NETWORKING ===

    public static void sendAction(ClientPlayerEntity player, MovementActionType action) {
        sendAction(player, action, null);
    }

    public static void sendAction(ClientPlayerEntity player, MovementActionType action, Vec3d wallNormal) {
        PacketByteBuf buf = PacketByteBufs.create();
        buf.writeVarInt(ClientMovementState.nextSequence());
        buf.writeVarInt(action.getId());

        // Write optional wall normal
        if (wallNormal != null) {
            buf.writeBoolean(true);
            buf.writeDouble(wallNormal.x);
            buf.writeDouble(wallNormal.y);
            buf.writeDouble(wallNormal.z);
        } else {
            buf.writeBoolean(false);
        }

        ClientPlayNetworking.send(ModPackets.MOVEMENT_ACTION, buf);
    }

    private static void sendHeartbeatIfNeeded(ClientPlayerEntity player) {
        ShinobiCoreConfig.MovementSection cfg = ShinobiCoreConfig.getInstance().movement;
        if (!cfg.serverMirrorPhysics) return;

        // Send heartbeat every N ticks
        if (player.age % cfg.heartbeatIntervalTicks != 0) return;

        PacketByteBuf buf = PacketByteBufs.create();
        buf.writeVarInt(ClientMovementState.nextSequence());
        buf.writeVarInt(ClientMovementState.getPhase().ordinal());
        buf.writeBoolean(ClientMovementState.isOnWater());
        buf.writeBoolean(ClientMovementState.isCrawling());
        buf.writeBoolean(ClientMovementState.isSliding());
        buf.writeBoolean(ClientMovementState.isMeditating());

        ClientPlayNetworking.send(ModPackets.MOVEMENT_HEARTBEAT, buf);
    }

    // === HELPERS ===

    private static boolean isPlayerMoving(ClientPlayerEntity player) {
        return Math.abs(player.getVelocity().x) > 0.01
            || Math.abs(player.getVelocity().z) > 0.01
            || player.input.movementForward != 0
            || player.input.movementSideways != 0;
    }
}
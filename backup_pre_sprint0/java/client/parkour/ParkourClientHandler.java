package com.example.shinobicore.client.parkour;
import com.example.shinobicore.util.DebugTraceLogger;

import com.example.shinobicore.combat.ParkourActions;
import com.example.shinobicore.network.packet.ParkourActionPacket;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

public class ParkourClientHandler {
    // Edge detection variables
    private static boolean prevSneakPressed = false;
    private static boolean prevJumpPressed = false;
    private static boolean prevSprintPressed = false;
    
    // Timers
    private static long lastSneakTap = 0;
    private static final int DOUBLE_TAP_MS = 250;
    private static int slideCooldown = 0;
    private static int wallWalkCooldown = 0;

    public static void init() {
        ClientTickEvents.END_CLIENT_TICK.register(ParkourClientHandler::tick);
    }

    private static void tick(MinecraftClient client) {
        ClientPlayerEntity player = client.player;
        if (player == null || client.currentScreen != null) return;

        // Update cooldowns
        if (slideCooldown > 0) slideCooldown--;
        if (wallWalkCooldown > 0) wallWalkCooldown--;

        // === EDGE DETECTION ===
        boolean sneakPressed = client.options.sneakKey.isPressed();
        boolean sneakJustPressed = sneakPressed && !prevSneakPressed;
        prevSneakPressed = sneakPressed;

        boolean jumpPressed = client.options.jumpKey.isPressed();
        boolean jumpJustPressed = jumpPressed && !prevJumpPressed;
        prevJumpPressed = jumpPressed;

        boolean sprintPressed = client.options.sprintKey.isPressed();
        boolean sprintJustPressed = sprintPressed && !prevSprintPressed;
        prevSprintPressed = sprintPressed;

        // === 1. DOUBLE JUMP / WALL JUMP (CLIENT-AUTHORITATIVE) ===
        if (jumpJustPressed && !player.isOnGround() && player.getVelocity().y < 0.05) {
            DebugTraceLogger.action("JUMP", "Air Jump/Wall Jump | VelY: " + player.getVelocity().y + " | HorizCol: " + player.horizontalCollision);
            Vec3d wallNormal = com.example.shinobicore.client.parkour.util.WallDetector.getWallNormal(player);
            if (wallNormal != null) {
                // Wall jump: client applies impulse immediately
                Vec3d push = wallNormal.multiply(0.6);
                player.setVelocity(push.x, 0.45, push.z);
                player.velocityModified = true;
                ParkourActionPacket.send(ParkourActions.WALL_JUMP, player.getYaw());
            } else {
                ParkourActionPacket.send(ParkourActions.DOUBLE_JUMP, player.getYaw());
            }
        }

        // === 2. DODGE (Dash): Sprint key tap + Direction held ===
        if (sprintJustPressed) {
            DebugTraceLogger.action("DODGE", "Sprint pressed | Dir: F=" + client.options.forwardKey.isPressed() + " L=" + client.options.leftKey.isPressed());
            if (client.options.forwardKey.isPressed()) {
                ParkourActionPacket.send(ParkourActions.DASH, player.getYaw());
            } else if (client.options.leftKey.isPressed()) {
                ParkourActionPacket.send(ParkourActions.DASH, player.getYaw() - 90f);
            } else if (client.options.rightKey.isPressed()) {
                ParkourActionPacket.send(ParkourActions.DASH, player.getYaw() + 90f);
            } else if (client.options.backKey.isPressed()) {
                ParkourActionPacket.send(ParkourActions.DASH, player.getYaw() + 180f);
            }
        }

        // === 3. CRAWL: Double-tap Shift (just pressed, not held) ===
        if (sneakJustPressed) {
            long now = System.currentTimeMillis();
            if (now - lastSneakTap < DOUBLE_TAP_MS) {
                ParkourActionPacket.send(ParkourActions.CRAWL, player.getYaw());
                lastSneakTap = 0; // Reset to prevent triple-tap
            } else {
                lastSneakTap = now;
            }
        }

        // === 4. SLIDE: Sprinting + JUST pressed sneak ===
        if (sneakJustPressed && player.isSprinting() && player.isOnGround() && slideCooldown <= 0) {
            ParkourActionPacket.send(ParkourActions.SLIDE, player.getYaw());
            slideCooldown = 20; // 1 second cooldown
        }

        // === 5. WALL WALK: Auto-detect with cooldown ===
        // Client detects collision and sends packet to server
        if (player.horizontalCollision && !player.isOnGround() && wallWalkCooldown <= 0) {
            ParkourActionPacket.send(ParkourActions.WALL_WALK, player.getYaw());
            wallWalkCooldown = 5; // Send every 5 ticks max (prevent spam)
        }
    }
}
// SHINOBICORE MOVEMENT V3 FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.chakra.client.ClientChakraController;
import com.example.shinobicore.config.ShinobiCoreConfig;
import com.example.shinobicore.movement.common.MovementActionType;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.util.math.Vec3d;

/**
 * Meditation mechanic: M key to meditate.
 * 
 * Requirements:
 * - On ground
 * - Not moving
 * - Not in active phase (water, wall, slide, etc.)
 * 
 * Effects:
 * - Accelerated chakra regen (meditationRegenMultiplier)
 * - Accelerated fatigue decay (meditationFatigueDecayMultiplier)
 * - Interrupted by movement or damage
 * - Visual particles (enchantment glint)
 */
public final class MeditationClient {

    private MeditationClient() {}

    private static int meditationTicks = 0;
    private static int damageCooldown = 0;

    /**
     * Toggle meditation on/off.
     * Called from ClientMovementService when M pressed.
     */
    public static void toggle(ClientPlayerEntity player) {
        if (ClientChakraController.isMeditating()) {
            stop(player);
        } else {
            start(player);
        }
    }

    /**
     * Try to start meditating.
     */
    public static void start(ClientPlayerEntity player) {
        ShinobiCoreConfig.MeditationSection cfg = ShinobiCoreConfig.getInstance().meditation;
        if (!cfg.enabled) return;

        // Must be on ground
        if (!player.isOnGround()) return;

        // Must not be moving
        if (isPlayerMoving(player)) return;

        // Must not be in active phase
        MovementPhase phase = ClientMovementState.getPhase();
        if (phase != MovementPhase.NORMAL) return;

        // Check damage cooldown
        if (damageCooldown > 0) return;

        // Start meditation
        ClientMovementState.setPhase(MovementPhase.MEDITATING);
        ClientMovementState.setMeditating(true);
        ClientChakraController.setMeditating(true);
        meditationTicks = 0;

        // Send packet
        ClientMovementService.sendAction(player, MovementActionType.MEDITATION_START);
    }

    /**
     * Stop meditating.
     */
    public static void stop(ClientPlayerEntity player) {
        if (!ClientChakraController.isMeditating()) return;

        ClientMovementState.setPhase(MovementPhase.NORMAL);
        ClientMovementState.setMeditating(false);
        ClientChakraController.setMeditating(false);
        meditationTicks = 0;

        // Send packet
        ClientMovementService.sendAction(player, MovementActionType.MEDITATION_STOP);
    }

    /**
     * Tick meditation logic.
     * Called from ClientMovementService when in MEDITATING phase.
     */
    public static void tick(ClientPlayerEntity player) {
        meditationTicks++;

        // Check damage cooldown
        if (damageCooldown > 0) {
            damageCooldown--;
        }

        // Check interruption conditions
        if (shouldInterrupt(player)) {
            stop(player);
            return;
        }

        // Spawn meditation particles every 5 ticks
        if (meditationTicks % 5 == 0) {
            spawnMeditationParticles(player);
        }

        // Chakra regen and fatigue decay are handled in ClientChakraController
    }

    /**
     * Check if meditation should be interrupted.
     */
    private static boolean shouldInterrupt(ClientPlayerEntity player) {
        // Interrupt if moving
        if (isPlayerMoving(player)) return true;

        // Interrupt if not on ground
        if (!player.isOnGround()) return true;

        // Interrupt if in active phase
        MovementPhase phase = ClientMovementState.getPhase();
        if (phase != MovementPhase.MEDITATING) return true;

        return false;
    }

    /**
     * Called when player takes damage.
     * Sets damage cooldown to prevent immediate re-meditation.
     */
    public static void onDamage(ClientPlayerEntity player) {
        ShinobiCoreConfig.MeditationSection cfg = ShinobiCoreConfig.getInstance().meditation;
        
        if (ClientChakraController.isMeditating()) {
            stop(player);
        }
        
        damageCooldown = cfg.damageCooldownTicks;
    }

    /**
     * Spawn meditation particles (enchantment glint effect).
     */
    private static void spawnMeditationParticles(ClientPlayerEntity player) {
        Vec3d pos = player.getPos();
        double height = player.getHeight();
        
        // Spawn 3-5 particles around player
        int count = 3 + player.getWorld().random.nextInt(3);
        for (int i = 0; i < count; i++) {
            double offsetX = (player.getWorld().random.nextDouble() - 0.5) * 1.0;
            double offsetY = player.getWorld().random.nextDouble() * height;
            double offsetZ = (player.getWorld().random.nextDouble() - 0.5) * 1.0;
            
            player.getWorld().addParticle(
                ParticleTypes.ENCHANT,
                pos.x + offsetX,
                pos.y + offsetY,
                pos.z + offsetZ,
                0, 0.1, 0
            );
        }
    }

    /**
     * Check if player is moving.
     */
    private static boolean isPlayerMoving(ClientPlayerEntity player) {
        Vec3d vel = player.getVelocity();
        double speed = Math.sqrt(vel.x * vel.x + vel.z * vel.z);
        return speed > 0.01 
            || player.input.movementForward != 0 
            || player.input.movementSideways != 0;
    }

    public static int getMeditationTicks() {
        return meditationTicks;
    }

    public static int getDamageCooldown() {
        return damageCooldown;
    }
}
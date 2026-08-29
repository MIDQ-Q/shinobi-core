// SHINOBICORE MOVEMENT V3 FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.chakra.client.ClientChakraController;
import com.example.shinobicore.config.ShinobiCoreConfig;
import com.example.shinobicore.movement.common.MovementActionType;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.util.math.Vec3d;

/**
 * Client-side water walking logic.
 * 
 * Requirements:
 * - Chakra mode must be active
 * - Player must be on water surface (within tolerance)
 * - Player must not be sneaking (if disableWhenSneaking is true)
 * - Player must not be crawling (if disableWhenCrawling is true)
 * 
 * Effects:
 * - Prevents falling into water
 * - Drains chakra over time
 * - Optional splash particles
 */
public final class WaterWalkClient {

    private WaterWalkClient() {}

    private static int ticksOnWater = 0;

    /**
     * Try to start water walking.
     * Called from ClientMovementService when conditions are met.
     */
    public static boolean tryStart(ClientPlayerEntity player) {
        ShinobiCoreConfig.WaterWalkSection cfg = ShinobiCoreConfig.getInstance().waterWalk;

        // Check if water walk is enabled
        if (!cfg.enabled) return false;

        // Check chakra mode
        if (!ClientChakraController.isChakraModeActive()) return false;

        // Check if on water surface
        if (!WaterDetector.isOnWaterSurface(player)) return false;

        // Check sneak/crawl restrictions
        if (cfg.disableWhenSneaking && player.isSneaking()) return false;
        if (cfg.disableWhenCrawling && ClientMovementState.isCrawling()) return false;

        // Check if already in water walk phase
        if (ClientMovementState.getPhase() == MovementPhase.WATER_WALKING) return true;

        // Check if we can transition to water walk
        MovementPhase currentPhase = ClientMovementState.getPhase();
        if (currentPhase != MovementPhase.NORMAL) return false;

        // Start water walking
        ClientMovementState.setPhase(MovementPhase.WATER_WALKING);
        ClientMovementState.setOnWater(true);
        ticksOnWater = 0;

        // Send packet to server
        ClientMovementService.sendAction(player, MovementActionType.WATER_START);

        return true;
    }

    /**
     * Tick water walking logic.
     * Called from ClientMovementService when in WATER_WALKING phase.
     */
    public static void tick(ClientPlayerEntity player) {
        ShinobiCoreConfig.WaterWalkSection cfg = ShinobiCoreConfig.getInstance().waterWalk;

        ticksOnWater++;

        // Check if we should stop water walking
        if (shouldStop(player)) {
            stop(player);
            return;
        }

        // Drain chakra
        float drainPerTick = cfg.drainPerSecond / 20.0f;
        if (!ClientChakraController.spendChakra(drainPerTick)) {
            // Not enough chakra - stop water walking
            stop(player);
            return;
        }

        // Apply speed multiplier
        if (cfg.speedMultiplier != 1.0f) {
            Vec3d velocity = player.getVelocity();
            double horizontalSpeed = Math.sqrt(velocity.x * velocity.x + velocity.z * velocity.z);
            if (horizontalSpeed > 0.01) {
                Vec3d newVelocity = velocity.multiply(cfg.speedMultiplier, 1.0, cfg.speedMultiplier);
                player.setVelocity(newVelocity);
            }
        }

        // Spawn splash particles
        if (cfg.splashParticles && ticksOnWater % 5 == 0) {
            spawnSplashParticles(player);
        }
    }

    /**
     * Stop water walking.
     */
    public static void stop(ClientPlayerEntity player) {
        if (ClientMovementState.getPhase() != MovementPhase.WATER_WALKING) return;

        ClientMovementState.setPhase(MovementPhase.NORMAL);
        ClientMovementState.setOnWater(false);
        ticksOnWater = 0;

        // Send packet to server
        ClientMovementService.sendAction(player, MovementActionType.WATER_STOP);
    }

    /**
     * Check if water walking should stop.
     */
    private static boolean shouldStop(ClientPlayerEntity player) {
        ShinobiCoreConfig.WaterWalkSection cfg = ShinobiCoreConfig.getInstance().waterWalk;

        // Stop if chakra mode is off
        if (!ClientChakraController.isChakraModeActive()) return true;

        // Stop if no longer on water surface
        if (!WaterDetector.isOnWaterSurface(player)) return true;

        // Stop if submerged
        if (WaterDetector.isSubmerged(player)) return true;

        // Stop if sneaking (and config says so)
        if (cfg.disableWhenSneaking && player.isSneaking()) return true;

        // Stop if crawling (and config says so)
        if (cfg.disableWhenCrawling && ClientMovementState.isCrawling()) return true;

        return false;
    }

    /**
     * Spawn splash particles at player's feet.
     */
    private static void spawnSplashParticles(ClientPlayerEntity player) {
        Vec3d pos = player.getPos();
        double waterY = WaterDetector.getWaterSurfaceY(player);

        if (waterY < 0) return;

        // Spawn 2-4 particles
        int count = 2 + player.getWorld().random.nextInt(3);
        for (int i = 0; i < count; i++) {
            double offsetX = (player.getWorld().random.nextDouble() - 0.5) * 0.5;
            double offsetZ = (player.getWorld().random.nextDouble() - 0.5) * 0.5;
            player.getWorld().addParticle(
                ParticleTypes.SPLASH,
                pos.x + offsetX,
                waterY + 0.1,
                pos.z + offsetZ,
                0, 0.1, 0
            );
        }
    }

    public static int getTicksOnWater() {
        return ticksOnWater;
    }
}
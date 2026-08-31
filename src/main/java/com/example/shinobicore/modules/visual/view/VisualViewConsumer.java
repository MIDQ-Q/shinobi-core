package com.example.shinobicore.modules.visual.view;

import com.example.shinobicore.core.view.CoreViews;
import net.minecraft.client.MinecraftClient;
import net.minecraft.entity.player.PlayerEntity;

import java.util.Optional;

/**
 * Safely polls views from other modules.
 * If a module is disabled or its view is not registered, this class handles it gracefully
 * without throwing NullPointerExceptions.
 */
public final class VisualViewConsumer {

    public static void pollViews() {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;
        
        PlayerEntity player = client.player;

        // Example: Safe polling for Movement View
        // Uncomment when movement module registers MovementVisualView
        /*
        CoreViews.get(player, MovementVisualView.class).ifPresent(movement -> {
            if (movement.isWaterWalking()) {
                // MovementVisualListener.emitWaterRipple(player);
            }
            if (movement.isWallRunning()) {
                // MovementVisualListener.emitWallRunDust(player);
            }
        });
        */

        // Example: Safe polling for Jutsu View
        // Uncomment when jutsu module registers JutsuVisualView
        /*
        CoreViews.get(player, JutsuVisualView.class).ifPresent(jutsu -> {
            if (jutsu.isCasting()) {
                // JutsuVisualListener.emitCastParticles(player, jutsu.getElementId());
            }
        });
        */
        
        // Example: Safe polling for Combat View
        /*
        CoreViews.get(player, CombatVisualView.class).ifPresent(combat -> {
            if (combat.isBlocking()) {
                // CombatVisualListener.emitBlockAura(player);
            }
        });
        */
    }
}
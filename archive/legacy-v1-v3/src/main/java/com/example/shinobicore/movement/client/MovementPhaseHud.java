// SHINOBICORE:SPRINT12:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.chakra.client.ChakraClientController;
import com.example.shinobicore.config.FeatureFlags;
import net.fabricmc.fabric.api.client.rendering.v1.HudRenderCallback;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;

/**
 * SPRINT 12 debug HUD.
 * Renders current movement phase, iframes, and chakra on screen.
 */
public final class MovementPhaseHud {
    private MovementPhaseHud() {}

    public static void register() {
        HudRenderCallback.EVENT.register(MovementPhaseHud::render);
    }

    private static void render(DrawContext context, float tickDelta) {
        if (!FeatureFlags.debugMovement) return;
        
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null || client.options.hudHidden) return;

        String phase = ClientMovementState.getPhase().name();
        String iframes = ClientMovementState.isInvulnerable() ? " [IFRAMES]" : "";
        String chakra = String.format("Chakra: %.0f / %.0f", ChakraClientController.getCurrentChakra(), ChakraClientController.getMaxChakra());
        String mode = ChakraClientController.isChakraModeActive() ? " [MODE ON]" : "";
        String meditating = MeditationClient.isActive() ? " [MEDITATING]" : "";

        context.drawText(client.textRenderer, phase + iframes, 10, 10, 0xFFFFFF, true);
        context.drawText(client.textRenderer, chakra + mode + meditating, 10, 20, 0x00FFFF, true);
    }
}
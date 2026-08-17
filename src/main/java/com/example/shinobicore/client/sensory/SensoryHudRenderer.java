package com.example.shinobicore.client.sensory;

import net.fabricmc.fabric.api.client.rendering.v1.HudRenderCallback;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.text.Text;
import net.minecraft.util.math.ColorHelper;

/**
 * S6-02: Danger sense indicator (pulsing red vignette).
 * S6-03: Direction arrow pointing toward nearest threat.
 */
public class SensoryHudRenderer {

    public static void register() {
        HudRenderCallback.EVENT.register(SensoryHudRenderer::render);
    }

    private static void render(DrawContext ctx, float tickDelta) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;

        int sw = client.getWindow().getScaledWidth();
        int sh = client.getWindow().getScaledHeight();

        // === S6-02: DANGER VIGNETTE ===
        if (SensoryClientState.dangerActive) {
            float pulse = (float)(0.3 + 0.2 * Math.sin(System.currentTimeMillis() / 150.0));
            int alpha = (int)(pulse * 255);
            int color = ColorHelper.Argb.getArgb(alpha, 255, 30, 30);

            // Draw vignette edges
            int edgeW = 6;
            ctx.fill(0, 0, sw, edgeW, color);           // top
            ctx.fill(0, sh - edgeW, sw, sh, color);     // bottom
            ctx.fill(0, 0, edgeW, sh, color);           // left
            ctx.fill(sw - edgeW, 0, sw, sh, color);     // right

            // Danger text
            int textAlpha = (int)(180 + 75 * Math.sin(System.currentTimeMillis() / 120.0));
            ctx.drawTextWithShadow(client.textRenderer, Text.literal("!! DANGER !!"),
                sw / 2 - 30, sh / 2 - 50, ColorHelper.Argb.getArgb(textAlpha, 255, 60, 60));
        }

        // === S6-03: DIRECTION ARROW ===
        if (SensoryClientState.directionActive && SensoryClientState.sensoryTier >= 2) {
            float dx = SensoryClientState.directionX;
            float dz = SensoryClientState.directionZ;

            // Calculate angle relative to player facing
            float playerYaw = client.player.getYaw() * ((float) Math.PI / 180f);
            float threatAngle = (float) Math.atan2(dx, dz);
            float relativeAngle = threatAngle - playerYaw;

            // Normalize to -PI..PI
            while (relativeAngle > Math.PI) relativeAngle -= 2 * Math.PI;
            while (relativeAngle < -Math.PI) relativeAngle += 2 * Math.PI;

            // Draw arrow at edge of screen
            int arrowRadius = 60;
            int cx = sw / 2;
            int cy = sh / 2;
            int ax = cx + (int)(Math.sin(relativeAngle) * arrowRadius);
            int ay = cy - (int)(Math.cos(relativeAngle) * arrowRadius);

            int arrowAlpha = (int)(150 + 105 * Math.sin(System.currentTimeMillis() / 200.0));
            int arrowColor = ColorHelper.Argb.getArgb(arrowAlpha, 255, 180, 50);

            // Simple arrow (3 pixels triangle)
            ctx.fill(ax - 2, ay - 2, ax + 2, ay + 2, arrowColor);
            ctx.fill(ax - 1, ay - 4, ax + 1, ay - 2, arrowColor);
            ctx.fill(ax - 1, ay + 2, ax + 1, ay + 4, arrowColor);

            // "Threat nearby" text
            if (SensoryClientState.dangerActive) {
                ctx.drawTextWithShadow(client.textRenderer, Text.literal("\u2191 Threat"),
                    ax - 15, ay + 8, arrowColor);
            }
        }

        // === SCAN COOLDOWN INDICATOR ===
        if (SensoryClientState.sensoryTier >= 3 && SensoryClientState.scanCooldownRemaining > 0) {
            int cdAlpha = 180;
            ctx.drawTextWithShadow(client.textRenderer,
                Text.literal(String.format("Scan CD: %.1fs", SensoryClientState.scanCooldownRemaining)),
                10, sh - 30, ColorHelper.Argb.getArgb(cdAlpha, 100, 200, 255));
        }
    }
}
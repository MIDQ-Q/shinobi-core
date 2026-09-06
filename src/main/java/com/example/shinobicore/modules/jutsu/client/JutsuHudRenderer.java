package com.example.shinobicore.modules.jutsu.client;

import com.example.shinobicore.client.ClientNinjaStateHolder;
import net.fabricmc.fabric.api.client.rendering.v1.HudRenderCallback;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.text.Text;

/**
 * Renders jutsu cast progress bar and selected slot indicator.
 */
public final class JutsuHudRenderer {
    private JutsuHudRenderer() {}

    public static void register() {
        HudRenderCallback.EVENT.register(JutsuHudRenderer::render);
    }

    private static void render(DrawContext ctx, float tickDelta) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;

        int sw = client.getWindow().getScaledWidth();
        int sh = client.getWindow().getScaledHeight();

        // Cast progress bar (center-bottom)
        if (JutsuClientState.isCasting()) {
            float progress = JutsuClientState.getCastProgress();
            String jutsuName = ClientNinjaStateHolder.get().getName(
                JutsuClientState.getCurrentJutsuId());
            int barW = 120, barH = 6;
            int bx = (sw - barW) / 2;
            int by = sh / 2 + 50;

            // Background
            ctx.fill(bx - 1, by - 1, bx + barW + 1, by + barH + 1, 0xFF000000);
            ctx.fill(bx, by, bx + barW, by + barH, 0xFF222222);

            // Fill
            int fillW = (int)(barW * progress);
            int color = "PREPARE".equals(JutsuClientState.getCastPhase())
                ? 0xFFFFAA00 : 0xFF44AAFF;
            ctx.fill(bx, by, bx + fillW, by + barH, color);

            // Label
            String label = jutsuName.isEmpty()
                ? JutsuClientState.getCurrentJutsuId() : jutsuName;
            int tw = client.textRenderer.getWidth(label);
            ctx.drawTextWithShadow(client.textRenderer,
                Text.literal(label), (sw - tw) / 2, by - 12, 0xFFFFFFFF);
        }

        // Selected slot indicator (bottom-right, above hotbar)
        int activeA = ClientNinjaStateHolder.get().getActive(0);
        String activeName = ClientNinjaStateHolder.get().getName(
            ClientNinjaStateHolder.get().getActiveJutsuId(0));
        if (!activeName.isEmpty()) {
            String slotText = "[A" + (activeA + 1) + "] " + activeName;
            int tw = client.textRenderer.getWidth(slotText);
            ctx.drawTextWithShadow(client.textRenderer,
                Text.literal(slotText), sw - tw - 10, sh - 60, 0xFF88CCFF);
        }
    }
}
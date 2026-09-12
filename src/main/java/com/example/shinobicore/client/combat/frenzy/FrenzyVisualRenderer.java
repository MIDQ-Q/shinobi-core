package com.example.shinobicore.client.combat.frenzy;

import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;

/**
 * Combat Pack v1 (1.1.4): красный оверлей и виньетка боевого ража.
 * Рисуется в HUD-слое; регистрируется из FrenzyClientState.register().
 */
public final class FrenzyVisualRenderer {

    private FrenzyVisualRenderer() {}

    public static void render(DrawContext ctx, float tickDelta) {
        int alpha = FrenzyClientState.getOverlayAlpha();
        if (alpha <= 0) return;
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;
        int w = client.getWindow().getScaledWidth();
        int h = client.getWindow().getScaledHeight();

        // 1) лёгкая красная тонировка всего экрана
        int tint = (Math.min(alpha, 90) << 24) | 0x8A1010;
        ctx.fill(0, 0, w, h, tint);

        // 2) виньетка: четыре градиента от краёв (темно-красные)
        int vig = (Math.min(alpha + 40, 150) << 24) | 0x3A0000;
        int vigT = 0x00000000;
        int band = Math.max(24, h / 4);
        int bandX = Math.max(24, w / 5);
        ctx.fillGradient(0, 0, w, band, vig, vigT);            // верх
        ctx.fillGradient(0, h - band, w, h, vigT, vig);        // низ
        ctx.fillGradient(0, 0, bandX, h, vig, vigT);           // лево
        ctx.fillGradient(w - bandX, 0, w, h, vigT, vig);       // право

        // 3) индикатор уровня и остатка (маленькая полоска внизу по центру)
        int level = FrenzyClientState.getLevel();
        if (level > 0) {
            int barW = 90;
            int barH = 3;
            int x0 = (w - barW) / 2;
            int y0 = h - 34;
            ctx.fill(x0 - 1, y0 - 1, x0 + barW + 1, y0 + barH + 1, 0xAA000000);
            int fillW = (int) (barW * Math.min(1f, FrenzyClientState.getRemainingMs() / 5000f));
            int col = 0xFF3030 | ((0xC0 - level * 0x18) << 24);
            ctx.fill(x0, y0, x0 + fillW, y0 + barH, col);
            String label = "FRENZY " + level;
            int tw = client.textRenderer.getWidth(label);
            ctx.drawTextWithShadow(client.textRenderer, label, (w - tw) / 2, y0 - 11, 0xFFFF5555);
        }
    }
}
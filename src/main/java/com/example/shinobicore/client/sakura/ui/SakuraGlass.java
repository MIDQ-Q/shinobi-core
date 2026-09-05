package com.example.shinobicore.client.sakura.ui;

import net.minecraft.client.gui.DrawContext;

public final class SakuraGlass {
    private SakuraGlass() {}

    public static void drawPanel(DrawContext ctx, int x, int y, int w, int h) {
        ctx.fill(x - 1, y - 1, x + w + 1, y + h + 1, 0x990D0810);
        SakuraTextures.drawPanel(ctx, x, y, w, h);
        ctx.fill(x + 2, y + 1, x + w - 2, y + 2, SakuraTheme.GLASS_HILIGHT);
        ctx.fill(x, y, x + w, y + 1, SakuraTheme.GLASS_EDGE);
        ctx.fill(x, y + h - 1, x + w, y + h, SakuraTheme.GLASS_EDGE);
        ctx.fill(x, y, x + 1, y + h, SakuraTheme.GLASS_EDGE);
        ctx.fill(x + w - 1, y, x + w, y + h, SakuraTheme.GLASS_EDGE);
    }

    public static void drawPanelNoBorder(DrawContext ctx, int x, int y, int w, int h) {
        ctx.fill(x - 2, y - 2, x + w + 2, y + h + 2, 0x990D0810);
        SakuraTextures.drawPanel(ctx, x, y, w, h);
        ctx.fill(x + 2, y + 1, x + w - 2, y + 2, SakuraTheme.GLASS_HILIGHT);
    }

    public static void drawShadow(DrawContext ctx, int x, int y, int w, int h) {
        ctx.fill(x - 3, y + h, x + w + 3, y + h + 3, 0x22000000);
        ctx.fill(x - 2, y + h, x + w + 2, y + h + 2, 0x33000000);
        ctx.fill(x - 1, y + h, x + w + 1, y + h + 1, 0x44000000);
    }

    public static void drawGlowRect(DrawContext ctx, int x, int y, int w, int h, int glowColor, int fillColor) {
        ctx.fill(x - 3, y - 3, x + w + 3, y + h + 3, glowColor & 0x11FFFFFF);
        ctx.fill(x - 2, y - 2, x + w + 2, y + h + 2, glowColor & 0x22FFFFFF);
        ctx.fill(x - 1, y - 1, x + w + 1, y + h + 1, glowColor & 0x33FFFFFF);
        ctx.fill(x, y, x + w, y + h, fillColor);
    }
}
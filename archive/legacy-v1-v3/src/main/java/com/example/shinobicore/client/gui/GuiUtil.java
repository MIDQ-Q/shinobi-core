package com.example.shinobicore.client.gui;

import net.minecraft.client.gui.DrawContext;

/**
* SPRINT B: Shared drawing helpers for the parchment/ink UI.
*/
public final class GuiUtil {
    private GuiUtil() {}

    /** Draws a 1px rectangular border using four fills (avoids API uncertainty). */
    public static void drawBorder(DrawContext context, int x, int y, int w, int h, int color) {
        context.fill(x, y, x + w, y + 1, color);
        context.fill(x, y + h - 1, x + w, y + h, color);
        context.fill(x, y, x + 1, y + h, color);
        context.fill(x + w - 1, y, x + w, y + h, color);
    }

    /** Draws a parchment panel with an ink outer border and a lighter inner edge. */
    public static void drawPanel(DrawContext context, int x, int y, int w, int h) {
        context.fill(x, y, x + w, y + h, ShinobiColors.PANEL_BG);
        drawBorder(context, x, y, w, h, ShinobiColors.INK);
        drawBorder(context, x + 2, y + 2, w - 4, h - 4, ShinobiColors.PANEL_EDGE);
    }
}
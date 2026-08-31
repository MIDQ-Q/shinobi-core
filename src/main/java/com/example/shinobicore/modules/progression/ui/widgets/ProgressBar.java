package com.example.shinobicore.modules.progression.ui.widgets;

import net.minecraft.client.gui.DrawContext;

public final class ProgressBar {
    private final int x, y, width, height;
    private final int bgColor, fillColor;

    public ProgressBar(int x, int y, int width, int height, int bgColor, int fillColor) {
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;
        this.bgColor = bgColor;
        this.fillColor = fillColor;
    }

    public void render(DrawContext ctx, float progress) {
        ctx.fill(x, y, x + width, y + height, bgColor);
        int fillWidth = (int)(width * Math.max(0, Math.min(1, progress)));
        if (fillWidth > 0) {
            ctx.fill(x, y, x + fillWidth, y + height, fillColor);
        }
    }
}
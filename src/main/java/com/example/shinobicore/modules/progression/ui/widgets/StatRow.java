package com.example.shinobicore.modules.progression.ui.widgets;

import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.font.TextRenderer;

public final class StatRow {
    private final int x, y;
    private final String label;
    private final int value;

    public StatRow(int x, int y, String label, int value) {
        this.x = x;
        this.y = y;
        this.label = label;
        this.value = value;
    }

    public void render(DrawContext ctx, TextRenderer textRenderer) {
        ctx.drawTextWithShadow(textRenderer, label + ": " + value, x, y, 0xFFFFFF);
    }
}
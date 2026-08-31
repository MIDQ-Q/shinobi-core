package com.example.shinobicore.modules.progression.ui.widgets;

import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.font.TextRenderer;

public final class TooltipCard {
    private final int x, y, width, height;
    private final String title;
    private final String description;

    public TooltipCard(int x, int y, int width, int height, String title, String description) {
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;
        this.title = title;
        this.description = description;
    }

    public void render(DrawContext ctx, TextRenderer textRenderer) {
        ctx.fill(x, y, x + width, y + height, 0xEE111111);
        ctx.drawTextWithShadow(textRenderer, title, x + 5, y + 5, 0xFFFF00);
        ctx.drawTextWithShadow(textRenderer, description, x + 5, y + 18, 0xCCCCCC);
    }
}
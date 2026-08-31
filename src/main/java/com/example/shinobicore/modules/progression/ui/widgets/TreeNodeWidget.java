package com.example.shinobicore.modules.progression.ui.widgets;

import net.minecraft.client.gui.DrawContext;

public final class TreeNodeWidget {
    private final int x, y, size;
    private final String icon;
    private final boolean unlocked;
    private final boolean available;

    public TreeNodeWidget(int x, int y, int size, String icon, boolean unlocked, boolean available) {
        this.x = x;
        this.y = y;
        this.size = size;
        this.icon = icon;
        this.unlocked = unlocked;
        this.available = available;
    }

    public void render(DrawContext ctx, net.minecraft.client.font.TextRenderer textRenderer) {
        int color;
        if (unlocked) color = 0xFF00FF00;
        else if (available) color = 0xFFFFFF00;
        else color = 0xFF555555;

        ctx.fill(x, y, x + size, y + size, 0xFF222222);
        ctx.fill(x + 1, y + 1, x + size - 1, y + size - 1, color);
        ctx.drawCenteredTextWithShadow(textRenderer, icon, x + size / 2, y + size / 2 - 4, 0x000000);
    }

    public boolean isMouseOver(double mouseX, double mouseY) {
        return mouseX >= x && mouseX <= x + size && mouseY >= y && mouseY <= y + size;
    }
}
package com.example.shinobicore.client.gui.widget;

import com.example.shinobicore.client.gui.GuiUtil;
import com.example.shinobicore.client.gui.ShinobiColors;
import net.minecraft.client.font.TextRenderer;
import net.minecraft.client.gui.DrawContext;

/**
* SPRINT B: Parchment tab button with ink border.
*/
public class TabButton {
    private final int x;
    private final int y;
    private final int width;
    private final int height;
    private final String label;

    public TabButton(int x, int y, int width, int height, String label) {
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;
        this.label = label;
    }

    public boolean isMouseOver(double mouseX, double mouseY) {
        return mouseX >= x && mouseX < x + width && mouseY >= y && mouseY < y + height;
    }

    public void render(DrawContext context, TextRenderer textRenderer, boolean active,
                       int mouseX, int mouseY, float delta) {
        boolean hovered = isMouseOver(mouseX, mouseY);
        int bg;
        if (active) {
            bg = ShinobiColors.TAB_ACTIVE;
        } else if (hovered) {
            bg = ShinobiColors.TAB_HOVER;
        } else {
            bg = ShinobiColors.TAB_INACTIVE;
        }
        context.fill(x, y, x + width, y + height, bg);
        GuiUtil.drawBorder(context, x, y, width, height, ShinobiColors.INK);

        int textWidth = textRenderer.getWidth(label);
        int textColor = active ? ShinobiColors.TEXT_LIGHT : ShinobiColors.TEXT_DIM;
        context.drawText(textRenderer, label, x + (width - textWidth) / 2,
                y + (height - 8) / 2, textColor, false);
    }
}
package com.example.shinobicore.client.gui.widget;

import com.example.shinobicore.client.gui.GuiUtil;
import com.example.shinobicore.client.gui.ShinobiColors;
import net.minecraft.client.gui.DrawContext;

/**
* SPRINT B: Parchment-style progress bar with ink border.
*/
public class ProgressBar {
    private int x;
    private int y;
    private final int width;
    private final int height;
    private float progress;

    public ProgressBar(int x, int y, int width, int height) {
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;
        this.progress = 0f;
    }

    public void setPosition(int x, int y) {
        this.x = x;
        this.y = y;
    }

    public void setProgress(float progress) {
        if (progress < 0f) progress = 0f;
        if (progress > 1f) progress = 1f;
        this.progress = progress;
    }

    public void render(DrawContext context) {
        context.fill(x, y, x + width, y + height, ShinobiColors.BAR_BG);
        int fillWidth = (int) (width * progress);
        if (fillWidth > 0) {
            context.fill(x, y, x + fillWidth, y + height, ShinobiColors.BAR_FILL);
        }
        GuiUtil.drawBorder(context, x, y, width, height, ShinobiColors.BAR_BORDER);
    }
}
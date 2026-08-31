package com.example.shinobicore.client.gui.widget;

import com.example.shinobicore.client.gui.GuiUtil;
import com.example.shinobicore.client.gui.ShinobiColors;
import com.example.shinobicore.stat.component.IStatsComponent;
import com.example.shinobicore.stat.component.StatType;
import net.minecraft.client.font.TextRenderer;
import net.minecraft.client.gui.DrawContext;

/**
* SPRINT B: A single stat row: colored icon, name+level, progress bar, XP fraction.
* Uses only StatType constants known to exist; unknown/new stats fall to default color.
*/
public class StatRow {
    private final StatType stat;
    private final ProgressBar progressBar;

    public StatRow(StatType stat) {
        this.stat = stat;
        this.progressBar = new ProgressBar(0, 0, 110, 8);
    }

    public void render(DrawContext context, TextRenderer textRenderer, IStatsComponent stats,
                       int x, int y, int width) {
        int level = stats.getStatLevel(stat);
        int xp = stats.getStatXp(stat);
        int required = stats.getXpForNextLevel(stat);
        float progress = required > 0 ? Math.min(1f, (float) xp / (float) required) : 0f;

        // Colored category icon
        int iconColor = getStatColor(stat);
        context.fill(x, y + 1, x + 10, y + 11, iconColor);
        GuiUtil.drawBorder(context, x, y + 1, 10, 10, ShinobiColors.INK);

        // Name + level
        String label = stat.getDisplayName() + " Lv." + level;
        context.drawText(textRenderer, label, x + 16, y + 2, ShinobiColors.TEXT_LIGHT, false);

        // Progress bar (right side)
        int barWidth = 110;
        int barX = x + width - barWidth - 55;
        progressBar.setPosition(barX, y + 3);
        progressBar.setProgress(progress);
        progressBar.render(context);

        // XP fraction text
        String xpText = xp + "/" + required;
        context.drawText(textRenderer, xpText, x + width - 50, y + 2, ShinobiColors.TEXT_DIM, false);
    }

    private int getStatColor(StatType stat) {
        switch (stat) {
            case TAIJUTSU:
            case KENJUTSU:
            case SHURIKEN:
            case GENJUTSU:
            case NINJUTSU:
                return ShinobiColors.CAT_COMBAT;
            case CONTROL:
                return ShinobiColors.CAT_CHAKRA;
            case PERCEPTION:
            case MEDICAL:
            case SPACE_TIME:
                return ShinobiColors.CAT_UTILITY;
            case NATURE_FIRE:
            case NATURE_WATER:
            case NATURE_WIND:
            case NATURE_EARTH:
            case NATURE_LIGHTNING:
                return ShinobiColors.CAT_ELEMENT;
            default:
                return ShinobiColors.CAT_UTILITY;
        }
    }
}
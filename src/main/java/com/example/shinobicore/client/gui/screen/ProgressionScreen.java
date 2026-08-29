package com.example.shinobicore.client.gui.screen;

import com.example.shinobicore.client.gui.GuiUtil;
import com.example.shinobicore.client.gui.ShinobiColors;
import com.example.shinobicore.client.gui.widget.StatRow;
import com.example.shinobicore.client.gui.widget.TabButton;
import com.example.shinobicore.stat.component.IClanComponent;
import com.example.shinobicore.stat.component.IStatsComponent;
import com.example.shinobicore.stat.component.NinjaComponents;
import com.example.shinobicore.stat.component.StatType;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.gui.screen.Screen;
import net.minecraft.text.Text;

import java.util.ArrayList;
import java.util.List;

/**
* SPRINT B: Main progression hub screen, opened with K.
* Parchment/ink themed with 5 tabs. Stats tab implemented;
* Tree/Attunement/Settings are placeholders for Sprints C/D/E.
*/
public class ProgressionScreen extends Screen {
    private static final int TAB_COUNT = 5;
    private static final String[] TAB_LABELS = { "Stats", "Tree", "Attunement", "Clans", "Settings" };
    private static final int ROW_HEIGHT = 14;

    private int activeTab = 0;
    private int scrollOffset = 0;
    private final List<TabButton> tabs = new ArrayList<>();
    private final List<StatRow> statRows = new ArrayList<>();

    public ProgressionScreen() {
        super(Text.literal("Progression"));
    }

    @Override
    protected void init() {
        super.init();
        rebuildTabs();
        statRows.clear();
        for (StatType stat : StatType.values()) {
            statRows.add(new StatRow(stat));
        }
    }

    private void rebuildTabs() {
        tabs.clear();
        int panelW = panelWidth();
        int panelX = panelX();
        int tabY = panelY() + 18;
        int tabWidth = panelW / TAB_COUNT;
        for (int i = 0; i < TAB_COUNT; i++) {
            tabs.add(new TabButton(panelX + i * tabWidth, tabY, tabWidth, 20, TAB_LABELS[i]));
        }
    }

    private int panelWidth() { return Math.min(420, this.width - 20); }
    private int panelHeight() { return Math.min(300, this.height - 20); }
    private int panelX() { return (this.width - panelWidth()) / 2; }
    private int panelY() { return (this.height - panelHeight()) / 2; }
    private int contentY() { return panelY() + 40; }
    private int contentHeight() { return Math.max(40, panelHeight() - 46); }

    @Override
    public void render(DrawContext context, int mouseX, int mouseY, float delta) {
        // Dark overlay background
        context.fill(0, 0, this.width, this.height, ShinobiColors.BG_OVERLAY);

        int px = panelX();
        int py = panelY();
        int pw = panelWidth();
        int ph = panelHeight();

        GuiUtil.drawPanel(context, px, py, pw, ph);

        // Title
        context.drawCenteredTextWithShadow(this.textRenderer, "Shinobi Progression",
                px + pw / 2, py + 7, ShinobiColors.TEXT_TITLE);

        // Tabs
        for (int i = 0; i < tabs.size(); i++) {
            tabs.get(i).render(context, this.textRenderer, i == activeTab, mouseX, mouseY, delta);
        }

        int contentY = contentY();
        int contentH = contentHeight();

        switch (activeTab) {
            case 0:
                renderStatsTab(context, mouseX, mouseY, px, contentY, pw, contentH);
                break;
            case 1:
                renderPlaceholder(context, "Skill Tree (Sprint C)", px, contentY, pw, contentH);
                break;
            case 2:
                renderPlaceholder(context, "Attunement (Sprint D)", px, contentY, pw, contentH);
                break;
            case 3:
                renderClansTab(context, px, contentY, pw, contentH);
                break;
            case 4:
                renderPlaceholder(context, "Settings (Sprint E)", px, contentY, pw, contentH);
                break;
            default:
                break;
        }

        super.render(context, mouseX, mouseY, delta);
    }

    private void renderStatsTab(DrawContext context, int mouseX, int mouseY,
                                int px, int contentY, int pw, int contentH) {
        MinecraftClient mc = MinecraftClient.getInstance();
        if (mc.player == null) return;
        IStatsComponent stats = NinjaComponents.getStats(mc.player);
        if (stats == null) return;

        int listX = px + 10;
        int listWidth = pw - 20;
        int scrollAreaHeight = contentH - 16;
        int totalHeight = statRows.size() * ROW_HEIGHT;
        int maxScroll = Math.max(0, totalHeight - scrollAreaHeight);
        if (scrollOffset > maxScroll) scrollOffset = maxScroll;
        if (scrollOffset < 0) scrollOffset = 0;

        int y = contentY + 2 - scrollOffset;
        for (StatRow row : statRows) {
            if (y + ROW_HEIGHT > contentY && y < contentY + scrollAreaHeight) {
                row.render(context, this.textRenderer, stats, listX, y, listWidth);
            }
            y += ROW_HEIGHT;
        }

        // SP display at bottom
        int sp = stats.getSkillPoints();
        context.drawText(this.textRenderer, "SP: " + sp, listX,
                contentY + contentH - 12, ShinobiColors.TEXT_LIGHT, false);
    }

    private void renderClansTab(DrawContext context, int px, int contentY, int pw, int contentH) {
        MinecraftClient mc = MinecraftClient.getInstance();
        if (mc.player == null) return;
        IClanComponent clan = NinjaComponents.getClan(mc.player);
        String clanName = "None";
        if (clan != null && clan.getClanId() != null && !clan.getClanId().isEmpty()) {
            clanName = clan.getClanId();
        }
        context.drawCenteredTextWithShadow(this.textRenderer, "Clan: " + clanName,
                px + pw / 2, contentY + 24, ShinobiColors.TEXT_LIGHT);
        context.drawCenteredTextWithShadow(this.textRenderer, "Clan progression coming soon",
                px + pw / 2, contentY + 44, ShinobiColors.TEXT_DIM);
    }

    private void renderPlaceholder(DrawContext context, String message,
                                   int px, int contentY, int pw, int contentH) {
        context.drawCenteredTextWithShadow(this.textRenderer, message,
                px + pw / 2, contentY + contentH / 2, ShinobiColors.TEXT_DIM);
    }

    @Override
    public boolean mouseClicked(double mouseX, double mouseY, int button) {
        if (button == 0) {
            for (int i = 0; i < tabs.size(); i++) {
                if (tabs.get(i).isMouseOver(mouseX, mouseY)) {
                    activeTab = i;
                    scrollOffset = 0;
                    return true;
                }
            }
        }
        return super.mouseClicked(mouseX, mouseY, button);
    }

    @Override
    public boolean mouseScrolled(double mouseX, double mouseY, double amount) {
        if (activeTab == 0) {
            scrollOffset -= (int) (amount * 12);
            return true;
        }
        return super.mouseScrolled(mouseX, mouseY, amount);
    }

    @Override
    public boolean shouldPause() {
        return false;
    }
}
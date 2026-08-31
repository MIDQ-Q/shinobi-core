package com.example.shinobicore.modules.progression.ui;

import com.example.shinobicore.modules.progression.client.ProgressionClientState;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.gui.screen.Screen;
import net.minecraft.client.gui.widget.ButtonWidget;
import net.minecraft.text.Text;

public final class ProgressionHubTab extends Screen {
    private static final String[] TAB_NAMES = {
        "Progression", "Skill Tree", "Attunement", "Stats", "Jutsu Slots", "Clan"
    };
    private int activeTab = 0;

    public ProgressionHubTab() {
        super(Text.literal("Progression"));
    }

    @Override
    protected void init() {
        super.init();
        int buttonWidth = 80;
        int startX = (width - TAB_NAMES.length * (buttonWidth + 5)) / 2;

        for (int i = 0; i < TAB_NAMES.length; i++) {
            final int tabIndex = i;
            int x = startX + i * (buttonWidth + 5);
            addDrawableChild(ButtonWidget.builder(
                Text.literal(TAB_NAMES[i]),
                btn -> activeTab = tabIndex
            ).position(x, 20).size(buttonWidth, 20).build());
        }
    }

    @Override
    public void render(DrawContext ctx, int mouseX, int mouseY, float delta) {
        renderBackground(ctx);
        super.render(ctx, mouseX, mouseY, delta);

        int level = ProgressionClientState.level;
        int xp = ProgressionClientState.xp;
        int sp = ProgressionClientState.sp;

        switch (activeTab) {
            case 0 -> renderProgressionTab(ctx, level, xp, sp);
            case 1 -> renderTreeTab(ctx);
            case 2 -> renderAttunementTab(ctx);
            case 3 -> renderStatsTab(ctx);
            case 4 -> renderJutsuSlotsTab(ctx);
            case 5 -> renderClanTab(ctx);
        }
    }

    private void renderProgressionTab(DrawContext ctx, int level, int xp, int sp) {
        ctx.drawCenteredTextWithShadow(textRenderer, "Level: " + level, width / 2, 60, 0xFFFF00);
        ctx.drawCenteredTextWithShadow(textRenderer, "XP: " + xp, width / 2, 80, 0xFFFFFF);
        ctx.drawCenteredTextWithShadow(textRenderer, "SP: " + sp, width / 2, 100, 0x00FF00);
    }

    private void renderTreeTab(DrawContext ctx) {
        ctx.drawCenteredTextWithShadow(textRenderer, "Skill Tree (zoom/pan)", width / 2, 60, 0xFFFFFF);
    }

    private void renderAttunementTab(DrawContext ctx) {
        ctx.drawCenteredTextWithShadow(textRenderer, "Attunement", width / 2, 60, 0xFFFFFF);
    }

    private void renderStatsTab(DrawContext ctx) {
        int y = 60;
        ctx.drawCenteredTextWithShadow(textRenderer, "=== Stats ===", width / 2, y, 0xFFFF00);
        y += 20;
        for (var entry : ProgressionClientState.statLevels.entrySet()) {
            ctx.drawCenteredTextWithShadow(textRenderer,
                entry.getKey() + ": " + entry.getValue(), width / 2, y, 0xFFFFFF);
            y += 12;
        }
    }

    private void renderJutsuSlotsTab(DrawContext ctx) {
        ctx.drawCenteredTextWithShadow(textRenderer, "Jutsu Slots", width / 2, 60, 0xFFFFFF);
    }

    private void renderClanTab(DrawContext ctx) {
        ctx.drawCenteredTextWithShadow(textRenderer, "Clan Info (read-only)", width / 2, 60, 0xFFFFFF);
    }

    @Override
    public boolean shouldPause() { return false; }
}
// SHINOBICORE:SPRINT18:FILE
package com.example.shinobicore.client.gui.screen;

import com.example.shinobicore.client.network.ProgressionV3ClientPackets;
import com.example.shinobicore.progression.v3.ProgressionClientState;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.gui.screen.Screen;
import net.minecraft.client.gui.widget.ButtonWidget;
import net.minecraft.text.Text;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * SPRINT 18 progression hub screen.
 * Tabs: Stats, Tree, Attunement, Settings.
 */
public class ProgressionHubScreen extends Screen {
    private int selectedTab = 0;

    private final List<ButtonWidget> statButtons = new ArrayList<>();

    public ProgressionHubScreen() {
        super(Text.literal("Progression"));
    }

    @Override
    protected void init() {
        this.clearChildren();
        this.statButtons.clear();

        int centerX = this.width / 2;

        addDrawableChild(ButtonWidget.builder(Text.literal("Stats"), button -> {
                    selectedTab = 0;
                })
                .dimensions(centerX - 152, 18, 72, 20)
                .build());

        addDrawableChild(ButtonWidget.builder(Text.literal("Tree"), button -> {
                    selectedTab = 1;
                })
                .dimensions(centerX - 76, 18, 72, 20)
                .build());

        addDrawableChild(ButtonWidget.builder(Text.literal("Attunement"), button -> {
                    selectedTab = 2;
                })
                .dimensions(centerX, 18, 72, 20)
                .build());

        addDrawableChild(ButtonWidget.builder(Text.literal("Settings"), button -> {
                    selectedTab = 3;
                })
                .dimensions(centerX + 76, 18, 72, 20)
                .build());

        int y = 80;

        for (String stat : new ArrayList<>(ProgressionClientState.getStatLevels().keySet())) {
            ButtonWidget button = ButtonWidget.builder(Text.literal("+"), b -> {
                        ProgressionV3ClientPackets.sendSpendStat(stat);
                    })
                    .dimensions(centerX + 110, y - 2, 20, 16)
                    .build();

            statButtons.add(button);
            addDrawableChild(button);

            y += 18;
        }
    }

    @Override
    public void render(DrawContext context, int mouseX, int mouseY, float delta) {
        context.fill(0, 0, this.width, this.height, 0xC8100C08);

        context.drawCenteredTextWithShadow(
                this.textRenderer,
                this.title,
                this.width / 2,
                6,
                0xFFF0E6C8
        );

        for (ButtonWidget button : statButtons) {
            button.visible = selectedTab == 0;
            button.active = ProgressionClientState.getSp() > 0;
        }

        int x = 24;
        int y = 50;

        if (selectedTab == 0) {
            context.drawText(this.textRenderer, "Level: " + ProgressionClientState.getLevel(), x, y, 0xFFFF55, false);
            context.drawText(this.textRenderer, "XP: " + ProgressionClientState.getXp(), x, y + 12, 0x55FFFF, false);
            context.drawText(this.textRenderer, "SP: " + ProgressionClientState.getSp(), x, y + 24, 0x55FF55, false);

            y += 46;

            if (ProgressionClientState.getStatLevels().isEmpty()) {
                context.drawText(this.textRenderer, "No stats yet. Fight, move, or meditate to gain XP.", x, y, 0xAAAAAA, false);
            } else {
                for (Map.Entry<String, Integer> entry : ProgressionClientState.getStatLevels().entrySet()) {
                    String stat = entry.getKey();
                    int level = entry.getValue();
                    int xp = ProgressionClientState.getStatXp().getOrDefault(stat, 0);

                    context.drawText(
                            this.textRenderer,
                            stat + " Lv." + level + "  XP: " + xp,
                            x,
                            y,
                            0xFFE8DCC0,
                            false
                    );

                    y += 18;
                }
            }
        } else if (selectedTab == 1) {
            context.drawText(this.textRenderer, "Skill Tree", x, y, 0xFFF0E6C8, false);
            context.drawText(this.textRenderer, "Coming in a future sprint.", x, y + 14, 0xAAAAAA, false);
        } else if (selectedTab == 2) {
            context.drawText(this.textRenderer, "Attunement", x, y, 0xFFF0E6C8, false);
            context.drawText(this.textRenderer, "Element alignment coming in a future sprint.", x, y + 14, 0xAAAAAA, false);
        } else if (selectedTab == 3) {
            context.drawText(this.textRenderer, "Settings", x, y, 0xFFF0E6C8, false);
            context.drawText(this.textRenderer, "Progression UI settings coming in a future sprint.", x, y + 14, 0xAAAAAA, false);
        }

        super.render(context, mouseX, mouseY, delta);
    }

    @Override
    public boolean shouldPause() {
        return false;
    }
}
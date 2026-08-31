// SHINOBICORE:SPRINT13:FILE
package com.example.shinobicore.client.gui.screen;

import com.example.shinobicore.progression.v3.ProgressionClientState;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.gui.screen.Screen;
import net.minecraft.text.Text;

/**
 * SPRINT 13 minimal progression screen.
 * Opened with K key.
 */
public class ProgressionV3Screen extends Screen {

    public ProgressionV3Screen() {
        super(Text.literal("Progression V3"));
    }

    @Override
    public void render(DrawContext context, int mouseX, int mouseY, float delta) {
        context.fill(0, 0, this.width, this.height, 0xC0101010);

        context.drawCenteredTextWithShadow(
                this.textRenderer,
                this.title,
                this.width / 2,
                20,
                0xFFFFFF
        );

        context.drawText(
                this.textRenderer,
                "Level: " + ProgressionClientState.getLevel(),
                20,
                45,
                0xFFFF55,
                false
        );

        context.drawText(
                this.textRenderer,
                "XP: " + ProgressionClientState.getXp(),
                20,
                57,
                0x55FFFF,
                false
        );

        context.drawText(
                this.textRenderer,
                "SP: " + ProgressionClientState.getSp(),
                20,
                69,
                0x55FF55,
                false
        );

        context.drawText(
                this.textRenderer,
                "Sprint 13 foundation. Server sync will be added later.",
                20,
                90,
                0xAAAAAA,
                false
        );

        super.render(context, mouseX, mouseY, delta);
    }
}
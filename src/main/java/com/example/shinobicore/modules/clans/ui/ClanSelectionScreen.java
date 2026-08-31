package com.example.shinobicore.modules.clans.ui;

import com.example.shinobicore.modules.clans.data.ClanDefinition;
import com.example.shinobicore.modules.clans.data.ClanRegistry;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.gui.screen.Screen;
import net.minecraft.client.gui.widget.ButtonWidget;
import net.minecraft.text.Text;
import net.minecraft.util.Formatting;

public class ClanSelectionScreen extends Screen {
    private final Screen parent;

    public ClanSelectionScreen(Screen parent) {
        super(Text.literal("Clan Selection"));
        this.parent = parent;
    }

    @Override
    protected void init() {
        super.init();
        int y = 40;
        for (ClanDefinition clan : ClanRegistry.all()) {
            String label = clan.name() + " [" + clan.affinity() + "]";
            addDrawableChild(ButtonWidget.builder(Text.literal(label), button -> {
                // Note: Actual clan change must be done via server command or packet.
                // This is a visual placeholder for operator UI.
                if (client != null && client.player != null) {
                    client.player.networkHandler.sendChatCommand("shinobicore clan set @s " + clan.id());
                }
                close();
            }).dimensions(this.width / 2 - 100, y, 200, 20).build());
            y += 24;
        }
    }

    @Override
    public void render(DrawContext context, int mouseX, int mouseY, float delta) {
        super.render(context, mouseX, mouseY, delta);
        context.drawCenteredTextWithShadow(this.textRenderer, Text.literal("Select Clan").formatted(Formatting.GOLD), this.width / 2, 20, 0xFFFFFF);
    }

    @Override
    public void close() {
        if (this.client != null) {
            this.client.setScreen(this.parent);
        }
    }
}
package com.example.shinobicore.client.hud.sections;

import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.client.ChakraHudRenderer;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.text.Text;
import net.minecraft.util.math.ColorHelper;
import com.example.shinobicore.client.ClientNinjaStateHolder;

public final class StatusIndicatorsSection {
    private StatusIndicatorsSection() {}

    public static int render(DrawContext context, MinecraftClient client, int x, int y) {
        if (ClientNinjaStateHolder.get().isChakraMode()) {
            int alpha = (int) (150 + 105 * Math.sin(System.currentTimeMillis() / 200.0));
            context.drawTextWithShadow(client.textRenderer, Text.literal("CHAKRA MODE"), x, y,
                ColorHelper.Argb.getArgb(alpha, 255, 136, 0));
            y += 10;
        }
        if (ChakraHudRenderer.exhausted) {
            context.drawTextWithShadow(client.textRenderer, Text.literal("EXHAUSTED"), x, y, 0xFF3333);
            y += 10;
        }
        if (ClientNinjaStateHolder.get().getUnlockedNodes().contains("sen_glow")) {
            context.drawTextWithShadow(client.textRenderer,
                Text.literal(ClientNinjaStateHolder.get().isSensoryEnabled() ? "SENSORY ON" : "SENSORY OFF"),
                x, y, ClientNinjaStateHolder.get().isSensoryEnabled() ? 0xFF66DDFF : 0xFF666666);
            y += 10;
        }
        if (ClientNinjaStateHolder.get().isDangerSense()) {
            int alpha = (int) (150 + 105 * Math.sin(System.currentTimeMillis() / 150.0));
            context.drawTextWithShadow(client.textRenderer, Text.literal("!! DANGER !!"), x, y,
                ColorHelper.Argb.getArgb(alpha, 255, 60, 60));
            y += 10;
        }
        return y;
    }
}
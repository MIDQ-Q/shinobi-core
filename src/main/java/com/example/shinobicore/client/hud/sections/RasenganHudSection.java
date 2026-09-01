package com.example.shinobicore.client.hud.sections;

import com.example.shinobicore.client.RasenganClientState;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.text.Text;
import net.minecraft.util.math.ColorHelper;

public final class RasenganHudSection {
    private RasenganHudSection() {}

    public static int render(DrawContext context, MinecraftClient client, int x, int y) {
        if (RasenganClientState.charging) {
            float progress = RasenganClientState.chargeProgress;
            int barW = 60, barH = 4;
            context.fill(x, y + 8, x + barW, y + 8 + barH, 0xCC222222);
            context.fill(x, y + 8, x + (int)(barW * progress), y + 8 + barH, 0xFF44AAFF);
            context.drawTextWithShadow(client.textRenderer, Text.literal("RASENGAN " + (int)(progress * 100) + "%"),
                x, y + 14, 0xFF44AAFF);
            y += 24;
        }
        if (RasenganClientState.ready) {
            int alpha = (int)(150 + 105 * Math.sin(System.currentTimeMillis() / 100.0));
            context.drawTextWithShadow(client.textRenderer, Text.literal("RASENGAN READY - LMB!"),
                x, y + 8, ColorHelper.Argb.getArgb(alpha, 68, 170, 255));
            y += 18;
        }
        return y;
    }
}
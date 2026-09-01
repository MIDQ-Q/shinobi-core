package com.example.shinobicore.client;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.text.Text;
import net.minecraft.util.math.ColorHelper;
import com.example.shinobicore.client.ClientNinjaStateHolder;
public class HandSignsHudRenderer {
    public static void render(DrawContext ctx, float tickDelta) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;
        HandSignsClientState.ActiveSigns signs = HandSignsClientState.get(client.player.getId());
        if (signs == null) return;
        float progress = signs.getProgress();
        String name = ClientNinjaStateHolder.get().getName(signs.jutsuId);
        int sw = client.getWindow().getScaledWidth();
        int sh = client.getWindow().getScaledHeight();
        int barW = 120, barH = 6;
        int barX = (sw - barW) / 2;
        int barY = sh / 2 + 40;
        int alpha = (int)(180 + 75 * Math.sin(System.currentTimeMillis() / 100.0));
        ctx.fill(barX - 1, barY - 1, barX + barW + 1, barY + barH + 1, 0xCC000000);
        ctx.fill(barX, barY, barX + barW, barY + barH, 0xFF222222);
        int fillW = (int)(barW * progress);
        int fillColor = ColorHelper.Argb.getArgb(alpha, 255, 170, 0);
        ctx.fill(barX, barY, barX + fillW, barY + barH, fillColor);
        ctx.fill(barX, barY, barX + fillW, barY + 1, ColorHelper.Argb.getArgb(alpha / 2, 255, 255, 255));
        String label = "Weaving signs: " + name + " (" + (int)(progress * 100) + "%)";
        int tw = client.textRenderer.getWidth(label);
        ctx.drawTextWithShadow(client.textRenderer, Text.literal(label),
            (sw - tw) / 2, barY - 12, 0xFFFFAA00);
    }
}
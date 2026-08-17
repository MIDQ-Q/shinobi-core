package com.example.shinobicore.client;

import net.fabricmc.fabric.api.client.rendering.v1.HudRenderCallback;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.text.Text;

/**
 * S3-03: Cast bar rendered under the crosshair.
 * Shows: progress, jutsu name, charge level.
 */
public class CastBarHudRenderer {
    public static void register() {
        HudRenderCallback.EVENT.register(CastBarHudRenderer::render);
    }
    
    private static void render(DrawContext ctx, float tickDelta) {
        if (!HudSettings.current.showCastBar) return;
        
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;
        
        HandSignsClientState.ActiveSigns signs = HandSignsClientState.get(client.player.getId());
        if (signs == null) return;
        
        float progress = signs.getProgress();
        String name = ClientNinjaState.name(signs.jutsuId);
        if (name == null || name.isEmpty()) name = signs.jutsuId;
        
        int sw = client.getWindow().getScaledWidth();
        int sh = client.getWindow().getScaledHeight();
        
        // Position: centered, 30px below crosshair (crosshair is at sh/2)
        int barWidth = 140;
        int barHeight = 6;
        int barX = (sw - barWidth) / 2;
        int barY = sh / 2 + 30;
        
        // Background
        int alpha = (int)(200 * HudSettings.current.opacity);
        int bgAlpha = (int)(120 * HudSettings.current.opacity);
        ctx.fill(barX - 2, barY - 12, barX + barWidth + 2, barY + barHeight + 4, 
                 (bgAlpha << 24) | 0x111111);
        
        // Bar background
        ctx.fill(barX, barY, barX + barWidth, barY + barHeight, 
                 (bgAlpha << 24) | 0x222222);
        
        // Progress fill
        int fillWidth = (int)(barWidth * progress);
        int fillColor = (alpha << 24) | 0xFFAA00;
        ctx.fill(barX, barY, barX + fillWidth, barY + barHeight, fillColor);
        
        // Highlight on top
        int highlightAlpha = alpha / 3;
        ctx.fill(barX, barY, barX + fillWidth, barY + 1, 
                 (highlightAlpha << 24) | 0xFFFFFF);
        
        // Jutsu name above bar
        int textAlpha = (int)(255 * HudSettings.current.opacity);
        int textColor = (textAlpha << 24) | 0xFFFFAA;
        int textWidth = client.textRenderer.getWidth(name);
        ctx.drawTextWithShadow(client.textRenderer, Text.literal(name),
                               (sw - textWidth) / 2, barY - 10, textColor);
        
        // Percentage
        String pct = (int)(progress * 100) + "%";
        int pctWidth = client.textRenderer.getWidth(pct);
        ctx.drawTextWithShadow(client.textRenderer, Text.literal(pct),
                               barX + barWidth - pctWidth, barY + barHeight + 2, 
                               (textAlpha << 24) | 0xAAAAAA);
    }
}
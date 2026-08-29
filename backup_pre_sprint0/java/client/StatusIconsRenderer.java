package com.example.shinobicore.client;

import net.fabricmc.fabric.api.client.rendering.v1.HudRenderCallback;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.text.Text;

/**
 * S3-04: Compact status icons for buffs/debuffs.
 * Replaces verbose text indicators with icon badges.
 */
public class StatusIconsRenderer {
    private static final int ICON_SIZE = 18;
    private static final int GAP = 2;
    
    public static void register() {
        HudRenderCallback.EVENT.register(StatusIconsRenderer::render);
    }
    
    private static void render(DrawContext ctx, float tickDelta) {
        if (!HudSettings.current.showStatusIcons) return;
        
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;
        
        int x = 10 + HudSettings.current.offsetX;
        int y = 10 + HudSettings.current.offsetY;
        
        // Collect active states
        int count = 0;
        
        if (ClientNinjaState.chakraMode && ChakraHudRenderer.currentChakra > 0) {
            drawIcon(ctx, x + count * (ICON_SIZE + GAP), y, "CM", 0xFFFF8800, "Chakra Mode");
            count++;
        }
        
        if (ChakraHudRenderer.exhausted) {
            drawIcon(ctx, x + count * (ICON_SIZE + GAP), y, "EX", 0xFF3333, "Exhausted");
            count++;
        }
        
        if (ClientNinjaState.sensoryEnabled && ClientNinjaState.unlockedNodes.contains("sen_glow")) {
            drawIcon(ctx, x + count * (ICON_SIZE + GAP), y, "SE", 0xFF66DDFF, "Sensory");
            count++;
        }
        
        if (ClientNinjaState.dangerSense) {
            int pulse = (int)(150 + 105 * Math.sin(System.currentTimeMillis() / 150.0));
            drawIcon(ctx, x + count * (ICON_SIZE + GAP), y, "!!", (pulse << 24) | 0xFF3C3C, "Danger");
            count++;
        }
        
        // Kawarimi cooldown indicator
        if (com.example.shinobicore.client.combat.TaijutsuKickHandler.isOnCooldown()) {
            drawIcon(ctx, x + count * (ICON_SIZE + GAP), y, "CD", 0xFF44AAFF, "Kick CD");
            count++;
        }
        
        // Rasengan ready
        if (RasenganClientState.ready) {
            int pulse = (int)(150 + 105 * Math.sin(System.currentTimeMillis() / 100.0));
            drawIcon(ctx, x + count * (ICON_SIZE + GAP), y, "RG", (pulse << 24) | 0x44AAFF, "Rasengan Ready");
            count++;
        }
    }
    
    private static void drawIcon(DrawContext ctx, int x, int y, String label, int color, String tooltip) {
        int alpha = (color >> 24) & 0xFF;
        if (alpha == 0) alpha = 255;
        int baseColor = color & 0xFFFFFF;
        
        // Background
        int bgAlpha = (int)(alpha * 0.4f);
        ctx.fill(x, y, x + ICON_SIZE, y + ICON_SIZE, (bgAlpha << 24) | 0x111111);
        
        // Border
        ctx.fill(x, y, x + ICON_SIZE, y + 1, (alpha << 24) | baseColor);
        ctx.fill(x, y + ICON_SIZE - 1, x + ICON_SIZE, y + ICON_SIZE, (alpha << 24) | baseColor);
        ctx.fill(x, y, x + 1, y + ICON_SIZE, (alpha << 24) | baseColor);
        ctx.fill(x + ICON_SIZE - 1, y, x + ICON_SIZE, y + ICON_SIZE, (alpha << 24) | baseColor);
        
        // Label
        MinecraftClient client = MinecraftClient.getInstance();
        int textWidth = client.textRenderer.getWidth(label);
        int textColor = (alpha << 24) | 0xFFFFFF;
        ctx.drawTextWithShadow(client.textRenderer, Text.literal(label),
                               x + (ICON_SIZE - textWidth) / 2, y + 5, textColor);
    }
}
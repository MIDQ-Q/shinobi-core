package com.example.shinobicore.client.sakura.ui;

import com.example.shinobicore.client.sakura.CuriosSlot;
import com.example.shinobicore.client.sakura.SakuraHandler;
import com.example.shinobicore.compat.CuriosCompat;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.item.ItemStack;
import net.minecraft.text.Text;
import net.minecraft.util.math.ColorHelper;

import java.util.List;

public final class ArtifactPanel {
    private ArtifactPanel() {}
    
    public static void render(DrawContext ctx, SakuraHandler handler, int gx, int gy, int mx, int my, long now) {
        if (!CuriosCompat.isLoaded() || handler.artifactSlots.isEmpty()) return;
        
        MinecraftClient client = MinecraftClient.getInstance();
        List<CuriosCompat.ArtifactSlotInfo> infos = CuriosCompat.getArtifactSlots();
        
        // Panel background
        int panelX = gx + SakuraHandler.ARTIFACT_X - 6;
        int panelY = gy + SakuraHandler.ARTIFACT_Y0 - 6;
        int panelW = 28;
        int panelH = handler.artifactSlots.size() * SakuraHandler.ARTIFACT_DY + 12;
        
        SakuraTextures.drawPanel(ctx, panelX, panelY, panelW, panelH);
        
        // Header
        ctx.drawTextWithShadow(client.textRenderer, 
            Text.translatable("gui.shinobicore.artifacts"),
            panelX + 4, panelY + 4, SakuraTheme.SAKURA);
        
        // Render each artifact slot
        for (int i = 0; i < handler.artifactSlots.size(); i++) {
            CuriosSlot slot = handler.artifactSlots.get(i);
            CuriosCompat.ArtifactSlotInfo info = i < infos.size() ? infos.get(i) : null;
            
            int slotX = gx + slot.x;
            int slotY = gy + slot.y;
            int slotSize = 16;
            
            boolean hovered = mx >= slotX && mx < slotX + slotSize && my >= slotY && my < slotY + slotSize;
            
            // Slot background with accent color
            int accentColor = info != null ? info.accentColor : SakuraTheme.SAKURA;
            int bgAlpha = hovered ? 0x55 : 0x22;
            int bgColor = ColorHelper.Argb.getArgb(bgAlpha * 255 / 255, 
                (accentColor >> 16) & 0xFF,
                (accentColor >> 8) & 0xFF,
                accentColor & 0xFF);
            
            ctx.fill(slotX, slotY, slotX + slotSize, slotY + slotSize, bgColor);
            
            // Border with accent
            int borderColor = hovered ? accentColor : withAlpha(accentColor, 0.5f);
            ctx.fill(slotX, slotY, slotX + slotSize, slotY + 1, borderColor);
            ctx.fill(slotX, slotY + slotSize - 1, slotX + slotSize, slotY + slotSize, borderColor);
            ctx.fill(slotX, slotY, slotX + 1, slotY + slotSize, borderColor);
            ctx.fill(slotX + slotSize - 1, slotY, slotX + slotSize, slotY + slotSize, borderColor);
            
            // Draw item or placeholder icon
            ItemStack stack = slot.getStack();
            if (!stack.isEmpty()) {
                ctx.drawItem(stack, slotX, slotY);
                if (stack.getCount() > 1) {
                    ctx.drawItemInSlot(client.textRenderer, stack, slotX, slotY);
                }
            } else {
                // Draw placeholder glyph
                drawArtifactGlyph(ctx, info != null ? info.id : "", slotX + 8, slotY + 8, 
                    withAlpha(accentColor, 0.4f));
            }
            
            // Hover tooltip
            if (hovered && stack.isEmpty() && info != null) {
                ctx.drawTooltip(client.textRenderer, 
                    Text.literal(info.displayName), mx, my);
            }
        }
    }
    
    private static void drawArtifactGlyph(DrawContext ctx, String type, int cx, int cy, int color) {
        // Procedural glyphs for artifact types
        switch (type) {
            case "necklace" -> {
                // Circle with pendant
                for (int i = 0; i < 12; i++) {
                    double a = i * Math.PI * 2 / 12;
                    int x = cx + (int)(Math.cos(a) * 4);
                    int y = cy - 2 + (int)(Math.sin(a) * 3);
                    ctx.fill(x, y, x + 1, y + 1, color);
                }
                ctx.fill(cx, cy + 2, cx + 1, cy + 5, color);
            }
            case "ring" -> {
                // Simple ring
                for (int i = 0; i < 8; i++) {
                    double a = i * Math.PI * 2 / 8;
                    int x = cx + (int)(Math.cos(a) * 3);
                    int y = cy + (int)(Math.sin(a) * 3);
                    ctx.fill(x, y, x + 1, y + 1, color);
                }
            }
            case "belt" -> {
                // Horizontal belt
                ctx.fill(cx - 4, cy - 1, cx + 4, cy + 1, color);
                ctx.fill(cx - 1, cy - 2, cx + 1, cy + 2, color);
            }
            case "head" -> {
                // Crown/helmet
                ctx.fill(cx - 3, cy + 1, cx + 3, cy + 2, color);
                ctx.fill(cx - 2, cy - 1, cx - 1, cy + 1, color);
                ctx.fill(cx, cy - 2, cx + 1, cy, color);
                ctx.fill(cx + 2, cy - 1, cx + 3, cy + 1, color);
            }
            case "hands" -> {
                // Gauntlet
                ctx.fill(cx - 2, cy - 2, cx + 2, cy + 2, color);
                ctx.fill(cx - 3, cy - 1, cx - 2, cy + 1, color);
                ctx.fill(cx + 2, cy - 1, cx + 3, cy + 1, color);
            }
            case "feet" -> {
                // Boot
                ctx.fill(cx - 2, cy - 2, cx + 1, cy + 1, color);
                ctx.fill(cx - 1, cy + 1, cx + 3, cy + 2, color);
            }
            default -> ctx.fill(cx - 1, cy - 1, cx + 1, cy + 1, color);
        }
    }
    
    private static int withAlpha(int color, float alpha) {
        int a = (int)(alpha * 255);
        return (a << 24) | (color & 0x00FFFFFF);
    }
}
package com.example.shinobicore.modules.chakra.client;

import com.example.shinobicore.api.chakra.ChakraApi;
import com.example.shinobicore.core.service.CoreServices;
import net.fabricmc.fabric.api.client.rendering.v1.HudRenderCallback;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.util.math.MatrixStack;

public final class ChakraHudRenderer implements HudRenderCallback {
    private static boolean registered = false;
    
    public static void register() {
        if (registered) return;
        HudRenderCallback.EVENT.register(new ChakraHudRenderer());
        registered = true;
    }

    @Override
    public void onHudRender(DrawContext ctx, float tickDelta) {
        MinecraftClient mc = MinecraftClient.getInstance();
        if (mc.player == null) return;
        if (mc.options.hudHidden) return;
        
        CoreServices.get(ChakraApi.class).ifPresent(api -> {
            double current = api.getCurrent(mc.player);
            double max = api.getMax(mc.player);
            boolean active = api.isChakraModeActive(mc.player);
            boolean exhausted = api.isExhausted(mc.player);
            
            int width = mc.getWindow().getScaledWidth();
            int height = mc.getWindow().getScaledHeight();
            
            // Position: bottom-left above hotbar
            int barWidth = 100;
            int barHeight = 8;
            int x = 10;
            int y = height - 50;
            
            // Background
            ctx.fill(x - 1, y - 1, x + barWidth + 1, y + barHeight + 1, 0xAA000000);
            ctx.fill(x, y, x + barWidth, y + barHeight, 0xFF222222);
            
            // Fill
            int fillWidth = (int)((current / max) * barWidth);
            int color = exhausted ? 0xFFAA0000 : (active ? 0xFF4488FF : 0xFF2244AA);
            ctx.fill(x, y, x + fillWidth, y + barHeight, color);
            
            // Text
            String text = String.format("Chakra: %.0f/%.0f%s", current, max, 
                exhausted ? " [EXHAUSTED]" : (active ? " [ACTIVE]" : ""));
            ctx.drawText(mc.textRenderer, text, x, y - 10, 0xFFFFFFFF, true);
            
            // Stamina bar (simple placeholder)
            int staminaY = y + barHeight + 4;
            ctx.fill(x - 1, staminaY - 1, x + barWidth + 1, staminaY + 5, 0xAA000000);
            ctx.fill(x, staminaY, x + barWidth, staminaY + 4, 0xFF22AA22);
            ctx.drawText(mc.textRenderer, "Stamina: 100/100", x, staminaY + 8, 0xFFFFFFFF, true);
        });
    }
}
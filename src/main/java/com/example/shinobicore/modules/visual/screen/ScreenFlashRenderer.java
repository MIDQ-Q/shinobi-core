package com.example.shinobicore.modules.visual.screen;

import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;

public final class ScreenFlashRenderer {
    public static void register() {
        net.fabricmc.fabric.api.client.rendering.v1.HudRenderCallback.EVENT.register((context, delta) -> {
            render(context);
        });
    }
    private static float flashAlpha = 0.0f;
    private static int flashColor = 0xFFFFFF;
    private static int flashDurationTicks = 0;
    private static int flashTick = 0;

    public static void triggerFlash(int color, int durationTicks) {
        flashColor = color;
        flashDurationTicks = durationTicks;
        flashTick = 0;
        flashAlpha = 0.5f;
    }

    public static void tick() {
        if (flashDurationTicks <= 0) return;
        
        flashTick++;
        if (flashTick >= flashDurationTicks) {
            flashAlpha = 0.0f;
            flashDurationTicks = 0;
            return;
        }
        
        float progress = (float) flashTick / flashDurationTicks;
        flashAlpha = 0.5f * (1.0f - progress);
    }

    public static void render(DrawContext context) {
        if (flashAlpha <= 0.0f) return;
        
        MinecraftClient client = MinecraftClient.getInstance();
        int width = client.getWindow().getScaledWidth();
        int height = client.getWindow().getScaledHeight();
        
        int r = (flashColor >> 16) & 0xFF;
        int g = (flashColor >> 8) & 0xFF;
        int b = flashColor & 0xFF;
        int a = (int)(flashAlpha * 255);
        int color = (a << 24) | (r << 16) | (g << 8) | b;
        
        context.fill(0, 0, width, height, color);
    }
}
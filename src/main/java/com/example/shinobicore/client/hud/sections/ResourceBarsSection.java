package com.example.shinobicore.client.hud.sections;

import com.example.shinobicore.client.ChakraHudRenderer;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;

public final class ResourceBarsSection {
    private ResourceBarsSection() {}

    public static int render(DrawContext context, MinecraftClient client, int x, int y) {
        // Delegate to ChakraHudRenderer.drawBar for now
        // Bars are rendered in ChakraHudRenderer.render() via barsCache
        // This section is a placeholder for future extraction
        return y;
    }
}
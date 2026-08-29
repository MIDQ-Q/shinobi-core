package com.example.shinobicore.client.debug;

import com.example.shinobicore.client.ChakraHudRenderer;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.network.NetworkDebugLogger;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.text.Text;

/**
 * S0-08: Debug overlay for developers.
 * Toggle with F6. Shows chakra, fatigue, VFX, clones, packets/s, memory, FPS.
 */
public class DebugOverlayRenderer {

    private static int tickCounter = 0;

    public static void render(DrawContext ctx, float tickDelta) {
        if (!DebugProfiler.isEnabled()) return;

        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;

        tickCounter++;
        DebugProfiler.beginFrame();

        int sw = client.getWindow().getScaledWidth();
        int x = sw - 210;
        int y = 10;

        // Background
        ctx.fill(x - 8, y - 6, sw - 4, y + 195, 0xAA111111);
        ctx.fill(x - 8, y - 6, sw - 4, y - 5, 0xFFB4470F);

        // Title
        drawText(ctx, client, "SHINOBI DEBUG", x, y, 0xFFFFAA00);
        y += 16;

        // Resources
        float chakra = ChakraHudRenderer.currentChakra;
        float maxChakra = ChakraHudRenderer.maxChakra;
        drawText(ctx, client, String.format("Chakra: %.0f/%.0f", chakra, maxChakra), x, y, 0xFF4499FF);
        y += 12;

        drawText(ctx, client, String.format("Fatigue: %.1f%%", ChakraHudRenderer.fatigue), x, y, 0xFFEEBB33);
        y += 12;

        boolean exhausted = ChakraHudRenderer.exhausted;
        drawText(ctx, client, "Exhausted: " + (exhausted ? "YES" : "no"), x, y,
                 exhausted ? 0xFFFF4444 : 0xFF888888);
        y += 12;

        // Separator
        y += 3;
        ctx.fill(x, y, sw - 12, y + 1, 0xFF333333);
        y += 6;

        // Performance
        int vfxCount = DebugProfiler.getActiveVfxCount();
        int vfxColor = vfxCount > 50 ? 0xFFFF4444 : vfxCount > 20 ? 0xFFFFAA00 : 0xFF44FF44;
        drawText(ctx, client, "Active VFX: " + vfxCount, x, y, vfxColor);
        y += 12;

        int cloneCount = DebugProfiler.getActiveCloneCount();
        drawText(ctx, client, "Active Clones: " + cloneCount, x, y, 0xFFCCCCCC);
        y += 12;

        long pps = NetworkDebugLogger.getPacketsPerSecond();
        int ppsColor = pps > 100 ? 0xFFFF4444 : pps > 50 ? 0xFFFFAA00 : 0xFF44FF44;
        drawText(ctx, client, "Packets/s: " + pps, x, y, ppsColor);
        y += 12;

        float frameMs = DebugProfiler.getFrameTimeMs();
        int frameColor = frameMs > 8f ? 0xFFFF4444 : frameMs > 4f ? 0xFFFFAA00 : 0xFF44FF44;
        drawText(ctx, client, String.format("Frame: %.2f ms", frameMs), x, y, frameColor);
        y += 12;

        long usedMb = DebugProfiler.getUsedMemoryMb();
        long maxMb = DebugProfiler.getMaxMemoryMb();
        drawText(ctx, client, String.format("Memory: %d/%d MB", usedMb, maxMb), x, y, 0xFFAAAAAA);
        y += 12;

        // FPS
        int fps = client.getCurrentFps();
        int fpsColor = fps < 30 ? 0xFFFF4444 : fps < 60 ? 0xFFFFAA00 : 0xFF44FF44;
        drawText(ctx, client, "FPS: " + fps, x, y, fpsColor);
        y += 12;

        // Separator
        y += 3;
        ctx.fill(x, y, sw - 12, y + 1, 0xFF333333);
        y += 6;

        // State
        boolean netDebug = NetworkDebugLogger.isEnabled();
        drawText(ctx, client, "Net Debug: " + (netDebug ? "ON" : "OFF"), x, y,
                 netDebug ? 0xFF44FF44 : 0xFF666666);
        y += 12;

        drawText(ctx, client, "SP: " + ClientNinjaState.skillPoints, x, y, 0xFFCCCCCC);
        y += 12;

        drawText(ctx, client, "Clan: " + ClientNinjaState.clanId, x, y, 0xFFCCCCCC);
        y += 12;

        drawText(ctx, client, "Tree Nodes: " + ClientNinjaState.unlockedNodes.size(), x, y, 0xFFCCCCCC);
        y += 12;

        drawText(ctx, client, "Learned: " + ClientNinjaState.learned.size(), x, y, 0xFFCCCCCC);
        y += 12;

        drawText(ctx, client, "Reserve Lv: " + ClientNinjaState.reserveLevel, x, y, 0xFFCCCCCC);

        DebugProfiler.endFrame();
    }

    private static void drawText(DrawContext ctx, MinecraftClient client,
                                  String text, int x, int y, int color) {
        ctx.drawTextWithShadow(client.textRenderer, Text.literal(text), x, y, color);
    }
}
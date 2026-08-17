package com.example.shinobicore.client.sensory;

import net.fabricmc.fabric.api.client.rendering.v1.HudRenderCallback;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.text.Text;
import net.minecraft.util.math.ColorHelper;

/**
 * S6-06: Chakra reading display.
 * Shows detailed info about a scanned entity's chakra.
 * Displayed as a panel on the right side of screen.
 */
public class SensoryReadingHud {

    public static void register() {
        HudRenderCallback.EVENT.register(SensoryReadingHud::render);
    }

    private static void render(DrawContext ctx, float tickDelta) {
        if (!SensoryClientState.isReadingActive()) return;
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;

        SensoryClientState.ReadingData reading = SensoryClientState.lastReading;
        if (reading == null) return;

        int sw = client.getWindow().getScaledWidth();
        int sh = client.getWindow().getScaledHeight();

        // Panel position (right side)
        int panelW = 160;
        int panelH = 90;
        int px = sw - panelW - 10;
        int py = sh / 2 - panelH / 2;

        // Background
        ctx.fill(px - 2, py - 2, px + panelW + 2, py + panelH + 2, 0xFF111111);
        ctx.fill(px, py, px + panelW, py + panelH, 0xCC1A1A2E);

        // Border
        ctx.fill(px, py, px + panelW, py + 1, 0xFF44AAFF);
        ctx.fill(px, py + panelH - 1, px + panelW, py + panelH, 0xFF44AAFF);
        ctx.fill(px, py, px + 1, py + panelH, 0xFF44AAFF);
        ctx.fill(px + panelW - 1, py, px + panelW, py + panelH, 0xFF44AAFF);

        int ty = py + 6;
        int tx = px + 8;

        // Title
        ctx.drawTextWithShadow(client.textRenderer, Text.literal("CHAKRA READING"),
            tx, ty, 0xFF44AAFF);
        ty += 12;

        // Entity name
        ctx.drawTextWithShadow(client.textRenderer, Text.literal("Target: " + reading.name),
            tx, ty, 0xFFFFFFFF);
        ty += 11;

        // Chakra level bar
        String chakraLabel = "Chakra:";
        ctx.drawTextWithShadow(client.textRenderer, Text.literal(chakraLabel),
            tx, ty, 0xFFAAAAAA);
        int barX = tx + 50;
        int barW = 90;
        int barH = 6;
        ctx.fill(barX, ty + 1, barX + barW, ty + 1 + barH, 0xFF333333);
        int filled = (int)(barW * Math.min(1f, reading.chakraRatio));
        int barColor = reading.chakraRatio > 0.7f ? 0xFF44FF44 :
                       reading.chakraRatio > 0.3f ? 0xFFFFAA44 : 0xFFFF4444;
        ctx.fill(barX, ty + 1, barX + filled, ty + 1 + barH, barColor);
        ty += 12;

        // Chakra mode
        if (reading.chakraModeActive) {
            ctx.drawTextWithShadow(client.textRenderer, Text.literal("MODE: ACTIVE"),
                tx, ty, 0xFFFF8800);
        } else {
            ctx.drawTextWithShadow(client.textRenderer, Text.literal("MODE: Inactive"),
                tx, ty, 0xFF666666);
        }
        ty += 11;

        // Reserve level
        if (reading.reserveLevel > 0) {
            ctx.drawTextWithShadow(client.textRenderer, Text.literal("Reserve Lv: " + reading.reserveLevel),
                tx, ty, 0xFFAAAAAA);
            ty += 11;
        }

        // Dojutsu
        if (reading.hasDojutsu) {
            String djName = reading.dojutsuId.equals("sharingan") ? "Sharingan" :
                           reading.dojutsuId.equals("byakugan") ? "Byakugan" : reading.dojutsuId;
            ctx.drawTextWithShadow(client.textRenderer, Text.literal("Dojutsu: " + djName),
                tx, ty, 0xFFFF4444);
        }
    }
}
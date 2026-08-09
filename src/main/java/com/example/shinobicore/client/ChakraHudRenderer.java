package com.example.shinobicore.client;

import com.example.shinobicore.client.parkour.ParkourManager;
import com.example.shinobicore.client.parkour.actions.ChargedJumpAction;
import com.example.shinobicore.client.parkour.ParkourManager;
import com.example.shinobicore.client.parkour.actions.ChargedJumpAction;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.text.Text;
import net.minecraft.util.math.ColorHelper;

public class ChakraHudRenderer {

    public static float currentChakra = 100f;
    public static float maxChakra = 100f;
    public static float fatigue = 0f;
    public static boolean exhausted = false;

    public static void render(DrawContext context, float tickDelta) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;

        int x = 10, y = 10, width = 200, height = 16;

        context.fillGradient(x - 1, y - 1, x + width + 1, y + height + 1, 0xCC000000, 0xCC111111);

        float ratio = maxChakra > 0 ? currentChakra / maxChakra : 0;
        ratio = Math.max(0, Math.min(1, ratio));
        int filled = (int) (width * ratio);

        int top, bottom;
        if (exhausted) { top = ColorHelper.Argb.getArgb(255, 180, 40, 40); bottom = ColorHelper.Argb.getArgb(255, 140, 30, 30); }
        else if (fatigue > 70) { top = ColorHelper.Argb.getArgb(255, 200, 120, 40); bottom = ColorHelper.Argb.getArgb(255, 160, 90, 30); }
        else if (fatigue > 50) { top = ColorHelper.Argb.getArgb(255, 220, 180, 60); bottom = ColorHelper.Argb.getArgb(255, 180, 140, 40); }
        else { top = ColorHelper.Argb.getArgb(255, 80, 140, 240); bottom = ColorHelper.Argb.getArgb(255, 40, 100, 200); }

        context.fillGradient(x, y, x + filled, y + height, top, bottom);
        context.fill(x, y, x + filled, y + 2, 0x40FFFFFF);

        context.drawTextWithShadow(client.textRenderer,
            Text.literal(String.format("Chakra: %d/%d", (int) currentChakra, (int) maxChakra)),
            x + 4, y + 4, 0xFFFFFF);

        int lineY = y + height + 4;

        if (fatigue > 0) {
            context.drawTextWithShadow(client.textRenderer,
                Text.literal(String.format("Fatigue: %d%%", (int) fatigue)), x, lineY, 0xFFCC44);
            lineY += 10;
        }
        if (exhausted) {
            context.drawTextWithShadow(client.textRenderer, Text.literal("EXHAUSTED"), x, lineY, 0xFF3333);
            lineY += 10;
        }

        lineY = drawLoadoutLine(context, client, 0, "A", x, lineY);
        lineY = drawLoadoutLine(context, client, 1, "B", x, lineY);

        if (ClientNinjaState.skillPoints > 0) {
            context.drawTextWithShadow(client.textRenderer,
                Text.literal("SP: " + ClientNinjaState.skillPoints + " (K)"), x, lineY, 0xFFFF55);
            lineY += 10;
        }

        float hp = client.player.getHealth();
        float maxHp = client.player.getMaxHealth();
        drawPixelHeart(context, x, lineY);
        context.drawTextWithShadow(client.textRenderer, Text.literal(String.format("%.0f/%.0f", hp, maxHp)),
            x + 8, lineY, 0xFF5555);
        lineY += 12;

        // === CHARGED JUMP PROGRESS BAR ===
        ChargedJumpAction chargedJump = ParkourManager.getChargedJumpAction();
        if (chargedJump != null && chargedJump.isCharging()) {
            float charge = chargedJump.getChargeRatio();
            int barWidth = 100;
            int barHeight = 6;
            int barX = (client.getWindow().getScaledWidth() - barWidth) / 2;
            int barY = client.getWindow().getScaledHeight() - 80;

            // Фон
            context.fill(barX - 1, barY - 1, barX + barWidth + 1, barY + barHeight + 1, 0xCC000000);

            // Прогресс
            int chargeFilled = (int) (barWidth * charge);
            int color = 0xFFFF00;  // жёлтый
            if (charge >= 0.8f) color = 0xFF5555;  // красный при полном заряде
            context.fill(barX, barY, barX + chargeFilled, barY + barHeight, color);

            // Текст
            String chargeText = String.format("Charge: %.0f%%", charge * 100);
            context.drawCenteredTextWithShadow(client.textRenderer, chargeText,
                barX + barWidth / 2, barY - 10, 0xFFFFFF);
        }

        if (ClientNinjaState.chakraMode) {
            int alpha = (int) (128 + 127 * Math.sin(System.currentTimeMillis() / 200.0));
            context.drawTextWithShadow(client.textRenderer, Text.literal("CHAKRA MODE"),
                x, lineY, ColorHelper.Argb.getArgb(alpha, 85, 255, 255));
        }
    }

    private static int drawLoadoutLine(DrawContext context, MinecraftClient client, int set, String label, int x, int lineY) {
        String current = ClientNinjaState.activeJutsuId(set);
        String name = current == null ? "empty" : ClientNinjaState.name(current);
        context.drawTextWithShadow(client.textRenderer,
            Text.literal("[" + label + "] Slot " + (ClientNinjaState.active(set) + 1) + ": " + name),
            x, lineY, 0xFFFFFF);
        lineY += 10;

        for (int i = 0; i < 5; i++) {
            int color = (i == ClientNinjaState.active(set)) ? 0x55FF55
                : (ClientNinjaState.loadout(set)[i] != null ? 0xAAAAAA : 0x555555);
            context.drawTextWithShadow(client.textRenderer, Text.literal("[" + (i + 1) + "]"),
                x + i * 18, lineY, color);
        }
        return lineY + 12;
    }

    private static void drawPixelHeart(DrawContext context, int x, int y) {
        int c = 0xFF5555;
        context.fill(x, y + 1, x + 2, y + 3, c);
        context.fill(x + 3, y + 1, x + 5, y + 3, c);
        context.fill(x, y + 2, x + 5, y + 4, c);
        context.fill(x + 1, y + 4, x + 4, y + 5, c);
        context.fill(x + 2, y + 5, x + 3, y + 6, c);
    }
}
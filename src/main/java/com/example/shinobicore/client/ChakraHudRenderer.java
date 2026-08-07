package com.example.shinobicore.client;

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

        int x = 10;
        int y = 10;
        int width = 200;
        int height = 16;

        // === ПОЛОСКА ЧАКРЫ ===
        // Фон с градиентом
        drawGradientRect(context, x - 1, y - 1, x + width + 1, y + height + 1,
            0xCC000000, 0xCC111111);

        // Заполнение
        float ratio = maxChakra > 0 ? currentChakra / maxChakra : 0;
        ratio = Math.max(0, Math.min(1, ratio));
        int filledWidth = (int) (width * ratio);

        // Цвет полоски с градиентом
        int barColorTop, barColorBottom;
        if (exhausted) {
            barColorTop = ColorHelper.Argb.getArgb(255, 180, 40, 40);
            barColorBottom = ColorHelper.Argb.getArgb(255, 140, 30, 30);
        } else if (fatigue > 70) {
            barColorTop = ColorHelper.Argb.getArgb(255, 200, 120, 40);
            barColorBottom = ColorHelper.Argb.getArgb(255, 160, 90, 30);
        } else if (fatigue > 50) {
            barColorTop = ColorHelper.Argb.getArgb(255, 220, 180, 60);
            barColorBottom = ColorHelper.Argb.getArgb(255, 180, 140, 40);
        } else {
            barColorTop = ColorHelper.Argb.getArgb(255, 80, 140, 240);
            barColorBottom = ColorHelper.Argb.getArgb(255, 40, 100, 200);
        }

        drawGradientRect(context, x, y, x + filledWidth, y + height, barColorTop, barColorBottom);

        // Блик сверху
        context.fill(x, y, x + filledWidth, y + 2, 0x40FFFFFF);

        // Текст чакры
        String chakraText = String.format("Chakra: %d/%d", (int) currentChakra, (int) maxChakra);
        context.drawTextWithShadow(client.textRenderer, Text.literal(chakraText),
            x + 4, y + 4, 0xFFFFFF);

        int lineY = y + height + 4;

        // === УСТАЛОСТЬ ===
        if (fatigue > 0) {
            int fatigueColor = fatigue > 70 ? 0xFFAA00 : 0xFFCC44;
            context.drawTextWithShadow(client.textRenderer,
                Text.literal(String.format("Fatigue: %d%%", (int) fatigue)),
                x, lineY, fatigueColor);
            lineY += 10;
        }

        // === ИСТОЩЕНИЕ ===
        if (exhausted) {
            context.drawTextWithShadow(client.textRenderer, Text.literal("EXHAUSTED"),
                x, lineY, 0xFF3333);
            lineY += 10;
        }

        // === АКТИВНЫЙ СЛОТ ===
        String current = ClientNinjaState.activeJutsuId();
        String slotLine;
        if (current == null) {
            slotLine = "Slot " + (ClientNinjaState.activeSlot + 1) + ": empty";
        } else {
            String nice = current.contains(":") ? current.substring(current.indexOf(':') + 1) : current;
            nice = nice.replace('_', ' ');
            slotLine = "Slot " + (ClientNinjaState.activeSlot + 1) + ": " + nice;
        }
        context.drawTextWithShadow(client.textRenderer, Text.literal(slotLine), x, lineY, 0xFFFFFF);
        lineY += 12;

        // === ИНДИКАТОРЫ 5 СЛОТОВ ===
        for (int i = 0; i < 5; i++) {
            int slotColor;
            if (i == ClientNinjaState.activeSlot) {
                slotColor = 0x55FF55; // зелёный
            } else if (ClientNinjaState.loadout[i] != null) {
                slotColor = 0xAAAAAA; // серый
            } else {
                slotColor = 0x555555; // тёмно-серый
            }
            
            // Фон слота
            context.fill(x + i * 20 - 1, lineY - 1, x + i * 20 + 11, lineY + 11, 0x80000000);
            
            // Текст слота
            context.drawTextWithShadow(client.textRenderer, Text.literal("[" + (i + 1) + "]"),
                x + i * 20, lineY, slotColor);
        }
        lineY += 14;

        // === SP ===
        if (ClientNinjaState.skillPoints > 0) {
            context.drawTextWithShadow(client.textRenderer,
                Text.literal("SP: " + ClientNinjaState.skillPoints + " (K)"),
                x, lineY, 0xFFFF55);
            lineY += 10;
        }

        // === HP ===
        float hp = client.player.getHealth();
        float maxHp = client.player.getMaxHealth();
        drawPixelHeart(context, x, lineY);
        context.drawTextWithShadow(client.textRenderer,
            Text.literal(String.format("%.0f/%.0f", hp, maxHp)),
            x + 8, lineY, 0xFF5555);
        lineY += 12;

        // === ЧАКРА-РЕЖИМ ===
        if (ClientNinjaState.chakraMode) {
            // Пульсирующий текст
            int alpha = (int) (128 + 127 * Math.sin(System.currentTimeMillis() / 200.0));
            int color = ColorHelper.Argb.getArgb(alpha, 85, 255, 255);
            context.drawTextWithShadow(client.textRenderer, Text.literal("CHAKRA MODE"),
                x, lineY, color);
        }
    }

    private static void drawGradientRect(DrawContext context, int x1, int y1, int x2, int y2, int colorTop, int colorBottom) {
        context.fillGradient(x1, y1, x2, y2, colorTop, colorBottom);
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
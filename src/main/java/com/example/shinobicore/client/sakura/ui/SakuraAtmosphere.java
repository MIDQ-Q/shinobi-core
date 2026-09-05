package com.example.shinobicore.client.sakura.ui;

import net.minecraft.client.gui.DrawContext;

public final class SakuraAtmosphere {
    private SakuraAtmosphere() {}

    public static void render(DrawContext ctx, int w, int h, long now) {
        render(ctx, w, h, now, 0, 0);
    }

    public static void render(DrawContext ctx, int w, int h, long now, double camX, double camY) {
        ctx.fillGradient(0, 0, w, h, SakuraTheme.BG_TOP, SakuraTheme.BG_BOTTOM);

        float rot0 = now * 0.00002f;
        renderParallaxDots(ctx, w, h, camX * 0.15, camY * 0.15, rot0, 0x08FF9EC4, 6, 80);

        float rot1 = now * 0.00003f;
        renderParallaxDots(ctx, w, h, camX * 0.35, camY * 0.35, rot1, 0x0CFF9EC4, 10, 50);

        renderSpiral(ctx, w, h, camX * 0.5, camY * 0.5, now);

        for (int i = 0; i < 12; i++) {
            int a = (int)(30 * (1f - i / 12f));
            int c = a << 24;
            ctx.fill(i, 0, i + 1, h, c);
            ctx.fill(w - 1 - i, 0, w - i, h, c);
        }
        ctx.fillGradient(0, 0, w, 12, 0x28000000, 0x00000000);
        ctx.fillGradient(0, h - 12, w, h, 0x00000000, 0x28000000);
    }

    private static void renderParallaxDots(DrawContext ctx, int w, int h,
            double offX, double offY, float rot, int color, int count, int spacing) {
        for (int i = 0; i < count; i++) {
            float angle = rot + (i * 6.28f / count);
            int x = (int)(w / 2 + Math.cos(angle) * spacing * (1 + i * 0.3) - offX) % w;
            int y = (int)(h / 2 + Math.sin(angle) * spacing * 0.7 * (1 + i * 0.2) - offY) % h;
            if (x < 0) x += w;
            if (y < 0) y += h;
            int r = 2 + (i % 3);
            ctx.fill(x - r, y - r, x + r, y + r, color);
        }
    }

    private static void renderSpiral(DrawContext ctx, int w, int h,
            double offX, double offY, long now) {
        float rot = now * 0.00004f;
        int cx = (int)(w / 2 - offX * 0.3);
        int cy = (int)(h / 2 - offY * 0.3);
        int prevX = -1, prevY = -1;
        for (int i = 0; i <= 120; i++) {
            float t = i / 120f * (float)(Math.PI * 5.5);
            float r = 6 + t * 10;
            int x = cx + (int)(Math.cos(t + rot) * r);
            int y = cy + (int)(Math.sin(t + rot) * r * 0.9f);
            if (prevX >= 0) {
                int steps = Math.max(Math.abs(x - prevX), Math.abs(y - prevY));
                if (steps > 0) {
                    for (int s = 0; s <= steps; s++) {
                        ctx.fill(
                            prevX + (x - prevX) * s / steps,
                            prevY + (y - prevY) * s / steps,
                            prevX + (x - prevX) * s / steps + 2,
                            prevY + (y - prevY) * s / steps + 2,
                            0x12FF9EC4);
                    }
                }
            }
            prevX = x; prevY = y;
        }
    }
}
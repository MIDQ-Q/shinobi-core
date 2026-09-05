package com.example.shinobicore.client.sakura.ui;

import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.texture.NativeImage;
import net.minecraft.client.texture.NativeImageBackedTexture;
import net.minecraft.util.Identifier;

/**
 * Runtime-generated textures (no asset files):
 *  - rounded panel with 1px border + soft outer glow (9-slice)
 *  - sakura petal sprite
 * Falls back to flat fills if texture registration fails.
 */
public final class SakuraTextures {
    private static final int PS = 24;    // panel sprite size
    private static final int EDGE = 7;   // 9-slice corner size
    private static boolean ready = false;
    private static Identifier panelTex;
    private static Identifier petalTex;

    private SakuraTextures() {}

    public static boolean ready() { return ready; }
    public static Identifier petal() { return petalTex; }

    public static void init(MinecraftClient client) {
        if (ready) return;
        try {
            panelTex = register(client, "sakura_panel", makePanel());
            petalTex = register(client, "sakura_petal", makePetal());
            ready = true;
        } catch (Throwable t) {
            ready = false;
        }
    }

    private static Identifier register(MinecraftClient client, String name, NativeImage img) {
        Identifier id = new Identifier("shinobicore", "dynamic/" + name);
        client.getTextureManager().registerTexture(id, new NativeImageBackedTexture(img));
        return id;
    }

    /** NativeImage.setColor expects ABGR byte order. */
    private static int abgr(int r, int g, int b, int a) {
        return (a << 24) | (b << 16) | (g << 8) | r;
    }

    private static int abgrFromArgb(int argb, int alphaOverride) {
        int a = (alphaOverride >= 0) ? alphaOverride : (argb >>> 24) & 0xFF;
        int r = (argb >>> 16) & 0xFF;
        int g = (argb >>> 8) & 0xFF;
        int b = argb & 0xFF;
        return (a << 24) | (b << 16) | (g << 8) | r;
    }

    /** Rounded rect SDF: fill + 1px border ring + 2px outer glow. */
    private static NativeImage makePanel() {
        NativeImage img = new NativeImage(PS, PS, true);
        float c = (PS - 1) / 2f;
        float half = PS / 2f - 2f;
        float r = SakuraTheme.PANEL_R;
        for (int y = 0; y < PS; y++) {
            for (int x = 0; x < PS; x++) {
                float qx = Math.max(Math.abs(x - c) - (half - r), 0);
                float qy = Math.max(Math.abs(y - c) - (half - r), 0);
                float d = (float) Math.sqrt(qx * qx + qy * qy) - r;
                int col;
                if (d <= 0f) {
                    col = (d > -1.4f)
                            ? abgrFromArgb(SakuraTheme.SAK_DIM, 255)
                            : abgrFromArgb(SakuraTheme.PANEL, 240);
                } else {
                    float a = Math.max(0f, 1f - d / 2f);
                    col = abgrFromArgb(SakuraTheme.SAKURA, (int) (a * a * 70));
                }
                img.setColor(x, y, col);
            }
        }
        return img;
    }

    /** Soft petal with a notch at the top. */
    private static NativeImage makePetal() {
        NativeImage img = new NativeImage(16, 16, true);
        for (int y = 0; y < 16; y++) {
            for (int x = 0; x < 16; x++) {
                float u = (x - 8) / 6.5f;
                float v = (y - 9) / 7.5f;
                float d = u * u + v * v;
                float notch = (y < 6) ? ((6 - y) / 6f) * (float) Math.exp(-((x - 8) * (x - 8)) / 2f) : 0;
                float a = Math.max(0, 1 - d) - notch * 0.8f;
                a = Math.max(0, Math.min(1, a));
                int r = 255;
                int g = 190 + (int) (40 * (1 - a));
                int b = 205 + (int) (30 * (1 - a));
                img.setColor(x, y, abgr(r, g, b, (int) (a * 255)));
            }
        }
        return img;
    }

    /** 9-slice rounded panel. Falls back to flat fill. */
    public static void drawPanel(DrawContext ctx, int x, int y, int w, int h) {
        if (!ready || w < EDGE * 2 || h < EDGE * 2) {
            ctx.fill(x, y, x + w, y + h, SakuraTheme.PANEL);
            ctx.fill(x, y, x + w, y + 1, SakuraTheme.SAK_DIM);
            return;
        }
        int cw = PS - EDGE * 2;
        int iw = w - EDGE * 2;
        int ih = h - EDGE * 2;
        slice(ctx, x, y, EDGE, EDGE, 0, 0, EDGE, EDGE);
        slice(ctx, x + EDGE, y, iw, EDGE, EDGE, 0, cw, EDGE);
        slice(ctx, x + w - EDGE, y, EDGE, EDGE, PS - EDGE, 0, EDGE, EDGE);
        slice(ctx, x, y + EDGE, EDGE, ih, 0, EDGE, EDGE, cw);
        slice(ctx, x + EDGE, y + EDGE, iw, ih, EDGE, EDGE, cw, cw);
        slice(ctx, x + w - EDGE, y + EDGE, EDGE, ih, PS - EDGE, EDGE, EDGE, cw);
        slice(ctx, x, y + h - EDGE, EDGE, EDGE, 0, PS - EDGE, EDGE, EDGE);
        slice(ctx, x + EDGE, y + h - EDGE, iw, EDGE, EDGE, PS - EDGE, cw, EDGE);
        slice(ctx, x + w - EDGE, y + h - EDGE, EDGE, EDGE, PS - EDGE, PS - EDGE, EDGE, EDGE);
    }

    private static void slice(DrawContext ctx, int dx, int dy, int dw, int dh,
                              int su, int sv, int sw, int sh) {
        if (dw <= 0 || dh <= 0) return;
        ctx.drawTexture(panelTex, dx, dy, dw, dh, su, sv, sw, sh, PS, PS);
    }
}
package com.example.shinobicore.client.sakura.ui;

import net.minecraft.client.gui.DrawContext;

/** Procedural line-art glyphs for elements (no textures needed). */
public final class GlyphPainter {
    private GlyphPainter() {}

    public static int rankColor(String rank) {
        if (rank == null) return 0xFF9A8FA6;
        switch (rank.toUpperCase()) {
            case "S": return 0xFFFFD75E;
            case "A": return 0xFFD78AFF;
            case "B": return 0xFF7EB7FF;
            case "C": return 0xFF8AE08A;
            default: return 0xFF9A8FA6;
        }
    }

    private static final float[][] FIRE = {{0,-4},{2,-1},{1,2},{0,4},{-1,2},{-2,-1},{0,-4}};
    private static final float[][] WATER = {{0,-4},{2,-1},{2,1},{1,3},{0,4},{-1,3},{-2,1},{-2,-1},{0,-4}};
    private static final float[][] EARTH = {{-4,3},{0,-3},{4,3},{-4,3}};
    private static final float[][] BOLT = {{1,-4},{-1,-1},{1,-1},{-1,4}};
    private static final float[][] WIND_A = {{-3,-2},{0,-3},{3,-2}};
    private static final float[][] WIND_B = {{-3,1},{0,0},{3,1}};
    private static final float[][] WIND_C = {{-3,4},{0,3},{3,4}};
    private static final float[][] YIN = {{0,-4},{3,-3},{4,0},{3,3},{0,4},{-3,3},{-4,0},{-3,-3},{0,-4}};
    private static final float[][] SHAPE = {{0,0},{2,-1},{2,2},{-1,3},{-3,1},{-2,-2},{1,-4},{4,-2}};

    public static void drawGlyph(DrawContext ctx, String key, int cx, int cy, int color) {
        switch (key == null ? "" : key.toLowerCase()) {
            case "fire": poly(ctx, FIRE, cx, cy, color); break;
            case "water": poly(ctx, WATER, cx, cy, color); break;
            case "earth": poly(ctx, EARTH, cx, cy, color); break;
            case "lightning": poly(ctx, BOLT, cx, cy, color); break;
            case "wind":
                poly(ctx, WIND_A, cx, cy - 1, color);
                poly(ctx, WIND_B, cx, cy - 1, color);
                poly(ctx, WIND_C, cx, cy - 1, color);
                break;
            case "yin": poly(ctx, YIN, cx, cy, color); dot(ctx, cx, cy, color); break;
            case "yang":
                poly(ctx, YIN, cx, cy, color);
                line(ctx, cx - 6, cy, cx - 5, cy, color);
                line(ctx, cx + 5, cy, cx + 6, cy, color);
                line(ctx, cx, cy - 6, cx, cy - 5, color);
                line(ctx, cx, cy + 5, cx, cy + 6, color);
                break;
            case "shape": poly(ctx, SHAPE, cx, cy, color); break;
            default: dot(ctx, cx, cy, color); break;
        }
    }

    private static void dot(DrawContext ctx, int x, int y, int c) {
        ctx.fill(x - 1, y - 1, x + 1, y + 1, c);
    }

    private static void poly(DrawContext ctx, float[][] pts, int cx, int cy, int c) {
        for (int i = 0; i < pts.length - 1; i++) {
            line(ctx, cx + (int) pts[i][0], cy + (int) pts[i][1],
                    cx + (int) pts[i + 1][0], cy + (int) pts[i + 1][1], c);
        }
    }

    private static void line(DrawContext ctx, int x1, int y1, int x2, int y2, int c) {
        int steps = Math.max(Math.abs(x2 - x1), Math.abs(y2 - y1));
        if (steps == 0) { ctx.fill(x1, y1, x1 + 1, y1 + 1, c); return; }
        for (int i = 0; i <= steps; i++) {
            ctx.fill(x1 + (x2 - x1) * i / steps, y1 + (y2 - y1) * i / steps,
                    x1 + (x2 - x1) * i / steps + 1, y1 + (y2 - y1) * i / steps + 1, c);
        }
    }
}
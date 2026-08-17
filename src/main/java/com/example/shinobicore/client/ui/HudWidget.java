package com.example.shinobicore.client.ui;

import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;

/**
 * S3-01: Base class for all HUD widgets.
 * Each widget manages its own rendering, visibility, and position.
 * New widgets extend this class and register in HudWidgetManager.
 */
public abstract class HudWidget {

    private final String id;
    private boolean enabled = true;
    private float opacity = 1.0f;
    protected int x = 0;
    protected int y = 0;

    public HudWidget(String id) {
        this.id = id;
    }

    public String getId() { return id; }

    public boolean isEnabled() { return enabled; }
    public void setEnabled(boolean v) { this.enabled = v; }

    public float getOpacity() { return opacity; }
    public void setOpacity(float v) { this.opacity = Math.max(0f, Math.min(1f, v)); }

    public int getX() { return x; }
    public void setX(int v) { this.x = v; }
    public int getY() { return y; }
    public void setY(int v) { this.y = v; }

    /**
     * Whether this widget should render this frame.
     * Override for contextual logic (e.g., hide when full).
     */
    public abstract boolean shouldRender(MinecraftClient client);

    /**
     * Main render method. Called only if shouldRender() returns true.
     */
    public abstract void render(DrawContext ctx, MinecraftClient client, float tickDelta);

    /**
     * Priority for render order. Lower = rendered first (behind).
     */
    public int getPriority() { return 100; }

    /**
     * Called once when widget is registered.
     */
    public void init(MinecraftClient client) {}

    /**
     * Called every tick for state updates.
     */
    public void tick(MinecraftClient client) {}

    // --- Utility drawing methods ---

    protected void drawRect(DrawContext ctx, int x, int y, int w, int h, int color) {
        int a = (int)(((color >> 24) & 0xFF) * opacity);
        int r = (color >> 16) & 0xFF;
        int g = (color >> 8) & 0xFF;
        int b = color & 0xFF;
        int finalColor = (a << 24) | (r << 16) | (g << 8) | b;
        ctx.fill(x, y, x + w, y + h, finalColor);
    }

    protected void drawText(DrawContext ctx, MinecraftClient client, String text, int x, int y, int color) {
        ctx.drawTextWithShadow(client.textRenderer, text, x, y, color);
    }

    protected void drawScaledText(DrawContext ctx, MinecraftClient client, String text,
                                   float x, float y, int color, float scale) {
        ctx.getMatrices().push();
        ctx.getMatrices().translate(x, y, 0);
        ctx.getMatrices().scale(scale, scale, 1f);
        ctx.drawTextWithShadow(client.textRenderer, text, 0, 0, color);
        ctx.getMatrices().pop();
    }

    protected void drawBar(DrawContext ctx, int bx, int by, int bw, int bh,
                           float ratio, int fillColor, int bgColor, int borderColor) {
        ratio = Math.max(0f, Math.min(1f, ratio));
        int a = (int)(255 * opacity);
        drawRect(ctx, bx - 1, by - 1, bw + 2, bh + 2, borderColor);
        drawRect(ctx, bx, by, bw, bh, bgColor);
        int filled = (int)(bw * ratio);
        if (filled > 0) {
            int fr = ((fillColor >> 16) & 0xFF);
            int fg = ((fillColor >> 8) & 0xFF);
            int fb = (fillColor & 0xFF);
            int fc = (a << 24) | (fr << 16) | (fg << 8) | fb;
            ctx.fill(bx, by, bx + filled, by + bh, fc);
            // highlight line
            int hl = (a / 3 << 24) | 0xFFFFFF;
            ctx.fill(bx, by, bx + filled, by + 1, hl);
        }
    }
}
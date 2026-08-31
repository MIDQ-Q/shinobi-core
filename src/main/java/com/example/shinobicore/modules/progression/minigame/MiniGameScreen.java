package com.example.shinobicore.modules.progression.minigame;

import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.gui.screen.Screen;
import net.minecraft.text.Text;

public abstract class MiniGameScreen extends Screen {
    protected enum State { PLAYING, SUCCESS, FAILURE }
    protected State state = State.PLAYING;
    protected final String gameId;

    protected MiniGameScreen(String title, String gameId) {
        super(Text.literal(title));
        this.gameId = gameId;
    }

    @Override
    public void tick() {
        super.tick();
        if (state == State.PLAYING) {
            gameTick();
        }
    }

    protected abstract void gameTick();

    @Override
    public void render(DrawContext context, int mouseX, int mouseY, float delta) {
        renderBackground(context);
        gameRender(context, mouseX, mouseY, delta);
        super.render(context, mouseX, mouseY, delta);
    }

    protected abstract void gameRender(
        DrawContext context, int mouseX, int mouseY, float delta);

    protected void drawCircle(DrawContext ctx, int cx, int cy, int radius, int color) {
        if (radius <= 0) return;
        for (int y = -radius; y <= radius; y++) {
            for (int x = -radius; x <= radius; x++) {
                if (x * x + y * y <= radius * radius) {
                    ctx.fill(cx + x, cy + y, cx + x + 1, cy + y + 1, color);
                }
            }
        }
    }

    protected void drawRing(DrawContext ctx, int cx, int cy, int radius, int thickness, int color) {
        if (radius <= 0) return;
        int innerR = radius - thickness;
        if (innerR < 0) innerR = 0;
        for (int y = -radius; y <= radius; y++) {
            for (int x = -radius; x <= radius; x++) {
                int distSq = x * x + y * y;
                if (distSq <= radius * radius && distSq >= innerR * innerR) {
                    ctx.fill(cx + x, cy + y, cx + x + 1, cy + y + 1, color);
                }
            }
        }
    }

    @Override
    public boolean shouldPause() { return false; }
}
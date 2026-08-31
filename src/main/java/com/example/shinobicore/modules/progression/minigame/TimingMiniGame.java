package com.example.shinobicore.modules.progression.minigame;

import com.example.shinobicore.modules.progression.network.MiniGameResultPacket;
import net.minecraft.client.gui.DrawContext;

public final class TimingMiniGame extends MiniGameScreen {
    private float markerPos = 0.0f;
    private float targetStart = 0.4f;
    private float targetEnd = 0.6f;
    private float speed = 1.5f;
    private boolean movingRight = true;
    private int resultTicks = 0;

    public TimingMiniGame(String gameId, float speed,
            float targetStart, float targetEnd) {
        super("Timing: " + gameId, gameId);
        this.speed = speed;
        this.targetStart = targetStart;
        this.targetEnd = targetEnd;
    }

    @Override
    protected void gameTick() {
        if (movingRight) {
            markerPos += speed / 20.0f;
            if (markerPos >= 1.0f) movingRight = false;
        } else {
            markerPos -= speed / 20.0f;
            if (markerPos <= 0.0f) {
                state = State.FAILURE;
                MiniGameResultPacket.sendToServer(gameId, false);
            }
        }

        if (state != State.PLAYING) {
            resultTicks++;
            if (resultTicks > 40) close();
        }
    }

    @Override
    public boolean mouseClicked(double mouseX, double mouseY, int button) {
        if (state != State.PLAYING) return false;

        boolean inZone = markerPos >= targetStart && markerPos <= targetEnd;
        state = inZone ? State.SUCCESS : State.FAILURE;
        MiniGameResultPacket.sendToServer(gameId, inZone);
        return true;
    }

    @Override
    protected void gameRender(DrawContext ctx, int mouseX, int mouseY, float delta) {
        int barWidth = 200;
        int barHeight = 20;
        int barX = (width - barWidth) / 2;
        int barY = height / 2;

        // Background bar
        ctx.fill(barX, barY, barX + barWidth, barY + barHeight, 0xFF333333);

        // Target zone
        int zoneStart = barX + (int)(barWidth * targetStart);
        int zoneEnd = barX + (int)(barWidth * targetEnd);
        ctx.fill(zoneStart, barY, zoneEnd, barY + barHeight, 0x8800FF00);

        // Marker
        int markerX = barX + (int)(barWidth * markerPos);
        ctx.fill(markerX - 2, barY - 5, markerX + 2, barY + barHeight + 5, 0xFFFFFFFF);

        // Status
        String statusText = switch (state) {
            case PLAYING -> "Click when the marker is in the green zone";
            case SUCCESS -> "Perfect timing!";
            case FAILURE -> "Missed! Try again.";
        };
        ctx.drawCenteredTextWithShadow(textRenderer, statusText, width / 2, barY + 40, 0xFFFFFF);
    }
}
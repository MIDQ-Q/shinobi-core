package com.example.shinobicore.modules.progression.minigame;

import com.example.shinobicore.modules.progression.network.AttunementAttemptPacket;
import net.minecraft.client.gui.DrawContext;

public final class PulseCircleMiniGame extends MiniGameScreen {
    private float circleSize = 0.0f;
    private float targetSize = 0.5f;
    private float tolerance = 0.1f;
    private boolean growing = true;
    private float speed = 2.0f;
    private final String elementId;
    private int resultTicks = 0;

    public PulseCircleMiniGame(String elementId, float speed,
            float targetSize, float tolerance) {
        super("Attunement: " + elementId, "pulse_circle");
        this.elementId = elementId;
        this.speed = speed;
        this.targetSize = targetSize;
        this.tolerance = tolerance;
    }

    @Override
    protected void gameTick() {
        if (growing) {
            circleSize += speed / 20.0f;
            if (circleSize >= 1.0f) {
                circleSize = 1.0f;
                growing = false;
            }
        } else {
            circleSize -= speed / 20.0f;
            if (circleSize <= 0.0f) {
                state = State.FAILURE;
                AttunementAttemptPacket.sendToServer(elementId, false);
            }
        }

        if (state == State.SUCCESS || state == State.FAILURE) {
            resultTicks++;
            if (resultTicks > 40) {
                close();
            }
        }
    }

    @Override
    public boolean mouseClicked(double mouseX, double mouseY, int button) {
        if (state != State.PLAYING) return false;

        float diff = Math.abs(circleSize - targetSize);
        boolean success = diff <= tolerance;
        state = success ? State.SUCCESS : State.FAILURE;
        AttunementAttemptPacket.sendToServer(elementId, success);
        return true;
    }

    @Override
    protected void gameRender(DrawContext ctx, int mouseX, int mouseY, float delta) {
        int cx = width / 2;
        int cy = height / 2;
        int maxRadius = 80;

        // Target ring
        int targetRadius = (int) (maxRadius * targetSize);
        drawRing(ctx, cx, cy, targetRadius, 2, 0x44FFFFFF);

        // Tolerance zone
        int tolPixels = (int) (maxRadius * tolerance);
        drawRing(ctx, cx, cy, targetRadius + tolPixels, 1, 0x2200FF00);
        if (targetRadius - tolPixels > 0) {
            drawRing(ctx, cx, cy, targetRadius - tolPixels, 1, 0x2200FF00);
        }

        // Current pulsing circle
        int currentRadius = (int) (maxRadius * circleSize);
        boolean inWindow = Math.abs(circleSize - targetSize) <= tolerance;
        int color = inWindow ? 0xFF00FF00 : 0xFFFF4444;

        if (state == State.SUCCESS) color = 0xFF00FF00;
        if (state == State.FAILURE) color = 0xFFFF0000;

        drawRing(ctx, cx, cy, currentRadius, 3, color);

        // Status text
        String statusText = switch (state) {
            case PLAYING -> "Click when the circle matches the target ring";
            case SUCCESS -> "Attunement successful!";
            case FAILURE -> "Attunement failed. Try again.";
        };
        ctx.drawCenteredTextWithShadow(textRenderer, statusText, cx, cy + maxRadius + 20, 0xFFFFFF);

        ctx.drawCenteredTextWithShadow(textRenderer, elementId.toUpperCase(),
            cx, cy - maxRadius - 10, 0xFFFF00);
    }
}
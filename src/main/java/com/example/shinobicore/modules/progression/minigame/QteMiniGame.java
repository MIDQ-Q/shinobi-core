package com.example.shinobicore.modules.progression.minigame;

import com.example.shinobicore.modules.progression.network.MiniGameResultPacket;
import net.minecraft.client.gui.DrawContext;

import java.util.ArrayList;
import java.util.List;

public final class QteMiniGame extends MiniGameScreen {
    private static final char[] KEYS = {'A', 'S', 'D', 'W', 'Q', 'E'};
    private final List<Character> sequence = new ArrayList<>();
    private int currentIndex = 0;
    private int maxTicks = 150;
    private int ticksElapsed = 0;
    private int resultTicks = 0;

    public QteMiniGame(String gameId, int sequenceLength, int maxTicks) {
        super("QTE: " + gameId, gameId);
        this.maxTicks = maxTicks;
        for (int i = 0; i < sequenceLength; i++) {
            sequence.add(KEYS[(int)(Math.random() * KEYS.length)]);
        }
    }

    @Override
    protected void gameTick() {
        ticksElapsed++;
        if (ticksElapsed >= maxTicks && state == State.PLAYING) {
            state = State.FAILURE;
            MiniGameResultPacket.sendToServer(gameId, false);
        }

        if (state != State.PLAYING) {
            resultTicks++;
            if (resultTicks > 40) close();
        }
    }

    @Override
    public boolean keyPressed(int keyCode, int scanCode, int modifiers) {
        if (state != State.PLAYING) return false;

        char pressed = (char) keyCode;
        char expected = sequence.get(currentIndex);

        if (pressed == expected) {
            currentIndex++;
            if (currentIndex >= sequence.size()) {
                state = State.SUCCESS;
                MiniGameResultPacket.sendToServer(gameId, true);
            }
        } else {
            state = State.FAILURE;
            MiniGameResultPacket.sendToServer(gameId, false);
        }
        return true;
    }

    @Override
    protected void gameRender(DrawContext ctx, int mouseX, int mouseY, float delta) {
        int y = height / 2;
        int startX = width / 2 - (sequence.size() * 30) / 2;

        for (int i = 0; i < sequence.size(); i++) {
            int x = startX + i * 30;
            int color;
            if (i < currentIndex) color = 0xFF00FF00;
            else if (i == currentIndex) color = 0xFFFFFFFF;
            else color = 0xFF888888;

            ctx.fill(x, y, x + 24, y + 24, 0xFF333333);
            ctx.drawCenteredTextWithShadow(textRenderer,
                String.valueOf(sequence.get(i)), x + 12, y + 8, color);
        }

        String timeLeft = "Time: " + (maxTicks - ticksElapsed) / 20 + "s";
        ctx.drawCenteredTextWithShadow(textRenderer, timeLeft, width / 2, y - 30, 0xFFFFFF);

        if (state == State.SUCCESS) {
            ctx.drawCenteredTextWithShadow(textRenderer, "Sequence complete!", width / 2, y + 50, 0x00FF00);
        } else if (state == State.FAILURE) {
            ctx.drawCenteredTextWithShadow(textRenderer, "Wrong key!", width / 2, y + 50, 0xFF0000);
        }
    }
}
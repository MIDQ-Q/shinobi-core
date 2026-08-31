package com.example.shinobicore.modules.progression.minigame;

import com.example.shinobicore.modules.progression.network.MiniGameResultPacket;
import net.minecraft.client.gui.DrawContext;

import java.util.ArrayList;
import java.util.List;

public final class TargetMiniGame extends MiniGameScreen {
    private static final int TARGET_COUNT = 5;
    private static final int TARGET_RADIUS = 15;
    private final List<int[]> targets = new ArrayList<>();
    private int hitsRequired = 3;
    private int hits = 0;
    private int ticksElapsed = 0;
    private int maxTicks = 200;
    private int resultTicks = 0;

    public TargetMiniGame(String gameId, int hitsRequired, int maxTicks) {
        super("Targets: " + gameId, gameId);
        this.hitsRequired = hitsRequired;
        this.maxTicks = maxTicks;
        spawnTargets();
    }

    private void spawnTargets() {
        targets.clear();
        for (int i = 0; i < TARGET_COUNT; i++) {
            int x = 50 + (int)(Math.random() * 200);
            int y = 50 + (int)(Math.random() * 150);
            targets.add(new int[]{x, y});
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
    public boolean mouseClicked(double mouseX, double mouseY, int button) {
        if (state != State.PLAYING) return false;

        int mx = (int) mouseX;
        int my = (int) mouseY;

        for (int i = targets.size() - 1; i >= 0; i--) {
            int[] t = targets.get(i);
            int dx = mx - t[0];
            int dy = my - t[1];
            if (dx * dx + dy * dy <= TARGET_RADIUS * TARGET_RADIUS) {
                targets.remove(i);
                hits++;
                if (hits >= hitsRequired) {
                    state = State.SUCCESS;
                    MiniGameResultPacket.sendToServer(gameId, true);
                }
                return true;
            }
        }
        return false;
    }

    @Override
    protected void gameRender(DrawContext ctx, int mouseX, int mouseY, float delta) {
        for (int[] t : targets) {
            drawRing(ctx, t[0], t[1], TARGET_RADIUS, 2, 0xFFFF4444);
        }

        String info = "Hits: " + hits + "/" + hitsRequired
            + "  Time: " + (maxTicks - ticksElapsed) / 20 + "s";
        ctx.drawCenteredTextWithShadow(textRenderer, info, width / 2, 20, 0xFFFFFF);

        if (state == State.SUCCESS) {
            ctx.drawCenteredTextWithShadow(textRenderer, "All targets hit!", width / 2, height / 2, 0x00FF00);
        } else if (state == State.FAILURE) {
            ctx.drawCenteredTextWithShadow(textRenderer, "Time expired!", width / 2, height / 2, 0xFF0000);
        }
    }
}
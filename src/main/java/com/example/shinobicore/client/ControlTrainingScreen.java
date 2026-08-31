package com.example.shinobicore.client;

import com.example.shinobicore.network.ModPackets;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.gui.screen.Screen;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.text.Text;

public class ControlTrainingScreen extends Screen {

    private long startTime;
    private int hits = 0;
    private int attemptsLeft = 5;
    private int endTimer = -1;
    private String lastMsg = "";
    private float speed;
    private float targetCenter;
    private float targetWidth;

    public ControlTrainingScreen() {
        super(Text.literal("Chakra Control Training"));
        startTime = System.currentTimeMillis();
        int control = ClientNinjaState.statLevels.getOrDefault("control", 0);
        speed = 1.2f + control * 0.012f;
        targetWidth = Math.max(0.12f, 0.3f - control * 0.0018f);
        targetCenter = 0.35f + (float)(Math.random() * 0.3);
    }

    private float pulse() {
        float t = (System.currentTimeMillis() - startTime) / 1000f;
        return (float)(0.5 + 0.5 * Math.sin(t * speed * Math.PI * 2));
    }

    @Override
    public void render(DrawContext ctx, int mx, int my, float delta) {
        renderBackground(ctx);
        super.render(ctx, mx, my, delta);
        int cx = width / 2, cy = height / 2;
        int maxR = 70;

        int r1 = (int)(maxR * (targetCenter - targetWidth / 2));
        int r2 = (int)(maxR * (targetCenter + targetWidth / 2));
        for (int r = r1; r <= r2; r += 2) {
            drawCircleOutline(ctx, cx, cy, r, 0x4444FF44);
        }

        float p = pulse();
        int r = Math.max(4, (int)(maxR * p));
        drawCircleOutline(ctx, cx, cy, r, 0xFF44AAFF);
        drawCircleOutline(ctx, cx, cy, r - 1, 0xFF88CCFF);

        drawCentered(ctx, "Chakra Control Training", cx, cy - maxR - 34, 0xFF44AAFF);
        drawCentered(ctx, "LMB when blue circle is in green zone", cx, cy - maxR - 22, 0xFFAAAAAA);
        drawCentered(ctx, "Hits: " + hits + "  |  Left: " + attemptsLeft, cx, cy + maxR + 16, 0xFFFFFFFF);
        drawCentered(ctx, lastMsg, cx, cy + maxR + 30, 0xFF88FF88);
        drawCentered(ctx, "ESC - exit", cx, cy + maxR + 44, 0xFF888888);
    }

    @Override
    public void tick() {
        if (endTimer > 0) {
            endTimer--;
            if (endTimer <= 0) close();
        }
    }

    @Override
    public boolean mouseClicked(double mx, double my, int button) {
        if (button != 0 || attemptsLeft <= 0) return true;
        float p = pulse();
        float diff = Math.abs(p - targetCenter);
        boolean success = diff <= targetWidth / 2f;
        float accuracy = success ? 1f - diff / (targetWidth / 2f) : 0f;
        if (success) hits++;
        attemptsLeft--;
        lastMsg = success ? String.format("HIT! accuracy %.0f%%", accuracy * 100) : "Miss...";
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeBoolean(success);
        buf.writeFloat(accuracy);
        ClientPlayNetworking.send(ModPackets.CONTROL_TRAIN_ID, buf);
        if (attemptsLeft > 0) {
            targetCenter = 0.2f + (float)(Math.random() * 0.6);
            startTime = System.currentTimeMillis();
        } else {
            endTimer = 40;
        }
        return true;
    }

    private void drawCircleOutline(DrawContext ctx, int cx, int cy, int r, int color) {
        if (r <= 0) return;
        int steps = Math.max(24, r * 4);
        for (int i = 0; i < steps; i++) {
            float a = (float)(i * 2 * Math.PI / steps);
            int x = cx + (int)(Math.cos(a) * r);
            int y = cy + (int)(Math.sin(a) * r);
            ctx.fill(x, y, x + 1, y + 1, color);
        }
    }

    private void drawCentered(DrawContext ctx, String text, int cx, int y, int color) {
        int w = textRenderer.getWidth(text);
        ctx.drawText(textRenderer, text, cx - w / 2, y, color, false);
    }

    @Override
    public boolean shouldPause() { return false; }
}
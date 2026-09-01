package com.example.shinobicore.client.attunement;

import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.network.ModPackets;
import com.example.shinobicore.stat.ElementType;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.gui.screen.Screen;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.text.Text;
import net.minecraft.client.MinecraftClient;
import net.minecraft.sound.SoundEvents;
import com.example.shinobicore.client.ClientNinjaStateHolder;

public class AttunementScreen extends Screen {

    private final ElementType element;
    private final int spCost;

    private float needleAngle = 0f;
    private float needleSpeed;
    private float zoneCenter;
    private float zoneWidth;
    private int attemptsLeft = 3;
    private int phase = 0;
    private int resultTimer = 0;

    public AttunementScreen(ElementType element, int spCost) {
        super(Text.literal("Attunement"));
        this.element = element;
        this.spCost = spCost;

        int control = ClientNinjaStateHolder.get().getStatLevels().getOrDefault("control", 0);
        this.zoneWidth = Math.max(15f, 40f - control * 0.25f);
        this.needleSpeed = 4f + control * 0.04f;
        this.zoneCenter = 30f + (float)(Math.random() * 300.0);
    }

    @Override
    public void render(DrawContext ctx, int mx, int my, float delta) {
        renderBackground(ctx);
        super.render(ctx, mx, my, delta);

        int cx = width / 2;
        int cy = height / 2;
        int radius = 60;
        int color = getElementColor(element);

        drawRing(ctx, cx, cy, radius, color);
        drawZone(ctx, cx, cy, radius, zoneCenter, zoneWidth, 0xFF44FF44);
        drawNeedle(ctx, cx, cy, radius, needleAngle);

        for (int i = 0; i < 3; i++) {
            int dotColor = i < attemptsLeft ? 0xFFFFFFFF : 0xFF555555;
            ctx.fill(cx - 30 + i * 25, cy + radius + 20,
                     cx - 20 + i * 25, cy + radius + 30, dotColor);
        }

        drawCentered(ctx, "Attune to " + element.getId(), cx, cy - radius - 30, color);
        drawCentered(ctx, "LMB when needle is in green zone", cx, cy - radius - 18, 0xFFAAAAAA);
        drawCentered(ctx, "SP cost: " + spCost, cx, cy + radius + 36, 0xFF888888);

        if (phase == 1) {
            drawCentered(ctx, "SUCCESS!", cx, cy, 0xFF44FF44);
        } else if (phase == 2) {
            drawCentered(ctx, "FAILED", cx, cy, 0xFFFF4444);
        }
    }

    @Override
    public void tick() {
        if (phase == 0) {
            needleAngle = (needleAngle + needleSpeed) % 360f;
        } else {
            resultTimer++;
            if (resultTimer > 40) close();
        }
    }

    @Override
    public boolean mouseClicked(double mx, double my, int button) {
        if (phase != 0 || button != 0) return true;

        float diff = angleDiff(needleAngle, zoneCenter);
        if (Math.abs(diff) <= zoneWidth / 2f) {
            phase = 1;
            playResultSound(true);
            sendResult(true);
        } else {
            attemptsLeft--;
            if (attemptsLeft <= 0) {
                phase = 2;
                playResultSound(false);
                sendResult(false);
            } else {
                playMissSound();
                zoneCenter = 30f + (float)(Math.random() * 300.0);
            }
        }
        return true;
    }

    private void sendResult(boolean success) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeString(element.getId());
        buf.writeBoolean(success);
        ClientPlayNetworking.send(ModPackets.ATTUNEMENT_ID, buf);
    }

    private void playResultSound(boolean success) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;
        if (success) {
            client.player.playSound(SoundEvents.ENTITY_EXPERIENCE_ORB_PICKUP, 1.0f, 1.2f);
            client.player.playSound(SoundEvents.BLOCK_BEACON_ACTIVATE, 0.8f, 1.0f);
        } else {
            client.player.playSound(SoundEvents.ENTITY_VILLAGER_NO, 1.0f, 0.8f);
        }
    }

    private void playMissSound() {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;
        client.player.playSound(SoundEvents.ENTITY_VILLAGER_NO, 0.4f, 1.5f);
    }

    private float angleDiff(float a, float b) {
        float d = a - b;
        while (d > 180f) d -= 360f;
        while (d < -180f) d += 360f;
        return d;
    }

    private void drawRing(DrawContext ctx, int cx, int cy, int r, int color) {
        int seg = 36;
        for (int i = 0; i < seg; i++) {
            float a1 = (float)(i * 2 * Math.PI / seg);
            float a2 = (float)((i + 1) * 2 * Math.PI / seg);
            int x1 = cx + (int)(Math.cos(a1) * r);
            int y1 = cy + (int)(Math.sin(a1) * r);
            int x2 = cx + (int)(Math.cos(a2) * r);
            int y2 = cy + (int)(Math.sin(a2) * r);
            drawLine(ctx, x1, y1, x2, y2, color);
        }
    }

    private void drawZone(DrawContext ctx, int cx, int cy, int r,
                          float center, float w, int color) {
        float start = (float)Math.toRadians(center - w / 2f);
        float end   = (float)Math.toRadians(center + w / 2f);
        int seg = 12;
        for (int i = 0; i < seg; i++) {
            float a1 = start + (end - start) * i / seg;
            float a2 = start + (end - start) * (i + 1) / seg;
            int x1 = cx + (int)(Math.cos(a1) * r);
            int y1 = cy + (int)(Math.sin(a1) * r);
            int x2 = cx + (int)(Math.cos(a2) * r);
            int y2 = cy + (int)(Math.sin(a2) * r);
            drawLine(ctx, x1, y1, x2, y2, color);
        }
    }

    private void drawNeedle(DrawContext ctx, int cx, int cy, int r, float angle) {
        float rad = (float)Math.toRadians(angle);
        int x2 = cx + (int)(Math.cos(rad) * r);
        int y2 = cy + (int)(Math.sin(rad) * r);
        drawLine(ctx, cx, cy, x2, y2, 0xFFFFFFFF);
    }

    private void drawLine(DrawContext ctx, int x1, int y1, int x2, int y2, int color) {
        int steps = Math.max(Math.abs(x2 - x1), Math.abs(y2 - y1));
        if (steps == 0) { ctx.fill(x1, y1, x1 + 1, y1 + 1, color); return; }
        for (int i = 0; i <= steps; i++) {
            int x = x1 + (x2 - x1) * i / steps;
            int y = y1 + (y2 - y1) * i / steps;
            ctx.fill(x, y, x + 1, y + 1, color);
        }
    }

    private void drawCentered(DrawContext ctx, String text, int cx, int y, int color) {
        int w = textRenderer.getWidth(text);
        ctx.drawText(textRenderer, text, cx - w / 2, y, color, false);
    }

    private int getElementColor(ElementType e) {
        return switch (e) {
            case FIRE      -> 0xFFFF4400;
            case WATER     -> 0xFF2266FF;
            case WIND      -> 0xFF88DDAA;
            case LIGHTNING -> 0xFFFFFF44;
            case EARTH     -> 0xFF996633;
        };
    }
}
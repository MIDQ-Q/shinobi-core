package com.example.shinobicore.client.sakura;

import com.example.shinobicore.client.sakura.ui.GlyphPainter;
import com.example.shinobicore.client.sakura.ui.UiSounds;
import com.example.shinobicore.clan.ClanDefinition;
import com.example.shinobicore.clan.ClanRegistry;
import com.example.shinobicore.stat.ElementType;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.gui.screen.Screen;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.text.Text;
import net.minecraft.util.math.MathHelper;

import java.util.ArrayList;
import java.util.List;

public class AwakeningScreen extends Screen {
    private enum Phase { INTRO, CLAN_SELECT, ELEMENT_REVEAL, DONE }
    private Phase phase = Phase.INTRO;
    private long phaseStartMs;
    private String selectedClan = null;
    private ElementType rolledElement = null;
    private float revealScale = 0f;

    public AwakeningScreen() {
        super(Text.literal("Awakening"));
        this.phaseStartMs = System.currentTimeMillis();
    }

    @Override
    public void render(DrawContext ctx, int mx, int my, float delta) {
        long now = System.currentTimeMillis();
        float t = (now - phaseStartMs) / 1000f;
        
        ctx.fill(0, 0, width, height, 0xDD000000);

        switch (phase) {
            case INTRO -> renderIntro(ctx, t);
            case CLAN_SELECT -> renderClanSelect(ctx, mx, my, t);
            case ELEMENT_REVEAL -> renderElementReveal(ctx, t);
            case DONE -> { if (client != null) client.setScreen(null); }
        }
    }

    private void renderIntro(DrawContext ctx, float t) {
        String[] lines = {
            "You feel a strange energy flowing within...",
            "The chakra pathways are opening.",
            "It is time to choose your path."
        };
        int cy = height / 2 - 40;
        for (int i = 0; i < lines.length; i++) {
            float alpha = MathHelper.clamp((t - i * 1.5f) * 2f, 0, 1);
            int color = (int)(alpha * 255) << 24 | 0xFFF2EAF0;
            drawCentered(ctx, lines[i], width / 2, cy + i * 20, color);
        }
        if (t > 6f) {
            phase = Phase.CLAN_SELECT;
            phaseStartMs = System.currentTimeMillis();
            UiSounds.tab();
        }
    }

    private void renderClanSelect(DrawContext ctx, int mx, int my, float t) {
        drawCentered(ctx, "Choose Your Clan", width / 2, 40, 0xFFFF9EC4);
        List<ClanDefinition> clans = new ArrayList<>(ClanRegistry.getAll());
        if (clans.isEmpty()) {
            drawCentered(ctx, "No clans found. Skipping...", width / 2, height / 2, 0xFF9A8FA6);
            if (t > 2f) phase = Phase.DONE;
            return;
        }
        
        int cols = Math.min(3, clans.size());
        int cardW = 120, cardH = 140, gap = 16;
        int totalW = cols * cardW + (cols - 1) * gap;
        int startX = (width - totalW) / 2;
        int startY = height / 2 - cardH / 2;

        for (int i = 0; i < clans.size(); i++) {
            ClanDefinition c = clans.get(i);
            int col = i % cols;
            int row = i / cols;
            int x = startX + col * (cardW + gap);
            int y = startY + row * (cardH + gap);
            
            boolean hov = mx >= x && mx <= x + cardW && my >= y && my <= y + cardH;
            int bg = hov ? 0xFF2A1B38 : 0xFF171119;
            ctx.fill(x, y, x + cardW, y + cardH, bg);
            ctx.fill(x, y, x + cardW, y + 2, 0xFFFF9EC4);
            
            drawCentered(ctx, c.name(), x + cardW / 2, y + 10, 0xFFF2EAF0);
            
            if (c.affinity() != null) {
                GlyphPainter.drawGlyph(ctx, c.affinity().getId(), x + cardW / 2, y + 40, 0xFFD78AFF);
            }
            
            String affText = c.affinity() != null ? c.affinity().getId() : "None";
            ctx.drawTextWrapped(textRenderer, Text.literal("Affinity: " + affText), x + 8, y + 70, cardW - 16, 0xFF9A8FA6);
            ctx.drawTextWrapped(textRenderer, Text.literal("Bonus: " + (int)(c.reserveBonus() * 100) + "% Reserve"), x + 8, y + 90, cardW - 16, 0xFF9A8FA6);
        }
    }

    private void renderElementReveal(DrawContext ctx, float t) {
        revealScale = MathHelper.clamp(t * 2f, 0, 1.2f);
        if (t > 1.5f) revealScale = 1f + (float)Math.sin((t - 1.5f) * 4f) * 0.05f;
        
        drawCentered(ctx, "Your innate nature awakens...", width / 2, height / 2 - 60, 0xFFF2EAF0);
        
        if (rolledElement != null) {
            int cx = width / 2;
            int cy = height / 2;
            ctx.getMatrices().push();
            ctx.getMatrices().translate(cx, cy, 0);
            ctx.getMatrices().scale(revealScale, revealScale, 1);
            GlyphPainter.drawGlyph(ctx, rolledElement.getId(), 0, 0, 0xFFFFD75E);
            ctx.getMatrices().pop();
            
            drawCentered(ctx, rolledElement.getId().toUpperCase(), cx, cy + 50, 0xFFFFD75E);
        }
        
        if (t > 4f) {
            phase = Phase.DONE;
        }
    }

    @Override
    public boolean mouseClicked(double mx, double my, int btn) {
        if (phase == Phase.CLAN_SELECT && btn == 0) {
            List<ClanDefinition> clans = new ArrayList<>(ClanRegistry.getAll());
            int cols = Math.min(3, clans.size());
            int cardW = 120, cardH = 140, gap = 16;
            int totalW = cols * cardW + (cols - 1) * gap;
            int startX = (width - totalW) / 2;
            int startY = height / 2 - cardH / 2;

            for (int i = 0; i < clans.size(); i++) {
                int col = i % cols;
                int row = i / cols;
                int x = startX + col * (cardW + gap);
                int y = startY + row * (cardH + gap);
                if (mx >= x && mx <= x + cardW && my >= y && my <= y + cardH) {
                    selectedClan = clans.get(i).id();
                    PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
                    buf.writeString(selectedClan);
                    ClientPlayNetworking.send(new net.minecraft.util.Identifier("shinobicore", "awakening_choose"), buf);
                    UiSounds.click();
                    return true;
                }
            }
        }
        return super.mouseClicked(mx, my, btn);
    }
    
    public void revealElement(String elId) {
        ElementType e = null;
        for (ElementType et : ElementType.values()) if (et.getId().equals(elId)) { e = et; break; }
        if (e == null) e = ElementType.FIRE;
        rolledElement = e;
        phase = Phase.ELEMENT_REVEAL;
        phaseStartMs = System.currentTimeMillis();
        UiSounds.unlock();
    }

    private void drawCentered(DrawContext ctx, String text, int x, int y, int color) {
        ctx.drawTextWithShadow(textRenderer, Text.literal(text), x - textRenderer.getWidth(text) / 2, y, color);
    }
    
    @Override public boolean shouldPause() { return true; }
    @Override public boolean shouldCloseOnEsc() { return false; }
}
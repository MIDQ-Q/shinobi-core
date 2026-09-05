package com.example.shinobicore.client.sakura.ui;

import com.example.shinobicore.client.ClientNinjaStateHolder;
import com.example.shinobicore.client.attunement.AttunementScreen;
import com.example.shinobicore.clan.ClanDefinition;
import com.example.shinobicore.clan.ClanRegistry;
import com.example.shinobicore.network.ModPackets;
import com.example.shinobicore.stat.ElementType;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.StatType;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.gui.screen.ingame.InventoryScreen;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.text.Text;

import java.util.ArrayList;
import java.util.List;

/** Interactive character panel with mouse-wheel scrolling. */
public final class CharacterPanel {
    private CharacterPanel() {}

    private static final int ROW_H = 12;
    private static final int CONTENT_TOP_PAD = 32; // fixed header height inside panel
    private static int scroll = 0;

    private record Row(String type, String id, String name, int level, int xp, int need,
                       int cost, boolean maxed, boolean locked, int y) {}

    private static int infoX(int x0) { return x0 + 170; }
    private static int barX(int x0)  { return infoX(x0) + 78; }
    private static int lvX(int x0)   { return infoX(x0) + 140; }
    private static int btnX(int x0)  { return infoX(x0) + 178; }

    public static boolean mouseScrolled(double mx, double my, double amount) {
        scroll -= (int) (amount * 16);
        return true;
    }

    public static void resetScroll() { scroll = 0; }

    /** Rows in local content coordinates (start at y=44). */
    private static List<Row> buildRows() {
        ClientNinjaStateHolder st = ClientNinjaStateHolder.get();
        List<Row> rows = new ArrayList<>();
        int y = 44;
        for (StatType s : StatType.values()) {
            int lvl = st.getStatLevels().getOrDefault(s.getId(), 0);
            int xp = st.getStatXp().getOrDefault(s.getId(), 0);
            rows.add(new Row("stat", s.getId(), s.getId(), lvl, xp,
                NinjaFormula.xpToNextLevel(lvl), NinjaFormula.spCostForLevel(lvl), lvl >= 100, false, y));
            y += ROW_H;
        }
        int rl = st.getReserveLevel();
        rows.add(new Row("reserve", "reserve", "reserve", rl, st.getReserveXp(),
            NinjaFormula.xpToNextLevel(rl), NinjaFormula.spCostForLevel(rl), rl >= 100, false, y));
        y += ROW_H + 8;
        int hp = st.getHpLevel(), sp = st.getSpeedLevel(), jp = st.getJumpLevel();
        rows.add(new Row("body", "hp", "hp", hp, -1, 0, NinjaFormula.bodySpCost(), hp >= 7, false, y)); y += ROW_H;
        rows.add(new Row("body", "speed", "speed", sp, -1, 0, NinjaFormula.bodySpCost(), sp >= 7, false, y)); y += ROW_H;
        rows.add(new Row("body", "jump", "jump", jp, -1, 0, NinjaFormula.bodySpCost(), jp >= 7, false, y));
        y += ROW_H + 8;
        int unlockedCount = 0;
        for (ElementType e : ElementType.values())
            if (st.getNatureUnlocked().getOrDefault(e.getId(), false)) unlockedCount++;
        int attuneCost = 10 + unlockedCount * 5;
        for (ElementType e : ElementType.values()) {
            boolean un = st.getNatureUnlocked().getOrDefault(e.getId(), false);
            int lvl = st.getNatureLevels().getOrDefault(e.getId(), 0);
            int xp = st.getNatureXp().getOrDefault(e.getId(), 0);
            rows.add(new Row("nature", e.getId(), e.getId(), lvl, un ? xp : -1,
                NinjaFormula.xpToNextLevel(lvl), NinjaFormula.spCostForLevel(lvl),
                lvl >= 100, !un, y));
            y += ROW_H;
        }
        return rows;
    }

    private static int contentHeight() {
        List<Row> rows = buildRows();
        if (rows.isEmpty()) return 60;
        return rows.get(rows.size() - 1).y() + ROW_H + 6;
    }

    public static void render(DrawContext ctx, int x0, int y0, int w, int h, int mx, int my) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;
        ClientNinjaStateHolder st = ClientNinjaStateHolder.get();

        // model (fixed)
        int modelX = x0 + 80;
        int modelY = y0 + 140;
        InventoryScreen.drawEntity(ctx, modelX, modelY, 45,
            (float) (modelX - mx), (float) (modelY - 50 - my), client.player);

        int ix = infoX(x0);

        // fixed header: clan + SP
        String clanId = st.getClanId();
        ClanDefinition clan = ClanRegistry.get(clanId);
        String clanName = clan != null ? clan.name() : "Ronin";
        ctx.drawTextWithShadow(client.textRenderer, Text.literal(clanName), ix, y0 + 16, 0xFFFF9EC4);
        ctx.drawTextWithShadow(client.textRenderer, Text.literal("SP: " + st.getSkillPoints()),
            btnX(x0), y0 + 16, 0xFFFFD75E);

        // scrollable area
        int clipTop = y0 + CONTENT_TOP_PAD;
        int clipBottom = y0 + h;
        int viewH = clipBottom - clipTop;
        int contentH = contentHeight();
        int maxScroll = Math.max(0, contentH - viewH);
        if (scroll < 0) scroll = 0;
        if (scroll > maxScroll) scroll = maxScroll;
        int base = clipTop - scroll;

        ctx.enableScissor(x0, clipTop, x0 + w, clipBottom);

        ctx.drawTextWithShadow(client.textRenderer, Text.literal("Affinities:"), ix, base, 0xFF9A8FA6);
        int glyphX = ix;
        for (ElementType e : ElementType.values()) {
            if (st.getNatureUnlocked().getOrDefault(e.getId(), false)) {
                GlyphPainter.drawGlyph(ctx, e.getId(), glyphX + 8, base + 16, 0xFFF2EAF0);
                glyphX += 24;
            }
        }
        ctx.drawTextWithShadow(client.textRenderer, Text.literal("Stats:"), ix, base + 32, 0xFF9A8FA6);

        String prevSection = "";
        for (Row r : buildRows()) {
            String section = r.type().equals("nature") ? "nature" : r.type().equals("body") ? "body" : "stat";
            int ry = base + r.y();
            if (!section.equals(prevSection)) {
                if (section.equals("body")) {
                    ctx.drawTextWithShadow(client.textRenderer, Text.literal("Body:"), ix, ry - 8, 0xFF9A8FA6);
                } else if (section.equals("nature")) {
                    ctx.drawTextWithShadow(client.textRenderer, Text.literal("Natures:"), ix, ry - 8, 0xFF9A8FA6);
                }
                prevSection = section;
            }

            int nameColor = r.locked() ? 0xFF5A5060 : 0xFFD9CFDA;
            ctx.drawTextWithShadow(client.textRenderer, Text.literal(r.name()), ix, ry, nameColor);

            if (!r.locked() && r.xp() >= 0) {
                int bx = barX(x0), bw = 56, bh = 5, by = ry + 3;
                ctx.fill(bx, by, bx + bw, by + bh, 0xFF2A1F2E);
                float prog = r.need() > 0 ? Math.min(1f, (float) r.xp() / r.need()) : 1f;
                int fw = (int) (bw * prog);
                if (fw > 0) {
                    ctx.fill(bx, by, bx + fw, by + bh, 0xFF8A4A66);
                    ctx.fill(bx, by, bx + fw, by + 1, 0xFFD78AB0);
                }
            }
            if (!r.locked()) {
                ctx.drawTextWithShadow(client.textRenderer, Text.literal("Lv " + r.level()), lvX(x0), ry, 0xFFF2EAF0);
            }

            int bx2 = btnX(x0);
            boolean hov = mx >= bx2 - 2 && mx <= bx2 + 28 && my >= ry - 2 && my <= ry + 10;
            if (r.maxed()) {
                ctx.drawTextWithShadow(client.textRenderer, Text.literal("MAX"), bx2, ry, 0xFF5A5060);
            } else if (r.locked()) {
                int col = hov ? 0xFFFFFFFF : 0xFF7EC8FF;
                if (hov) ctx.fill(bx2 - 2, ry - 2, bx2 + 28, ry + 10, 0x227EC8FF);
                ctx.drawTextWithShadow(client.textRenderer, Text.literal("attune " + r.cost()), bx2, ry, col);
            } else {
                boolean afford = st.getSkillPoints() >= r.cost();
                int col = !afford ? 0xFF5A5060 : (hov ? 0xFFFFFFFF : 0xFFFF9EC4);
                if (hov && afford) ctx.fill(bx2 - 2, ry - 2, bx2 + 28, ry + 10, 0x22FF9EC4);
                ctx.drawTextWithShadow(client.textRenderer, Text.literal("+" + r.cost()), bx2, ry, col);
            }
        }

        // scrollbar
        if (maxScroll > 0) {
            int trackX = x0 + w - 5;
            int trackTop = clipTop + 2;
            int trackH = viewH - 4;
            int thumbH = Math.max(10, trackH * viewH / contentH);
            int thumbY = trackTop + (int) ((long) scroll * (trackH - thumbH) / maxScroll);
            ctx.fill(trackX, trackTop, trackX + 2, trackTop + trackH, 0x33FFFFFF);
            ctx.fill(trackX, thumbY, trackX + 2, thumbY + thumbH, 0xFF8A4A66);
        }

        ctx.disableScissor();
    }

    public static boolean handleClick(double mx, double my, int x0, int y0, int button) {
        if (button != 0) return false;
        ClientNinjaStateHolder st = ClientNinjaStateHolder.get();
        int bx = btnX(x0);
        int base = y0 + CONTENT_TOP_PAD - scroll;
        for (Row r : buildRows()) {
            int ry = base + r.y();
            if (mx < bx - 2 || mx > bx + 28 || my < ry - 2 || my > ry + 10) continue;
            if (r.maxed()) return false;
            if (r.locked()) {
                for (ElementType e : ElementType.values()) {
                    if (e.getId().equals(r.id())) {
                        MinecraftClient.getInstance().setScreen(new AttunementScreen(e, r.cost()));
                        return true;
                    }
                }
                return false;
            }
            PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
            buf.writeString(r.type());
            buf.writeString(r.id());
            ClientPlayNetworking.send(ModPackets.SPEND_SP_ID, buf);
            return true;
        }
        return false;
    }
}
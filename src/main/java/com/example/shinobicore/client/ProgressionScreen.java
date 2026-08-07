package com.example.shinobicore.client;

import com.example.shinobicore.network.ModPackets;
import com.example.shinobicore.stat.ElementType;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.StatType;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.gui.screen.Screen;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.text.Text;

import java.util.ArrayList;
import java.util.List;

public class ProgressionScreen extends Screen {

    private record Row(String name, String type, String id, int level, int xp, int need, int cost, boolean locked) {
        public Row(String name, String type, String id, int level, int xp, int need, int cost) {
            this(name, type, id, level, xp, need, cost, false);
        }
    }

    private int tab = 0;

    public ProgressionScreen() {
        super(Text.literal("Ninja Progression"));
    }

    @Override
    public void render(DrawContext context, int mouseX, int mouseY, float delta) {
        renderBackground(context);
        super.render(context, mouseX, mouseY, delta);

        int w = 280;
        int h = 240;
        int x0 = (width - w) / 2;
        int y0 = (height - h) / 2;

        context.fill(x0, y0, x0 + w, y0 + h, 0xCC000000);

        // Заголовок
        String clanText = ClientNinjaState.clanId.equals("none") ? "No Clan" : ClientNinjaState.clanId;
        String affText = ClientNinjaState.affinityId != null ? ClientNinjaState.affinityId : "none";
        context.drawCenteredTextWithShadow(textRenderer,
            clanText + " | " + affText + " | SP: " + ClientNinjaState.skillPoints,
            x0 + w / 2, y0 + 6, 0xFFFFFF);

        // Табы
        int tabW = w / 3 - 6;
        drawTab(context, x0 + 4, y0 + 18, tabW, 0, "Stats");
        drawTab(context, x0 + 8 + tabW, y0 + 18, tabW, 1, "Natures");
        drawTab(context, x0 + 12 + tabW * 2, y0 + 18, tabW, 2, "Body");

        List<Row> rows = buildRows();
        int y = y0 + 34;
        for (Row row : rows) {
            int nameColor = row.locked() ? 0x555555 : 0xAAAAAA;
            int levelColor = row.locked() ? 0x555555 : 0xFFFFFF;
            int xpColor = row.locked() ? 0x444444 : 0x888888;
            
            String displayName = row.locked() ? "🔒 " + row.name() : row.name();
            context.drawTextWithShadow(textRenderer, Text.literal(displayName), x0 + 8, y + 2, nameColor);
            context.drawTextWithShadow(textRenderer, Text.literal("Lv " + row.level()), x0 + 90, y + 2, levelColor);
            
            if (row.xp() >= 0) {
                context.drawTextWithShadow(textRenderer, Text.literal(row.xp() + "/" + row.need()), x0 + 130, y + 2, xpColor);
            }

            if (!row.locked()) {
                boolean afford = ClientNinjaState.skillPoints >= row.cost();
                int color = afford ? 0x55FF55 : 0x555555;
                context.drawTextWithShadow(textRenderer, Text.literal("[+" + row.cost() + "]"), x0 + w - 40, y + 2, color);
            }
            y += 14;
        }

        context.drawCenteredTextWithShadow(textRenderer, Text.literal("K - close"), x0 + w / 2, y0 + h - 12, 0x666666);
    }

    private void drawTab(DrawContext context, int x, int y, int w, int id, String label) {
        int color = (tab == id) ? 0xFF3366AA : 0xFF222222;
        context.fill(x, y, x + w, y + 12, color);
        context.drawCenteredTextWithShadow(textRenderer, Text.literal(label), x + w / 2, y + 2, 0xFFFFFF);
    }

    private List<Row> buildRows() {
        List<Row> rows = new ArrayList<>();
        if (tab == 0) {
            for (StatType s : StatType.values()) {
                int lvl = ClientNinjaState.statLevels.getOrDefault(s.getId(), 0);
                int xp = ClientNinjaState.statXp.getOrDefault(s.getId(), 0);
                rows.add(new Row(s.getId(), "stat", s.getId(), lvl, xp,
                    NinjaFormula.xpToNextLevel(lvl), NinjaFormula.spCostForLevel(lvl)));
            }
            rows.add(new Row("reserve", "reserve", "reserve",
                ClientNinjaState.reserveLevel, ClientNinjaState.reserveXp,
                NinjaFormula.xpToNextLevel(ClientNinjaState.reserveLevel),
                NinjaFormula.spCostForLevel(ClientNinjaState.reserveLevel)));
        } else if (tab == 1) {
            for (ElementType e : ElementType.values()) {
                int lvl = ClientNinjaState.natureLevels.getOrDefault(e.getId(), 0);
                int xp = ClientNinjaState.natureXp.getOrDefault(e.getId(), 0);
                boolean unlocked = ClientNinjaState.natureUnlocked.getOrDefault(e.getId(), false);
                rows.add(new Row(e.getId(), "nature", e.getId(), lvl, xp,
                    NinjaFormula.xpToNextLevel(lvl), NinjaFormula.spCostForLevel(lvl), !unlocked));
            }
        } else {
            rows.add(new Row("HP (max x8)", "body", "hp", ClientNinjaState.hpLevel, -1, 0, NinjaFormula.bodySpCost()));
            rows.add(new Row("Speed (max x2)", "body", "speed", ClientNinjaState.speedLevel, -1, 0, NinjaFormula.bodySpCost()));
            rows.add(new Row("Jump (max x2)", "body", "jump", ClientNinjaState.jumpLevel, -1, 0, NinjaFormula.bodySpCost()));
        }
        return rows;
    }

    @Override
    public boolean mouseClicked(double mouseX, double mouseY, int button) {
        int w = 280;
        int h = 240;
        int x0 = (width - w) / 2;
        int y0 = (height - h) / 2;

        int tabW = w / 3 - 6;
        if (inRect(mouseX, mouseY, x0 + 4, y0 + 18, tabW, 12)) { tab = 0; return true; }
        if (inRect(mouseX, mouseY, x0 + 8 + tabW, y0 + 18, tabW, 12)) { tab = 1; return true; }
        if (inRect(mouseX, mouseY, x0 + 12 + tabW * 2, y0 + 18, tabW, 12)) { tab = 2; return true; }

        List<Row> rows = buildRows();
        int y = y0 + 34;
        for (Row row : rows) {
            if (!row.locked() && inRect(mouseX, mouseY, x0 + w - 44, y, 40, 12)) {
                sendSpend(row.type(), row.id());
                return true;
            }
            y += 14;
        }
        return super.mouseClicked(mouseX, mouseY, button);
    }

    private boolean inRect(double mx, double my, int x, int y, int w, int h) {
        return mx >= x && mx <= x + w && my >= y && my <= y + h;
    }

    private void sendSpend(String type, String id) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeString(type);
        buf.writeString(id);
        ClientPlayNetworking.send(ModPackets.SPEND_SP_ID, buf);
    }

    @Override
    public boolean shouldPause() {
        return false;
    }
}
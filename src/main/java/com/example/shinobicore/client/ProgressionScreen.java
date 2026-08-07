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
    private int loadoutSet = 0;
    private int assignSlot = -1;
    private int listOffset = 0;

    public ProgressionScreen() {
        super(Text.literal("Ninja Progression"));
    }

    @Override
    public void render(DrawContext context, int mouseX, int mouseY, float delta) {
        renderBackground(context);
        super.render(context, mouseX, mouseY, delta);

        int w = 280, h = 240;
        int x0 = (width - w) / 2, y0 = (height - h) / 2;

        context.fill(x0, y0, x0 + w, y0 + h, 0xCC000000);

        String clanText = ClientNinjaState.clanId.equals("none") ? "No Clan" : ClientNinjaState.clanId;
        String affText = ClientNinjaState.affinityId != null ? ClientNinjaState.affinityId : "none";
        context.drawCenteredTextWithShadow(textRenderer,
            clanText + " | " + affText + " | SP: " + ClientNinjaState.skillPoints,
            x0 + w / 2, y0 + 6, 0xFFFFFF);

        int tabW = w / 4 - 5;
        drawTab(context, x0 + 4, y0 + 18, tabW, 0, "Stats");
        drawTab(context, x0 + 8 + tabW, y0 + 18, tabW, 1, "Natures");
        drawTab(context, x0 + 12 + tabW * 2, y0 + 18, tabW, 2, "Body");
        drawTab(context, x0 + 16 + tabW * 3, y0 + 18, tabW, 3, "Jutsu");

        int y = y0 + 34;

        if (tab < 3) {
            for (Row row : buildRows()) {
                int nameColor = row.locked() ? 0x555555 : 0xAAAAAA;
                String displayName = row.locked() ? "* " + row.name() : row.name();
                context.drawTextWithShadow(textRenderer, Text.literal(displayName), x0 + 8, y + 2, nameColor);
                context.drawTextWithShadow(textRenderer, Text.literal("Lv " + row.level()), x0 + 90, y + 2, row.locked() ? 0x555555 : 0xFFFFFF);
                if (row.xp() >= 0) {
                    context.drawTextWithShadow(textRenderer, Text.literal(row.xp() + "/" + row.need()), x0 + 130, y + 2, 0x888888);
                }
                if (!row.locked()) {
                    boolean afford = ClientNinjaState.skillPoints >= row.cost();
                    context.drawTextWithShadow(textRenderer, Text.literal("[+" + row.cost() + "]"),
                        x0 + w - 40, y + 2, afford ? 0x55FF55 : 0x555555);
                }
                y += 14;
            }
        } else {
            renderLoadouts(context, x0, y0, w, y);
        }

        context.drawCenteredTextWithShadow(textRenderer, Text.literal("K - close"), x0 + w / 2, y0 + h - 12, 0x666666);
    }

    private void renderLoadouts(DrawContext context, int x0, int y0, int w, int y) {
        context.fill(x0 + 8, y, x0 + 68, y + 12, loadoutSet == 0 ? 0xFF3366AA : 0xFF222222);
        context.drawCenteredTextWithShadow(textRenderer, Text.literal("Set A"), x0 + 38, y + 2, 0xFFFFFF);
        context.fill(x0 + 76, y, x0 + 136, y + 12, loadoutSet == 1 ? 0xFF3366AA : 0xFF222222);
        context.drawCenteredTextWithShadow(textRenderer, Text.literal("Set B"), x0 + 106, y + 2, 0xFFFFFF);
        y += 18;

        if (assignSlot == -1) {
            context.drawTextWithShadow(textRenderer, Text.literal("Click a slot to assign:"), x0 + 8, y, 0xAAAAAA);
            y += 12;
            for (int i = 0; i < 5; i++) {
                String id = ClientNinjaState.loadout(loadoutSet)[i];
                String name = id == null ? "empty" : ClientNinjaState.name(id);
                context.drawTextWithShadow(textRenderer, Text.literal((i + 1) + ": " + name), x0 + 8, y + 2, 0xFFFFFF);
                y += 14;
            }
        } else {
            context.drawTextWithShadow(textRenderer, Text.literal("Assign to slot " + (assignSlot + 1) + " (Esc to cancel):"), x0 + 8, y, 0xFFFF55);
            y += 12;
            List<String> learned = new ArrayList<>(ClientNinjaState.learned);
            java.util.Collections.sort(learned);
            int shown = 0;
            for (int i = listOffset; i < learned.size() && shown < 8; i++, shown++) {
                String id = learned.get(i);
                context.drawTextWithShadow(textRenderer, Text.literal("- " + ClientNinjaState.name(id)), x0 + 8, y + 2, 0x55FF55);
                y += 14;
            }
            context.drawTextWithShadow(textRenderer, Text.literal("[X] clear slot"), x0 + 8, y + 2, 0xFF5555);
        }
    }

    private void drawTab(DrawContext context, int x, int y, int w, int id, String label) {
        context.fill(x, y, x + w, y + 12, (tab == id) ? 0xFF3366AA : 0xFF222222);
        context.drawCenteredTextWithShadow(textRenderer, Text.literal(label), x + w / 2, y + 2, 0xFFFFFF);
    }

    private List<Row> buildRows() {
        List<Row> rows = new ArrayList<>();
        if (tab == 0) {
            for (StatType s : StatType.values()) {
                int lvl = ClientNinjaState.statLevels.getOrDefault(s.getId(), 0);
                int xp = ClientNinjaState.statXp.getOrDefault(s.getId(), 0);
                rows.add(new Row(s.getId(), "stat", s.getId(), lvl, xp, NinjaFormula.xpToNextLevel(lvl), NinjaFormula.spCostForLevel(lvl)));
            }
            rows.add(new Row("reserve", "reserve", "reserve", ClientNinjaState.reserveLevel, ClientNinjaState.reserveXp,
                NinjaFormula.xpToNextLevel(ClientNinjaState.reserveLevel), NinjaFormula.spCostForLevel(ClientNinjaState.reserveLevel)));
        } else if (tab == 1) {
            for (ElementType e : ElementType.values()) {
                int lvl = ClientNinjaState.natureLevels.getOrDefault(e.getId(), 0);
                int xp = ClientNinjaState.natureXp.getOrDefault(e.getId(), 0);
                boolean unlocked = ClientNinjaState.natureUnlocked.getOrDefault(e.getId(), false);
                rows.add(new Row(e.getId(), "nature", e.getId(), lvl, xp, NinjaFormula.xpToNextLevel(lvl), NinjaFormula.spCostForLevel(lvl), !unlocked));
            }
        } else if (tab == 2) {
            rows.add(new Row("HP (max x8)", "body", "hp", ClientNinjaState.hpLevel, -1, 0, NinjaFormula.bodySpCost()));
            rows.add(new Row("Speed (max x2)", "body", "speed", ClientNinjaState.speedLevel, -1, 0, NinjaFormula.bodySpCost()));
            rows.add(new Row("Jump (max x2)", "body", "jump", ClientNinjaState.jumpLevel, -1, 0, NinjaFormula.bodySpCost()));
        }
        return rows;
    }

    @Override
    public boolean mouseClicked(double mouseX, double mouseY, int button) {
        int w = 280, h = 240;
        int x0 = (width - w) / 2, y0 = (height - h) / 2;

        int tabW = w / 4 - 5;
        if (inRect(mouseX, mouseY, x0 + 4, y0 + 18, tabW, 12)) { tab = 0; assignSlot = -1; return true; }
        if (inRect(mouseX, mouseY, x0 + 8 + tabW, y0 + 18, tabW, 12)) { tab = 1; assignSlot = -1; return true; }
        if (inRect(mouseX, mouseY, x0 + 12 + tabW * 2, y0 + 18, tabW, 12)) { tab = 2; assignSlot = -1; return true; }
        if (inRect(mouseX, mouseY, x0 + 16 + tabW * 3, y0 + 18, tabW, 12)) { tab = 3; assignSlot = -1; return true; }

        if (tab == 3) {
            int y = y0 + 34;
            if (inRect(mouseX, mouseY, x0 + 8, y, 60, 12)) { loadoutSet = 0; return true; }
            if (inRect(mouseX, mouseY, x0 + 76, y, 60, 12)) { loadoutSet = 1; return true; }
            y += 18;

            if (assignSlot == -1) {
                y += 12;
                for (int i = 0; i < 5; i++) {
                    if (inRect(mouseX, mouseY, x0 + 8, y, w - 16, 12)) { assignSlot = i; listOffset = 0; return true; }
                    y += 14;
                }
            } else {
                y += 12;
                List<String> learned = new ArrayList<>(ClientNinjaState.learned);
                java.util.Collections.sort(learned);
                int shown = 0;
                for (int i = listOffset; i < learned.size() && shown < 8; i++, shown++) {
                    if (inRect(mouseX, mouseY, x0 + 8, y, w - 16, 12)) {
                        sendSetSlot(loadoutSet, assignSlot, learned.get(i));
                        assignSlot = -1;
                        return true;
                    }
                    y += 14;
                }
                if (inRect(mouseX, mouseY, x0 + 8, y, w - 16, 12)) {
                    sendSetSlot(loadoutSet, assignSlot, "");
                    assignSlot = -1;
                    return true;
                }
            }
            return true;
        }

        int y = y0 + 34;
        for (Row row : buildRows()) {
            if (!row.locked() && inRect(mouseX, mouseY, x0 + w - 44, y, 40, 12)) {
                sendSpend(row.type(), row.id());
                return true;
            }
            y += 14;
        }
        return super.mouseClicked(mouseX, mouseY, button);
    }

    @Override
    public boolean mouseScrolled(double mouseX, double mouseY, double amount) {
        if (tab == 3 && assignSlot >= 0) {
            listOffset = Math.max(0, (int) (listOffset - amount));
            return true;
        }
        return super.mouseScrolled(mouseX, mouseY, amount);
    }

    @Override
    public boolean keyPressed(int keyCode, int scanCode, int modifiers) {
        if (assignSlot >= 0 && keyCode == 256) {
            assignSlot = -1;
            return true;
        }
        return super.keyPressed(keyCode, scanCode, modifiers);
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

    private void sendSetSlot(int set, int slot, String id) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(set);
        buf.writeInt(slot);
        buf.writeString(id);
        ClientPlayNetworking.send(ModPackets.SET_SLOT_ID, buf);
    }

    @Override
    public boolean shouldPause() {
        return false;
    }
}
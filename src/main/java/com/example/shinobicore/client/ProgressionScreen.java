package com.example.shinobicore.client;

import com.example.shinobicore.client.attunement.AttunementScreen;
import com.example.shinobicore.client.JutsuAssignmentScreen;
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

    private record Row(String name, String type, String id, int level, int xp,
                       int need, int cost, boolean locked) {
        public Row(String name, String type, String id, int level, int xp, int need, int cost) {
            this(name, type, id, level, xp, need, cost, false);
        }
    }

    private static final int PARCHMENT      = 0xFFD8C098;
    private static final int PARCHMENT_EDGE = 0xFFC4A87C;
    private static final int WOOD           = 0xFF5A3A1E;
    private static final int WOOD_DARK      = 0xFF3E2812;
    private static final int WOOD_LIGHT     = 0xFF7A5430;
    private static final int INK            = 0xFF2E1F10;
    private static final int INK_LIGHT      = 0xFF6A563C;
    private static final int SEAL_RED       = 0xFFA3221E;
    private static final int SEAL_RED_ACTIVE= 0xFFD0342C;
    private static final int ACCENT         = 0xFFB4470F;
    private static final int ATTUNE_COLOR   = 0xFF44AAFF;

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

        int w = 300, h = 260;
        int x0 = (width - w) / 2, y0 = (height - h) / 2;

        drawScrollFrame(context, x0, y0, w, h);

        String clanText = ClientNinjaState.clanId.equals("none") ? "No Clan" : ClientNinjaState.clanId;
        String affText  = ClientNinjaState.affinityId != null ? ClientNinjaState.affinityId : "none";
        drawCentered(context, clanText + "  |  " + affText + "  |  SP: " + ClientNinjaState.skillPoints,
                x0 + w / 2, y0 + 8, INK);

        // === Вкладки (5 штук, уменьшенная ширина) ===
        int tabW = 54, tabH = 14, tabY = y0 + 22;
        drawSealTab(context, x0 + 8,                  tabY, tabW, tabH, 0, "Stats");
        drawSealTab(context, x0 + 8 + (tabW + 6),     tabY, tabW, tabH, 1, "Nature");
        drawSealTab(context, x0 + 8 + (tabW + 6) * 2, tabY, tabW, tabH, 2, "Body");
        drawSealTab(context, x0 + 8 + (tabW + 6) * 3, tabY, tabW, tabH, 3, "Jutsu");
        drawSealTab(context, x0 + 8 + (tabW + 6) * 4, tabY, tabW, tabH, 4, "Tree");

        int y = y0 + 44;

        if (tab < 3) {
            for (Row row : buildRows()) {
                int nameColor = row.locked() ? INK_LIGHT : INK;
                String displayName = row.locked() ? "* " + row.name() : row.name();
                context.drawText(textRenderer, Text.literal(displayName), x0 + 10, y + 2, nameColor, false);
                context.drawText(textRenderer, Text.literal("Lv " + row.level()), x0 + 100, y + 2,
                        row.locked() ? INK_LIGHT : INK, false);
                if (row.xp() >= 0) {
                    context.drawText(textRenderer, Text.literal(row.xp() + "/" + row.need()),
                            x0 + 140, y + 2, INK_LIGHT, false);
                }

                if (tab == 0 && row.id().equals("control")) {
                    context.drawText(textRenderer, Text.literal("[Train]"),
                            x0 + w - 80, y + 2, 0xFF1F7A1F, false);
                }
                if (!row.locked()) {
                    boolean afford = ClientNinjaState.skillPoints >= row.cost();
                    context.drawText(textRenderer, Text.literal("[+" + row.cost() + "]"),
                            x0 + w - 44, y + 2, afford ? ACCENT : INK_LIGHT, false);
                } else if (tab == 1) {
                    // Заблокированная стихия -> кнопка Attune
                    int attuneCost = getAttuneCost();
                    boolean afford = ClientNinjaState.skillPoints >= attuneCost;
                    context.drawText(textRenderer, Text.literal("[Attune " + attuneCost + "]"),
                            x0 + w - 80, y + 2, afford ? ATTUNE_COLOR : INK_LIGHT, false);
                }
                y += 14;
            }
        } else if (tab == 3) {
            renderLoadouts(context, x0, y0, w, y);
        } else if (tab == 4) {
            // === ДРЕВО ПРОКАЧКИ: подсказка ===
            drawCentered(context, "Skill Tree", x0 + w / 2, y + 10, INK);
            drawCentered(context, "Press [J] to open full tree view", x0 + w / 2, y + 26, INK_LIGHT);
            drawCentered(context, "Unlocked nodes: " + ClientNinjaState.unlockedNodes.size(),
                    x0 + w / 2, y + 42, ACCENT);
        }

        drawCentered(context, "K - close", x0 + w / 2, y0 + h - 14, INK_LIGHT);
    }

    private int getAttuneCost() {
        int unlockedCount = 0;
        for (ElementType e : ElementType.values()) {
            if (ClientNinjaState.natureUnlocked.getOrDefault(e.getId(), false)) unlockedCount++;
        }
        return 10 + unlockedCount * 5;
    }

    private void drawScrollFrame(DrawContext context, int x0, int y0, int w, int h) {
        context.fill(x0 - 8, y0 - 10, x0 + w + 8, y0, WOOD);
        context.fill(x0 - 8, y0 - 10, x0 + w + 8, y0 - 8, WOOD_LIGHT);
        context.fill(x0 - 8, y0 - 2, x0 + w + 8, y0, WOOD_DARK);
        context.fill(x0 - 8, y0 + h, x0 + w + 8, y0 + h + 10, WOOD);
        context.fill(x0 - 8, y0 + h, x0 + w + 8, y0 + h + 2, WOOD_LIGHT);
        context.fill(x0 - 8, y0 + h + 8, x0 + w + 8, y0 + h + 10, WOOD_DARK);
        context.fill(x0 - 12, y0 - 12, x0 - 8, y0 + 2, WOOD_DARK);
        context.fill(x0 + w + 8, y0 - 12, x0 + w + 12, y0 + 2, WOOD_DARK);
        context.fill(x0 - 12, y0 + h - 2, x0 - 8, y0 + h + 12, WOOD_DARK);
        context.fill(x0 + w + 8, y0 + h - 2, x0 + w + 12, y0 + h + 12, WOOD_DARK);
        context.fill(x0, y0, x0 + w, y0 + h, PARCHMENT);
        context.fill(x0, y0, x0 + 4, y0 + h, PARCHMENT_EDGE);
        context.fill(x0 + w - 4, y0, x0 + w, y0 + h, PARCHMENT_EDGE);
        context.fill(x0 + 6, y0 + 4, x0 + w - 6, y0 + 5, INK_LIGHT);
        context.fill(x0 + 6, y0 + h - 5, x0 + w - 6, y0 + h - 4, INK_LIGHT);
    }

    private void drawSealTab(DrawContext context, int x, int y, int w, int h, int id, String label) {
        boolean active = tab == id;
        context.fill(x, y, x + w, y + h, active ? SEAL_RED_ACTIVE : SEAL_RED);
        context.fill(x, y, x + w, y + 1, 0xFFE08078);
        context.fill(x, y + h - 1, x + w, y + h, 0xFF6E120E);
        if (active) {
            context.fill(x - 1, y - 1, x + w + 1, y, 0xFF1A1A1A);
            context.fill(x - 1, y + h, x + w + 1, y + h + 1, 0xFF1A1A1A);
            context.fill(x - 1, y, x, y + h, 0xFF1A1A1A);
            context.fill(x + w, y, x + w + 1, y + h, 0xFF1A1A1A);
        }
        drawCentered(context, label, x + w / 2, y + 3, 0xFFFFFFFF);
    }

    private void drawSetButton(DrawContext context, int x, int y, int w, int h, int set, String label) {
        boolean active = loadoutSet == set;
        context.fill(x, y, x + w, y + h, active ? ACCENT : PARCHMENT_EDGE);
        context.fill(x, y, x + w, y + 1, 0xFFE8D8B8);
        context.fill(x, y + h - 1, x + w, y + h, 0xFF8A6A40);
        drawCentered(context, label, x + w / 2, y + 2, active ? 0xFFFFFFFF : INK);
    }

    private void renderLoadouts(DrawContext context, int x0, int y0, int w, int y) {
        drawSetButton(context, x0 + 10, y, 60, 12, 0, "Set A");
        drawSetButton(context, x0 + 78, y, 60, 12, 1, "Set B");
        y += 18;
        if (assignSlot == -1) {
            context.drawText(textRenderer, Text.literal("Click a slot to assign:"), x0 + 10, y, INK, false);
            y += 12;
            for (int i = 0; i < 5; i++) {
                String id = ClientNinjaState.loadout(loadoutSet)[i];
                String name = id == null ? "empty" : ClientNinjaState.name(id);
                context.drawText(textRenderer, Text.literal((i + 1) + ": " + name), x0 + 10, y + 2, INK, false);
                y += 14;
            }
        } else {
            context.drawText(textRenderer, Text.literal("Assign to slot " + (assignSlot + 1) + " (Esc cancel):"),
                    x0 + 10, y, ACCENT, false);
            y += 12;
            List<String> learned = new ArrayList<>(ClientNinjaState.learned);
            java.util.Collections.sort(learned);
            int shown = 0;
            for (int i = listOffset; i < learned.size() && shown < 8; i++, shown++) {
                context.drawText(textRenderer, Text.literal("- " + ClientNinjaState.name(learned.get(i))),
                        x0 + 10, y + 2, INK, false);
                y += 14;
            }
            context.drawText(textRenderer, Text.literal("[X] clear slot"), x0 + 10, y + 2, SEAL_RED_ACTIVE, false);
        }
    }

    private void drawCentered(DrawContext context, String text, int cx, int y, int color) {
        int w = textRenderer.getWidth(text);
        context.drawText(textRenderer, text, cx - w / 2, y, color, false);
    }

    private List<Row> buildRows() {
        List<Row> rows = new ArrayList<>();
        if (tab == 0) {
            for (StatType s : StatType.values()) {
                int lvl = ClientNinjaState.statLevels.getOrDefault(s.getId(), 0);
                int xp  = ClientNinjaState.statXp.getOrDefault(s.getId(), 0);
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
                int xp  = ClientNinjaState.natureXp.getOrDefault(e.getId(), 0);
                boolean unlocked = ClientNinjaState.natureUnlocked.getOrDefault(e.getId(), false);
                rows.add(new Row(e.getId(), "nature", e.getId(), lvl, xp,
                        NinjaFormula.xpToNextLevel(lvl), NinjaFormula.spCostForLevel(lvl), !unlocked));
            }
        } else if (tab == 2) {
            rows.add(new Row("HP (max x8)",   "body", "hp",    ClientNinjaState.hpLevel,    -1, 0, NinjaFormula.bodySpCost()));
            rows.add(new Row("Speed (max x2)","body", "speed", ClientNinjaState.speedLevel, -1, 0, NinjaFormula.bodySpCost()));
            rows.add(new Row("Jump (max x2)", "body", "jump",  ClientNinjaState.jumpLevel,  -1, 0, NinjaFormula.bodySpCost()));
        }
        return rows;
    }

    @Override
    public boolean mouseClicked(double mouseX, double mouseY, int button) {
        int w = 300, h = 260;
        int x0 = (width - w) / 2, y0 = (height - h) / 2;

        // Вкладки (5 штук)
        int tabW = 54, tabH = 14, tabY = y0 + 22;
        for (int i = 0; i < 5; i++) {
            if (inRect(mouseX, mouseY, x0 + 8 + (tabW + 6) * i, tabY, tabW, tabH)) {
                tab = i;
                assignSlot = -1;
                return true;
            }
        }

        if (tab == 3) {
            int y = y0 + 44;
            if (inRect(mouseX, mouseY, x0 + 10, y, 60, 12)) { loadoutSet = 0; return true; }
            if (inRect(mouseX, mouseY, x0 + 78, y, 60, 12)) { loadoutSet = 1; return true; }
            y += 18;
            if (assignSlot == -1) {
                y += 12;
                for (int i = 0; i < 5; i++) {
                    if (inRect(mouseX, mouseY, x0 + 10, y, w - 20, 12)) {
                        client.setScreen(new JutsuAssignmentScreen(this, loadoutSet, i)); return true;
                    }
                    y += 14;
                }
            } else {
                y += 12;
                List<String> learned = new ArrayList<>(ClientNinjaState.learned);
                java.util.Collections.sort(learned);
                int shown = 0;
                for (int i = listOffset; i < learned.size() && shown < 8; i++, shown++) {
                    if (inRect(mouseX, mouseY, x0 + 10, y, w - 20, 12)) {
                        sendSetSlot(loadoutSet, assignSlot, learned.get(i));
                        assignSlot = -1;
                        return true;
                    }
                    y += 14;
                }
                if (inRect(mouseX, mouseY, x0 + 10, y, w - 20, 12)) {
                    sendSetSlot(loadoutSet, assignSlot, "");
                    assignSlot = -1;
                    return true;
                }
            }
            return true;
        }

        if (tab == 4) {
            // Древо: клик открывает полный экран
            if (this.client != null) {
                this.client.setScreen(new SkillTreeScreen());
            }
            return true;
        }

        // Прокачка и аттюнмент (табы 0-2)
        int y = y0 + 44;
        for (Row row : buildRows()) {
            // Кнопка прокачки
            if (tab == 0 && row.id().equals("control") && inRect(mouseX, mouseY, x0 + w - 80, y, 36, 12)) {
                if (this.client != null) this.client.setScreen(new ControlTrainingScreen());
                return true;
            }
            if (!row.locked() && inRect(mouseX, mouseY, x0 + w - 44, y, 40, 12)) {
                sendSpend(row.type(), row.id());
                return true;
            }
            // Кнопка Attune для заблокированных стихий
            if (row.locked() && tab == 1 && inRect(mouseX, mouseY, x0 + w - 80, y, 76, 12)) {
                int attuneCost = getAttuneCost();
                if (ClientNinjaState.skillPoints >= attuneCost) {
                    ElementType element = null;
                    for (ElementType e : ElementType.values()) {
                        if (e.getId().equals(row.id())) { element = e; break; }
                    }
                    if (element != null) {
                        // SP deducted server-side on success
                        if (this.client != null) {
                            this.client.setScreen(new AttunementScreen(element, attuneCost));
                        }
                    }
                }
                return true;
            }
            y += 14;
        }
        return super.mouseClicked(mouseX, mouseY, button);
    }

    @Override
    public boolean mouseScrolled(double mouseX, double mouseY, double amount) {
        if (tab == 3 && assignSlot >= 0) {
            listOffset = Math.max(0, (int)(listOffset - amount));
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
    public boolean shouldPause() { return false; }
}
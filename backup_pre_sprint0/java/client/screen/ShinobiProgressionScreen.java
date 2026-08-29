package com.example.shinobicore.client.screen;

import com.example.shinobicore.network.packet.ProgressionActionPacket;
import com.example.shinobicore.progression.SkillNodes;
import com.example.shinobicore.stat.StatType;
import com.example.shinobicore.stat.component.IJutsuComponent;
import com.example.shinobicore.stat.component.IStatsComponent;
import com.example.shinobicore.stat.component.NinjaComponents;
import com.example.shinobicore.jutsu.data.JutsuDefinition;
import com.example.shinobicore.jutsu.data.JutsuRegistry;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.gui.screen.Screen;
import net.minecraft.client.gui.widget.TextFieldWidget;
import net.minecraft.text.Text;

import java.util.ArrayList;
import java.util.List;

/**
 * Progression screen (K): tabs Stats / Jutsu / Skill Tree.
 * Sakura-styled hybrid tree. All mutations go through packets.
 */
public class ShinobiProgressionScreen extends Screen {

    private int tab = 0;
    private String pendingJutsu = null;
    private String filter = "All";
    private TextFieldWidget search;

    private static final StatType[] STAT_ORDER = {
        StatType.NINJUTSU, StatType.TAIJUTSU, StatType.GENJUTSU,
        StatType.KENJUTSU, StatType.SHURIKEN, StatType.CONTROL
    };
    private static final String[] BODY_IDS = { "speed", "jump", "vitality", "reserve", "endurance" };
    private static final String[] FILTERS = { "All", "elemental", "taijutsu", "genjutsu", "kenjutsu", "utility" };

    public ShinobiProgressionScreen() {
        super(Text.literal("Shinobi Progression"));
    }

    @Override
    protected void init() {
        super.init();
        search = new TextFieldWidget(textRenderer, width / 2 + 20, 40, 140, 16, Text.literal("search"));
        search.setMaxLength(40);
    }

    @Override
    public boolean shouldPause() {
        return false;
    }

    @Override
    public void render(DrawContext context, int mouseX, int mouseY, float delta) {
        renderBackground(context);
        context.drawCenteredTextWithShadow(textRenderer, "Shinobi Progression", width / 2, 12, 0xFFFFD7E6);

        // Tabs
        drawTab(context, 0, "Stats", width / 2 - 90);
        drawTab(context, 1, "Jutsu", width / 2 - 30);
        drawTab(context, 2, "Skill Tree", width / 2 + 30);

        IStatsComponent stats = client != null && client.player != null
            ? NinjaComponents.getStats(client.player) : null;
        int sp = stats != null ? stats.getSkillPoints() : 0;
        context.drawText(textRenderer, "SP: " + sp, width - 60, 14, 0xFFFFFFFF, true);

        if (tab == 0) renderStats(context, stats);
        else if (tab == 1) renderJutsu(context);
        else renderTree(context, stats, mouseX, mouseY);

        super.render(context, mouseX, mouseY, delta);
        if (tab == 1) search.render(context, mouseX, mouseY, delta);
    }

    private void drawTab(DrawContext context, int id, String label, int x) {
        int color = (tab == id) ? 0xFFFF9EC7 : 0xAA555555;
        context.fill(x, 24, x + 56, 36, color);
        context.drawText(textRenderer, label, x + 6, 27, 0xFF221122, true);
    }

    // ---------------- STATS TAB ----------------

    private void renderStats(DrawContext context, IStatsComponent stats) {
        int y = 48;
        for (StatType t : STAT_ORDER) {
            int level = stats != null ? stats.getStatLevel(t) : 0;
            float prog = stats != null ? stats.getProgressToNextLevel(t) : 0f;
            context.drawText(textRenderer, t.getDisplayName() + " " + level, 20, y, 0xFFFFFFFF, true);
            context.fill(140, y, 300, y + 6, 0xAA222222);
            context.fill(140, y, 140 + (int) (160 * prog), y + 6, 0xFFFF6B6B);
            drawPlus(context, 310, y - 2);
            y += 14;
        }
        y += 6;
        for (String body : BODY_IDS) {
            int level = bodyLevel(stats, body);
            int max = body.equals("vitality") || body.equals("reserve") || body.equals("endurance") ? 100 : 10;
            context.drawText(textRenderer, body + " " + level + "/" + max, 20, y, 0xFFBFE6FF, true);
            drawPlus(context, 310, y - 2);
            y += 14;
        }
    }

    private int bodyLevel(IStatsComponent stats, String body) {
        if (stats == null) return 0;
        switch (body) {
            case "speed": return stats.getBodyLevelSpeed();
            case "jump": return stats.getBodyLevelJump();
            case "vitality": return stats.getBodyLevelVitality();
            case "reserve": return stats.getBodyLevelReserve();
            case "endurance": return stats.getBodyLevelEndurance();
            default: return 0;
        }
    }

    private void drawPlus(DrawContext context, int x, int y) {
        context.fill(x, y, x + 10, y + 10, 0xFF444444);
        context.drawText(textRenderer, "+", x + 3, y + 1, 0xFFFFFFFF, true);
    }

    // ---------------- JUTSU TAB ----------------

    private void renderJutsu(DrawContext context) {
        IJutsuComponent jutsu = client != null && client.player != null
            ? NinjaComponents.getJutsu(client.player) : null;

        // Loadouts
        for (int l = 0; l < 2; l++) {
            int y = 60 + l * 40;
            context.drawText(textRenderer, (l == 0 ? "Layout A" : "Layout B"), 20, y - 10, 0xFFFFFFFF, true);
            String[] slots = jutsu != null ? jutsu.getLoadout(l) : new String[5];
            for (int s = 0; s < 5; s++) {
                int x = 20 + s * 24;
                context.fill(x, y, x + 20, y + 20, 0xAA222222);
                context.fill(x, y, x + 20, y + 1, 0xAA888888);
                context.fill(x, y + 19, x + 20, y + 20, 0xAA888888);
                context.fill(x, y, x + 1, y + 20, 0xAA888888);
                context.fill(x + 19, y, x + 20, y + 20, 0xAA888888);
                String id = slots != null && s < slots.length ? slots[s] : null;
                if (id != null) {
                    context.drawText(textRenderer, shortName(id), x + 7, y + 6, 0xFFFFD7E6, true);
                }
            }
        }

        // Search + filter
        context.drawText(textRenderer, "Filter: " + filter + " (click)", width / 2 + 20, 60, 0xFFBFE6FF, true);

        // Jutsu grid (learned only)
        int gx = width / 2 + 20;
        int gy = 76;
        String q = search.getText().toLowerCase();
        int count = 0;
        if (jutsu != null) {
            List<JutsuDefinition> all = new ArrayList<>(JutsuRegistry.getAll());
            for (JutsuDefinition def : all) {
                if (!jutsu.hasLearned(def.id())) continue;
                if (!filter.equals("All") && !filter.equals(def.category())) continue;
                if (!def.name().toLowerCase().contains(q) && !def.id().toLowerCase().contains(q)) continue;
                int x = gx + (count % 4) * 40;
                int y = gy + (count / 4) * 40;
                boolean pending = def.id().equals(pendingJutsu);
                context.fill(x, y, x + 32, y + 32, pending ? 0xFFFF9EC7 : 0xAA333333);
                context.drawText(textRenderer, shortName(def.id()), x + 12, y + 12, 0xFFFFFFFF, true);
                count++;
                if (count >= 40) break;
            }
        }
        if (pendingJutsu != null) {
            context.drawText(textRenderer, "Selected: " + pendingJutsu + " -> click a slot", 20, height - 20, 0xFFFF9EC7, true);
        }
    }

    // ---------------- TREE TAB ----------------

    private void renderTree(DrawContext context, IStatsComponent stats, int mouseX, int mouseY) {
        int cx = width / 2;
        int cy = height / 2;
        int rw = Math.min(360, width / 2 - 20);
        int rh = Math.min(200, height / 2 - 40);

        // Lines
        for (SkillNodes.Node n : SkillNodes.NODES) {
            if (n.parent == null) continue;
            SkillNodes.Node p = SkillNodes.byId(n.parent);
            if (p == null) continue;
            drawLine(context,
                cx + (int) ((p.x - 0.5) * 2 * rw), cy + (int) ((p.y - 0.5) * 2 * rh),
                cx + (int) ((n.x - 0.5) * 2 * rw), cy + (int) ((n.y - 0.5) * 2 * rh),
                0xAA66CCDD);
        }

        // Nodes
        SkillNodes.Node hovered = null;
        for (SkillNodes.Node n : SkillNodes.NODES) {
            int x = cx + (int) ((n.x - 0.5) * 2 * rw);
            int y = cy + (int) ((n.y - 0.5) * 2 * rh);
            boolean unlocked = stats != null && stats.hasPassive(n.id);
            int color = unlocked ? n.color : 0xAA444444;
            context.fill(x - 7, y - 7, x + 7, y + 7, color);
            context.fill(x - 7, y - 7, x + 7, y - 6, 0xFFFFFFFF);
            context.fill(x - 7, y + 6, x + 7, y + 7, 0xFFFFFFFF);
            context.fill(x - 7, y - 7, x - 6, y + 7, 0xFFFFFFFF);
            context.fill(x + 6, y - 7, x + 7, y + 7, 0xFFFFFFFF);
            if (mouseX >= x - 7 && mouseX <= x + 7 && mouseY >= y - 7 && mouseY <= y + 7) {
                hovered = n;
            }
        }

        if (hovered != null) {
            String info = hovered.name + " | " + hovered.desc + " | cost " + hovered.cost + " SP";
            context.drawText(textRenderer, info, mouseX + 8, mouseY + 8, 0xFFFFFFFF, true);
        }
    }

    private void drawLine(DrawContext context, int x1, int y1, int x2, int y2, int color) {
        int steps = Math.max(Math.abs(x2 - x1), Math.abs(y2 - y1));
        if (steps == 0) return;
        for (int i = 0; i <= steps; i++) {
            int x = x1 + (x2 - x1) * i / steps;
            int y = y1 + (y2 - y1) * i / steps;
            context.fill(x, y, x + 1, y + 1, color);
        }
    }

    private String shortName(String jutsuId) {
        String s = jutsuId;
        int idx = s.indexOf(':');
        if (idx >= 0 && idx + 1 < s.length()) {
            s = s.substring(idx + 1);
        }
        return s.isEmpty() ? "?" : s.substring(0, 1).toUpperCase();
    }

    // ---------------- INPUT ----------------

    @Override
    public boolean mouseClicked(double mouseX, double mouseY, int button) {
        // Tabs
        if (mouseY >= 24 && mouseY <= 36) {
            if (mouseX >= width / 2 - 90 && mouseX <= width / 2 - 34) { tab = 0; return true; }
            if (mouseX >= width / 2 - 30 && mouseX <= width / 2 + 26) { tab = 1; return true; }
            if (mouseX >= width / 2 + 30 && mouseX <= width / 2 + 86) { tab = 2; return true; }
        }

        if (tab == 0) return statsClick(mouseX, mouseY);
        if (tab == 1) return jutsuClick(mouseX, mouseY);
        if (tab == 2) return treeClick(mouseX, mouseY);
        return super.mouseClicked(mouseX, mouseY, button);
    }

    private boolean statsClick(double mouseX, double mouseY) {
        int y = 48;
        for (StatType t : STAT_ORDER) {
            if (hitPlus(mouseX, mouseY, 310, y - 2)) {
                ProgressionActionPacket.send(1, t.getId());
                return true;
            }
            y += 14;
        }
        y += 6;
        for (String body : BODY_IDS) {
            if (hitPlus(mouseX, mouseY, 310, y - 2)) {
                ProgressionActionPacket.send(2, body);
                return true;
            }
            y += 14;
        }
        return false;
    }

    private boolean hitPlus(double mouseX, double mouseY, int x, int y) {
        return mouseX >= x && mouseX <= x + 10 && mouseY >= y && mouseY <= y + 10;
    }

    private boolean jutsuClick(double mouseX, double mouseY) {
        if (search != null && search.mouseClicked(mouseX, mouseY, button(mouseX))) {
            return true;
        }
        // Filter cycle
        if (mouseX >= width / 2 + 20 && mouseX <= width / 2 + 160 && mouseY >= 58 && mouseY <= 70) {
            int idx = 0;
            for (int i = 0; i < FILTERS.length; i++) {
                if (FILTERS[i].equals(filter)) idx = i;
            }
            filter = FILTERS[(idx + 1) % FILTERS.length];
            return true;
        }
        // Loadout slots
        IJutsuComponent jutsu = client != null && client.player != null
            ? NinjaComponents.getJutsu(client.player) : null;
        for (int l = 0; l < 2; l++) {
            int y = 60 + l * 40;
            for (int s = 0; s < 5; s++) {
                int x = 20 + s * 24;
                if (mouseX >= x && mouseX <= x + 20 && mouseY >= y && mouseY <= y + 20) {
                    String id = pendingJutsu != null ? pendingJutsu : "";
                    ProgressionActionPacket.send(4, l + ":" + s + ":" + id);
                    pendingJutsu = null;
                    return true;
                }
            }
        }
        // Jutsu grid
        int gx = width / 2 + 20;
        int gy = 76;
        String q = search != null ? search.getText().toLowerCase() : "";
        int count = 0;
        if (jutsu != null) {
            List<JutsuDefinition> all = new ArrayList<>(JutsuRegistry.getAll());
            for (JutsuDefinition def : all) {
                if (!jutsu.hasLearned(def.id())) continue;
                if (!filter.equals("All") && !filter.equals(def.category())) continue;
                if (!def.name().toLowerCase().contains(q) && !def.id().toLowerCase().contains(q)) continue;
                int x = gx + (count % 4) * 40;
                int y = gy + (count / 4) * 40;
                if (mouseX >= x && mouseX <= x + 32 && mouseY >= y && mouseY <= y + 32) {
                    pendingJutsu = def.id();
                    return true;
                }
                count++;
                if (count >= 40) break;
            }
        }
        return false;
    }

    private int button(double mouseX) { return 0; }

    private boolean treeClick(double mouseX, double mouseY) {
        int cx = width / 2;
        int cy = height / 2;
        int rw = Math.min(360, width / 2 - 20);
        int rh = Math.min(200, height / 2 - 40);
        for (SkillNodes.Node n : SkillNodes.NODES) {
            int x = cx + (int) ((n.x - 0.5) * 2 * rw);
            int y = cy + (int) ((n.y - 0.5) * 2 * rh);
            if (mouseX >= x - 7 && mouseX <= x + 7 && mouseY >= y - 7 && mouseY <= y + 7) {
                ProgressionActionPacket.send(3, n.id);
                return true;
            }
        }
        return false;
    }

    @Override
    public boolean keyPressed(int keyCode, int scanCode, int modifiers) {
        if (tab == 1 && search != null && search.keyPressed(keyCode, scanCode, modifiers)) {
            return true;
        }
        return super.keyPressed(keyCode, scanCode, modifiers);
    }

    @Override
    public boolean charTyped(char chr, int modifiers) {
        if (tab == 1 && search != null && search.charTyped(chr, modifiers)) {
            return true;
        }
        return super.charTyped(chr, modifiers);
    }
}
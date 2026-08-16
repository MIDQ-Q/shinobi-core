package com.example.shinobicore.client;
import com.example.shinobicore.network.ModPackets;
import com.example.shinobicore.tree.SkillTreeNode;
import com.example.shinobicore.tree.SkillTreeRegistry;
import com.example.shinobicore.tree.SkillTreeRegistry.BranchDef;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.gui.screen.Screen;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.text.Text;
import java.util.*;

public class SkillTreeScreen extends Screen {

    private static final int NODE = 26;
    private static final int HALF = NODE / 2;
    private static final int COL_W = 120;
    private static final int ROW_H = 70;
    private static final int TOP = 70;

    private static final int BG = 0xFF161616;
    private static final int GRID = 0xFF1D1D1D;
    private static final int SLOT_BG = 0xFF212121;
    private static final int SLOT_HI = 0xFF373737;
    private static final int SLOT_LO = 0xFF0C0C0C;
    private static final int LINE_DONE = 0xFF9B9B9B;
    private static final int LINE_LOCK = 0xFF3F3F3F;

    private static final String[] BASE_ORDER = {
        "taijutsu", "earth", "water", "general", "medical", "fire", "wind", "lightning",
        "sensory", "space", "shuriken", "kekkei", "summon", "sealing", "kenjutsu"
    };

    private double viewX, viewY;
    private float zoom = 1.0f;
    private boolean dragging = false;
    private int dragStartX, dragStartY;
    private double dragViewX, dragViewY;
    private SkillTreeNode hovered = null;
    private boolean centered = false;

    public SkillTreeScreen() { super(Text.literal("Skill Tree")); }

    private List<String> branchOrder() {
        List<String> order = new ArrayList<>(Arrays.asList(BASE_ORDER));
        String clan = ClientNinjaState.clanId;
        if (clan != null && !clan.equals("none") && SkillTreeRegistry.getBranch(clan) != null) {
            order.add(clan);
        }
        order.add("forbidden");
        return order;
    }

    private int colX(String branch) {
        List<String> order = branchOrder();
        int i = order.indexOf(branch);
        if (i < 0) i = order.size() - 1;
        return i * COL_W;
    }

    private int[] worldPos(SkillTreeNode n) {
        return new int[]{ colX(n.branch()) + (int)(n.angleOffset() * 5), TOP + n.distance() * ROW_H };
    }

    private int sx(int wx) { return (int)(width / 2f + (wx - viewX) * zoom); }
    private int sy(int wy) { return (int)(height / 2f + (wy - viewY) * zoom); }

    @Override
    public void render(DrawContext ctx, int mx, int my, float delta) {
        if (!centered) {
            viewX = colX("general");
            viewY = TOP + 2 * ROW_H;
            centered = true;
        }

        ctx.fill(0, 0, width, height, BG);
        renderGrid(ctx);
        renderUzumakiSpiral(ctx);

        hovered = null;
        List<String> order = branchOrder();

        // === Р—РђР“РћР›РћР’РљР Р’Р•РўРћРљ ===
        for (String b : order) {
            BranchDef def = SkillTreeRegistry.getBranch(b);
            if (def == null || !isBranchVisible(def)) continue;
            int x = sx(colX(b));
            int y = sy(TOP - 50);
            if (x < -100 || x > width + 100) continue;
            int w = textRenderer.getWidth(def.label()) + 12;
            ctx.fill(x - w / 2, y - 4, x + w / 2, y + 10, 0xFF2A2A2A);
            ctx.fill(x - w / 2, y - 4, x + w / 2, y - 3, 0xFF4A4A4A);
            ctx.fill(x - w / 2, y + 9, x + w / 2, y + 10, 0xFF111111);
            vLine(ctx, x, y + 10, sy(TOP - HALF), 0xFF3A3A3A);
            drawCentered(ctx, def.label(), x, y - 1, def.color());
        }

        // === РљРћРќРќР•РљРўРћР Р« (СѓРіР»РѕРІР°С‚С‹Рµ, РєР°Рє РІ РґРѕСЃС‚РёР¶РµРЅРёСЏС…) ===
        for (SkillTreeNode n : SkillTreeRegistry.getAll()) {
            if (!SkillTreeRegistry.isVisibleClient(n)) continue;
            int[] c = worldPos(n);
            for (String req : n.requires()) {
                SkillTreeNode p = SkillTreeRegistry.get(req);
                if (p == null || !SkillTreeRegistry.isVisibleClient(p)) continue;
                int[] pw = worldPos(p);
                boolean done = ClientNinjaState.unlockedNodes.contains(n.id())
                        && ClientNinjaState.unlockedNodes.contains(req);
                int color = done ? LINE_DONE : LINE_LOCK;
                int px = sx(pw[0]), py = sy(pw[1]);
                int cx2 = sx(c[0]), cy2 = sy(c[1]);
                if (px == cx2) {
                    vLine(ctx, px, py + HALF, cy2 - HALF, color);
                } else if (py == cy2) {
                    hLine(ctx, px, cx2, py, color);
                } else {
                    int startY = py + (cy2 > py ? HALF : -HALF);
                    int endY = cy2 + (cy2 > py ? -HALF : HALF);
                    vLine(ctx, px, startY, endY, color);
                    hLine(ctx, px, cx2, endY, color);
                }
            }
        }

        // === РЈР—Р›Р«-РЎР›РћРўР« ===
        for (SkillTreeNode n : SkillTreeRegistry.getAll()) {
            if (!SkillTreeRegistry.isVisibleClient(n)) continue;
            int[] w = worldPos(n);
            int x = sx(w[0]), y = sy(w[1]);
            if (x < -40 || x > width + 40 || y < -40 || y > height + 40) continue;

            boolean unlocked = ClientNinjaState.unlockedNodes.contains(n.id());
            boolean available = canUnlock(n);
            BranchDef def = SkillTreeRegistry.getBranch(n.branch());
            int bc = def != null ? (0xFF000000 | (def.color() & 0xFFFFFF)) : 0xFFAAAAAA;

            if (mx >= x - HALF - 2 && mx <= x + HALF + 2 && my >= y - HALF - 2 && my <= y + HALF + 2) {
                hovered = n;
            }

            // Р¤РѕРЅ СЃР»РѕС‚Р°
            ctx.fill(x - HALF, y - HALF, x + HALF, y + HALF, SLOT_BG);
            ctx.fill(x - HALF, y - HALF, x + HALF, y - HALF + 1, SLOT_HI);
            ctx.fill(x - HALF, y + HALF - 1, x + HALF, y + HALF, SLOT_LO);

            // Р Р°РјРєР° 2px
            boolean invalid = SkillTreeRegistry.isInvalid(n.id());            int border;
            if (invalid) {                border = 0xFFFF2222;            } else if (unlocked) {                border = bc;
            } else if (available) {
                int pulse = (int)(150 + 105 * Math.sin(System.currentTimeMillis() / 250.0));
                border = (pulse << 24) | 0xFFFF00;
            } else {
                border = 0xFF555555;
            }
            ctx.fill(x - HALF - 2, y - HALF - 2, x + HALF + 2, y - HALF, border);
            ctx.fill(x - HALF - 2, y + HALF, x + HALF + 2, y + HALF + 2, border);
            ctx.fill(x - HALF - 2, y - HALF, x - HALF, y + HALF, border);
            ctx.fill(x + HALF, y - HALF, x + HALF + 2, y + HALF, border);

            // РРєРѕРЅРєР°
            int iconColor = unlocked ? 0xFFFFFFFF : (available ? 0xFFDDDDDD : 0xFF777777);
            drawCentered(ctx, n.icon(), x, y - 4, iconColor);

            // РњРµС‚РєР° СЂР°Р·Р±Р»РѕРєРёСЂРѕРІРєРё
            if (unlocked) {
                ctx.fill(x + HALF - 6, y + HALF - 6, x + HALF - 2, y + HALF - 2, bc);
            }
        }

        // === Р’Р•Р РҐРќРЇРЇ РџР›РђРЁРљРђ (РІР°Р№Р± РќР°СЂСѓС‚Рѕ) ===
        ctx.fill(0, 0, width, 22, 0xCC000000);
        ctx.fill(0, 22, width, 23, 0xFFB4470F);
        drawCentered(ctx, "SHINOBI PATH  |  SP: " + ClientNinjaState.skillPoints
                + "  |  Clan: " + ClientNinjaState.clanId + "  |  ESC - close",
                width / 2, 7, 0xFFFFAA00);

        if (hovered != null) renderTooltip(ctx, hovered, mx, my);

        ctx.fill(0, height - 14, width, height, 0xCC000000);
        drawCentered(ctx, "LMB - unlock | RMB - move | Wheel - zoom " + (int)(zoom * 100) + "%",
                width / 2, height - 11, 0xFF888888);
    }

    // === РЎР•РўРљРђ Р¤РћРќРђ (РєР°Рє РІ РґРѕСЃС‚РёР¶РµРЅРёСЏС…) ===
    private void renderGrid(DrawContext ctx) {
        int step = 32;
        double wl = viewX - width / (2.0 * zoom);
        double wr = viewX + width / (2.0 * zoom);
        double wt = viewY - height / (2.0 * zoom);
        double wb = viewY + height / (2.0 * zoom);
        for (double gx = Math.floor(wl / step) * step; gx <= wr; gx += step) {
            int x = sx((int) gx);
            ctx.fill(x, 0, x + 1, height, GRID);
        }
        for (double gy = Math.floor(wt / step) * step; gy <= wb; gy += step) {
            int y = sy((int) gy);
            ctx.fill(0, y, width, y + 1, GRID);
        }
    }

    // === РЎРџРР РђР›Р¬ РЈР—РЈРњРђРљР (С„РѕРЅРѕРІР°СЏ РїРµС‡Р°С‚СЊ) ===
    private void renderUzumakiSpiral(DrawContext ctx) {
        int cxw = colX("general");
        int cyw = TOP + 2 * ROW_H;
        int prevX = -1, prevY = -1;
        for (int i = 0; i <= 160; i++) {
            float t = i / 160.0f * (float)(Math.PI * 6);
            float r = 8 + t * 9;
            int x = sx((int)(cxw + Math.cos(t) * r));
            int y = sy((int)(cyw + Math.sin(t) * r));
            if (prevX >= 0) {
                int steps = Math.max(Math.abs(x - prevX), Math.abs(y - prevY));
                if (steps > 0) {
                    for (int s = 0; s <= steps; s++) {
                        int ix = prevX + (x - prevX) * s / steps;
                        int iy = prevY + (y - prevY) * s / steps;
                        ctx.fill(ix, iy, ix + 2, iy + 2, 0x22FF7700);
                    }
                }
            }
            prevX = x; prevY = y;
        }
    }

    private boolean isBranchVisible(BranchDef b) {
        if (b.clan() != null && !b.clan().equals(ClientNinjaState.clanId)) return false;
        if (b.hidden()) {
            for (SkillTreeNode n : SkillTreeRegistry.getAll()) {
                if (n.branch().equals(b.id()) && SkillTreeRegistry.isVisibleClient(n)) return true;
            }
            return false;
        }
        return true;
    }

    private boolean canUnlock(SkillTreeNode node) {
        if (SkillTreeRegistry.isInvalid(node.id())) return false;
        if (ClientNinjaState.unlockedNodes.contains(node.id())) return false;
        if (ClientNinjaState.skillPoints < node.spCost()) return false;
        if (node.requiresTeacher() && !ClientNinjaState.teacherApproved.contains(node.id())) return false;
        for (String r : node.requires()) {
            if (!ClientNinjaState.unlockedNodes.contains(r)) return false;
        }
        return true;
    }

    // === РўРЈР›РўРРџ-РЎР’РРўРћРљ (РїРµСЂРіР°РјРµРЅС‚, РІР°Р№Р± РќР°СЂСѓС‚Рѕ) ===
    private void renderTooltip(DrawContext ctx, SkillTreeNode node, int mx, int my) {
        List<String> lines = new ArrayList<>();
        lines.add(node.displayName());
        lines.add("Branch: " + node.branch());
        if (node.jutsuId() != null) lines.add("Teaches: " + ClientNinjaState.name(node.jutsuId()));
        if (node.description() != null && !node.description().isEmpty()) lines.add(node.description());
        lines.add("SP: " + node.spCost());
        if (!node.requires().isEmpty()) lines.add("Requires: " + String.join(", ", node.requires()));
        boolean unlocked = ClientNinjaState.unlockedNodes.contains(node.id());
        boolean available = canUnlock(node);
        if (SkillTreeRegistry.isInvalid(node.id())) lines.add("[INVALID] " + SkillTreeRegistry.getInvalidReason(node.id()));
        else if (unlocked) lines.add("[UNLOCKED]");
        else if (available) lines.add("[Click to unlock]");
        else {
            lines.add("[Locked]");
            if (node.requiresTeacher() && !ClientNinjaState.teacherApproved.contains(node.id())) {
                lines.add("  Requires a teacher");
            }
            if (node.requiresScroll() != null && !node.requiresScroll().isEmpty()) {
                lines.add("  Requires scroll: " + node.requiresScroll());
            }
        }

        int tw = 0;
        for (String l : lines) tw = Math.max(tw, textRenderer.getWidth(l));
        int th = lines.size() * 10 + 10;
        int tx = Math.min(mx + 12, width - tw - 20);
        int ty = Math.max(my - th - 8, 4);

        // РџРµСЂРіР°РјРµРЅС‚ + РґРµСЂРµРІСЏРЅРЅР°СЏ СЂР°РјРєР°
        ctx.fill(tx - 3, ty - 3, tx + tw + 15, ty + th + 3, 0xFF5A3A1E);
        ctx.fill(tx, ty, tx + tw + 12, ty + th, 0xFFD8C098);
        ctx.fill(tx, ty, tx + tw + 12, ty + 1, 0xFFE8D8B8);
        ctx.fill(tx, ty + th - 1, tx + tw + 12, ty + th, 0xFFC4A87C);

        BranchDef b = SkillTreeRegistry.getBranch(node.branch());
        int barColor = b != null ? (0xFF000000 | (b.color() & 0xFFFFFF)) : 0xFF2E1F10;
        ctx.fill(tx + 4, ty + 4, tx + 7, ty + 12, barColor);

        int ly = ty + 5;
        ctx.drawText(textRenderer, lines.get(0), tx + 10, ly, 0xFF2E1F10, false);
        ly += 11;
        for (int i = 1; i < lines.size(); i++) {
            String l = lines.get(i);
            int col = 0xFF6A563C;
            if (l.startsWith("[")) col = unlocked ? 0xFF1F7A1F : (available ? 0xFFB4470F : 0xFFA3221E);
            ctx.drawText(textRenderer, l, tx + 6, ly, col, false);
            ly += 10;
        }
    }

    @Override public boolean mouseClicked(double mx, double my, int btn) {
        if (btn == 1) {
            dragging = true;
            dragStartX = (int) mx; dragStartY = (int) my;
            dragViewX = viewX; dragViewY = viewY;
            return true;
        }
        if (btn == 0 && hovered != null && canUnlock(hovered)) {
            PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
            buf.writeString(hovered.id());
            ClientPlayNetworking.send(ModPackets.UNLOCK_NODE_ID, buf);
            return true;
        }
        return super.mouseClicked(mx, my, btn);
    }

    @Override public boolean mouseReleased(double mx, double my, int btn) {
        if (btn == 1) dragging = false;
        return super.mouseReleased(mx, my, btn);
    }

    @Override public boolean mouseDragged(double mx, double my, int btn, double dx, double dy) {
        if (dragging) {
            viewX = dragViewX - (mx - dragStartX) / zoom;
            viewY = dragViewY - (my - dragStartY) / zoom;
            return true;
        }
        return super.mouseDragged(mx, my, btn, dx, dy);
    }

    @Override public boolean mouseScrolled(double mx, double my, double amount) {
        zoom = (float)Math.max(0.5, Math.min(1.6, zoom + amount * 0.1));
        return true;
    }

    private void vLine(DrawContext ctx, int x, int y1, int y2, int c) {
        if (y2 < y1) { int t = y1; y1 = y2; y2 = t; }
        ctx.fill(x - 1, y1, x + 1, y2, c);
    }

    private void hLine(DrawContext ctx, int x1, int x2, int y, int c) {
        if (x2 < x1) { int t = x1; x1 = x2; x2 = t; }
        ctx.fill(x1, y - 1, x2, y + 1, c);
    }

    private void drawCentered(DrawContext ctx, String text, int cx, int y, int color) {
        int w = textRenderer.getWidth(text);
        ctx.drawText(textRenderer, text, cx - w / 2, y, color, false);
    }

    @Override public boolean shouldPause() { return false; }
}
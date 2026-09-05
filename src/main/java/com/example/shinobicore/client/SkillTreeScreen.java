package com.example.shinobicore.client;

import com.example.shinobicore.client.sakura.ui.GlyphPainter;
import com.example.shinobicore.client.sakura.ui.IconAtlas;
import com.example.shinobicore.client.sakura.ui.SakuraAtmosphere;
import com.example.shinobicore.client.sakura.ui.SakuraGlass;
import com.example.shinobicore.client.sakura.ui.SakuraTextures;
import com.example.shinobicore.client.sakura.ui.SakuraTheme;
import com.example.shinobicore.client.sakura.ui.UiAnim;
import com.example.shinobicore.client.sakura.ui.UiEase;
import com.example.shinobicore.client.sakura.ui.UiSounds;
import com.example.shinobicore.network.ModPackets;
import com.example.shinobicore.tree.SkillTreeNode;
import com.example.shinobicore.tree.SkillTreeRegistry;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.gui.screen.Screen;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.text.Text;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/** Variant B: hanging scroll gallery (kakemono). */
public class SkillTreeScreen extends Screen {

    private static final int MM_W = 168;
    private static final int MM_H = 74;

    private final boolean embedded;

    // camera
    private double viewX, viewY, tViewX, tViewY;
    private float zoom = 1f, tZoom = 1f;
    private double panVX, panVY;
    private boolean dragging;
    private boolean centered;
    private long lastMs;
    private long lastDenyMs;
    private long openMs;
    private long lastClickMs = -1000;
    private int lastClickScroll = -1;

    // interaction
    private String hoveredId;
    private final Map<String, Long> fx = new HashMap<>();
    private Set<String> prevUnlocked;

    // per-frame layout cache
    private final List<ScrollBox> scrolls = new ArrayList<>();
    private final Map<String, int[]> nodePos = new HashMap<>();
    private final List<int[]> edgeAvail = new ArrayList<>();
    private float uiScale = 1f;

    private static class ScrollBox {
        String branch; int index; int x; int top; int fullH; int curH; int nodes;
    }

    public SkillTreeScreen(boolean embedded) {
        super(Text.literal("Skill Tree"));
        this.embedded = embedded;
    }

    public SkillTreeScreen() { this(false); }

    @Override
    protected void init() {
        super.init();
        if (client != null) {
            SakuraTextures.init(client);
            IconAtlas.init(client);
        }
        openMs = System.currentTimeMillis();
    }

    private int spNow() { return ClientNinjaStateHolder.get().getSkillPoints(); }

    // ================= RENDER =================

    @Override
    public void render(DrawContext ctx, int mx, int my, float delta) {
        long now = System.currentTimeMillis();
        float dt = lastMs == 0 ? 0.016f : Math.min(0.1f, (now - lastMs) / 1000f);
        lastMs = now;

        uiScale = Math.min(width / 800f, height / 500f);
        uiScale = Math.max(0.8f, Math.min(uiScale, 1.4f));

        if (!centered) {
            List<String> order = branchOrder();
            int home = order.indexOf("general");
            if (home < 0) home = 0;
            tViewX = viewX = home * (SakuraTheme.SCROLL_W + SakuraTheme.SCROLL_GAP) + SakuraTheme.SCROLL_W / 2f;
            tViewY = viewY = 170;
            centered = true;
        }

        panVX *= Math.exp(-6 * dt);
        panVY *= Math.exp(-6 * dt);
        if (!dragging) { tViewX += panVX * dt; tViewY += panVY * dt; }
        float k = 1 - (float) Math.exp(-14 * dt);
        viewX += (tViewX - viewX) * k;
        viewY += (tViewY - viewY) * k;
        zoom += (tZoom - zoom) * k;

        SakuraAtmosphere.render(ctx, width, height, now, viewX * zoom, viewY * zoom);

        Set<String> unlocked = ClientNinjaStateHolder.get().getUnlockedNodes();
        if (prevUnlocked != null) {
            for (String id : unlocked) {
                if (!prevUnlocked.contains(id) && SkillTreeRegistry.get(id) != null) {
                    fx.put(id, now);
                    UiSounds.unlock();
                }
            }
        }
        prevUnlocked = new HashSet<>(unlocked);

        buildLayout(now);
        hoveredId = null;
        edgeAvail.clear();

        // world space
        ctx.getMatrices().push();
        ctx.getMatrices().translate(width / 2f, height / 2f, 0);
        ctx.getMatrices().scale(scale(), scale(), 1);
        ctx.getMatrices().translate(-viewX, -viewY, 0);

        drawBeam(ctx);
        for (ScrollBox sb : scrolls) drawScroll(ctx, sb, now);
        drawHoverLinks(ctx, unlocked);
        for (ScrollBox sb : scrolls) drawScrollNodes(ctx, sb, unlocked, now);

        ctx.getMatrices().pop();

        // screen space
        drawEdgeIndicators(ctx);
        drawMinimap(ctx, unlocked);
        drawHud(ctx);

        if (hoveredId != null) {
            drawTooltip(ctx, SkillTreeRegistry.get(hoveredId), mx, my, unlocked);
        }
    }

    private void drawBeam(DrawContext ctx) {
        if (scrolls.isEmpty()) return;
        int x0 = scrolls.get(0).x - 60;
        int x1 = scrolls.get(scrolls.size() - 1).x + SakuraTheme.SCROLL_W + 60;
        ctx.fill(x0, 0, x1, SakuraTheme.BEAM_H, SakuraTheme.ROLLER);
        ctx.fill(x0, 0, x1, 2, 0xFF8A6A4A);
        ctx.fill(x0, SakuraTheme.BEAM_H - 2, x1, SakuraTheme.BEAM_H, SakuraTheme.ROLLER_DARK);
    }

    private void drawScroll(DrawContext ctx, ScrollBox sb, long now) {
        int sx0 = sx(sb.x);
        if (sx0 + SakuraTheme.SCROLL_W * scale() < -40 || sx0 > width + 40) return;
        int cx = sb.x + SakuraTheme.SCROLL_W / 2;

        // cords (V shape) from beam to top roller
        line(ctx, cx, SakuraTheme.BEAM_H, sb.x + 8, sb.top, SakuraTheme.CORD_RED);
        line(ctx, cx, SakuraTheme.BEAM_H, sb.x + SakuraTheme.SCROLL_W - 8, sb.top, SakuraTheme.CORD_RED);
        ctx.fill(cx - 2, SakuraTheme.BEAM_H - 2, cx + 2, SakuraTheme.BEAM_H + 3, SakuraTheme.CORD_RED);

        int w = SakuraTheme.SCROLL_W;
        int h = sb.curH;
        int y0 = sb.top;

        // paper
        ctx.fill(sb.x, y0, sb.x + w, y0 + h, SakuraTheme.PAPER);
        ctx.fill(sb.x, y0, sb.x + 3, y0 + h, SakuraTheme.PAPER_EDGE);
        ctx.fill(sb.x + w - 3, y0, sb.x + w, y0 + h, SakuraTheme.PAPER_EDGE);
        ctx.fill(sb.x + 3, y0, sb.x + 6, y0 + h, SakuraTheme.PAPER_SHADE);
        ctx.fill(sb.x + w - 6, y0, sb.x + w - 3, y0 + h, SakuraTheme.PAPER_SHADE);

        // rollers
        ctx.fill(sb.x - 5, y0 - SakuraTheme.ROLLER_H, sb.x + w + 5, y0, SakuraTheme.ROLLER);
        ctx.fill(sb.x - 7, y0 - SakuraTheme.ROLLER_H, sb.x - 5, y0, SakuraTheme.ROLLER_DARK);
        ctx.fill(sb.x + w + 5, y0 - SakuraTheme.ROLLER_H, sb.x + w + 7, y0, SakuraTheme.ROLLER_DARK);
        int by = y0 + h;
        ctx.fill(sb.x - 5, by, sb.x + w + 5, by + SakuraTheme.ROLLER_H, SakuraTheme.ROLLER);
        ctx.fill(sb.x - 7, by, sb.x - 5, by + SakuraTheme.ROLLER_H, SakuraTheme.ROLLER_DARK);
        ctx.fill(sb.x + w + 5, by, sb.x + w + 7, by + SakuraTheme.ROLLER_H, SakuraTheme.ROLLER_DARK);

        if (h < SakuraTheme.ROLLER_H * 2 + SakuraTheme.HEADER_H) return;

        // header: icon + label
        SkillTreeRegistry.BranchDef def = SkillTreeRegistry.getBranch(sb.branch);
        int hc = def != null ? def.color() : 0xFFAAAAAA;
        IconAtlas.draw(ctx, branchIcon(sb.branch), cx - 7, y0 + SakuraTheme.ROLLER_H + 4, 14);
        String label = def != null ? def.label() : sb.branch;
        ctx.drawTextWithShadow(textRenderer, Text.literal(label),
            cx - textRenderer.getWidth(label) / 2, y0 + SakuraTheme.ROLLER_H + 20, 0xFF2A2130);
        ctx.fill(cx - w / 2 + 10, y0 + SakuraTheme.ROLLER_H + 30, cx + w / 2 - 10,
            y0 + SakuraTheme.ROLLER_H + 31, (0xFF000000 | (hc & 0x00FFFFFF)) & 0x88FFFFFF);

        // footer progress
        if (h >= sb.fullH - 4) {
            Set<String> unlocked = ClientNinjaStateHolder.get().getUnlockedNodes();
            int un = 0, avail = 0;
            for (SkillTreeNode n : nodesOf(sb.branch)) {
                if (unlocked.contains(n.id())) un++;
                else if (canUnlockClient(n, unlocked)) avail++;
            }
            String prog = avail > 0 ? "+" + avail : (un + "/" + sb.nodes);
            int pc = avail > 0 ? 0xFFB3222E : 0xFF6B5A44;
            ctx.drawTextWithShadow(textRenderer, Text.literal(prog),
                cx - textRenderer.getWidth(prog) / 2, by - 14, pc);
        }
    }

    private void drawScrollNodes(DrawContext ctx, ScrollBox sb, Set<String> unlocked, long now) {
        if (sb.curH < sb.fullH - 4) return;
        int sx0 = sx(sb.x);
        if (sx0 + SakuraTheme.SCROLL_W * scale() < -40 || sx0 > width + 40) return;

        List<SkillTreeNode> ns = nodesOf(sb.branch);
        // ink line
        if (ns.size() > 1) {
            int[] a = nodePos.get(ns.get(0).id());
            int[] b = nodePos.get(ns.get(ns.size() - 1).id());
            if (a != null && b != null) ctx.fill(a[0], a[1], a[0] + 1, b[1], SakuraTheme.INK_LINE);
        }

        double wmx = viewX + (mouseX() - width / 2f) / scale();
        double wmy = viewY + (mouseY() - height / 2f) / scale();

        for (SkillTreeNode n : ns) {
            int[] c = nodePos.get(n.id());
            if (c == null) continue;
            int x = c[0], y = c[1];
            boolean isUnlocked = unlocked.contains(n.id());
            boolean avail = !isUnlocked && canUnlockClient(n, unlocked);

            double dist = Math.hypot(wmx - x, wmy - y);
            boolean hovered = dist <= SakuraTheme.NODE_R + 4;
            if (hovered) hoveredId = n.id();

            SkillTreeRegistry.BranchDef b = SkillTreeRegistry.getBranch(n.branch());
            int bc = b != null ? (0xFF000000 | b.color()) : 0xFFAAAAAA;

            float animScale = 1f;
            Long f = fx.get(n.id());
            if (f != null) {
                float t = (now - f) / (float) SakuraTheme.UNLOCK_MS;
                if (t >= 1f) fx.remove(n.id());
                else animScale = 0.4f + 0.6f * UiEase.outBack(Math.max(0, t));
            }
            int drawR = Math.max(5, (int) (SakuraTheme.NODE_R * animScale * (hovered ? 1.12f : 1f)));

            // unlock glow flash
            if (f != null) {
                float t = (now - f) / (float) SakuraTheme.UNLOCK_MS;
                int ga = (int) ((1f - t) * 90);
                fillCircle(ctx, x, y, drawR + 5, (ga << 24) | 0xFF9EC4);
            }

            // unlocked steady glow
            if (isUnlocked) fillCircle(ctx, x, y, drawR + 3, SakuraTheme.NODE_GLOW);

            // available pulse ring
            if (avail) {
                float pulse = 0.5f + 0.5f * (float) Math.sin(
                    (now % SakuraTheme.PULSE_MS) / (float) SakuraTheme.PULSE_MS * Math.PI * 2);
                int pa = (int) (50 + 90 * pulse);
                fillCircle(ctx, x, y, drawR + 2, (pa << 24) | (bc & 0x00FFFFFF));
            }

            // medallion ring + inner
            int ring = isUnlocked ? bc : (avail ? SakuraTheme.NODE_AVAIL : 0xFF5A5060);
            fillCircle(ctx, x, y, drawR, ring);
            fillCircle(ctx, x, y, drawR - 2, isUnlocked ? 0xFF241B2A : 0xFF201822);

            // icon
            String icon = nodeIcon(n);
            IconAtlas.draw(ctx, icon, x - 7, y - 7, 14, !isUnlocked && !avail);

            // hover ring
            if (hovered) {
                ctx.fill(x - drawR - 1, y - drawR - 1, x + drawR + 2, y - drawR, 0xAAF2EAF0);
                ctx.fill(x - drawR - 1, y + drawR, x + drawR + 2, y + drawR + 1, 0xAAF2EAF0);
            }

            // rank badge
            String rank = rankOf(n);
            if (rank != null) {
                ctx.drawTextWithShadow(textRenderer, Text.literal(rank),
                    x + drawR - 3, y + drawR - 4, GlyphPainter.rankColor(rank));
            }

            // lock badge
            if (!isUnlocked && !avail) {
                IconAtlas.draw(ctx, "lock", x + drawR - 6, y - drawR - 2, 8);
            }

            // edge indicator collect
            if (avail) {
                int ex = sx(x), ey = sy(y);
                if (ex < -10 || ex > width + 10 || ey < -10 || ey > height + 10) {
                    edgeAvail.add(new int[]{ex, ey});
                }
            }
        }
    }

    private void drawHoverLinks(DrawContext ctx, Set<String> unlocked) {
        if (hoveredId == null) return;
        SkillTreeNode n = SkillTreeRegistry.get(hoveredId);
        if (n == null) return;
        int[] a = nodePos.get(n.id());
        if (a == null) return;
        for (String req : n.requires()) {
            SkillTreeNode rn = SkillTreeRegistry.get(req);
            if (rn == null || rn.branch().equals(n.branch())) continue;
            int[] b = nodePos.get(req);
            if (b == null) continue;
            boolean done = unlocked.contains(req);
            dottedBezier(ctx, a[0], a[1], b[0], b[1],
                done ? 0xAA7ED07E : 0xAAFF9EC4);
        }
    }

    private void drawEdgeIndicators(DrawContext ctx) {
        int shown = 0;
        for (int[] e : edgeAvail) {
            if (shown >= 8) break;
            int ex = Math.max(14, Math.min(width - 14, e[0]));
            int ey = Math.max(14, Math.min(height - 14, e[1]));
            ctx.fill(ex - 3, ey - 3, ex + 4, ey + 4, 0x88FF9EC4);
            ctx.fill(ex - 1, ey - 1, ex + 2, ey + 2, 0xFFFF9EC4);
            shown++;
        }
    }

    private void drawMinimap(DrawContext ctx, Set<String> unlocked) {
        if (scrolls.isEmpty()) return;
        int x0 = 8, y0 = height - MM_H - 8;
        SakuraGlass.drawPanel(ctx, x0, y0, MM_W, MM_H);

        int worldW = scrolls.get(scrolls.size() - 1).x + SakuraTheme.SCROLL_W;
        int worldH = 0;
        for (ScrollBox sb : scrolls) worldH = Math.max(worldH, sb.fullH + sb.top);
        if (worldW <= 0 || worldH <= 0) return;
        float ms = Math.min((MM_W - 12f) / worldW, (MM_H - 12f) / worldH);

        for (ScrollBox sb : scrolls) {
            int px = x0 + 6 + (int) (sb.x * ms);
            int py = y0 + 6 + (int) (sb.top * ms);
            int ph = Math.max(4, (int) (sb.fullH * ms));
            ctx.fill(px, py, px + 3, py + ph, 0xFFB9A88C);
            for (SkillTreeNode n : nodesOf(sb.branch)) {
                int[] c = nodePos.get(n.id());
                if (c == null) continue;
                int ny = y0 + 6 + (int) (c[1] * ms);
                int col = unlocked.contains(n.id()) ? 0xFFFF9EC4
                    : (canUnlockClient(n, unlocked) ? 0xFFFFD75E : 0xFF5A5060);
                ctx.fill(px + 1, ny, px + 2, ny + 1, col);
            }
        }

        // viewport rect
        float s = scale();
        double wl = viewX - width / (2f * s);
        double wt = viewY - height / (2f * s);
        double wr = viewX + width / (2f * s);
        double wb = viewY + height / (2f * s);
        int vx = x0 + 6 + (int) (wl * ms);
        int vy = y0 + 6 + (int) (wt * ms);
        int vw = Math.max(2, (int) ((wr - wl) * ms));
        int vh = Math.max(2, (int) ((wb - wt) * ms));
        ctx.fill(vx, vy, vx + vw, vy + 1, 0xCCFF9EC4);
        ctx.fill(vx, vy + vh, vx + vw, vy + vh + 1, 0xCCFF9EC4);
        ctx.fill(vx, vy, vx + 1, vy + vh, 0xCCFF9EC4);
        ctx.fill(vx + vw, vy, vx + vw + 1, vy + vh, 0xCCFF9EC4);
    }

    private boolean minimapHit(int mx, int my) {
        return mx >= 8 && mx <= 8 + MM_W && my >= height - MM_H - 8 && my <= height - 8;
    }

    private void minimapJump(int mx, int my) {
        if (scrolls.isEmpty()) return;
        int worldW = scrolls.get(scrolls.size() - 1).x + SakuraTheme.SCROLL_W;
        int worldH = 0;
        for (ScrollBox sb : scrolls) worldH = Math.max(worldH, sb.fullH + sb.top);
        if (worldW <= 0 || worldH <= 0) return;
        float ms = Math.min((MM_W - 12f) / worldW, (MM_H - 12f) / worldH);
        if (ms <= 0f) return;
        tViewX = (mx - 8 - 6) / ms;
        tViewY = (my - (height - MM_H - 8) - 6) / ms;
    }

    private void drawHud(DrawContext ctx) {
        SakuraGlass.drawPanel(ctx, 6, 4, 64, 16);
        ctx.drawTextWithShadow(textRenderer, Text.literal("SP: " + spNow()), 12, 8, SakuraTheme.GOLD);
        ctx.drawTextWithShadow(textRenderer, Text.translatable("gui.shinobicore.tree.hint"),
            8, height - 12, 0xFF9A8FA6);
    }

    private void drawTooltip(DrawContext ctx, SkillTreeNode n, int mx, int my, Set<String> unlocked) {
        if (n == null) return;
        List<Text> lines = new ArrayList<>();
        lines.add(Text.literal(n.displayName()));
        String rank = rankOf(n);
        String el = elementOf(n);
        lines.add(Text.literal(
            Text.translatable("gui.shinobicore.tree.rank").getString() + ": " + (rank == null ? "-" : rank)
            + "  |  " + Text.translatable("gui.shinobicore.tree.element").getString() + ": "
            + (el == null ? n.branch() : el)));
        String cost = jutsuCost(n);
        if (cost != null) lines.add(Text.literal(Text.translatable("gui.shinobicore.tree.cost").getString() + cost));
        lines.add(Text.literal("SP: " + n.spCost()));
        if (!n.requires().isEmpty()) {
            StringBuilder rq = new StringBuilder(Text.translatable("gui.shinobicore.tree.requires").getString()).append(": ");
            for (String r : n.requires()) {
                SkillTreeNode rn = SkillTreeRegistry.get(r);
                String nm = rn != null ? rn.displayName() : r;
                rq.append(unlocked.contains(r) ? "§a" : "§c").append(nm).append("§r ");
            }
            lines.add(Text.literal(rq.toString()));
        }
        String state = unlocked.contains(n.id())
            ? "§a" + Text.translatable("gui.shinobicore.tree.unlocked").getString()
            : (canUnlockClient(n, unlocked)
                ? "§d" + Text.translatable("gui.shinobicore.tree.available").getString()
                : "§7" + Text.translatable("gui.shinobicore.tree.locked").getString());
        lines.add(Text.literal(state));

        int tw = 0;
        for (Text t : lines) tw = Math.max(tw, textRenderer.getWidth(t));
        int th = lines.size() * 11 + 10;
        int tx = Math.min(mx + 14, width - tw - 14);
        int ty = Math.max(4, Math.min(my - th - 6, height - th - 4));

        SakuraGlass.drawPanelNoBorder(ctx, tx - 4, ty - 4, tw + 12, th + 8);
        ctx.fill(tx - 4, ty - 4, tx + tw + 8, ty - 3, SakuraTheme.SAKURA);
        int ly = ty;
        for (Text t : lines) {
            ctx.drawTextWithShadow(textRenderer, t, tx, ly, SakuraTheme.INK);
            ly += 11;
        }
    }

    // ================= LAYOUT =================

    private List<String> branchOrder() {
        List<String> order = new ArrayList<>();
        for (SkillTreeRegistry.BranchDef b : SkillTreeRegistry.getAllBranches()) {
            if (b.clan() != null || b.hidden()) continue;
            boolean has = false;
            for (SkillTreeNode n : SkillTreeRegistry.getAll()) {
                if (n.branch().equals(b.id())) { has = true; break; }
            }
            if (has && !order.contains(b.id())) order.add(b.id());
        }
        order.sort((a, b) -> {
            if (a.equals("general")) return -1;
            if (b.equals("general")) return 1;
            return a.compareTo(b);
        });
        return order;
    }

    private List<SkillTreeNode> nodesOf(String branch) {
        List<SkillTreeNode> list = new ArrayList<>();
        for (SkillTreeNode n : SkillTreeRegistry.getAll()) {
            if (n.branch().equals(branch) && SkillTreeRegistry.isVisibleClient(n)) list.add(n);
        }
        list.sort((n1, n2) -> {
            int a1 = n1.id().startsWith("auto_") ? 0 : 1;
            int a2 = n2.id().startsWith("auto_") ? 0 : 1;
            if (a1 != a2) return a1 - a2;
            if (n1.distance() != n2.distance()) return Integer.compare(n1.distance(), n2.distance());
            return n1.id().compareTo(n2.id());
        });
        return list;
    }

    private void buildLayout(long now) {
        scrolls.clear();
        nodePos.clear();
        List<String> order = branchOrder();
        for (int i = 0; i < order.size(); i++) {
            String branch = order.get(i);
            List<SkillTreeNode> ns = nodesOf(branch);
            ScrollBox sb = new ScrollBox();
            sb.branch = branch;
            sb.index = i;
            sb.x = i * (SakuraTheme.SCROLL_W + SakuraTheme.SCROLL_GAP);
            sb.top = SakuraTheme.BEAM_H + SakuraTheme.CORD_H;
            sb.fullH = SakuraTheme.ROLLER_H * 2 + SakuraTheme.HEADER_H + SakuraTheme.FOOTER_H
                     + Math.max(1, ns.size()) * SakuraTheme.NODE_ROW;
            float unroll = UiAnim.openEase(openMs + i * 70L, now, SakuraTheme.UNROLL_MS);
            sb.curH = (int) (SakuraTheme.ROLLER_H * 2 + (sb.fullH - SakuraTheme.ROLLER_H * 2) * unroll);
            sb.nodes = ns.size();
            scrolls.add(sb);

            int cy = sb.top + SakuraTheme.ROLLER_H + SakuraTheme.HEADER_H;
            for (int row = 0; row < ns.size(); row++) {
                SkillTreeNode n = ns.get(row);
                int nx = sb.x + SakuraTheme.SCROLL_W / 2 + (int) (n.angleOffset() * 0.6f);
                int ny = cy + row * SakuraTheme.NODE_ROW + SakuraTheme.NODE_ROW / 2;
                nodePos.put(n.id(), new int[]{nx, ny});
            }
        }
    }

    private ScrollBox scrollAt(double wx) {
        for (ScrollBox sb : scrolls) {
            if (wx >= sb.x - 6 && wx <= sb.x + SakuraTheme.SCROLL_W + 6) return sb;
        }
        return null;
    }

    private float scale() { return zoom * uiScale; }
    private int sx(double wx) { return (int) (width / 2f + (wx - viewX) * scale()); }
    private int sy(double wy) { return (int) (height / 2f + (wy - viewY) * scale()); }

    private int mouseX() {
        if (client == null) return 0;
        return (int) ((double) client.mouse.getX() * width / client.getWindow().getWidth());
    }
    private int mouseY() {
        if (client == null) return 0;
        return (int) ((double) client.mouse.getY() * height / client.getWindow().getHeight());
    }

    // ================= HELPERS =================

    private void line(DrawContext ctx, int x1, int y1, int x2, int y2, int color) {
        int steps = Math.max(Math.abs(x2 - x1), Math.abs(y2 - y1));
        if (steps == 0) { ctx.fill(x1, y1, x1 + 1, y1 + 1, color); return; }
        for (int i = 0; i <= steps; i++) {
            int x = x1 + (x2 - x1) * i / steps;
            int y = y1 + (y2 - y1) * i / steps;
            ctx.fill(x, y, x + 1, y + 1, color);
        }
    }

    private void fillCircle(DrawContext ctx, int cx, int cy, int r, int color) {
        for (int dy = -r; dy <= r; dy++) {
            int hw = (int) Math.sqrt(Math.max(0, r * r - dy * dy));
            ctx.fill(cx - hw, cy + dy, cx + hw + 1, cy + dy + 1, color);
        }
    }

    private void dottedBezier(DrawContext ctx, int x1, int y1, int x2, int y2, int color) {
        float cy1 = y1 + (y2 - y1) * 0.45f;
        float cy2 = y2 - (y2 - y1) * 0.45f;
        for (int i = 0; i <= 24; i += 2) {
            float t = i / 24f;
            float u = 1 - t;
            int x = (int) (u * u * u * x1 + 3 * u * u * t * x1 + 3 * u * t * t * x2 + t * t * t * x2);
            int y = (int) (u * u * u * y1 + 3 * u * u * t * cy1 + 3 * u * t * t * cy2 + t * t * t * y2);
            ctx.fill(x, y, x + 1, y + 1, color);
        }
    }

    private String branchIcon(String branch) {
        switch (branch) {
            case "fire": case "water": case "wind": case "earth": case "lightning":
            case "taijutsu": case "kenjutsu": case "shuriken": case "medical":
            case "sensory": case "genjutsu": case "space": case "summon":
            case "sealing": case "uchiha": case "uzumaki": case "hyuga":
            case "nara": case "hatake": case "sarutobi": case "kekkei": case "forbidden":
                return branch;
            default:
                return "general";
        }
    }

    private String nodeIcon(SkillTreeNode n) {
        if ("passive".equals(n.type())) return "star";
        String el = elementOf(n);
        if (el != null) {
            switch (el) {
                case "fire": case "water": case "wind": case "earth": case "lightning":
                    return el;
                default: break;
            }
        }
        return branchIcon(n.branch());
    }

    private String elementOf(SkillTreeNode n) {
        if (n.jutsuId() == null) return null;
        com.example.shinobicore.jutsu.core.JutsuDefinition def =
            com.example.shinobicore.jutsu.registry.JutsuRegistry.get(n.jutsuId());
        if (def == null || def.getElement() == null || "none".equals(def.getElement().getId())) return null;
        return def.getElement().getId();
    }

    private String rankOf(SkillTreeNode n) {
        if (n.jutsuId() == null) return null;
        com.example.shinobicore.jutsu.core.JutsuDefinition def =
            com.example.shinobicore.jutsu.registry.JutsuRegistry.get(n.jutsuId());
        return def == null ? null : def.getRank();
    }

    private String jutsuCost(SkillTreeNode n) {
        if (n.jutsuId() == null) return null;
        com.example.shinobicore.jutsu.core.JutsuDefinition def =
            com.example.shinobicore.jutsu.registry.JutsuRegistry.get(n.jutsuId());
        if (def == null || def.getCost() == null) return null;
        Integer c = def.getCost().get(com.example.shinobicore.jutsu.enums.ResourceType.CHAKRA);
        return c == null ? null : c + " chakra";
    }

    private boolean canUnlockClient(SkillTreeNode n, Set<String> unlocked) {
        if (unlocked.contains(n.id())) return false;
        if (spNow() < n.spCost()) return false;
        for (String r : n.requires()) if (!unlocked.contains(r)) return false;
        if (isNatureBranch(n.branch())) {
            Boolean u = ClientNinjaStateHolder.get().getNatureUnlocked().get(n.branch());
            if (u == null || !u) return false;
        }
        SkillTreeRegistry.BranchDef b = SkillTreeRegistry.getBranch(n.branch());
        if (b != null && b.clan() != null && !b.clan().equals(ClientNinjaStateHolder.get().getClanId())) return false;
        return true;
    }

    private static boolean isNatureBranch(String b) {
        return b.equals("fire") || b.equals("water") || b.equals("wind")
            || b.equals("earth") || b.equals("lightning");
    }

    // ================= INPUT =================

    @Override
    public boolean mouseClicked(double mx, double my, int btn) {
        if (btn == 1) { dragging = true; panVX = panVY = 0; return true; }
        if (btn == 0) {
            if (minimapHit((int) mx, (int) my)) { minimapJump((int) mx, (int) my); return true; }
            if (hoveredId != null) {
                SkillTreeNode n = SkillTreeRegistry.get(hoveredId);
                if (n != null) {
                    Set<String> unlocked = ClientNinjaStateHolder.get().getUnlockedNodes();
                    if (canUnlockClient(n, unlocked)) {
                        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
                        buf.writeString(n.id());
                        ClientPlayNetworking.send(ModPackets.UNLOCK_NODE_ID, buf);
                        fx.put(n.id(), System.currentTimeMillis());
                        UiSounds.unlock();
                    } else if (System.currentTimeMillis() - lastDenyMs > 400) {
                        lastDenyMs = System.currentTimeMillis();
                        UiSounds.deny();
                    }
                }
                return true;
            }
            // double click -> focus scroll
            double wx = viewX + (mx - width / 2f) / scale();
            ScrollBox sb = scrollAt(wx);
            long now = System.currentTimeMillis();
            if (sb != null) {
                if (now - lastClickMs < 300 && lastClickScroll == sb.index) {
                    tViewX = sb.x + SakuraTheme.SCROLL_W / 2f;
                    tViewY = sb.top + sb.fullH / 2f;
                    tZoom = 1.1f;
                    UiSounds.tab();
                    lastClickMs = -1000;
                } else {
                    lastClickMs = now;
                    lastClickScroll = sb.index;
                }
            }
            return true;
        }
        return super.mouseClicked(mx, my, btn);
    }

    @Override
    public boolean mouseReleased(double mx, double my, int btn) {
        if (btn == 1) dragging = false;
        return super.mouseReleased(mx, my, btn);
    }

    @Override
    public boolean mouseDragged(double mx, double my, int b, double dx, double dy) {
        if (dragging && b == 1) {
            tViewX -= dx / scale();
            tViewY -= dy / scale();
            panVX = -dx / scale() * 8;
            panVY = -dy / scale() * 8;
            return true;
        }
        return super.mouseDragged(mx, my, b, dx, dy);
    }

    @Override
    public boolean mouseScrolled(double mx, double my, double amount) {
        float old = tZoom;
        tZoom = Math.max(0.5f, Math.min(1.8f, tZoom + (float) amount * 0.15f));
        if (old != tZoom) {
            double wx = viewX + (mx - width / 2f) / (old * uiScale);
            double wy = viewY + (my - height / 2f) / (old * uiScale);
            tViewX = wx - (mx - width / 2f) / (tZoom * uiScale);
            tViewY = wy - (my - height / 2f) / (tZoom * uiScale);
        }
        return true;
    }

    @Override
    public boolean shouldPause() { return false; }
}
$root = "E:\Games\mod"
$src = "$root\src\main\java\com\example\shinobicore"
$res = "$root\src\main\resources"
$utf8 = New-Object System.Text.UTF8Encoding($false)

Write-Host "=== SKILL TREE v2 (SAFE MODE) ===" -ForegroundColor Cyan

# === [1] SkillTreeNode.java ===
$file = "$src\tree\SkillTreeNode.java"
$code = @'
package com.example.shinobicore.tree;
import java.util.List;
public record SkillTreeNode(
    String id, String branch, int distance, float angleOffset,
    String type, String jutsuId, String effect, float value,
    int spCost, List<String> requires,
    String icon, String displayName, String description,
    String clanRequired,
    String visType, String visKey, int visValue
) {
    public boolean hasVisibilityCondition() { return visType != null && !visType.isEmpty(); }
    public boolean hasClanRestriction() { return clanRequired != null && !clanRequired.isEmpty(); }
}
'@
[System.IO.File]::WriteAllText($file, $code, $utf8)
Write-Host "[1] SkillTreeNode.java" -ForegroundColor Green

# === [2] SkillTreeRegistry.java ===
$file = "$src\tree\SkillTreeRegistry.java"
$code = @'
package com.example.shinobicore.tree;
import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.stat.ElementType;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.stat.StatType;
import com.google.gson.*;
import net.minecraft.resource.Resource;
import net.minecraft.resource.ResourceManager;
import net.minecraft.util.Identifier;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.*;
public class SkillTreeRegistry {
    private static final Map<String, SkillTreeNode> NODES = new LinkedHashMap<>();
    private static final Map<String, BranchDef> BRANCHES = new LinkedHashMap<>();

    public record BranchDef(String id, float angle, int color, String label, String clan, boolean hidden) {}

    public static void reload(ResourceManager manager) {
        NODES.clear(); BRANCHES.clear();
        Identifier fileId = new Identifier(ShinobiCore.MOD_ID, "skill_tree/tree.json");
        try {
            Resource resource = manager.getResource(fileId).orElse(null);
            if (resource == null) return;
            try (InputStream stream = resource.getInputStream()) {
                JsonObject root = JsonParser.parseReader(
                    new InputStreamReader(stream, StandardCharsets.UTF_8)).getAsJsonObject();
                if (root.has("branches")) {
                    for (var e : root.getAsJsonObject("branches").entrySet()) {
                        JsonObject b = e.getValue().getAsJsonObject();
                        float angle = b.has("angle") ? b.get("angle").getAsFloat() : 0;
                        int color = parseColor(b.has("color") ? b.get("color").getAsString() : "#FFFFFF");
                        String label = b.has("label") ? b.get("label").getAsString() : e.getKey();
                        String clan = b.has("clan") ? b.get("clan").getAsString() : null;
                        boolean hidden = b.has("hidden") && b.get("hidden").getAsBoolean();
                        BRANCHES.put(e.getKey(), new BranchDef(e.getKey(), angle, color, label, clan, hidden));
                    }
                }
                if (root.has("nodes")) {
                    for (JsonElement el : root.getAsJsonArray("nodes")) {
                        JsonObject n = el.getAsJsonObject();
                        String id = n.get("id").getAsString();
                        String branch = n.has("branch") ? n.get("branch").getAsString() : "general";
                        int dist = n.has("distance") ? n.get("distance").getAsInt() : 1;
                        float aOff = n.has("angleOffset") ? n.get("angleOffset").getAsFloat() : 0;
                        String type = n.has("type") ? n.get("type").getAsString() : "jutsu";
                        String jutsuId = n.has("jutsuId") ? n.get("jutsuId").getAsString() : null;
                        String effect = n.has("effect") ? n.get("effect").getAsString() : null;
                        float value = n.has("value") ? n.get("value").getAsFloat() : 0;
                        int spCost = n.has("spCost") ? n.get("spCost").getAsInt() : 1;
                        List<String> req = new ArrayList<>();
                        if (n.has("requires")) for (var r : n.getAsJsonArray("requires")) req.add(r.getAsString());
                        String icon = n.has("icon") ? n.get("icon").getAsString() : "?";
                        String name = n.has("name") ? n.get("name").getAsString() : id;
                        String desc = n.has("description") ? n.get("description").getAsString() : "";
                        String clanReq = n.has("clanRequired") ? n.get("clanRequired").getAsString() : null;
                        String vType = null, vKey = null; int vVal = 0;
                        if (n.has("visibilityCondition")) {
                            JsonObject vc = n.getAsJsonObject("visibilityCondition");
                            vType = vc.has("type") ? vc.get("type").getAsString() : null;
                            vKey = vc.has("key") ? vc.get("key").getAsString() : null;
                            vVal = vc.has("value") ? vc.get("value").getAsInt() : 0;
                        }
                        NODES.put(id, new SkillTreeNode(id, branch, dist, aOff, type, jutsuId,
                            effect, value, spCost, req, icon, name, desc, clanReq, vType, vKey, vVal));
                    }
                }
            }
        } catch (Exception e) { ShinobiCore.LOGGER.error("Skill tree load error: {}", e.getMessage()); }
        ShinobiCore.LOGGER.info("Loaded {} tree nodes, {} branches", NODES.size(), BRANCHES.size());
    }

    private static int parseColor(String hex) {
        try { return (int) Long.parseLong(hex.replace("#",""), 16) | 0xFF000000; } catch (Exception e) { return 0xFFFFFFFF; }
    }

    public static SkillTreeNode get(String id) { return NODES.get(id); }
    public static Collection<SkillTreeNode> getAll() { return NODES.values(); }
    public static BranchDef getBranch(String id) { return BRANCHES.get(id); }
    public static Collection<BranchDef> getAllBranches() { return BRANCHES.values(); }

    public static boolean isVisibleClient(SkillTreeNode node) {
        BranchDef branch = BRANCHES.get(node.branch());
        if (branch != null && branch.clan() != null) {
            if (!branch.clan().equals(ClientNinjaState.clanId)) return false;
        }
        if (node.hasClanRestriction()) {
            if (!node.clanRequired().equals(ClientNinjaState.clanId)) return false;
        }
        if (branch != null && branch.hidden()) {
            if (!checkVisibilityClient(node)) return false;
        }
        if (node.hasVisibilityCondition()) {
            if (!checkVisibilityClient(node)) return false;
        }
        return true;
    }

    public static boolean isVisibleServer(SkillTreeNode node, NinjaPlayerData data) {
        BranchDef branch = BRANCHES.get(node.branch());
        if (branch != null && branch.clan() != null) {
            if (!branch.clan().equals(data.getClanId())) return false;
        }
        if (node.hasClanRestriction()) {
            if (!node.clanRequired().equals(data.getClanId())) return false;
        }
        if ((branch != null && branch.hidden()) || node.hasVisibilityCondition()) {
            return checkVisibilityServer(node, data);
        }
        return true;
    }

    private static boolean checkVisibilityClient(SkillTreeNode node) {
        if (node.visType() == null) return true;
        return switch (node.visType()) {
            case "stat_level" -> {
                Integer lvl = ClientNinjaState.statLevels.get(node.visKey());
                yield lvl != null && lvl >= node.visValue();
            }
            case "nature_level" -> {
                Integer lvl = ClientNinjaState.natureLevels.get(node.visKey());
                yield lvl != null && lvl >= node.visValue();
            }
            case "nature_unlocked" -> {
                Boolean u = ClientNinjaState.natureUnlocked.get(node.visKey());
                yield u != null && u;
            }
            case "node_unlocked" -> ClientNinjaState.unlockedNodes.contains(node.visKey());
            case "clan" -> node.visKey().equals(ClientNinjaState.clanId);
            case "reserve_level" -> ClientNinjaState.reserveLevel >= node.visValue();
            default -> true;
        };
    }

    private static boolean checkVisibilityServer(SkillTreeNode node, NinjaPlayerData data) {
        if (node.visType() == null) return true;
        return switch (node.visType()) {
            case "stat_level" -> {
                StatType s = statById(node.visKey());
                yield s != null && data.getStatLevel(s) >= node.visValue();
            }
            case "nature_level" -> {
                ElementType e = elementById(node.visKey());
                yield e != null && data.getNatureLevel(e) >= node.visValue();
            }
            case "nature_unlocked" -> {
                ElementType e = elementById(node.visKey());
                yield e != null && data.isNatureUnlocked(e);
            }
            case "node_unlocked" -> data.isNodeUnlocked(node.visKey());
            case "clan" -> node.visKey().equals(data.getClanId());
            case "reserve_level" -> data.getReserveLevel() >= node.visValue();
            default -> true;
        };
    }

    private static StatType statById(String id) {
        for (StatType s : StatType.values()) if (s.getId().equals(id)) return s;
        return null;
    }
    private static ElementType elementById(String id) {
        for (ElementType e : ElementType.values()) if (e.getId().equals(id)) return e;
        return null;
    }
}
'@
[System.IO.File]::WriteAllText($file, $code, $utf8)
Write-Host "[2] SkillTreeRegistry.java" -ForegroundColor Green

# === [3] SkillTreeScreen.java ===
$file = "$src\client\SkillTreeScreen.java"
$code = @'
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
import net.minecraft.util.math.MathHelper;
import java.util.*;
public class SkillTreeScreen extends Screen {
    private static final int NODE_RADIUS = 14;
    private static final int BRANCH_LENGTH = 55;
    private static final int BG_COLOR = 0xFF080810;
    private static final int CENTER_GLOW = 0xFF332244;
    private static final int TEXT_BRIGHT = 0xFFFFFFFF;
    private static final int TEXT_DIM = 0xFF888899;
    private static final int LINE_ACTIVE = 0xFF666688;
    private static final int LINE_INACTIVE = 0xFF222233;

    private int panX = 0, panY = 0;
    private boolean dragging = false;
    private int dragStartX, dragStartY, dragPanX, dragPanY;
    private SkillTreeNode hoveredNode = null;

    private final List<int[]> stars = new ArrayList<>();
    public SkillTreeScreen() {
        super(Text.literal("Skill Tree"));
        Random r = new Random(42);
        for (int i = 0; i < 120; i++) {
            stars.add(new int[]{r.nextInt(2000) - 1000, r.nextInt(2000) - 1000,
                30 + r.nextInt(80), 1 + r.nextInt(2)});
        }
    }

    @Override public void render(DrawContext ctx, int mx, int my, float delta) {
        ctx.fill(0, 0, width, height, BG_COLOR);
        renderBackground(ctx);
        int cx = width / 2 + panX;
        int cy = height / 2 + panY;

        for (int[] s : stars) {
            int sx = cx + s[0], sy = cy + s[1];
            if (sx >= 0 && sx < width && sy >= 0 && sy < height) {
                int alpha = s[2] + (int)(30 * Math.sin(System.currentTimeMillis() / 1000.0 + s[0]));
                alpha = Math.max(20, Math.min(200, alpha));
                int col = (alpha << 24) | 0xAAAAFF;
                ctx.fill(sx, sy, sx + s[3], sy + s[3], col);
            }
        }

        for (int r = 40; r > 0; r -= 4) {
            int a = (int)(15 * (40 - r) / 40.0);
            ctx.fill(cx - r, cy - r, cx + r, cy + r, (a << 24) | (CENTER_GLOW & 0xFFFFFF));
        }

        hoveredNode = null;
        for (BranchDef b : SkillTreeRegistry.getAllBranches()) {
            if (!isBranchVisible(b)) continue;
            int maxDist = getMaxDistance(b.id());
            if (maxDist < 1) continue;
            float rad = (float)Math.toRadians(b.angle());
            int endX = cx + (int)(Math.sin(rad) * BRANCH_LENGTH * (maxDist + 0.5));
            int endY = cy - (int)(Math.cos(rad) * BRANCH_LENGTH * (maxDist + 0.5));
            drawThickLine(ctx, cx, cy, endX, endY, LINE_INACTIVE, 3);
            int labelX = cx + (int)(Math.sin(rad) * BRANCH_LENGTH * (maxDist + 1.2));
            int labelY = cy - (int)(Math.cos(rad) * BRANCH_LENGTH * (maxDist + 1.2));
            drawCentered(ctx, b.label(), labelX, labelY - 6, b.color());
        }

        for (SkillTreeNode node : SkillTreeRegistry.getAll()) {
            if (!SkillTreeRegistry.isVisibleClient(node)) continue;
            int[] pos = getNodePos(node, cx, cy);
            for (String reqId : node.requires()) {
                SkillTreeNode parent = SkillTreeRegistry.get(reqId);
                if (parent == null || !SkillTreeRegistry.isVisibleClient(parent)) continue;
                int[] ppos = getNodePos(parent, cx, cy);
                boolean bothUnlocked = ClientNinjaState.unlockedNodes.contains(node.id())
                    && ClientNinjaState.unlockedNodes.contains(reqId);
                drawThickLine(ctx, ppos[0], ppos[1], pos[0], pos[1],
                    bothUnlocked ? LINE_ACTIVE : LINE_INACTIVE, 2);
            }
        }

        for (SkillTreeNode node : SkillTreeRegistry.getAll()) {
            if (!SkillTreeRegistry.isVisibleClient(node)) continue;
            int[] pos = getNodePos(node, cx, cy);
            boolean unlocked = ClientNinjaState.unlockedNodes.contains(node.id());
            boolean available = canUnlock(node);
            BranchDef branch = SkillTreeRegistry.getBranch(node.branch());
            int color = branch != null ? branch.color() : 0xFFAAAAAA;

            if (mx >= pos[0] - NODE_RADIUS && mx <= pos[0] + NODE_RADIUS
                && my >= pos[1] - NODE_RADIUS && my <= pos[1] + NODE_RADIUS) {
                hoveredNode = node;
            }

            if (unlocked) {
                int pulse = (int)(150 + 50 * Math.sin(System.currentTimeMillis() / 300.0));
                drawCircle(ctx, pos[0], pos[1], NODE_RADIUS + 4, (pulse << 24) | (color & 0xFFFFFF));
                drawCircle(ctx, pos[0], pos[1], NODE_RADIUS, 0xFF000000 | (color & 0xFFFFFF));
                drawCircle(ctx, pos[0], pos[1], NODE_RADIUS - 2, 0xFF111111);
            } else if (available) {
                int pulse = (int)(80 + 60 * Math.sin(System.currentTimeMillis() / 200.0));
                drawCircle(ctx, pos[0], pos[1], NODE_RADIUS + 2, (pulse << 24) | (color & 0xFFFFFF));
                drawCircle(ctx, pos[0], pos[1], NODE_RADIUS, 0xFF333344);
                drawCircle(ctx, pos[0], pos[1], NODE_RADIUS - 2, 0xFF222233);
            } else {
                drawCircle(ctx, pos[0], pos[1], NODE_RADIUS, 0xFF1A1A22);
                drawCircle(ctx, pos[0], pos[1], NODE_RADIUS - 2, 0xFF111118);
            }

            int iconColor = unlocked ? 0xFFFFFFFF : (available ? color : 0xFF555566);
            drawCentered(ctx, node.icon(), pos[0], pos[1] - 4, iconColor);
        }

        drawCircle(ctx, cx, cy, 20, 0xFF221133);
        drawCircle(ctx, cx, cy, 18, 0xFF332244);
        drawCentered(ctx, "NINJA", cx, cy - 6, 0xFFCCAAEE);
        drawCentered(ctx, "WAY", cx, cy + 2, 0xFFCCAAEE);

        ctx.fill(0, 0, width, 24, 0xCC000000);
        drawCentered(ctx, "Skill Tree  |  SP: " + ClientNinjaState.skillPoints
            + "  |  Clan: " + ClientNinjaState.clanId
            + "  |  ESC to close", width / 2, 8, TEXT_BRIGHT);

        if (hoveredNode != null) renderTooltip(ctx, hoveredNode, mx, my);

        ctx.fill(0, height - 16, width, height, 0xCC000000);
        drawCentered(ctx, "LMB: unlock  |  RMB drag: pan",
            width / 2, height - 12, TEXT_DIM);
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

    private int getMaxDistance(String branch) {
        int max = 0;
        for (SkillTreeNode n : SkillTreeRegistry.getAll()) {
            if (n.branch().equals(branch) && SkillTreeRegistry.isVisibleClient(n)) {
                max = Math.max(max, n.distance());
            }
        }
        return max;
    }

    private int[] getNodePos(SkillTreeNode node, int cx, int cy) {
        BranchDef b = SkillTreeRegistry.getBranch(node.branch());
        if (b == null) return new int[]{cx, cy};
        float angle = b.angle() + node.angleOffset();
        float rad = (float)Math.toRadians(angle);
        int dist = (int)(BRANCH_LENGTH * node.distance());
        return new int[]{
            cx + (int)(Math.sin(rad) * dist),
            cy - (int)(Math.cos(rad) * dist)
        };
    }

    private boolean canUnlock(SkillTreeNode node) {
        if (ClientNinjaState.unlockedNodes.contains(node.id())) return false;
        if (ClientNinjaState.skillPoints < node.spCost()) return false;
        for (String r : node.requires()) {
            if (!ClientNinjaState.unlockedNodes.contains(r)) return false;
        }
        return true;
    }

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
        if (unlocked) lines.add("[UNLOCKED]");
        else if (available) lines.add("[Click to unlock]");
        else lines.add("[Locked]");

        int tw = 0;
        for (String l : lines) tw = Math.max(tw, textRenderer.getWidth(l));
        int th = lines.size() * 10 + 8;
        int tx = Math.min(mx + 12, width - tw - 16);
        int ty = Math.max(my - th - 8, 4);
        ctx.fill(tx, ty, tx + tw + 12, ty + th, 0xEE111122);
        ctx.fill(tx, ty, tx + tw + 12, ty + 1, 0xFF555577);
        ctx.fill(tx, ty + th - 1, tx + tw + 12, ty + th, 0xFF222244);
        int ly = ty + 4;
        BranchDef b = SkillTreeRegistry.getBranch(node.branch());
        int nameColor = b != null ? b.color() : 0xFFFFFFFF;
        ctx.drawText(textRenderer, lines.get(0), tx + 6, ly, nameColor, false);
        ly += 11;
        for (int i = 1; i < lines.size(); i++) {
            int col = lines.get(i).startsWith("[") ? (unlocked ? 0xFF44FF44 : (available ? 0xFFFFAA00 : 0xFFFF4444)) : 0xFFBBBBCC;
            ctx.drawText(textRenderer, lines.get(i), tx + 6, ly, col, false);
            ly += 10;
        }
    }

    @Override public boolean mouseClicked(double mx, double my, int btn) {
        if (btn == 1) {
            dragging = true;
            dragStartX = (int)mx; dragStartY = (int)my;
            dragPanX = panX; dragPanY = panY;
            return true;
        }
        if (btn == 0 && hoveredNode != null && canUnlock(hoveredNode)) {
            PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
            buf.writeString(hoveredNode.id());
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
            panX = dragPanX + ((int)mx - dragStartX);
            panY = dragPanY + ((int)my - dragStartY);
            return true;
        }
        return super.mouseDragged(mx, my, btn, dx, dy);
    }

    private void drawCircle(DrawContext ctx, int cx, int cy, int r, int color) {
        int a = (color >> 24) & 0xFF;
        if (a == 0) return;
        for (int y = -r; y <= r; y++) {
            int dx = (int)Math.sqrt(r * r - y * y);
            ctx.fill(cx - dx, cy + y, cx + dx + 1, cy + y + 1, color);
        }
    }

    private void drawThickLine(DrawContext ctx, int x1, int y1, int x2, int y2, int color, int thick) {
        int steps = Math.max(Math.abs(x2 - x1), Math.abs(y2 - y1));
        if (steps == 0) return;
        for (int i = 0; i <= steps; i++) {
            int x = x1 + (x2 - x1) * i / steps;
            int y = y1 + (y2 - y1) * i / steps;
            ctx.fill(x - thick/2, y - thick/2, x + thick/2 + 1, y + thick/2 + 1, color);
        }
    }

    private void drawCentered(DrawContext ctx, String text, int cx, int y, int color) {
        int w = textRenderer.getWidth(text);
        ctx.drawText(textRenderer, text, cx - w / 2, y, color, false);
    }

    @Override public boolean shouldPause() { return false; }
}
'@
[System.IO.File]::WriteAllText($file, $code, $utf8)
Write-Host "[3] SkillTreeScreen.java" -ForegroundColor Green

# === [4] tree.json ===
$file = "$res\data\shinobicore\skill_tree\tree.json"
$json = @'
{
  "branches": {
    "general":   {"angle": 0,   "color": "#AAAAAA", "label": "Ninja Way"},
    "fire":      {"angle": 51,  "color": "#FF6622", "label": "Fire Release"},
    "water":     {"angle": 103, "color": "#4488FF", "label": "Water Release"},
    "wind":      {"angle": 154, "color": "#88DDAA", "label": "Wind Release"},
    "lightning": {"angle": 206, "color": "#FFEE44", "label": "Lightning Release"},
    "earth":     {"angle": 257, "color": "#BB8844", "label": "Earth Release"},
    "taijutsu":  {"angle": 309, "color": "#66FF66", "label": "Taijutsu"},
    "uchiha":    {"angle": 40,  "color": "#FF2222", "label": "Uchiha Secret", "clan": "uchiha"},
    "hyuga":     {"angle": 320, "color": "#CCCCEE", "label": "Gentle Fist", "clan": "hyuga"},
    "uzumaki":   {"angle": 115, "color": "#FF8844", "label": "Uzumaki Seal", "clan": "uzumaki"},
    "nara":      {"angle": 265, "color": "#8866AA", "label": "Shadow Arts", "clan": "nara"},
    "hatake":    {"angle": 215, "color": "#EEEEFF", "label": "White Fang", "clan": "hatake"},
    "sarutobi":  {"angle": 55,  "color": "#FFAA44", "label": "Monkey King", "clan": "sarutobi"},
    "forbidden": {"angle": 180, "color": "#AA44FF", "label": "Forbidden Arts", "hidden": true}
  },
  "nodes": [
    {"id":"gen_meditation","branch":"general","distance":1,"type":"passive","effect":"meditation_bonus","value":0.1,"spCost":2,"requires":[],"icon":"*","name":"Inner Peace","description":"+10% meditation regen"},
    {"id":"gen_chakra_eff","branch":"general","distance":2,"type":"passive","effect":"cost_reduction","value":0.05,"spCost":3,"requires":["gen_meditation"],"icon":"*","name":"Chakra Efficiency","description":"-5% jutsu cost"},
    {"id":"gen_body_boost","branch":"general","distance":3,"type":"passive","effect":"hp_bonus","value":4,"spCost":4,"requires":["gen_chakra_eff"],"icon":"*","name":"Body Reinforcement","description":"+4 max HP"},
    {"id":"gen_chakra_surge","branch":"general","distance":4,"type":"passive","effect":"reserve_bonus","value":10,"spCost":5,"requires":["gen_body_boost"],"icon":"*","name":"Chakra Surge","description":"+10 reserve capacity"},

    {"id":"fire_basic","branch":"fire","distance":1,"type":"jutsu","jutsuId":"shinobicore:fire_release_flame_bullet","spCost":2,"requires":[],"icon":"F","name":"Flame Bullet","description":"Basic fire projectile"},
    {"id":"fire_mid","branch":"fire","distance":2,"type":"jutsu","jutsuId":"shinobicore:fire_release_great_fireball","spCost":4,"requires":["fire_basic"],"icon":"F","name":"Great Fireball","description":"Powerful fire sphere"},
    {"id":"fire_advanced","branch":"fire","distance":3,"type":"jutsu","jutsuId":"shinobicore:fire_release_dragon_flame","spCost":6,"requires":["fire_mid"],"icon":"F","name":"Dragon Flame","description":"Massive fire dragon"},
    {"id":"fire_phoenix","branch":"fire","distance":3,"angleOffset":-12,"type":"jutsu","jutsuId":"shinobicore:fire_release_phoenix_sage","spCost":5,"requires":["fire_mid"],"icon":"F","name":"Phoenix Sage","description":"Scattered fire shots"},

    {"id":"water_basic","branch":"water","distance":1,"type":"jutsu","jutsuId":"shinobicore:water_release_water_bullet","spCost":2,"requires":[],"icon":"W","name":"Water Bullet","description":"Basic water projectile"},
    {"id":"water_raging","branch":"water","distance":2,"type":"jutsu","jutsuId":"shinobicore:water_release_raging_waves","spCost":4,"requires":["water_basic"],"icon":"W","name":"Raging Waves","description":"AOE water blast"},
    {"id":"water_waterfall","branch":"water","distance":3,"type":"jutsu","jutsuId":"shinobicore:water_release_great_waterfall","spCost":6,"requires":["water_raging"],"icon":"W","name":"Great Waterfall","description":"Water dash attack"},

    {"id":"wind_basic","branch":"wind","distance":1,"type":"jutsu","jutsuId":"shinobicore:wind_release_gale_palm","spCost":2,"requires":[],"icon":"~","name":"Gale Palm","description":"Wind dash"},
    {"id":"wind_breakthrough","branch":"wind","distance":2,"type":"jutsu","jutsuId":"shinobicore:wind_release_great_breakthrough","spCost":4,"requires":["wind_basic"],"icon":"~","name":"Great Breakthrough","description":"AOE wind blast"},
    {"id":"wind_passing","branch":"wind","distance":2,"angleOffset":10,"type":"jutsu","jutsuId":"shinobicore:wind_release_passing_gale","spCost":3,"requires":["wind_basic"],"icon":"~","name":"Passing Gale","description":"Speed buff"},

    {"id":"light_basic","branch":"lightning","distance":1,"type":"jutsu","jutsuId":"shinobicore:lightning_release_shock","spCost":3,"requires":[],"icon":"L","name":"Lightning Shock","description":"Melee lightning"},
    {"id":"light_darkness","branch":"lightning","distance":2,"type":"jutsu","jutsuId":"shinobicore:lightning_release_false_darkness","spCost":5,"requires":["light_basic"],"icon":"L","name":"False Darkness","description":"Lightning beam AOE"},

    {"id":"earth_wall","branch":"earth","distance":1,"type":"jutsu","jutsuId":"shinobicore:earth_release_earth_wall","spCost":3,"requires":[],"icon":"#","name":"Earth Wall","description":"Temporary wall"},
    {"id":"earth_mud","branch":"earth","distance":2,"type":"jutsu","jutsuId":"shinobicore:earth_release_mud_wave","spCost":5,"requires":["earth_wall"],"icon":"#","name":"Mud Wave","description":"AOE slow wave"},

    {"id":"tai_whirlwind","branch":"taijutsu","distance":1,"type":"jutsu","jutsuId":"shinobicore:leaf_whirlwind","spCost":3,"requires":[],"icon":"T","name":"Leaf Whirlwind","description":"360 kick"},
    {"id":"tai_combo_master","branch":"taijutsu","distance":2,"type":"passive","effect":"combo_damage","value":0.15,"spCost":4,"requires":["tai_whirlwind"],"icon":"T","name":"Combo Master","description":"+15% combo damage"},

    {"id":"med_palm","branch":"general","distance":2,"angleOffset":20,"type":"jutsu","jutsuId":"shinobicore:mystical_palm_jutsu","spCost":3,"requires":["gen_meditation"],"icon":"+","name":"Mystical Palm","description":"Heal self"},
    {"id":"med_poison","branch":"general","distance":3,"angleOffset":20,"type":"jutsu","jutsuId":"shinobicore:poison_extraction","spCost":2,"requires":["med_palm"],"icon":"+","name":"Poison Extraction","description":"Clear debuffs"},

    {"id":"uchi_amaterasu","branch":"uchiha","distance":1,"type":"jutsu","jutsuId":"shinobicore:fire_release_great_fireball","spCost":8,"requires":[],"icon":"@","name":"Amaterasu","description":"Black flames","clanRequired":"uchiha"},
    {"id":"uchi_susano","branch":"uchiha","distance":2,"type":"passive","effect":"damage_reduction","value":0.2,"spCost":10,"requires":["uchi_amaterasu"],"icon":"@","name":"Susano'o","description":"-20% damage taken","clanRequired":"uchiha"},

    {"id":"hyu_64","branch":"hyuga","distance":1,"type":"passive","effect":"chakra_drain","value":5,"spCost":8,"requires":[],"icon":"O","name":"64 Palms","description":"Drain enemy chakra","clanRequired":"hyuga"},
    {"id":"hyu_128","branch":"hyuga","distance":2,"type":"passive","effect":"chakra_drain","value":10,"spCost":12,"requires":["hyu_64"],"icon":"O","name":"128 Palms","description":"Double drain","clanRequired":"hyuga"},

    {"id":"uzu_chains","branch":"uzumaki","distance":1,"type":"passive","effect":"chakra_regen","value":0.2,"spCost":8,"requires":[],"icon":"S","name":"Adamantine Chains","description":"+20% chakra regen","clanRequired":"uzumaki"},
    {"id":"uzu_seal","branch":"uzumaki","distance":2,"type":"passive","effect":"max_chakra","value":50,"spCost":10,"requires":["uzu_chains"],"icon":"S","name":"Sealing Arts","description":"+50 max chakra","clanRequired":"uzumaki"},

    {"id":"nara_shadow","branch":"nara","distance":1,"type":"passive","effect":"stun_duration","value":0.5,"spCost":8,"requires":[],"icon":"~","name":"Shadow Possession","description":"+50% stun","clanRequired":"nara"},
    {"id":"nara_strangle","branch":"nara","distance":2,"type":"passive","effect":"aoe_range","value":0.3,"spCost":10,"requires":["nara_shadow"],"icon":"~","name":"Shadow Strangle","description":"+30% AOE","clanRequired":"nara"},

    {"id":"hatake_chidori","branch":"hatake","distance":1,"type":"jutsu","jutsuId":"shinobicore:lightning_release_false_darkness","spCost":8,"requires":[],"icon":">","name":"Chidori","description":"Lightning blade","clanRequired":"hatake"},
    {"id":"hatake_copy","branch":"hatake","distance":2,"type":"passive","effect":"learn_bonus","value":1,"spCost":10,"requires":["hatake_chidori"],"icon":">","name":"Copy Ninja","description":"Learn jutsu faster","clanRequired":"hatake"},

    {"id":"saru_monkey","branch":"sarutobi","distance":1,"type":"passive","effect":"taijutsu_bonus","value":0.15,"spCost":8,"requires":[],"icon":"M","name":"Monkey King Staff","description":"+15% taijutsu","clanRequired":"sarutobi"},
    {"id":"saru_fire_prof","branch":"sarutobi","distance":2,"type":"passive","effect":"fire_mastery","value":0.2,"spCost":10,"requires":["saru_monkey"],"icon":"M","name":"Fire Professor","description":"+20% fire damage","clanRequired":"sarutobi"},

    {"id":"rasengan","branch":"general","distance":5,"type":"jutsu","jutsuId":"shinobicore:rasengan","spCost":15,"requires":["gen_chakra_surge","wind_basic","water_basic"],"icon":"O","name":"Rasengan","description":"Spiraling sphere"},

    {"id":"forb_8gates","branch":"forbidden","distance":1,"type":"passive","effect":"8gates_unlock","value":1,"spCost":20,"requires":[],"icon":"!","name":"Eight Gates","description":"Unlock 8 Gates","visibilityCondition":{"type":"stat_level","key":"taijutsu","value":50}},
    {"id":"forb_edo","branch":"forbidden","distance":2,"type":"passive","effect":"edo_tensei","value":1,"spCost":25,"requires":["forb_8gates"],"icon":"!","name":"Edo Tensei","description":"Forbidden resurrection","visibilityCondition":{"type":"stat_level","key":"taijutsu","value":50}}
  ]
}
'@
[System.IO.File]::WriteAllText($file, $json, $utf8)
Write-Host "[4] tree.json" -ForegroundColor Green

# === [5] ShinobiCore.java ===
$file = "$src\ShinobiCore.java"
$content = [System.IO.File]::ReadAllText($file, $utf8)
if ($content.Contains("Already unlocked") -and -not $content.Contains("isVisibleServer")) {
    $marker = 'player.sendMessage(Text.literal("§cAlready unlocked!"), false);'
    $insert = @'
player.sendMessage(Text.literal("§cAlready unlocked!"), false);
            return;
        }
        if (!SkillTreeRegistry.isVisibleServer(node, data)) {
            player.sendMessage(Text.literal("§cThis node is not available to you!"), false);
'@
    $content = $content.Replace($marker, $insert)
    [System.IO.File]::WriteAllText($file, $content, $utf8)
    Write-Host "[5] ShinobiCore.java updated" -ForegroundColor Green
} else {
    Write-Host "[5] ShinobiCore.java already OK" -ForegroundColor Gray
}

# === [6] KeyBindings.java ===
$file = "$src\client\KeyBindings.java"
$content = [System.IO.File]::ReadAllText($file, $utf8)
$lines = $content -split "`n"
$newLines = New-Object System.Collections.ArrayList
$skipBlock = $false
foreach ($line in $lines) {
    if ($line -match "SKILL_TREE") {
        if ($line -match "registerKeyBinding") { $skipBlock = $true }
        continue
    }
    if ($skipBlock) {
        if ($line -match "\)\);") { $skipBlock = $false }
        continue
    }
    [void]$newLines.Add($line)
}
$content = $newLines -join "`n"
[System.IO.File]::WriteAllText($file, $content, $utf8)
Write-Host "[6] KeyBindings.java cleaned" -ForegroundColor Green

# === [7] ClientInputHandler.java ===
$file = "$src\client\ClientInputHandler.java"
$content = [System.IO.File]::ReadAllText($file, $utf8)
$lines = $content -split "`n"
$newLines = New-Object System.Collections.ArrayList
$skipBlock = $false
foreach ($line in $lines) {
    if ($line -match "SKILL_TREE" -or $line -match "SkillTreeScreen") {
        if ($line -match "if \(") { $skipBlock = $true }
        continue
    }
    if ($skipBlock) {
        if ($line -match "^\s*\}\s*$") { $skipBlock = $false }
        continue
    }
    [void]$newLines.Add($line)
}
$content = $newLines -join "`n"
[System.IO.File]::WriteAllText($file, $content, $utf8)
Write-Host "[7] ClientInputHandler.java cleaned" -ForegroundColor Green

Write-Host "`n=== TREE v2 COMPLETE ===" -ForegroundColor Cyan
Write-Host "Run: .\gradlew.bat build" -ForegroundColor Yellow
# ============================================================
# SHINOBI CORE — PHASE A AUTO-APPLY
# Запуск: cd E:\Games\mod; powershell -ExecutionPolicy Bypass -File apply_phase_a.ps1
# ============================================================

$root = "E:\Games\mod"
$src = "$root\src\main\java\com\example\shinobicore"
$res = "$root\src\main\resources"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

Write-Host "=== SHINOBI CORE: PHASE A AUTO-APPLY ===" -ForegroundColor Cyan
Write-Host "Root: $root" -ForegroundColor Gray

# ============================================================
# ШАГ 0: БЭКАПЫ
# ============================================================
Write-Host "`n[0/8] Creating backups..." -ForegroundColor Yellow

$filesToBackup = @(
    "$src\client\ProgressionScreen.java",
    "$src\network\ModPackets.java",
    "$src\stat\NinjaPlayerData.java",
    "$src\client\ClientNinjaState.java",
    "$src\client\ShinobiCoreClient.java",
    "$src\ShinobiCore.java",
    "$src\client\KeyBindings.java",
    "$src\client\ClientInputHandler.java"
)

$backupDir = "$root\backup_phase_a"
if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }

foreach ($f in $filesToBackup) {
    if (Test-Path $f) {
        $name = Split-Path $f -Leaf
        Copy-Item $f "$backupDir\$name" -Force
        Write-Host "  Backed up: $name" -ForegroundColor Gray
    }
}
Write-Host "  Backups saved to: $backupDir" -ForegroundColor Green

# ============================================================
# ШАГ 1: СОЗДАНИЕ ПАПОК
# ============================================================
Write-Host "`n[1/8] Creating directories..." -ForegroundColor Yellow

$dirs = @(
    "$src\tree",
    "$src\client\attunement",
    "$res\data\shinobicore\skill_tree"
)
foreach ($d in $dirs) {
    if (-not (Test-Path $d)) {
        New-Item -ItemType Directory -Path $d -Force | Out-Null
        Write-Host "  Created: $d" -ForegroundColor Gray
    } else {
        Write-Host "  Exists:  $d" -ForegroundColor Gray
    }
}

# ============================================================
# ШАГ 2: НОВЫЕ ФАЙЛЫ
# ============================================================
Write-Host "`n[2/8] Creating new files..." -ForegroundColor Yellow

# --- 2a. SkillTreeNode.java ---
$file = "$src\tree\SkillTreeNode.java"
$code = @'
package com.example.shinobicore.tree;

import java.util.List;

public record SkillTreeNode(
    String id,
    String type,
    String jutsuId,
    String effect,
    float value,
    String nature,
    int spCost,
    List<String> requires,
    int posX,
    int posY
) {}
'@
[System.IO.File]::WriteAllText($file, $code, $utf8NoBom)
Write-Host "  Created: SkillTreeNode.java" -ForegroundColor Green

# --- 2b. SkillTreeRegistry.java ---
$file = "$src\tree\SkillTreeRegistry.java"
$code = @'
package com.example.shinobicore.tree;

import com.example.shinobicore.ShinobiCore;
import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import net.minecraft.resource.Resource;
import net.minecraft.resource.ResourceManager;
import net.minecraft.util.Identifier;

import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.*;

public class SkillTreeRegistry {

    private static final Map<String, SkillTreeNode> NODES = new LinkedHashMap<>();
    private static final Map<String, String> BRANCH_COLORS = new HashMap<>();
    private static final Map<String, String> BRANCH_LABELS = new HashMap<>();

    public static void reload(ResourceManager manager) {
        NODES.clear();
        BRANCH_COLORS.clear();
        BRANCH_LABELS.clear();

        Identifier fileId = new Identifier(ShinobiCore.MOD_ID, "skill_tree/tree.json");
        try {
            Resource resource = manager.getResource(fileId).orElse(null);
            if (resource == null) {
                ShinobiCore.LOGGER.warn("Skill tree file not found: {}", fileId);
                return;
            }
            try (InputStream stream = resource.getInputStream()) {
                JsonObject root = JsonParser.parseReader(
                        new InputStreamReader(stream, StandardCharsets.UTF_8)).getAsJsonObject();

                if (root.has("branches")) {
                    JsonObject branches = root.getAsJsonObject("branches");
                    for (String key : branches.keySet()) {
                        JsonObject b = branches.getAsJsonObject(key);
                        BRANCH_COLORS.put(key, b.has("color") ? b.get("color").getAsString() : "#FFFFFF");
                        BRANCH_LABELS.put(key, b.has("label") ? b.get("label").getAsString() : key);
                    }
                }

                if (root.has("nodes")) {
                    JsonArray nodesArr = root.getAsJsonArray("nodes");
                    for (JsonElement el : nodesArr) {
                        JsonObject n = el.getAsJsonObject();
                        String id = n.get("id").getAsString();
                        String type = n.has("type") ? n.get("type").getAsString() : "jutsu";
                        String jutsuId = n.has("jutsuId") ? n.get("jutsuId").getAsString() : null;
                        String effect = n.has("effect") ? n.get("effect").getAsString() : null;
                        float value = n.has("value") ? n.get("value").getAsFloat() : 0f;
                        String nature = n.has("branch") ? n.get("branch").getAsString() : "general";
                        int spCost = n.has("spCost") ? n.get("spCost").getAsInt() : 1;

                        List<String> requires = new ArrayList<>();
                        if (n.has("requires")) {
                            for (JsonElement r : n.getAsJsonArray("requires")) {
                                requires.add(r.getAsString());
                            }
                        }

                        int posX = 0, posY = 0;
                        if (n.has("position")) {
                            JsonObject pos = n.getAsJsonObject("position");
                            posX = pos.has("x") ? pos.get("x").getAsInt() : 0;
                            posY = pos.has("y") ? pos.get("y").getAsInt() : 0;
                        }

                        NODES.put(id, new SkillTreeNode(id, type, jutsuId, effect, value,
                                nature, spCost, requires, posX, posY));
                    }
                }
            }
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("Failed to load skill tree: {}", e.getMessage());
        }
        ShinobiCore.LOGGER.info("Loaded {} skill tree nodes", NODES.size());
    }

    public static SkillTreeNode get(String id) { return NODES.get(id); }
    public static Collection<SkillTreeNode> getAll() { return NODES.values(); }
    public static String getBranchColor(String branch) {
        return BRANCH_COLORS.getOrDefault(branch, "#FFFFFF");
    }
    public static String getBranchLabel(String branch) {
        return BRANCH_LABELS.getOrDefault(branch, branch);
    }
}
'@
[System.IO.File]::WriteAllText($file, $code, $utf8NoBom)
Write-Host "  Created: SkillTreeRegistry.java" -ForegroundColor Green

# --- 2c. AttunementScreen.java ---
$file = "$src\client\attunement\AttunementScreen.java"
$code = @'
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

        int control = ClientNinjaState.statLevels.getOrDefault("control", 0);
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
            sendResult(true);
        } else {
            attemptsLeft--;
            if (attemptsLeft <= 0) {
                phase = 2;
                sendResult(false);
            } else {
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
'@
[System.IO.File]::WriteAllText($file, $code, $utf8NoBom)
Write-Host "  Created: AttunementScreen.java" -ForegroundColor Green

# --- 2d. SkillTreeScreen.java ---
$file = "$src\client\SkillTreeScreen.java"
$code = @'
package com.example.shinobicore.client;

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
import java.util.List;

public class SkillTreeScreen extends Screen {

    private static final int NODE_W = 80;
    private static final int NODE_H = 20;
    private static final int GAP_X = 100;
    private static final int GAP_Y = 40;

    private int scrollX = 0;
    private int scrollY = 0;
    private boolean dragging = false;
    private int dragStartX, dragStartY;
    private int dragScrollX, dragScrollY;

    public SkillTreeScreen() {
        super(Text.literal("Skill Tree"));
    }

    @Override
    public void render(DrawContext ctx, int mx, int my, float delta) {
        renderBackground(ctx);
        super.render(ctx, mx, my, delta);

        ctx.fill(0, 0, width, height, 0xFF1A1A2E);

        drawCentered(ctx, "Skill Tree  |  SP: " + ClientNinjaState.skillPoints,
                width / 2, 10, 0xFFFFFFFF);

        for (SkillTreeNode node : SkillTreeRegistry.getAll()) {
            int nx = getNodeX(node);
            int ny = getNodeY(node);
            for (String req : node.requires()) {
                SkillTreeNode parent = SkillTreeRegistry.get(req);
                if (parent == null) continue;
                int px = getNodeX(parent);
                int py = getNodeY(parent);
                drawLine(ctx, px + NODE_W / 2, py + NODE_H / 2,
                         nx + NODE_W / 2, ny + NODE_H / 2, 0xFF555555);
            }
        }

        for (SkillTreeNode node : SkillTreeRegistry.getAll()) {
            int x = getNodeX(node);
            int y = getNodeY(node);
            boolean unlocked = ClientNinjaState.unlockedNodes.contains(node.id());
            boolean available = canUnlock(node);

            int bgColor;
            if (unlocked) {
                bgColor = 0xFF225522;
            } else if (available) {
                bgColor = 0xFF554400;
            } else {
                bgColor = 0xFF333333;
            }

            ctx.fill(x, y, x + NODE_W, y + NODE_H, bgColor);
            ctx.fill(x, y, x + NODE_W, y + 1, 0xFF888888);
            ctx.fill(x, y + NODE_H - 1, x + NODE_W, y + NODE_H, 0xFF222222);

            String label = getShortName(node);
            int textColor = unlocked ? 0xFF44FF44 : (available ? 0xFFFFAA00 : 0xFF888888);
            drawCentered(ctx, label, x + NODE_W / 2, y + 4, textColor);

            if (!unlocked) {
                drawCentered(ctx, "SP:" + node.spCost(), x + NODE_W / 2, y + 12, 0xFFAAAAAA);
            }

            if (mx >= x && mx <= x + NODE_W && my >= y && my <= y + NODE_H) {
                renderTooltip(ctx, node, mx, my);
            }
        }

        drawCentered(ctx, "RMB drag to scroll | LMB to unlock", width / 2, height - 14, 0xFF888888);
    }

    private int getNodeX(SkillTreeNode node) {
        return 40 + node.posX() * GAP_X - scrollX;
    }

    private int getNodeY(SkillTreeNode node) {
        return 40 + node.posY() * GAP_Y - scrollY;
    }

    private boolean canUnlock(SkillTreeNode node) {
        if (ClientNinjaState.unlockedNodes.contains(node.id())) return false;
        if (ClientNinjaState.skillPoints < node.spCost()) return false;
        for (String req : node.requires()) {
            if (!ClientNinjaState.unlockedNodes.contains(req)) return false;
        }
        return true;
    }

    private String getShortName(SkillTreeNode node) {
        if (node.jutsuId() != null) {
            String name = ClientNinjaState.name(node.jutsuId());
            if (name != null && !name.isEmpty()) {
                return name.length() > 12 ? name.substring(0, 12) + ".." : name;
            }
        }
        return node.id().length() > 12 ? node.id().substring(0, 12) + ".." : node.id();
    }

    private void renderTooltip(DrawContext ctx, SkillTreeNode node, int mx, int my) {
        List<String> lines = new ArrayList<>();
        lines.add(node.id());
        lines.add("Type: " + node.type());
        if (node.jutsuId() != null) lines.add("Jutsu: " + ClientNinjaState.name(node.jutsuId()));
        lines.add("SP Cost: " + node.spCost());
        lines.add("Branch: " + node.nature());
        if (!node.requires().isEmpty()) lines.add("Requires: " + String.join(", ", node.requires()));

        int tw = 0;
        for (String line : lines) tw = Math.max(tw, textRenderer.getWidth(line));
        int th = lines.size() * 10 + 6;

        int tx = Math.min(mx + 8, width - tw - 12);
        int ty = Math.min(my + 8, height - th - 4);

        ctx.fill(tx, ty, tx + tw + 8, ty + th, 0xDD000000);
        int ly = ty + 3;
        for (String line : lines) {
            ctx.drawText(textRenderer, line, tx + 4, ly, 0xFFFFFFFF, false);
            ly += 10;
        }
    }

    @Override
    public boolean mouseClicked(double mx, double my, int button) {
        if (button == 1) {
            dragging = true;
            dragStartX = (int) mx;
            dragStartY = (int) my;
            dragScrollX = scrollX;
            dragScrollY = scrollY;
            return true;
        }
        if (button == 0) {
            for (SkillTreeNode node : SkillTreeRegistry.getAll()) {
                int x = getNodeX(node);
                int y = getNodeY(node);
                if (mx >= x && mx <= x + NODE_W && my >= y && my <= y + NODE_H) {
                    if (canUnlock(node)) {
                        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
                        buf.writeString(node.id());
                        ClientPlayNetworking.send(ModPackets.UNLOCK_NODE_ID, buf);
                    }
                    return true;
                }
            }
        }
        return super.mouseClicked(mx, my, button);
    }

    @Override
    public boolean mouseReleased(double mx, double my, int button) {
        if (button == 1) dragging = false;
        return super.mouseReleased(mx, my, button);
    }

    @Override
    public boolean mouseDragged(double mx, double my, int button, double dx, double dy) {
        if (dragging) {
            scrollX = dragScrollX - ((int) mx - dragStartX);
            scrollY = dragScrollY - ((int) my - dragStartY);
            return true;
        }
        return super.mouseDragged(mx, my, button, dx, dy);
    }

    private void drawLine(DrawContext ctx, int x1, int y1, int x2, int y2, int color) {
        int steps = Math.max(Math.abs(x2 - x1), Math.abs(y2 - y1));
        if (steps == 0) return;
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

    @Override
    public boolean shouldPause() { return false; }
}
'@
[System.IO.File]::WriteAllText($file, $code, $utf8NoBom)
Write-Host "  Created: SkillTreeScreen.java" -ForegroundColor Green

# --- 2e. tree.json ---
$file = "$res\data\shinobicore\skill_tree\tree.json"
$json = @'
{
  "branches": {
    "fire":      {"color": "#FF4400", "label": "Fire Release"},
    "water":     {"color": "#2266FF", "label": "Water Release"},
    "wind":      {"color": "#88DDAA", "label": "Wind Release"},
    "lightning": {"color": "#FFFF44", "label": "Lightning Release"},
    "earth":     {"color": "#996633", "label": "Earth Release"},
    "taijutsu":  {"color": "#44FF44", "label": "Taijutsu"},
    "medical":   {"color": "#FF88CC", "label": "Medical"},
    "general":   {"color": "#AAAAAA", "label": "General"}
  },
  "nodes": [
    {
      "id": "fire_basic",
      "type": "jutsu",
      "jutsuId": "shinobicore:fire_release_flame_bullet",
      "spCost": 2,
      "requires": [],
      "branch": "fire",
      "position": {"x": 0, "y": 0}
    },
    {
      "id": "fire_mid",
      "type": "jutsu",
      "jutsuId": "shinobicore:fire_release_great_fireball",
      "spCost": 4,
      "requires": ["fire_basic"],
      "branch": "fire",
      "position": {"x": 0, "y": 1}
    },
    {
      "id": "fire_advanced",
      "type": "jutsu",
      "jutsuId": "shinobicore:fire_release_dragon_flame",
      "spCost": 6,
      "requires": ["fire_mid"],
      "branch": "fire",
      "position": {"x": 0, "y": 2}
    },
    {
      "id": "fire_phoenix",
      "type": "jutsu",
      "jutsuId": "shinobicore:fire_release_phoenix_sage",
      "spCost": 5,
      "requires": ["fire_mid"],
      "branch": "fire",
      "position": {"x": 1, "y": 2}
    },
    {
      "id": "water_basic",
      "type": "jutsu",
      "jutsuId": "shinobicore:water_release_water_bullet",
      "spCost": 2,
      "requires": [],
      "branch": "water",
      "position": {"x": 0, "y": 0}
    },
    {
      "id": "water_raging",
      "type": "jutsu",
      "jutsuId": "shinobicore:water_release_raging_waves",
      "spCost": 4,
      "requires": ["water_basic"],
      "branch": "water",
      "position": {"x": 0, "y": 1}
    },
    {
      "id": "water_waterfall",
      "type": "jutsu",
      "jutsuId": "shinobicore:water_release_great_waterfall",
      "spCost": 6,
      "requires": ["water_raging"],
      "branch": "water",
      "position": {"x": 0, "y": 2}
    },
    {
      "id": "wind_basic",
      "type": "jutsu",
      "jutsuId": "shinobicore:wind_release_gale_palm",
      "spCost": 2,
      "requires": [],
      "branch": "wind",
      "position": {"x": 0, "y": 0}
    },
    {
      "id": "wind_breakthrough",
      "type": "jutsu",
      "jutsuId": "shinobicore:wind_release_great_breakthrough",
      "spCost": 4,
      "requires": ["wind_basic"],
      "branch": "wind",
      "position": {"x": 0, "y": 1}
    },
    {
      "id": "wind_passing_gale",
      "type": "jutsu",
      "jutsuId": "shinobicore:wind_release_passing_gale",
      "spCost": 3,
      "requires": ["wind_basic"],
      "branch": "wind",
      "position": {"x": 1, "y": 1}
    },
    {
      "id": "lightning_basic",
      "type": "jutsu",
      "jutsuId": "shinobicore:lightning_release_shock",
      "spCost": 3,
      "requires": [],
      "branch": "lightning",
      "position": {"x": 0, "y": 0}
    },
    {
      "id": "lightning_darkness",
      "type": "jutsu",
      "jutsuId": "shinobicore:lightning_release_false_darkness",
      "spCost": 5,
      "requires": ["lightning_basic"],
      "branch": "lightning",
      "position": {"x": 0, "y": 1}
    },
    {
      "id": "earth_wall",
      "type": "jutsu",
      "jutsuId": "shinobicore:earth_release_earth_wall",
      "spCost": 3,
      "requires": [],
      "branch": "earth",
      "position": {"x": 0, "y": 0}
    },
    {
      "id": "earth_mud",
      "type": "jutsu",
      "jutsuId": "shinobicore:earth_release_mud_wave",
      "spCost": 5,
      "requires": ["earth_wall"],
      "branch": "earth",
      "position": {"x": 0, "y": 1}
    },
    {
      "id": "taijutsu_whirlwind",
      "type": "jutsu",
      "jutsuId": "shinobicore:leaf_whirlwind",
      "spCost": 3,
      "requires": [],
      "branch": "taijutsu",
      "position": {"x": 0, "y": 0}
    },
    {
      "id": "medical_palm",
      "type": "jutsu",
      "jutsuId": "shinobicore:mystical_palm_jutsu",
      "spCost": 3,
      "requires": [],
      "branch": "medical",
      "position": {"x": 0, "y": 0}
    },
    {
      "id": "medical_poison",
      "type": "jutsu",
      "jutsuId": "shinobicore:poison_extraction",
      "spCost": 2,
      "requires": ["medical_palm"],
      "branch": "medical",
      "position": {"x": 0, "y": 1}
    },
    {
      "id": "rasengan",
      "type": "jutsu",
      "jutsuId": "shinobicore:rasengan",
      "spCost": 10,
      "requires": ["wind_basic", "water_basic"],
      "branch": "general",
      "position": {"x": 0, "y": 3}
    }
  ]
}
'@
[System.IO.File]::WriteAllText($file, $json, $utf8NoBom)
Write-Host "  Created: tree.json" -ForegroundColor Green

Write-Host "`n  All new files created!" -ForegroundColor Green

# ============================================================
# ШАГ 3: MODPACKETS.JAVA — ДОБАВИТЬ ID И ОБРАБОТЧИКИ
# ============================================================
Write-Host "`n[3/8] Modifying ModPackets.java..." -ForegroundColor Yellow

$file = "$src\network\ModPackets.java"
$content = [System.IO.File]::ReadAllText($file, $utf8NoBom)

# 3a. Добавить новые ID после RASENGAN_STRIKE_ID
$marker = 'public static final Identifier RASENGAN_STRIKE_ID = new Identifier("shinobicore", "rasengan_strike");'
$insert = @'
public static final Identifier RASENGAN_STRIKE_ID = new Identifier("shinobicore", "rasengan_strike");
    public static final Identifier ATTUNEMENT_ID = new Identifier("shinobicore", "attunement");
    public static final Identifier TREE_SYNC_ID = new Identifier("shinobicore", "tree_sync");
    public static final Identifier UNLOCK_NODE_ID = new Identifier("shinobicore", "unlock_node");
'@
$content = $content.Replace($marker, $insert)
Write-Host "  Added 3 new packet IDs" -ForegroundColor Gray

# 3b. Добавить обработчики после блока RASENGAN_STRIKE_ID
$marker2 = 'ShinobiCore.handleRasenganStrike(player);
            });
        });'
$insert2 = @'
ShinobiCore.handleRasenganStrike(player);
            });
        });

        // === АТТЮНМЕНТ (клиент -> сервер) ===
        ServerPlayNetworking.registerGlobalReceiver(ATTUNEMENT_ID, (server, player, handler, buf, responseSender) -> {
            String elementId = buf.readString();
            boolean success = buf.readBoolean();
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                ElementType element = null;
                for (ElementType e : ElementType.values()) {
                    if (e.getId().equals(elementId)) { element = e; break; }
                }
                if (element == null) return;

                if (success) {
                    data.setNatureUnlocked(element, true);
                    if (data.getNatureLevel(element) < 1) {
                        data.setNatureLevel(element, 1);
                    }
                    ShinobiCore.sendStatsSync(player);
                    player.sendMessage(Text.literal("§aAttuned to " + elementId + "!"), false);
                } else {
                    player.sendMessage(Text.literal("§cAttunement failed."), false);
                }
            });
        });

        // === ДРЕВО: разблокировка узла (клиент -> сервер) ===
        ServerPlayNetworking.registerGlobalReceiver(UNLOCK_NODE_ID, (server, player, handler, buf, responseSender) -> {
            String nodeId = buf.readString();
            server.execute(() -> ShinobiCore.handleUnlockNode(player, nodeId));
        });
'@
$content = $content.Replace($marker2, $insert2)
Write-Host "  Added ATTUNEMENT_ID + UNLOCK_NODE_ID handlers" -ForegroundColor Gray

# 3c. Добавить импорты если их нет
if (-not $content.Contains("import com.example.shinobicore.stat.ElementType;")) {
    $importMarker = "import com.example.shinobicore.stat.NinjaDataHolder;"
    $importInsert = "import com.example.shinobicore.stat.ElementType;
import com.example.shinobicore.stat.NinjaDataHolder;"
    $content = $content.Replace($importMarker, $importInsert)
    Write-Host "  Added ElementType import" -ForegroundColor Gray
}

[System.IO.File]::WriteAllText($file, $content, $utf8NoBom)
Write-Host "  ModPackets.java updated!" -ForegroundColor Green

# ============================================================
# ШАГ 4: NINJAPLAYERDATA.JAVA — ДОБАВИТЬ UNLOCKEDNODES
# ============================================================
Write-Host "`n[4/8] Modifying NinjaPlayerData.java..." -ForegroundColor Yellow

$file = "$src\stat\NinjaPlayerData.java"
$content = [System.IO.File]::ReadAllText($file, $utf8NoBom)

# 4a. Поле unlockedNodes после wasOnGround
$marker = "private boolean wasOnGround = true;"
$insert = @'
private boolean wasOnGround = true;
    private final Set<String> unlockedNodes = new HashSet<>();
'@
$content = $content.Replace($marker, $insert)
Write-Host "  Added unlockedNodes field" -ForegroundColor Gray

# 4b. Геттеры/сеттеры после getCurrentStyleId
$marker = "public String getCurrentStyleId() { return currentStyleId; }"
$insert = @'
public String getCurrentStyleId() { return currentStyleId; }
    public Set<String> getUnlockedNodes() { return unlockedNodes; }
    public boolean isNodeUnlocked(String nodeId) { return unlockedNodes.contains(nodeId); }
    public void unlockNode(String nodeId) { unlockedNodes.add(nodeId); statsDirty = true; }
'@
$content = $content.Replace($marker, $insert)
Write-Host "  Added unlockedNodes getters/setters" -ForegroundColor Gray

# 4c. writeNbt — после ActiveSlotB
$marker = 'nbt.putInt("ActiveSlotB", activeSlotB);'
$insert = @'
nbt.putInt("ActiveSlotB", activeSlotB);
        NbtList nodes = new NbtList();
        for (String nodeId : unlockedNodes) nodes.add(NbtString.of(nodeId));
        nbt.put("UnlockedNodes", nodes);
'@
$content = $content.Replace($marker, $insert)
Write-Host "  Added unlockedNodes to writeNbt" -ForegroundColor Gray

# 4d. readNbt — после activeSlotB = nbt.getInt
$marker = 'activeSlotB = nbt.getInt("ActiveSlotB");'
$insert = @'
activeSlotB = nbt.getInt("ActiveSlotB");
        if (nbt.contains("UnlockedNodes")) {
            NbtList nodeList = nbt.getList("UnlockedNodes", 8);
            for (int i = 0; i < nodeList.size(); i++) unlockedNodes.add(nodeList.getString(i));
        }
'@
$content = $content.Replace($marker, $insert)
Write-Host "  Added unlockedNodes to readNbt" -ForegroundColor Gray

[System.IO.File]::WriteAllText($file, $content, $utf8NoBom)
Write-Host "  NinjaPlayerData.java updated!" -ForegroundColor Green

# ============================================================
# ШАГ 5: CLIENTNINJASTATE.JAVA — ДОБАВИТЬ UNLOCKEDNODES
# ============================================================
Write-Host "`n[5/8] Modifying ClientNinjaState.java..." -ForegroundColor Yellow

$file = "$src\client\ClientNinjaState.java"
$content = [System.IO.File]::ReadAllText($file, $utf8NoBom)

$marker = "public static String affinityId = null;"
$insert = @'
public static String affinityId = null;
    public static final Set<String> unlockedNodes = new HashSet<>();
'@
$content = $content.Replace($marker, $insert)
Write-Host "  Added unlockedNodes to ClientNinjaState" -ForegroundColor Gray

[System.IO.File]::WriteAllText($file, $content, $utf8NoBom)
Write-Host "  ClientNinjaState.java updated!" -ForegroundColor Green

# ============================================================
# ШАГ 6: SHINOBICORE.JAVA — ФИКСЫ + НОВЫЕ МЕТОДЫ
# ============================================================
Write-Host "`n[6/8] Modifying ShinobiCore.java..." -ForegroundColor Yellow

$file = "$src\ShinobiCore.java"
$content = [System.IO.File]::ReadAllText($file, $utf8NoBom)

# 6a. Фикс бага affinity в JOIN
$marker = "data.setAffinity(randomClan.affinity());"
$insert = @'
data.setAffinity(randomClan.affinity());
                    // === ФИКС: разблокировать affinity как nature ===
                    if (randomClan.affinity() != null) {
                        data.setNatureUnlocked(randomClan.affinity(), true);
                        if (data.getNatureLevel(randomClan.affinity()) < 5) {
                            data.setNatureLevel(randomClan.affinity(), 5);
                        }
                    }
'@
$content = $content.Replace($marker, $insert)
Write-Host "  Fixed affinity unlock bug in JOIN" -ForegroundColor Gray

# 6b. Добавить SkillTreeRegistry.reload в SERVER_STARTED
$marker = "ClanRegistry.reload(server.getResourceManager());"
$insert = @'
ClanRegistry.reload(server.getResourceManager());
            SkillTreeRegistry.reload(server.getResourceManager());
'@
$content = $content.Replace($marker, $insert)
Write-Host "  Added SkillTreeRegistry.reload to SERVER_STARTED" -ForegroundColor Gray

# 6c. Добавить SkillTreeRegistry.reload в END_DATA_PACK_RELOAD
$marker = "JutsuRegistry.reload(server.getResourceManager());
                ClanRegistry.reload(server.getResourceManager());"
$insert = @'
JutsuRegistry.reload(server.getResourceManager());
                ClanRegistry.reload(server.getResourceManager());
                SkillTreeRegistry.reload(server.getResourceManager());
'@
$content = $content.Replace($marker, $insert)
Write-Host "  Added SkillTreeRegistry.reload to END_DATA_PACK_RELOAD" -ForegroundColor Gray

# 6d. Добавить sendTreeSync в JOIN после sendBodySync
$marker = "sendBodySync(player);"
$insert = @'
sendBodySync(player);
                sendTreeSync(player);
'@
$content = $content.Replace($marker, $insert)
Write-Host "  Added sendTreeSync to JOIN" -ForegroundColor Gray

# 6e. Добавить методы sendTreeSync и handleUnlockNode после handleSpendSp
$marker = "private static StatType statById(String id) {"
$insert = @'
public static void sendTreeSync(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(data.getUnlockedNodes().size());
        for (String nodeId : data.getUnlockedNodes()) buf.writeString(nodeId);
        ServerPlayNetworking.send(player, ModPackets.TREE_SYNC_ID, buf);
    }

    public static void handleUnlockNode(ServerPlayerEntity player, String nodeId) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        SkillTreeNode node = SkillTreeRegistry.get(nodeId);
        if (node == null) {
            player.sendMessage(Text.literal("§cUnknown node: " + nodeId), false);
            return;
        }
        if (data.isNodeUnlocked(nodeId)) {
            player.sendMessage(Text.literal("§cAlready unlocked!"), false);
            return;
        }
        for (String req : node.requires()) {
            if (!data.isNodeUnlocked(req)) {
                player.sendMessage(Text.literal("§cRequires: " + req), false);
                return;
            }
        }
        if (data.getSkillPoints() < node.spCost()) {
            player.sendMessage(Text.literal("§cNot enough SP! Need " + node.spCost()), false);
            return;
        }
        if (!node.nature().equals("general") && !node.nature().equals("taijutsu")
            && !node.nature().equals("medical")) {
            ElementType nature = null;
            for (ElementType e : ElementType.values()) {
                if (e.getId().equals(node.nature())) { nature = e; break; }
            }
            if (nature != null && !data.isNatureUnlocked(nature)) {
                player.sendMessage(Text.literal("§cUnlock this nature first!"), false);
                return;
            }
        }

        data.addSkillPoints(-node.spCost());
        data.unlockNode(nodeId);

        if ("jutsu".equals(node.type()) && node.jutsuId() != null) {
            if (!data.getLearnedJutsus().contains(node.jutsuId())) {
                data.learnJutsu(node.jutsuId());
            }
        }

        sendStatsSync(player);
        sendLoadoutSync(player);
        sendTreeSync(player);
        player.sendMessage(Text.literal("§aUnlocked: " + nodeId), false);
    }

    private static StatType statById(String id) {
'@
$content = $content.Replace($marker, $insert)
Write-Host "  Added sendTreeSync + handleUnlockNode methods" -ForegroundColor Gray

# 6f. Добавить импорты
if (-not $content.Contains("import com.example.shinobicore.tree.SkillTreeNode;")) {
    $importMarker = "import com.example.shinobicore.stat.StatType;"
    $importInsert = "import com.example.shinobicore.tree.SkillTreeNode;
import com.example.shinobicore.tree.SkillTreeRegistry;
import com.example.shinobicore.stat.StatType;"
    $content = $content.Replace($importMarker, $importInsert)
    Write-Host "  Added SkillTree imports" -ForegroundColor Gray
}

[System.IO.File]::WriteAllText($file, $content, $utf8NoBom)
Write-Host "  ShinobiCore.java updated!" -ForegroundColor Green

# ============================================================
# ШАГ 7: SHINOBICORECLIENT.JAVA — ПРИЁМ TREE_SYNC
# ============================================================
Write-Host "`n[7/8] Modifying ShinobiCoreClient.java..." -ForegroundColor Yellow

$file = "$src\client\ShinobiCoreClient.java"
$content = [System.IO.File]::ReadAllText($file, $utf8NoBom)

# 7a. Добавить приём TREE_SYNC_ID перед HudRenderCallback
$marker = "HudRenderCallback.EVENT.register(ChakraHudRenderer::render);"
$insert = @'
ClientPlayNetworking.registerGlobalReceiver(ModPackets.TREE_SYNC_ID, (client, handler, buf, responseSender) -> {
            int count = buf.readInt();
            Set<String> nodes = new HashSet<>();
            for (int i = 0; i < count; i++) nodes.add(buf.readString());
            client.execute(() -> {
                ClientNinjaState.unlockedNodes.clear();
                ClientNinjaState.unlockedNodes.addAll(nodes);
            });
        });

        HudRenderCallback.EVENT.register(ChakraHudRenderer::render);
'@
$content = $content.Replace($marker, $insert)
Write-Host "  Added TREE_SYNC_ID receiver" -ForegroundColor Gray

[System.IO.File]::WriteAllText($file, $content, $utf8NoBom)
Write-Host "  ShinobiCoreClient.java updated!" -ForegroundColor Green

# ============================================================
# ШАГ 8: KEYBINDINGS + CLIENTINPUTHANDLER
# ============================================================
Write-Host "`n[8/8] Modifying KeyBindings.java + ClientInputHandler.java..." -ForegroundColor Yellow

# 8a. KeyBindings.java — добавить SKILL_TREE
$file = "$src\client\KeyBindings.java"
$content = [System.IO.File]::ReadAllText($file, $utf8NoBom)

$marker = "public static KeyBinding SWITCH_STYLE; // === НОВОЕ ==="
$insert = @'
public static KeyBinding SWITCH_STYLE; // === НОВОЕ ===
    public static KeyBinding SKILL_TREE;
'@
$content = $content.Replace($marker, $insert)

$marker = '"key.shinobicore.switch_style", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_B, COMBAT_CATEGORY));'
$insert = @'
"key.shinobicore.switch_style", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_B, COMBAT_CATEGORY));

        SKILL_TREE = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.skill_tree", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_J, CATEGORY));
'@
$content = $content.Replace($marker, $insert)

[System.IO.File]::WriteAllText($file, $content, $utf8NoBom)
Write-Host "  KeyBindings.java: added SKILL_TREE (J)" -ForegroundColor Gray

# 8b. ClientInputHandler.java — добавить обработку J
$file = "$src\client\ClientInputHandler.java"
$content = [System.IO.File]::ReadAllText($file, $utf8NoBom)

$marker = 'client.setScreen(new ProgressionScreen());'
$insert = @'
client.setScreen(new ProgressionScreen());
        }

        // === ДРЕВО ПРОКАЧКИ (J) ===
        if (KeyBindings.SKILL_TREE.wasPressed()) {
            ShinobiCore.LOGGER.info("[INPUT] SKILL_TREE (J) pressed");
            client.setScreen(new SkillTreeScreen());
'@
$content = $content.Replace($marker, $insert)

# Добавить импорт SkillTreeScreen если его нет
if (-not $content.Contains("import com.example.shinobicore.client.SkillTreeScreen;")) {
    $importMarker = "import com.example.shinobicore.client.ProgressionScreen;"
    # Если ProgressionScreen не импортирован, попробуем другой маркер
    if ($content.Contains($importMarker)) {
        $importInsert = "import com.example.shinobicore.client.SkillTreeScreen;
import com.example.shinobicore.client.ProgressionScreen;"
        $content = $content.Replace($importMarker, $importInsert)
    } else {
        # Вставим после последнего import
        $importMarker = "import net.minecraft.text.Text;"
        $importInsert = "import net.minecraft.text.Text;
import com.example.shinobicore.client.SkillTreeScreen;"
        $content = $content.Replace($importMarker, $importInsert)
    }
    Write-Host "  Added SkillTreeScreen import" -ForegroundColor Gray
}

[System.IO.File]::WriteAllText($file, $content, $utf8NoBom)
Write-Host "  ClientInputHandler.java: added J handler" -ForegroundColor Gray

# ============================================================
# ГОТОВО
# ============================================================
Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "  PHASE A AUTO-APPLY COMPLETE!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "New files created:" -ForegroundColor White
Write-Host "  - tree/SkillTreeNode.java" -ForegroundColor Gray
Write-Host "  - tree/SkillTreeRegistry.java" -ForegroundColor Gray
Write-Host "  - client/attunement/AttunementScreen.java" -ForegroundColor Gray
Write-Host "  - client/SkillTreeScreen.java" -ForegroundColor Gray
Write-Host "  - data/shinobicore/skill_tree/tree.json" -ForegroundColor Gray
Write-Host ""
Write-Host "Modified files:" -ForegroundColor White
Write-Host "  - network/ModPackets.java (3 IDs + 2 handlers)" -ForegroundColor Gray
Write-Host "  - stat/NinjaPlayerData.java (unlockedNodes)" -ForegroundColor Gray
Write-Host "  - client/ClientNinjaState.java (unlockedNodes)" -ForegroundColor Gray
Write-Host "  - ShinobiCore.java (affinity fix + tree methods)" -ForegroundColor Gray
Write-Host "  - client/ShinobiCoreClient.java (TREE_SYNC receiver)" -ForegroundColor Gray
Write-Host "  - client/KeyBindings.java (SKILL_TREE)" -ForegroundColor Gray
Write-Host "  - client/ClientInputHandler.java (J handler)" -ForegroundColor Gray
Write-Host ""
Write-Host "Backups saved to: $backupDir" -ForegroundColor Yellow
Write-Host ""
Write-Host "IMPORTANT: ProgressionScreen.java was NOT modified by this script." -ForegroundColor Red
Write-Host "The full replacement is too large. Apply it manually or ask for a" -ForegroundColor Red
Write-Host "separate script for ProgressionScreen.java." -ForegroundColor Red
Write-Host ""
Write-Host "Next step: cd E:\Games\mod; .\gradlew.bat runClient" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
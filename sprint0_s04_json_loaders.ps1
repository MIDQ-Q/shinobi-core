# ============================================================
#  SPRINT 0 / S0-04: JSON TREE LOADER + GRAPH VALIDATION
#  Validates: cycles, broken links, duplicates, missing fields
#  PS 5.1 compatible. UTF8 no BOM.
#  Run: powershell -ExecutionPolicy Bypass -File .\sprint0_s04_json_loaders.ps1
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$java = "$root\src\main\java\com\example\shinobicore"
$res = "$root\src\main\resources\data\shinobicore"
$ok = 0; $skip = 0; $err = 0

function Write-File($p, $c) {
    $dir = [System.IO.Path]::GetDirectoryName($p)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] $($p.Replace($root, ''))" -ForegroundColor Green
    $script:ok++
}

function Patch-File($p, $old, $new) {
    if (-not (Test-Path $p)) { Write-Host "[MISS] $p" -ForegroundColor Red; $script:err++; return }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    $cNorm = $c.Replace("`r`n", "`n")
    $oldNorm = $old.Replace("`r`n", "`n")
    $newNorm = $new.Replace("`r`n", "`n")
    if ($cNorm.Contains($newNorm)) { Write-Host "[SKIP] already: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Yellow; $script:skip++; return }
    if (-not $cNorm.Contains($oldNorm)) { Write-Host "[FAIL] pattern not found: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Red; $script:err++; return }
    $c = $c.Replace($oldNorm, $newNorm)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] patched: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Green
    $script:ok++
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  SPRINT 0 / S0-04: JSON TREE LOADER + VALIDATION" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# ================================================================
# 1. SkillTreeNode.java - add S0-04 fields
# ================================================================
Write-Host "[1/5] SkillTreeNode.java..." -ForegroundColor White
$contentNode = @'
package com.example.shinobicore.tree;

import java.util.List;

/**
* S0-04: Skill tree node definition.
* New fields: requiresTeacher, requiresScroll, positionX, positionY.
* Validation is done in SkillTreeRegistry, not here.
*/
public record SkillTreeNode(
    String id, String branch, int distance, float angleOffset,
    String type, String jutsuId, String effect, float value,
    int spCost, List<String> requires,
    String icon, String displayName, String description,
    String clanRequired,
    String visType, String visKey, int visValue,
    // S0-04: New fields from roadmap
    boolean requiresTeacher,
    String requiresScroll,
    int positionX, int positionY
) {
    public boolean hasVisibilityCondition() { return visType != null && !visType.isEmpty(); }
    public boolean hasClanRestriction() { return clanRequired != null && !clanRequired.isEmpty(); }
}
'@
Write-File "$java\tree\SkillTreeNode.java" $contentNode

# ================================================================
# 2. SkillTreeRegistry.java - full rewrite with graph validation
# ================================================================
Write-Host "[2/5] SkillTreeRegistry.java (with validation)..." -ForegroundColor White
$contentRegistry = @'
package com.example.shinobicore.tree;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.jutsu.JutsuRegistry;
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

/**
* S0-04: Skill tree registry with graph validation.
* Validates: broken links, cycles, duplicates, missing fields.
* Invalid nodes are marked and cannot be unlocked.
*/
public class SkillTreeRegistry {
    private static final Map<String, SkillTreeNode> NODES = new LinkedHashMap<>();
    private static final Map<String, BranchDef> BRANCHES = new LinkedHashMap<>();
    // S0-04: Validation state
    private static final Map<String, String> INVALID_NODES = new LinkedHashMap<>();

    public record BranchDef(String id, float angle, int color, String label, String clan, boolean hidden) {}

    public static void reload(ResourceManager manager) {
        NODES.clear(); BRANCHES.clear(); INVALID_NODES.clear();
        Identifier fileId = new Identifier(ShinobiCore.MOD_ID, "skill_tree/tree.json");
        try {
            Resource resource = manager.getResource(fileId).orElse(null);
            if (resource == null) {
                ShinobiCore.LOGGER.warn("[SkillTree] tree.json not found");
                return;
            }
            try (InputStream stream = resource.getInputStream()) {
                JsonObject root = JsonParser.parseReader(
                    new InputStreamReader(stream, StandardCharsets.UTF_8)).getAsJsonObject();
                // Parse branches
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
                // Parse nodes
                if (root.has("nodes")) {
                    for (JsonElement el : root.getAsJsonArray("nodes")) {
                        JsonObject n = el.getAsJsonObject();
                        try {
                            SkillTreeNode node = parseNode(n);
                            if (NODES.containsKey(node.id())) {
                                ShinobiCore.LOGGER.warn("[SkillTree] Duplicate node ID: {}", node.id());
                                markInvalid(node.id(), "Duplicate ID");
                            }
                            NODES.put(node.id(), node);
                        } catch (Exception e) {
                            String id = n.has("id") ? n.get("id").getAsString() : "unknown";
                            ShinobiCore.LOGGER.error("[SkillTree] Failed to parse node {}: {}", id, e.getMessage());
                            markInvalid(id, "Parse error: " + e.getMessage());
                        }
                    }
                }
            }
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("[SkillTree] Load error: {}", e.getMessage());
        }
        // S0-04: Validate graph after loading all nodes
        validate();
        ShinobiCore.LOGGER.info("[SkillTree] Loaded {} nodes, {} branches ({} invalid)",
                NODES.size(), BRANCHES.size(), INVALID_NODES.size());
    }

    private static SkillTreeNode parseNode(JsonObject n) {
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
        if (n.has("requires")) {
            for (var r : n.getAsJsonArray("requires")) req.add(r.getAsString());
        }
        String icon = n.has("icon") ? n.get("icon").getAsString() : "?";
        String name = n.has("name") ? n.get("name").getAsString() : id;
        String desc = n.has("description") ? n.get("description").getAsString() : "";
        String clanReq = n.has("clanRequired") ? n.get("clanRequired").getAsString() : null;
        String vType = null, vKey = null;
        int vVal = 0;
        if (n.has("visibilityCondition")) {
            JsonObject vc = n.getAsJsonObject("visibilityCondition");
            vType = vc.has("type") ? vc.get("type").getAsString() : null;
            vKey = vc.has("key") ? vc.get("key").getAsString() : null;
            vVal = vc.has("value") ? vc.get("value").getAsInt() : 0;
        }
        // S0-04: New fields
        boolean reqTeacher = n.has("requires_teacher") && n.get("requires_teacher").getAsBoolean();
        String reqScroll = n.has("requires_scroll") && !n.get("requires_scroll").isJsonNull()
                ? n.get("requires_scroll").getAsString() : null;
        int posX = 0, posY = 0;
        if (n.has("position") && n.get("position").isJsonArray()) {
            JsonArray pos = n.getAsJsonArray("position");
            if (pos.size() >= 2) {
                posX = pos.get(0).getAsInt();
                posY = pos.get(1).getAsInt();
            }
        }
        return new SkillTreeNode(id, branch, dist, aOff, type, jutsuId,
                effect, value, spCost, req, icon, name, desc, clanReq,
                vType, vKey, vVal, reqTeacher, reqScroll, posX, posY);
    }

    // ================================================================
    // S0-04: GRAPH VALIDATION
    // ================================================================
    private static void validate() {
        // 1. Broken requires links
        for (SkillTreeNode node : NODES.values()) {
            for (String req : node.requires()) {
                if (!NODES.containsKey(req)) {
                    markInvalid(node.id(), "Broken requires: '" + req + "' not found");
                }
            }
        }
        // 2. Cycle detection (DFS)
        Set<String> visited = new HashSet<>();
        for (String nodeId : NODES.keySet()) {
            if (!visited.contains(nodeId)) {
                if (hasCycle(nodeId, new LinkedHashSet<>(), visited)) {
                    markInvalid(nodeId, "Circular dependency detected");
                }
            }
        }
        // 3. Missing or zero spCost
        for (SkillTreeNode node : NODES.values()) {
            if (node.spCost() <= 0) {
                markInvalid(node.id(), "Missing or zero spCost");
            }
        }
        // 4. Missing icon
        for (SkillTreeNode node : NODES.values()) {
            if (node.icon() == null || node.icon().isEmpty()) {
                markInvalid(node.id(), "Missing icon");
            }
        }
        // 5. JutsuId references check
        for (SkillTreeNode node : NODES.values()) {
            if (node.jutsuId() != null && !node.jutsuId().isEmpty()) {
                if (JutsuRegistry.get(node.jutsuId()) == null) {
                    markInvalid(node.id(), "Jutsu not found: " + node.jutsuId());
                }
            }
        }
        // 6. Forbidden/S-rank without teacher or scroll
        for (SkillTreeNode node : NODES.values()) {
            if (node.branch().equals("forbidden")) {
                if (!node.requiresTeacher() && (node.requiresScroll() == null || node.requiresScroll().isEmpty())) {
                    markInvalid(node.id(), "Forbidden jutsu without teacher/scroll requirement");
                }
            }
        }
        // Log results
        if (!INVALID_NODES.isEmpty()) {
            ShinobiCore.LOGGER.warn("[SkillTree] {} invalid node(s):", INVALID_NODES.size());
            for (Map.Entry<String, String> e : INVALID_NODES.entrySet()) {
                ShinobiCore.LOGGER.warn("[SkillTree]   {} -> {}", e.getKey(), e.getValue());
            }
        }
    }

    private static boolean hasCycle(String nodeId, Set<String> path, Set<String> visited) {
        if (visited.contains(nodeId)) return false;
        if (path.contains(nodeId)) return true;
        path.add(nodeId);
        SkillTreeNode node = NODES.get(nodeId);
        if (node != null) {
            for (String req : node.requires()) {
                if (hasCycle(req, path, visited)) return true;
            }
        }
        path.remove(nodeId);
        visited.add(nodeId);
        return false;
    }

    private static void markInvalid(String nodeId, String reason) {
        INVALID_NODES.merge(nodeId, reason, (a, b) -> a + "; " + b);
    }

    public static boolean isInvalid(String nodeId) {
        return INVALID_NODES.containsKey(nodeId);
    }

    public static String getInvalidReason(String nodeId) {
        return INVALID_NODES.getOrDefault(nodeId, "unknown");
    }

    public static Map<String, String> getInvalidNodes() {
        return Collections.unmodifiableMap(INVALID_NODES);
    }

    // ================================================================
    // Existing API (unchanged)
    // ================================================================
    private static int parseColor(String hex) {
        try { return (int) Long.parseLong(hex.replace("#",""), 16) | 0xFF000000; }
        catch (Exception e) { return 0xFFFFFFFF; }
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
            case "two_natures_50" -> {
                int cnt = 0;
                for (Integer lvl : ClientNinjaState.natureLevels.values()) if (lvl >= node.visValue()) cnt++;
                yield cnt >= 2;
            }
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
            case "two_natures_50" -> {
                int cnt = 0;
                for (ElementType e2 : ElementType.values()) if (data.getNatureLevel(e2) >= node.visValue()) cnt++;
                yield cnt >= 2;
            }
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
Write-File "$java\tree\SkillTreeRegistry.java" $contentRegistry

# ================================================================
# 3. ShinobiCore.java - block invalid nodes in handleUnlockNode
# ================================================================
Write-Host "[3/5] Patching ShinobiCore.java..." -ForegroundColor White
$unlockOld = "if (data.isNodeUnlocked(nodeId)) {"
$unlockNew = @"
if (SkillTreeRegistry.isInvalid(nodeId)) {
            player.sendMessage(Text.literal("\u00a7cNode is broken: " + SkillTreeRegistry.getInvalidReason(nodeId)), false);
            return;
        }
        if (data.isNodeUnlocked(nodeId)) {
"@
Patch-File "$java\ShinobiCore.java" $unlockOld $unlockNew

# ================================================================
# 4. SkillTreeScreen.java - show invalid state in UI
# ================================================================
Write-Host "[4/5] Patching SkillTreeScreen.java..." -ForegroundColor White

# 4a. canUnlock: reject invalid nodes
$canUnlockOld = @"
private boolean canUnlock(SkillTreeNode node) {
        if (ClientNinjaState.unlockedNodes.contains(node.id())) return false;
"@
$canUnlockNew = @"
private boolean canUnlock(SkillTreeNode node) {
        if (SkillTreeRegistry.isInvalid(node.id())) return false;
        if (ClientNinjaState.unlockedNodes.contains(node.id())) return false;
"@
Patch-File "$java\client\SkillTreeScreen.java" $canUnlockOld $canUnlockNew

# 4b. Tooltip: show invalid reason
$tooltipOld = @"
if (unlocked) lines.add("[UNLOCKED]");
        else if (available) lines.add("[Click to unlock]");
        else lines.add("[Locked]");
"@
$tooltipNew = @"
if (SkillTreeRegistry.isInvalid(node.id())) lines.add("[INVALID] " + SkillTreeRegistry.getInvalidReason(node.id()));
        else if (unlocked) lines.add("[UNLOCKED]");
        else if (available) lines.add("[Click to unlock]");
        else lines.add("[Locked]");
"@
Patch-File "$java\client\SkillTreeScreen.java" $tooltipOld $tooltipNew

# 4c. Render: red border for invalid nodes
$borderOld = @"
int border;
                if (unlocked) {
                    border = bc;
                } else if (available) {
"@
$borderNew = @"
boolean invalid = SkillTreeRegistry.isInvalid(n.id());
                int border;
                if (invalid) {
                    border = 0xFFFF2222;
                } else if (unlocked) {
                    border = bc;
                } else if (available) {
"@
Patch-File "$java\client\SkillTreeScreen.java" $borderOld $borderNew

# ================================================================
# 5. Template file for new nodes
# ================================================================
Write-Host "[5/5] Creating _template_node.json..." -ForegroundColor White
$template = @'
{
  "__comment": "S0-04: Template for skill tree node. Copy into tree.json nodes array.",
  "id": "shinobicore:template_node",
  "branch": "general",
  "distance": 1,
  "angleOffset": 0,
  "type": "jutsu",
  "jutsuId": "shinobicore:example_jutsu",
  "effect": null,
  "value": 0,
  "spCost": 3,
  "requires": [],
  "icon": "?",
  "name": "Template Node",
  "description": "Example node for S0-04 schema",
  "clanRequired": null,
  "visibilityCondition": null,
  "requires_teacher": false,
  "requires_scroll": null,
  "position": [0, 0]
}
'@
Write-File "$res\skill_tree\_template_node.json" $template

# ================================================================
# SUMMARY & EXIT CODE
# ================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  S0-04 COMPLETE: OK=$ok SKIP=$skip ERR=$err" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Changes:" -ForegroundColor White
Write-Host "    - SkillTreeNode: +requiresTeacher, +requiresScroll, +position" -ForegroundColor White
Write-Host "    - SkillTreeRegistry: graph validation (cycles, broken links," -ForegroundColor White
Write-Host "      duplicates, missing spCost/icon, jutsu refs, forbidden check)" -ForegroundColor White
Write-Host "    - ShinobiCore: invalid nodes cannot be unlocked" -ForegroundColor White
Write-Host "    - SkillTreeScreen: red border + tooltip for invalid nodes" -ForegroundColor White
Write-Host "    - _template_node.json: schema reference" -ForegroundColor White
Write-Host ""

if ($err -gt 0) {
    Write-Host "  [ABORT] $err error(s) detected!" -ForegroundColor Red
    exit 1
}

Write-Host "  Next: .\gradlew.bat build" -ForegroundColor Yellow
Write-Host "  Then: sprint0_s05_json_loaders.ps1 (clans)" -ForegroundColor Yellow
exit 0
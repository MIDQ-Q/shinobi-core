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
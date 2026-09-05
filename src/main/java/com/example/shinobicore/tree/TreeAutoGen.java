package com.example.shinobicore.tree;

import com.example.shinobicore.jutsu.core.JutsuDefinition;
import com.example.shinobicore.jutsu.registry.JutsuRegistry;

import java.util.*;

/**
 * F2e: auto-generates skill tree nodes for every jutsu in JutsuRegistry.
 * Elemental jutsu -> element branch; others -> category branch.
 * Passives from tree.json stay; their requires are remapped to auto nodes.
 */
public final class TreeAutoGen {
    private TreeAutoGen() {}

    private static final Map<String, Integer> COLORS = new HashMap<>();
    static {
        COLORS.put("fire", 0xFFFF5533);
        COLORS.put("water", 0xFF4488FF);
        COLORS.put("wind", 0xFF88DDAA);
        COLORS.put("earth", 0xFFCC9955);
        COLORS.put("lightning", 0xFFFFEE44);
        COLORS.put("shape", 0xFF99CCFF);
        COLORS.put("general", 0xFFAAAAAA);
        COLORS.put("taijutsu", 0xFF66FF66);
        COLORS.put("kenjutsu", 0xFFFF9999);
        COLORS.put("medical", 0xFFFF88CC);
        COLORS.put("genjutsu", 0xFFCC66FF);
        COLORS.put("summon", 0xFFFFCC66);
        COLORS.put("sealing", 0xFF66CC99);
        COLORS.put("sensory", 0xFF66DDFF);
        COLORS.put("space", 0xFFCC99FF);
        COLORS.put("shuriken", 0xFFBBBBBB);
    }

    public static String autoId(String jutsuId) {
        return "auto_" + jutsuId.replace(':', '_').replace('.', '_');
    }

    private static String branchFor(JutsuDefinition def) {
        if (def.getElement() != null && !"none".equals(def.getElement().getId())) {
            return def.getElement().getId();
        }
        String cat = def.getCategory() == null ? "general" : def.getCategory();
        switch (cat) {
            case "shape_ninjutsu": return "shape";
            case "elemental_ninjutsu": return "general";
            case "summoning": case "summon": return "summon";
            case "space_time": return "space";
            case "taijutsu": case "kenjutsu": case "medical":
            case "genjutsu": case "sealing": case "sensory":
            case "shuriken": case "general": return cat;
            default: return "general";
        }
    }

    private static int rankValue(String rank) {
        if (rank == null) return 0;
        switch (rank.toUpperCase()) {
            case "S": return 5;
            case "A": return 4;
            case "B": return 3;
            case "C": return 2;
            case "D": return 1;
            default: return 0;
        }
    }

    private static int spByRank(String rank) {
        switch (rankValue(rank)) {
            case 5: return 9;
            case 4: return 6;
            case 3: return 4;
            case 1: return 2;
            default: return 3;
        }
    }

    public static void inject() {
        // 0) clear stale auto nodes (reload safety)
        for (SkillTreeNode n : new ArrayList<>(SkillTreeRegistry.getAll())) {
            if (n.id().startsWith("auto_")) SkillTreeRegistry.removeNode(n.id());
        }

        // 1) map old jutsu-type tree nodes -> jutsuId (for requires remap)
        Map<String, String> oldNodeToJutsu = new HashMap<>();
        for (SkillTreeNode n : SkillTreeRegistry.getAll()) {
            if ("jutsu".equals(n.type()) && n.jutsuId() != null && !n.id().startsWith("auto_")) {
                oldNodeToJutsu.put(n.id(), n.jutsuId());
            }
        }

        // 2) group jutsu by branch
        Map<String, List<JutsuDefinition>> byBranch = new LinkedHashMap<>();
        Map<String, String> jutsuToAuto = new HashMap<>();
        for (JutsuDefinition def : JutsuRegistry.getAll()) {
            byBranch.computeIfAbsent(branchFor(def), k -> new ArrayList<>()).add(def);
            jutsuToAuto.put(def.getId(), autoId(def.getId()));
        }

        // 3) ensure branch defs
        int angleIdx = 0;
        for (String b : byBranch.keySet()) {
            if (SkillTreeRegistry.getBranch(b) == null) {
                int color = COLORS.getOrDefault(b, 0xFFAAAAAA);
                String label = b.substring(0, 1).toUpperCase() + b.substring(1).replace('_', ' ');
                SkillTreeRegistry.putBranch(new SkillTreeRegistry.BranchDef(
                        b, angleIdx * 30f, color, label, null, false));
            }
            angleIdx++;
        }

        // 4) remap requires of existing passive nodes
        for (SkillTreeNode n : new ArrayList<>(SkillTreeRegistry.getAll())) {
            if (n.id().startsWith("auto_")) continue;
            boolean changed = false;
            List<String> newReq = new ArrayList<>();
            for (String r : n.requires()) {
                if (oldNodeToJutsu.containsKey(r)) {
                    String mapped = jutsuToAuto.get(oldNodeToJutsu.get(r));
                    if (mapped != null) newReq.add(mapped);
                    changed = true;
                } else {
                    if (SkillTreeRegistry.get(r) != null || jutsuToAuto.containsValue(r)) newReq.add(r);
                    else changed = true;
                }
            }
            if (changed) {
                SkillTreeRegistry.removeNode(n.id());
                SkillTreeRegistry.putNode(new SkillTreeNode(n.id(), n.branch(), n.distance(), n.angleOffset(),
                        n.type(), n.jutsuId(), n.effect(), n.value(), n.spCost(), newReq, n.icon(),
                        n.displayName(), n.description(), n.clanRequired(), n.visType(), n.visKey(), n.visValue()));
            }
        }

        // 5) create auto jutsu nodes, chained by rank
        for (Map.Entry<String, List<JutsuDefinition>> e : byBranch.entrySet()) {
            List<JutsuDefinition> list = e.getValue();
            list.sort(Comparator.comparingInt(a -> rankValue(a.getRank())));
            String prev = null;
            int dist = 1;
            for (JutsuDefinition def : list) {
                String id = autoId(def.getId());
                List<String> req = prev == null ? new ArrayList<>() : List.of(prev);
                String icon = (def.getElement() != null && !"none".equals(def.getElement().getId()))
                        ? def.getElement().getId().substring(0, 1).toUpperCase()
                        : String.valueOf(Character.toUpperCase(e.getKey().charAt(0)));
                SkillTreeRegistry.putNode(new SkillTreeNode(id, e.getKey(), dist, 0f, "jutsu",
                        def.getId(), null, 0f, spByRank(def.getRank()), req, icon,
                        def.getName(), def.getDescription() == null ? "" : def.getDescription(),
                        null, null, null, 0));
                prev = id;
                dist++;
            }
        }
    }
}
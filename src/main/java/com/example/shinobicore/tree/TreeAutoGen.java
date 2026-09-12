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
        // P3_BRANCH_FOR
        // Part 3: нестихийные школы попадают в СВОЮ ветку до проверки стихии.
        // Прежняя версия сначала смотрела на element, из-за чего техника
        // медицинской школы с element=yang уезжала в несуществующую ветку yang,
        // а гендзюцу с element=yin — в ветку yin.
        String cat = (def.getCategory() == null) ? "general" : def.getCategory();
        switch (cat) {
            case "summoning": case "summon": return "summon";
            case "space_time": return "space";
            case "taijutsu": case "kenjutsu": case "medical": case "genjutsu":
            case "sealing": case "sensory": case "shuriken": case "forbidden":
            case "kekkei": case "general":
                return cat;
            default: break;
        }
        // стихийные школы (elemental_ninjutsu, shape_ninjutsu, custom) — по стихии
        if (def.getElement() != null && !"none".equals(def.getElement().getId())) {
            return def.getElement().getId();
        }
        if ("shape_ninjutsu".equals(cat)) return "shape";
        return "general";
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

    /**
     * Part 3: отладочные техники не должны попадать в дерево игрока.
     * Файлы вида test_*.json остаются загруженными (их можно кастовать
     * командой /shinobicore jutsu cast), но узел для них не создаётся.
     */
    private static boolean isDevJutsu(String jutsuId) {
        if (jutsuId == null) return false;
        int c = jutsuId.indexOf(':');
        String path = (c >= 0) ? jutsuId.substring(c + 1) : jutsuId;
        return path.startsWith("test");
    }

    public static void inject() {
        // P3_MERGE_LAYER

        // 0) чистим устаревшие авто-узлы (безопасность при /reload)
        for (SkillTreeNode n : new ArrayList<>(SkillTreeRegistry.getAll())) {
            if (n.id().startsWith("auto_")) SkillTreeRegistry.removeNode(n.id());
        }

        // 1) снимаем МЕТАДАННЫЕ рукописных jutsu-узлов: jutsuId -> узел.
        //    Рукописный узел больше не определяет технику самостоятельно —
        //    он служит источником spCost / requires / clanRequired /
        //    visibilityCondition для единственного авто-узла этой техники.
        Map<String, SkillTreeNode> metaByJutsu = new HashMap<>();
        Map<String, String> oldNodeToJutsu = new HashMap<>();
        for (SkillTreeNode n : SkillTreeRegistry.getAll()) {
            if (n.id().startsWith("auto_")) continue;
            if ("jutsu".equals(n.type()) && n.jutsuId() != null) {
                metaByJutsu.put(n.jutsuId(), n);
                oldNodeToJutsu.put(n.id(), n.jutsuId());
            }
        }

        // 2) группируем техники по веткам (отладочные пропускаем)
        Map<String, List<JutsuDefinition>> byBranch = new LinkedHashMap<>();
        Map<String, String> jutsuToAuto = new HashMap<>();
        for (JutsuDefinition def : JutsuRegistry.getAll()) {
            if (isDevJutsu(def.getId())) continue;
            jutsuToAuto.put(def.getId(), autoId(def.getId()));
            // Part 3: ветку берём из рукописного узла, если он есть. Автор дерева
            // разместил технику осознанно (клановые ветки uchiha/hatake/hyuga/
            // nara/uzumaki/sarutobi, а также medical, genjutsu, forbidden, kekkei).
            // Чистый branchFor() ставит стихию выше категории и раскидал бы
            // Аматерасу в fire, гендзюцу в yin, медицину в yang, создав при этом
            // ветки yin/yang/shape, которых в tree.json нет — их углы
            // (angleIdx*30) наложились бы на уже существующие ветки.
            SkillTreeNode m = metaByJutsu.get(def.getId());
            String br = (m != null && m.branch() != null && !m.branch().isEmpty())
                    ? m.branch() : branchFor(def);
            byBranch.computeIfAbsent(br, k -> new ArrayList<>()).add(def);
        }

        // 3) гарантируем определения веток
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

        // 4) удаляем рукописные jutsu-узлы (метаданные уже сняты) и
        //    переназначаем requires у оставшихся пассивных узлов
        for (SkillTreeNode n : new ArrayList<>(SkillTreeRegistry.getAll())) {
            if (n.id().startsWith("auto_")) continue;
            if ("jutsu".equals(n.type()) && n.jutsuId() != null) {
                SkillTreeRegistry.removeNode(n.id());
                continue;
            }
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

        // 5) создаём авто-узлы цепочкой по рангам, наследуя рукописные метаданные
        for (Map.Entry<String, List<JutsuDefinition>> e : byBranch.entrySet()) {
            List<JutsuDefinition> list = e.getValue();
            list.sort(Comparator.comparingInt(a -> rankValue(a.getRank())));
            String prev = null;
            int dist = 1;
            for (JutsuDefinition def : list) {
                String id = autoId(def.getId());
                SkillTreeNode meta = metaByJutsu.get(def.getId());

                List<String> req = new ArrayList<>();
                if (meta != null) {
                    for (String r : meta.requires()) {
                        if (oldNodeToJutsu.containsKey(r)) {
                            String mapped = jutsuToAuto.get(oldNodeToJutsu.get(r));
                            if (mapped != null && !req.contains(mapped)) req.add(mapped);
                        } else if (SkillTreeRegistry.get(r) != null || jutsuToAuto.containsValue(r)) {
                            if (!req.contains(r)) req.add(r);
                        }
                    }
                }
                // Part 3: если у техники ЕСТЬ рукописный узел, его requires —
                // это воля автора дерева, даже когда список пуст. Цепочка по
                // рангам (prev) применяется ТОЛЬКО к техникам без рукописного
                // узла. Иначе автогенерация выдумывала prerequisite из чужой
                // ветки: Аматерасу требовал сначала купить Лава-Голема.
                if (meta == null && req.isEmpty() && prev != null) req.add(prev);

                String icon = (def.getElement() != null && !"none".equals(def.getElement().getId()))
                        ? def.getElement().getId().substring(0, 1).toUpperCase()
                        : String.valueOf(Character.toUpperCase(e.getKey().charAt(0)));
                if (meta != null && meta.icon() != null && !meta.icon().isEmpty()) icon = meta.icon();

                int sp    = (meta != null && meta.spCost() > 0)   ? meta.spCost()   : spByRank(def.getRank());
                int d     = (meta != null && meta.distance() > 0) ? meta.distance() : dist;
                float ao  = (meta != null) ? meta.angleOffset() : 0f;

                SkillTreeRegistry.putNode(new SkillTreeNode(id, e.getKey(), d, ao, "jutsu",
                        def.getId(), null, 0f, sp, req, icon,
                        def.getName(), def.getDescription() == null ? "" : def.getDescription(),
                        (meta != null) ? meta.clanRequired() : null,
                        (meta != null) ? meta.visType()      : null,
                        (meta != null) ? meta.visKey()       : null,
                        (meta != null) ? meta.visValue()     : 0));
                prev = id;
                dist++;
            }
        }
    }
}

package com.example.shinobicore.progression;

import java.util.ArrayList;
import java.util.List;

/** Shared skill-tree definition (client render + server validation). */
public final class SkillNodes {

    public static final class Node {
        public final String id;
        public final String name;
        public final String desc;
        public final int cost;
        public final String parent;
        public final double x;
        public final double y;
        public final int color;
        Node(String id, String name, String desc, int cost, String parent, double x, double y, int color) {
            this.id = id; this.name = name; this.desc = desc; this.cost = cost;
            this.parent = parent; this.x = x; this.y = y; this.color = color;
        }
    }

    public static final List<Node> NODES = new ArrayList<>();

    static {
        int root = 0xFFFFD7E6;
        int nin = 0xFFFF6B6B;
        int tai = 0xFF6BFF8A;
        int gen = 0xFFB06BFF;
        add("chakra_flow", "Chakra Flow", "Root: +5% chakra regen", 1, null, 0.50, 0.52, root);
        add("nin_core", "Ninjutsu Core", "Unlocks ninjutsu branch", 1, "chakra_flow", 0.30, 0.38, nin);
        add("tai_core", "Taijutsu Core", "Unlocks taijutsu branch", 1, "chakra_flow", 0.70, 0.38, tai);
        add("gen_core", "Genjutsu Core", "Unlocks genjutsu branch", 1, "chakra_flow", 0.50, 0.22, gen);
        add("fire_mastery", "Fire Mastery", "+10% fire jutsu damage", 2, "nin_core", 0.16, 0.28, nin);
        add("cost_reduction", "Efficient Control", "-5% chakra cost", 2, "nin_core", 0.16, 0.52, nin);
        add("meditation", "Meditation", "+1 chakra regen/sec", 2, "nin_core", 0.30, 0.68, nin);
        add("iron_fist", "Iron Fist", "+5% taijutsu damage (todo)", 2, "tai_core", 0.84, 0.28, tai);
        add("shunshin", "Shunshin", "+5% move speed (todo)", 2, "tai_core", 0.84, 0.52, tai);
        add("endurance_training", "Endurance", "-5% fatigue gain (todo)", 2, "tai_core", 0.70, 0.68, tai);
        add("gen_duration", "Lasting Illusion", "+10% genjutsu duration (todo)", 2, "gen_core", 0.50, 0.08, gen);
    }

    private static void add(String id, String name, String desc, int cost, String parent, double x, double y, int color) {
        NODES.add(new Node(id, name, desc, cost, parent, x, y, color));
    }

    public static Node byId(String id) {
        for (Node n : NODES) {
            if (n.id.equals(id)) return n;
        }
        return null;
    }

    private SkillNodes() {}
}
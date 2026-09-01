package com.example.shinobicore.tree;

import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.client.ClientNinjaStateHolder;

public class TreePassives {

    public static class Bonuses {
        public float fatigueReduction = 0f;
        public float affinityXpBonus = 0f;
        public float comboTimeoutBonus = 0f;
        public float autoParryChance = 0f;
        public boolean sensory = false;
        public int sensoryRadius = 0;
        public boolean dangerSense = false;
        public float fireWindSynergy = 0f;
        public float kekkeiFire = 0f;
        public float kekkeiEarth = 0f;
        public float kekkeiLightning = 0f;
        public float kekkeiRegen = 0f;
        public float kekkeiStun = 0f;
        public float genjutsuResist = 0f;
    }

    public static Bonuses collectServer(NinjaPlayerData data) {
        Bonuses b = new Bonuses();
        for (String nodeId : data.getUnlockedNodes()) apply(b, nodeId);
        return b;
    }

    public static Bonuses collectClient() {
        Bonuses b = new Bonuses();
        for (String nodeId : ClientNinjaStateHolder.get().getUnlockedNodes()) apply(b, nodeId);
        return b;
    }

    private static void apply(Bonuses b, String node) {
        switch (node) {
            case "gen_iron_will" -> b.fatigueReduction += 0.15f;
            case "gen_leaf_focus" -> b.affinityXpBonus += 0.25f;
            case "tai_combo_plus" -> b.comboTimeoutBonus += 0.5f;
            case "tai_counter" -> b.autoParryChance += 0.15f;
            case "sen_glow" -> { b.sensory = true; b.sensoryRadius = 20; }
            case "sen_danger" -> b.dangerSense = true;
            case "fire_synergy" -> b.fireWindSynergy += 0.15f;
            case "kg_blaze" -> b.kekkeiFire += 0.25f;
            case "kg_crystal" -> b.kekkeiEarth += 0.20f;
            case "kg_wood" -> b.kekkeiRegen += 0.30f;
            case "kg_shadow" -> b.kekkeiStun += 0.5f;
            case "kg_storm" -> b.kekkeiLightning += 0.25f;
            case "kg_lava" -> { b.kekkeiFire += 0.10f; b.kekkeiEarth += 0.10f; }
            case "gen_resist" -> b.genjutsuResist += 0.10f;
            default -> {}
        }
    }
}
// PHASE_B_GEN_PASSIVE_DONE
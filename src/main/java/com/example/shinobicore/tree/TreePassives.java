package com.example.shinobicore.tree;

import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.client.ClientNinjaStateHolder;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/**
 * H5: бонусы древа навыков с кэшем по версии.
 *
 * БЫЛО: collectServer(data) создавал новый Bonuses и перебирал ВСЕ unlocked-узлы
 * на каждый вызов. Вызывался из CombatPacketHandlers (на каждую атаку),
 * NinjaTickHandler (раз в секунду на игрока) и — до удаления в Part 1 —
 * из PlayerParryMixin на КАЖДЫЕй входящий урон. При 119 узлах это заметный
 * GC-мусор в горячем пути.
 *
 * СТАЛО: результат кэшируется и пересчитывается только когда NinjaPlayerData
 * увеличивает passivesVersion (покупка узла / сброс дерева / чтение NBT).
 */
public class TreePassives {

    public static class Bonuses {
        public float fatigueReduction = 0f;
        public float affinityXpBonus = 0f;
        public float comboTimeoutBonus = 0f;
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

    private static final Map<UUID, Bonuses> CACHE         = new HashMap<>();
    private static final Map<UUID, Integer> CACHE_VERSION = new HashMap<>();

    public static Bonuses collectServer(NinjaPlayerData data) {
        if (data == null) return new Bonuses();
        UUID uid = data.getOwnerId();
        if (uid == null) return computeFrom(data.getUnlockedNodes());

        int version = data.getPassivesVersion();
        Integer cached = CACHE_VERSION.get(uid);
        Bonuses b = CACHE.get(uid);
        if (b != null && cached != null && cached == version) return b;

        b = computeFrom(data.getUnlockedNodes());
        CACHE.put(uid, b);
        CACHE_VERSION.put(uid, version);
        return b;
    }

    public static Bonuses collectClient() {
        // Клиентская сторона остаётся без кэша: ClientNinjaStateHolder не имеет
        // версии, а вызовов там на порядок меньше (только рендер и HUD).
        return computeFrom(ClientNinjaStateHolder.get().getUnlockedNodes());
    }

    private static Bonuses computeFrom(Iterable<String> unlockedNodes) {
        Bonuses b = new Bonuses();
        if (unlockedNodes != null) {
            for (String nodeId : unlockedNodes) apply(b, nodeId);
        }
        return b;
    }

    /** H5: вызывать на ServerPlayConnectionEvents.DISCONNECT — иначе карты текут. */
    public static void removePlayer(UUID uid) {
        if (uid == null) return;
        CACHE.remove(uid);
        CACHE_VERSION.remove(uid);
    }

    public static void clearCache() {
        CACHE.clear();
        CACHE_VERSION.clear();
    }

    private static void apply(Bonuses b, String node) {
        switch (node) {
            case "gen_iron_will" -> b.fatigueReduction += 0.15f;
            case "gen_leaf_focus" -> b.affinityXpBonus += 0.25f;
            case "tai_combo_plus" -> b.comboTimeoutBonus += 0.5f;
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
package com.example.shinobicore.config;
import java.util.HashMap;
import java.util.Map;

import com.example.shinobicore.ShinobiCore;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import net.fabricmc.loader.api.FabricLoader;

import java.io.FileReader;
import java.io.FileWriter;
import java.nio.file.Files;
import java.nio.file.Path;

public class ModConfig {

    public static class Chakra {
        public float baseChakra = 100f;
        public float chakraPerReserveLevel = 12f;
        public float baseRegen = 1.0f;
        public float regenPerReserveLevel = 0.03f;
        public float regenPerControlLevel = 0.02f;
        public float regenHardFatigueMultiplier = 0.35f;
        public float regenExhaustedMultiplier = 0.2f;
    }

    public Parkour parkour = new Parkour();

    public static class Parkour {
        public float doubleJumpFatigue = 0.5f;
        public float wallJumpFatigue = 0.5f;
        public float vaultFatigue = 0.3f;
        
        // Slide
        public float slideFatigue = 0.3f;
        
        // Wall Run (для шага C)
        public float wallRunFatiguePerTick = 0.02f;
        public int wallRunMaxTicks = 40;
        
        // Edge Grab (для шага D)
        public float edgeGrabFatigue = 0.5f;
        
        // Roll (для шага F)
        public float rollFatigue = 1.0f;
        
        // Charged Jump (для шага E)
        public float chargedJumpFatiguePerCharge = 2.0f;

        public float dodgeFatigue = 2.0f;
    }
    
    public static class Fatigue {
        public float decayPerSecond = 2.0f;
        public float softThreshold = 50f;
        public float hardThreshold = 70f;
        public float costPenaltyMax = 1.0f;
    }

    public static class Taijutsu {
        public float baseDamage = 2.0f;
        public float damagePerLevel = 0.3f;
        public float chakraModeDamageMult = 1.5f;
        public float chakraModeSpeedMult = 1.3f;
        public int strongFistUnlockLevel = 50;
        public double range = 3.0;
        public double coneAngle = 120.0;
    }

    public Taijutsu taijutsu = new Taijutsu();

    public static class Meditation {
        public float regenMultiplier = 4.0f;
        public float fatigueDecayMultiplier = 2.0f;
        public int reserveXpPerSecond = 2;
        public int controlXpPerSecond = 1;
        public int slownessBase = 3;
        public float slownessControlReduction = 2.5f;
    }

    public static class Progression {
        public int xpBase = 100;
        public int xpPerLevel = 25;
        public int xpSquared = 5;
        public int spPerLevelUp = 1;
        public int spBaseCost = 1;
        public int spExtraCostEvery10 = 1;
        public int maxXpPerMinute = 500;
        public int maxUsagePerMinute = 10;
    }

    public static class Combat {
        public float masteryUsageWeight = 0.25f;
        public float masteryStatWeight = 0.75f;
        public float damageBaseMultiplier = 0.6f;
        public float damageMasteryScale = 0.8f;
        public float costControlReductionMax = 0.20f;
        public float costNatureReductionMax = 0.15f;
        public float affinityCostMultiplier = 0.85f;
        public float affinityDamageMultiplier = 1.10f;
        public float affinityXpMultiplier = 1.25f;
        public float costMasteryReductionMax = 0.25f;
        public Map<String, Map<String, Float>> categoryWeights = defaultCategoryWeights();
    }

    public static class Hud {
        public int x = 10;
        public int y = 10;
        public int width = 180;
        public int height = 14;
    }

    public Chakra chakra = new Chakra();
    public Fatigue fatigue = new Fatigue();
    public Meditation meditation = new Meditation();
    public Progression progression = new Progression();
    public Combat combat = new Combat();
    public Hud hud = new Hud();

    public static ModConfig instance = new ModConfig();
    private static final Gson GSON = new GsonBuilder().setPrettyPrinting().create();

    public static Path path() {
        return FabricLoader.getInstance().getConfigDir().resolve("shinobicore").resolve("main.json");
    }

    public static void load() {
        try {
            Path p = path();
            if (!Files.exists(p)) {
                Files.createDirectories(p.getParent());
                instance = new ModConfig();
                save();
            } else {
                try (FileReader reader = new FileReader(p.toFile())) {
                    ModConfig loaded = GSON.fromJson(reader, ModConfig.class);
                    if (loaded != null) instance = loaded;
                }
                save(); // дописываем в файл новые поля с дефолтами
            }
            ShinobiCore.LOGGER.info("Config loaded from {}", path());
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("Failed to load config, using defaults", e);
            instance = new ModConfig();
        }
    }

    public static void save() {
        try (FileWriter writer = new FileWriter(path().toFile())) {
            GSON.toJson(instance, writer);
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("Failed to save config", e);
        }
    }
        private static Map<String, Map<String, Float>> defaultCategoryWeights() {
        Map<String, Map<String, Float>> w = new HashMap<>();

        Map<String, Float> elemental = new HashMap<>();
        elemental.put("nature", 0.40f);
        elemental.put("control", 0.25f);
        elemental.put("ninjutsu", 0.25f);
        elemental.put("reserve", 0.10f);
        w.put("elemental_ninjutsu", elemental);

        Map<String, Float> shape = new HashMap<>();
        shape.put("control", 0.45f);
        shape.put("ninjutsu", 0.30f);
        shape.put("reserve", 0.15f);
        shape.put("perception", 0.10f);
        w.put("shape_ninjutsu", shape);

        Map<String, Float> tai = new HashMap<>();
        tai.put("taijutsu", 0.55f);
        tai.put("control", 0.20f);
        tai.put("reserve", 0.15f);
        tai.put("space_time", 0.10f);
        w.put("taijutsu", tai);

        Map<String, Float> gen = new HashMap<>();
        gen.put("genjutsu", 0.45f);
        gen.put("control", 0.25f);
        gen.put("perception", 0.20f);
        gen.put("reserve", 0.10f);
        w.put("genjutsu", gen);

        Map<String, Float> med = new HashMap<>();
        med.put("medical", 0.40f);
        med.put("control", 0.35f);
        med.put("reserve", 0.15f);
        med.put("perception", 0.10f);
        w.put("medical", med);

        Map<String, Float> space = new HashMap<>();
        space.put("space_time", 0.45f);
        space.put("control", 0.30f);
        space.put("reserve", 0.15f);
        space.put("ninjutsu", 0.10f);
        w.put("space_time", space);

        Map<String, Float> sensory = new HashMap<>();
        sensory.put("perception", 0.50f);
        sensory.put("control", 0.25f);
        sensory.put("genjutsu", 0.15f);
        sensory.put("reserve", 0.10f);
        w.put("sensory", sensory);

        return w;
    }
}
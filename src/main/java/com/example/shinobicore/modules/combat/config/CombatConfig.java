package com.example.shinobicore.modules.combat.config;

import com.google.gson.JsonObject;
import com.example.shinobicore.core.log.ShinobiLogger;

public final class CombatConfig {
    private static CombatConfig INSTANCE = new CombatConfig();
    
    public boolean enabled = true;
    public boolean debug = false;
    
    public BlockConfig block = new BlockConfig();
    public ParryConfig parry = new ParryConfig();
    public KickConfig kick = new KickConfig();
    public ThrownConfig thrown = new ThrownConfig();
    public SheathConfig sheath = new SheathConfig();
    public QuickSlotConfig quickSlot = new QuickSlotConfig();
    public ComboConfig combo = new ComboConfig();
    public UnarmedConfig unarmed = new UnarmedConfig();
    public ImbueConfig imbue = new ImbueConfig();

    public static CombatConfig get() { return INSTANCE; }

    public static void load(JsonObject json) {
        if (json == null) {
            ShinobiLogger.module("combat", "Config is null, using defaults");
            return;
        }
        try {
            if (json.has("enabled")) INSTANCE.enabled = json.get("enabled").getAsBoolean();
            if (json.has("debug")) INSTANCE.debug = json.get("debug").getAsBoolean();
            
            if (json.has("block") && json.get("block").isJsonObject()) {
                JsonObject b = json.getAsJsonObject("block");
                if (b.has("drainPerSecond")) INSTANCE.block.drainPerSecond = b.get("drainPerSecond").getAsDouble();
                if (b.has("damageReductionMultiplier")) INSTANCE.block.damageReductionMultiplier = b.get("damageReductionMultiplier").getAsFloat();
            }
            if (json.has("parry") && json.get("parry").isJsonObject()) {
                JsonObject p = json.getAsJsonObject("parry");
                if (p.has("baseWindowMs")) INSTANCE.parry.baseWindowMs = p.get("baseWindowMs").getAsLong();
                if (p.has("failRecoveryMs")) INSTANCE.parry.failRecoveryMs = p.get("failRecoveryMs").getAsLong();
                if (p.has("successChakraGain")) INSTANCE.parry.successChakraGain = p.get("successChakraGain").getAsFloat();
            }
            if (json.has("kick") && json.get("kick").isJsonObject()) {
                JsonObject k = json.getAsJsonObject("kick");
                if (k.has("baseDamage")) INSTANCE.kick.baseDamage = k.get("baseDamage").getAsFloat();
                if (k.has("taijutsuPerLevel")) INSTANCE.kick.taijutsuPerLevel = k.get("taijutsuPerLevel").getAsFloat();
                if (k.has("staminaCost")) INSTANCE.kick.staminaCost = k.get("staminaCost").getAsFloat();
                if (k.has("knockbackStrength")) INSTANCE.kick.knockbackStrength = k.get("knockbackStrength").getAsDouble();
            }
            if (json.has("thrown") && json.get("thrown").isJsonObject()) {
                JsonObject t = json.getAsJsonObject("thrown");
                if (t.has("perceptionSpreadReductionPerLevel")) INSTANCE.thrown.perceptionSpreadReductionPerLevel = t.get("perceptionSpreadReductionPerLevel").getAsFloat();
                if (t.has("speed")) INSTANCE.thrown.speed = t.get("speed").getAsDouble();
            }
            if (json.has("unarmed") && json.get("unarmed").isJsonObject()) {
                JsonObject u = json.getAsJsonObject("unarmed");
                if (u.has("baseDamage")) INSTANCE.unarmed.baseDamage = u.get("baseDamage").getAsFloat();
                if (u.has("taijutsuDamagePerLevel")) INSTANCE.unarmed.taijutsuDamagePerLevel = u.get("taijutsuDamagePerLevel").getAsFloat();
            }
            ShinobiLogger.module("combat", "Config loaded successfully");
        } catch (Exception e) {
            ShinobiLogger.error("combat", "Failed to parse config, using defaults", e);
        }
    }

    public static class BlockConfig {
        public double drainPerSecond = 5.0;
        public float damageReductionMultiplier = 0.4f;
    }
    public static class ParryConfig {
        public long baseWindowMs = 250;
        public long failRecoveryMs = 800;
        public float successChakraGain = 5.0f;
    }
    public static class KickConfig {
        public boolean enabled = true;
        public float baseDamage = 4.0f;
        public float taijutsuPerLevel = 0.05f;
        public float staminaCost = 8.0f;
        public double knockbackStrength = 0.6;
    }
    public static class ThrownConfig {
        public float perceptionSpreadReductionPerLevel = 0.01f;
        public double speed = 1.8;
    }
    public static class SheathConfig {
        public boolean enabled = true;
        public float quickDrawDamageBonusMultiplier = 1.3f;
    }
    public static class QuickSlotConfig {
        public boolean enabled = true;
    }
    public static class ComboConfig {
        public long timeoutMs = 1500;
    }
    public static class UnarmedConfig {
        public boolean enabled = true;
        public float baseDamage = 1.0f;
        public float taijutsuDamagePerLevel = 0.05f;
    }
    public static class ImbueConfig {
        public boolean enabled = true;
        public boolean allowedOnThrowables = true;
    }
}
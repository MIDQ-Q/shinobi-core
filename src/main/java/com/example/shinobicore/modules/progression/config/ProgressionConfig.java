package com.example.shinobicore.modules.progression.config;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.google.gson.JsonObject;

public final class ProgressionConfig {
    private static ProgressionConfig INSTANCE = new ProgressionConfig();

    public final XpConfig xp = new XpConfig();
    public final SpConfig sp = new SpConfig();
    public final JutsuConfig jutsu = new JutsuConfig();
    public final AttunementConfig attunement = new AttunementConfig();
    public final ReputationConfig reputation = new ReputationConfig();

    public static ProgressionConfig get() { return INSTANCE; }

    public void load(JsonObject root) {
        if (root == null) {
            ShinobiLogger.module("progression", "Config null, using defaults");
            return;
        }
        loadXp(root);
        loadSp(root);
        loadJutsu(root);
        loadAttunement(root);
        loadReputation(root);
        ShinobiLogger.module("progression", "Config loaded");
    }

    private void loadXp(JsonObject root) {
        if (!root.has("xp")) return;
        JsonObject sec = root.getAsJsonObject("xp");
        if (sec.has("baseXp")) xp.baseXp = sec.get("baseXp").getAsInt();
        if (sec.has("exponent")) xp.exponent = sec.get("exponent").getAsDouble();
        if (sec.has("xpPerCast")) xp.xpPerCast = sec.get("xpPerCast").getAsInt();
        if (sec.has("xpPerDamage")) xp.xpPerDamage = sec.get("xpPerDamage").getAsDouble();
        if (sec.has("xpPerKill")) xp.xpPerKill = sec.get("xpPerKill").getAsInt();
        if (sec.has("xpPerMeleeHit")) xp.xpPerMeleeHit = sec.get("xpPerMeleeHit").getAsInt();
        if (sec.has("xpPerMeleeKill")) xp.xpPerMeleeKill = sec.get("xpPerMeleeKill").getAsInt();
    }

    private void loadSp(JsonObject root) {
        if (!root.has("sp")) return;
        JsonObject sec = root.getAsJsonObject("sp");
        if (sec.has("spPerLevelUp")) sp.spPerLevelUp = sec.get("spPerLevelUp").getAsInt();
        if (sec.has("baseSpCostPerStat")) sp.baseSpCostPerStat = sec.get("baseSpCostPerStat").getAsInt();
        if (sec.has("spCostIncrementPerLevel")) sp.spCostIncrementPerLevel = sec.get("spCostIncrementPerLevel").getAsDouble();
        if (sec.has("maxStatLevel")) sp.maxStatLevel = sec.get("maxStatLevel").getAsInt();
        if (sec.has("maxBodyStatLevel")) sp.maxBodyStatLevel = sec.get("maxBodyStatLevel").getAsInt();
    }

    private void loadJutsu(JsonObject root) {
        if (!root.has("jutsu")) return;
        JsonObject sec = root.getAsJsonObject("jutsu");
        if (sec.has("maxLevel")) jutsu.maxLevel = sec.get("maxLevel").getAsInt();
        if (sec.has("baseJutsuXp")) jutsu.baseJutsuXp = sec.get("baseJutsuXp").getAsInt();
        if (sec.has("jutsuXpExponent")) jutsu.jutsuXpExponent = sec.get("jutsuXpExponent").getAsDouble();
        if (sec.has("xpPerUse")) jutsu.xpPerUse = sec.get("xpPerUse").getAsInt();
        if (sec.has("xpPerDamage")) jutsu.xpPerDamage = sec.get("xpPerDamage").getAsFloat();
        if (sec.has("xpPerKill")) jutsu.xpPerKill = sec.get("xpPerKill").getAsInt();
    }

    private void loadAttunement(JsonObject root) {
        if (!root.has("attunement")) return;
        JsonObject sec = root.getAsJsonObject("attunement");
        if (sec.has("baseAttunementSp")) attunement.baseAttunementSp = sec.get("baseAttunementSp").getAsInt();
        if (sec.has("spCostIncrement")) attunement.spCostIncrement = sec.get("spCostIncrement").getAsInt();
        if (sec.has("baseControlRequired")) attunement.baseControlRequired = sec.get("baseControlRequired").getAsInt();
        if (sec.has("controlIncrement")) attunement.controlIncrement = sec.get("controlIncrement").getAsInt();
        if (sec.has("freeAffinityCount")) attunement.freeAffinityCount = sec.get("freeAffinityCount").getAsInt();
        if (sec.has("successWindowBase")) attunement.successWindowBase = sec.get("successWindowBase").getAsFloat();
        if (sec.has("successWindowDecrement")) attunement.successWindowDecrement = sec.get("successWindowDecrement").getAsFloat();
        if (sec.has("minSuccessWindow")) attunement.minSuccessWindow = sec.get("minSuccessWindow").getAsFloat();
    }

    private void loadReputation(JsonObject root) {
        if (!root.has("reputation")) return;
        JsonObject sec = root.getAsJsonObject("reputation");
        if (sec.has("enabled")) reputation.enabled = sec.get("enabled").getAsBoolean();
        if (sec.has("maxReputation")) reputation.maxReputation = sec.get("maxReputation").getAsInt();
        if (sec.has("minReputation")) reputation.minReputation = sec.get("minReputation").getAsInt();
    }

    public static class XpConfig {
        public int baseXp = 100;
        public double exponent = 1.5;
        public int xpPerCast = 5;
        public double xpPerDamage = 0.5;
        public int xpPerKill = 50;
        public int xpPerMeleeHit = 1;
        public int xpPerMeleeKill = 20;
    }

    public static class SpConfig {
        public int spPerLevelUp = 1;
        public int baseSpCostPerStat = 1;
        public double spCostIncrementPerLevel = 0.1;
        public int maxStatLevel = 100;
        public int maxBodyStatLevel = 100;
    }

    public static class JutsuConfig {
        public int maxLevel = 10;
        public int baseJutsuXp = 50;
        public double jutsuXpExponent = 1.3;
        public int xpPerUse = 5;
        public float xpPerDamage = 0.3f;
        public int xpPerKill = 30;
    }

    public static class AttunementConfig {
        public int baseAttunementSp = 5;
        public int spCostIncrement = 3;
        public int baseControlRequired = 5;
        public int controlIncrement = 5;
        public int freeAffinityCount = 1;
        public float successWindowBase = 0.15f;
        public float successWindowDecrement = 0.02f;
        public float minSuccessWindow = 0.05f;
    }

    public static class ReputationConfig {
        public boolean enabled = true;
        public int maxReputation = 1000;
        public int minReputation = -1000;
    }
}
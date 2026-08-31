package com.example.shinobicore.modules.jutsu.config;

import com.google.gson.JsonObject;

public final class JutsuConfig {
    private static JutsuConfig INSTANCE;

    public final boolean enabled;
    public final boolean debug;
    public final int slotCount;
    public final int castQueueSize;
    public final float interruptOnDamageChance;
    public final boolean interruptOnMovement;
    public final float partialRefundOnCancel;
    public final int minCooldownTicks;
    public final int maxJutsuLevel;

    private JutsuConfig(JsonObject json) {
        this.enabled = getBool(json, "enabled", true);
        this.debug = getBool(json, "debug", false);
        
        JsonObject slots = getObj(json, "slots");
        this.slotCount = getInt(slots, "count", 3);
        
        JsonObject cast = getObj(json, "cast");
        this.castQueueSize = getInt(cast, "queueSize", 1);
        this.interruptOnDamageChance = getFloat(cast, "interruptOnDamageChance", 0.5f);
        this.interruptOnMovement = getBool(cast, "interruptOnMovement", true);
        this.partialRefundOnCancel = getFloat(cast, "partialRefundOnCancel", 0.3f);
        
        JsonObject cooldown = getObj(json, "cooldown");
        this.minCooldownTicks = getInt(cooldown, "minCooldownTicks", 1);
        
        JsonObject levels = getObj(json, "levels");
        this.maxJutsuLevel = getInt(levels, "maxLevel", 10);
    }

    public static void load(JsonObject json) {
        INSTANCE = new JutsuConfig(json);
    }

    public static JutsuConfig get() {
        if (INSTANCE == null) load(new JsonObject()); // Fallback to defaults
        return INSTANCE;
    }

    private static boolean getBool(JsonObject o, String k, boolean def) { return o != null && o.has(k) ? o.get(k).getAsBoolean() : def; }
    private static int getInt(JsonObject o, String k, int def) { return o != null && o.has(k) ? o.get(k).getAsInt() : def; }
    private static float getFloat(JsonObject o, String k, float def) { return o != null && o.has(k) ? o.get(k).getAsFloat() : def; }
    private static JsonObject getObj(JsonObject o, String k) { return o != null && o.has(k) ? o.getAsJsonObject(k) : new JsonObject(); }
}
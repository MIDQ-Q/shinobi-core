package com.example.shinobicore.modules.movement.config;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.google.gson.JsonObject;

public final class MovementConfig {
    public static boolean ENABLED = true;
    public static boolean DEBUG = false;
    
    public static double WATER_WALK_DRAIN = 1.5;
    public static double WATER_WALK_SURFACE_OFFSET = 0.05;
    
    public static double WALL_RUN_DRAIN = 1.5;
    public static double WALL_RUN_GRAVITY_MULT = 0.3;
    public static int WALL_RUN_COOLDOWN = 20;
    
    public static double WALL_JUMP_PUSH = 0.6;
    public static double WALL_JUMP_UP = 0.45;
    public static int WALL_JUMP_COOLDOWN = 20;
    
    public static int SLIDE_DURATION = 20;
    public static double SLIDE_FRICTION = 0.92;
    
    public static int ROLL_DURATION = 12;
    public static int ROLL_IFRAMES = 8;
    public static int ROLL_COOLDOWN = 40;
    public static double ROLL_DISTANCE = 3.0;
    
    public static double DODGE_STRENGTH = 3.2;
    public static int DODGE_IFRAMES = 4;
    public static int DODGE_COOLDOWN = 30;
    public static double DODGE_CHAKRA_COST = 2.0;
    
    public static double DOUBLE_JUMP_BOOST = 0.42;
    public static int DOUBLE_JUMP_MAX_CHARGES = 1;
    public static double DOUBLE_JUMP_CHAKRA_COST = 1.0;
    
    public static int CHARGED_JUMP_CHARGE_TICKS = 30;
    public static float CHARGED_JUMP_MAX_MULT = 2.5f;
    public static double CHARGED_JUMP_CHAKRA_COST = 3.0;
    
    public static double EDGE_GRAB_REACH = 0.6;
    public static double EDGE_GRAB_CHAKRA_COST = 1.0;
    public static double EDGE_GRAB_CLIMB_BOOST = 1.0;

    public static boolean NARUTO_RUN_ENABLED = true;
    public static float NARUTO_RUN_MIN_SPEED = 0.18f;
    
    private MovementConfig() {}

    public static void load(JsonObject json) {
        if (json == null || json.size() == 0) {
            ShinobiLogger.module("movement", "Config empty or missing, using defaults.");
            return;
        }
        try {
            ENABLED = json.has("enabled") ? json.get("enabled").getAsBoolean() : true;
            DEBUG = json.has("debug") ? json.get("debug").getAsBoolean() : false;
            
            if (json.has("waterWalk")) {
                JsonObject ww = json.getAsJsonObject("waterWalk");
                WATER_WALK_DRAIN = ww.has("drainPerSecond") ? ww.get("drainPerSecond").getAsDouble() : 1.5;
                WATER_WALK_SURFACE_OFFSET = ww.has("surfaceOffset") ? ww.get("surfaceOffset").getAsDouble() : 0.05;
            }
            if (json.has("wallRun")) {
                JsonObject wr = json.getAsJsonObject("wallRun");
                WALL_RUN_DRAIN = wr.has("drainPerSecond") ? wr.get("drainPerSecond").getAsDouble() : 1.5;
                WALL_RUN_GRAVITY_MULT = wr.has("gravityMultiplier") ? wr.get("gravityMultiplier").getAsDouble() : 0.3;
                WALL_RUN_COOLDOWN = wr.has("stickCooldownTicks") ? wr.get("stickCooldownTicks").getAsInt() : 20;
            }
            if (json.has("wallJump")) {
                JsonObject wj = json.getAsJsonObject("wallJump");
                WALL_JUMP_PUSH = wj.has("pushStrength") ? wj.get("pushStrength").getAsDouble() : 0.6;
                WALL_JUMP_UP = wj.has("upBoost") ? wj.get("upBoost").getAsDouble() : 0.45;
                WALL_JUMP_COOLDOWN = wj.has("cooldownTicks") ? wj.get("cooldownTicks").getAsInt() : 20;
            }
            if (json.has("slide")) {
                JsonObject s = json.getAsJsonObject("slide");
                SLIDE_DURATION = s.has("durationTicks") ? s.get("durationTicks").getAsInt() : 20;
                SLIDE_FRICTION = s.has("friction") ? s.get("friction").getAsDouble() : 0.92;
            }
            if (json.has("roll")) {
                JsonObject r = json.getAsJsonObject("roll");
                ROLL_DURATION = r.has("durationTicks") ? r.get("durationTicks").getAsInt() : 12;
                ROLL_IFRAMES = r.has("iframeTicks") ? r.get("iframeTicks").getAsInt() : 8;
                ROLL_COOLDOWN = r.has("cooldownTicks") ? r.get("cooldownTicks").getAsInt() : 40;
                ROLL_DISTANCE = r.has("distance") ? r.get("distance").getAsDouble() : 3.0;
            }
            if (json.has("dodge")) {
                JsonObject d = json.getAsJsonObject("dodge");
                DODGE_STRENGTH = d.has("strength") ? d.get("strength").getAsDouble() : 3.2;
                DODGE_IFRAMES = d.has("iframeTicks") ? d.get("iframeTicks").getAsInt() : 4;
                DODGE_COOLDOWN = d.has("cooldownTicks") ? d.get("cooldownTicks").getAsInt() : 30;
                DODGE_CHAKRA_COST = d.has("chakraCost") ? d.get("chakraCost").getAsDouble() : 2.0;
            }
            if (json.has("doubleJump")) {
                JsonObject dj = json.getAsJsonObject("doubleJump");
                DOUBLE_JUMP_BOOST = dj.has("boost") ? dj.get("boost").getAsDouble() : 0.42;
                DOUBLE_JUMP_MAX_CHARGES = dj.has("maxCharges") ? dj.get("maxCharges").getAsInt() : 1;
            }
            if (json.has("chargedJump")) {
                JsonObject cj = json.getAsJsonObject("chargedJump");
                CHARGED_JUMP_CHARGE_TICKS = cj.has("chargeTicks") ? cj.get("chargeTicks").getAsInt() : 30;
                CHARGED_JUMP_MAX_MULT = cj.has("maxMultiplier") ? cj.get("maxMultiplier").getAsFloat() : 2.5f;
                CHARGED_JUMP_CHAKRA_COST = cj.has("chakraCost") ? cj.get("chakraCost").getAsDouble() : 3.0;
            }
            if (json.has("edgeGrab")) {
                JsonObject eg = json.getAsJsonObject("edgeGrab");
                EDGE_GRAB_REACH = eg.has("reachDistance") ? eg.get("reachDistance").getAsDouble() : 0.6;
                EDGE_GRAB_CHAKRA_COST = eg.has("chakraCost") ? eg.get("chakraCost").getAsDouble() : 1.0;
                EDGE_GRAB_CLIMB_BOOST = eg.has("climbBoost") ? eg.get("climbBoost").getAsDouble() : 1.0;
            }
            if (json.has("narutoRun")) {
                JsonObject nr = json.getAsJsonObject("narutoRun");
                NARUTO_RUN_ENABLED = nr.has("enabled") ? nr.get("enabled").getAsBoolean() : true;
                NARUTO_RUN_MIN_SPEED = nr.has("minSprintSpeed") ? nr.get("minSprintSpeed").getAsFloat() : 0.18f;
            }
        } catch (Exception e) {
            ShinobiLogger.error("movement", "Failed to parse config, using defaults.", e);
        }
    }
}
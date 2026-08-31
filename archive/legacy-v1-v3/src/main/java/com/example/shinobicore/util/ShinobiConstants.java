package com.example.shinobicore.util;

public final class ShinobiConstants {
    private ShinobiConstants() {}

    public static final String MOD_ID = "shinobicore";

    public static final float BASE_MAX_CHAKRA = 2000.0f;
    public static final float CHAKRA_REGEN_PER_SEC = 2.0f;
    public static final float CHAKRA_MODE_DRAIN_PER_SEC = 5.0f;
    public static final float WATER_WALK_DRAIN_PER_TICK = 0.05f;
    public static final float WALL_WALK_DRAIN_PER_TICK = 0.075f;

    public static final float DOUBLE_JUMP_Y_VELOCITY = 0.95f;
    public static final int JUMPS_PER_RESET = 3;
    public static final float DASH_STRENGTH = 1.6f;
    public static final int DODGE_COOLDOWN_TICKS = 30;
    public static final int DODGE_IFRAME_TICKS = 8;
    public static final int SLIDE_DURATION_TICKS = 15;
    public static final int SLIDE_CHAKRA_DURATION_TICKS = 25;

    public static final float BLOCK_DAMAGE_REDUCTION = 0.6f;
    public static final float BLOCK_STAMINA_COST_PER_HIT = 10.0f;

    public static final int MAX_STAT_LEVEL = 100;
    public static final int XP_BASE = 100;
    // SPRINT A: New multiplicative XP formula: base * (1 + level*factor + levelВІ*squared)
    public static final float XP_FACTOR = 0.1f;
    public static final float XP_SQUARED_FACTOR = 0.05f;
    public static final int SP_PER_LEVEL_UP = 1;
    public static final int STARTING_STAT_LEVEL = 1;
    // Attunement
    public static final int ATTUNEMENT_SP_COST = 15;
    public static final int ATTUNEMENT_ELEMENT_COUNT_MIN = 1;
    public static final int ATTUNEMENT_ELEMENT_COUNT_MAX = 2;

    public static final double WORLD_BORDER_SIZE = 48000.0;
    public static final int VILLAGE_SPACING = 20;
}
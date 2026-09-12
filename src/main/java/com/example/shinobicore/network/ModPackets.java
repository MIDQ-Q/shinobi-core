package com.example.shinobicore.network;
import com.example.shinobicore.network.handlers.*;


import net.minecraft.util.Identifier;

/**
 * Packet ID constants only.
 * All handlers are registered in dedicated handler classes:
 * - ChakraPacketHandlers
 * - CombatPacketHandlers
 * - LoadoutPacketHandlers
 * - MovementPacketHandlers
 * - ProgressionPacketHandlers
 * - SensoryPacketHandlers
 */
public final class ModPackets {
    private ModPackets() {}

    // Chakra
    public static final Identifier CHAKRA_SYNC_ID = new Identifier("shinobicore", "chakra_sync");
    public static final Identifier MEDITATE_ID = new Identifier("shinobicore", "meditate");
    public static final Identifier CHAKRA_MODE_ID = new Identifier("shinobicore", "chakra_mode");

    // Loadout
    public static final Identifier SELECT_SLOT_ID = new Identifier("shinobicore", "select_slot");
    public static final Identifier CAST_SLOT_ID = new Identifier("shinobicore", "cast_slot");
    public static final Identifier SET_SLOT_ID = new Identifier("shinobicore", "set_slot");
    public static final Identifier LOADOUT_SYNC_ID = new Identifier("shinobicore", "loadout_sync");
    public static final Identifier CATALOG_SYNC_ID = new Identifier("shinobicore", "catalog_sync");

    // Stats & Progression
    public static final Identifier STATS_SYNC_ID = new Identifier("shinobicore", "stats_sync");
    public static final Identifier BODY_SYNC_ID = new Identifier("shinobicore", "body_sync");
    public static final Identifier SPEND_SP_ID = new Identifier("shinobicore", "spend_sp");
    public static final Identifier TREE_SYNC_ID = new Identifier("shinobicore", "tree_sync");
    public static final Identifier UNLOCK_NODE_ID = new Identifier("shinobicore", "unlock_node");
    public static final Identifier ATTUNEMENT_ID = new Identifier("shinobicore", "attunement");
    public static final Identifier CONTROL_TRAIN_ID = new Identifier("shinobicore", "control_train");

    // Combat
    public static final Identifier TAIJUTSU_ATTACK_ID = new Identifier("shinobicore", "taijutsu_attack");
    public static final Identifier TAIJUTSU_KICK_ID = new Identifier("shinobicore", "taijutsu_kick");
    public static final Identifier TAIJUTSU_STYLE_ID = new Identifier("shinobicore", "taijutsu_style");
    public static final Identifier KATANA_ATTACK_ID = new Identifier("shinobicore", "katana_attack");
    public static final Identifier KATANA_STANCE_ID = new Identifier("shinobicore", "katana_stance");
    public static final Identifier KATANA_DEFLECT_ID = new Identifier("shinobicore", "katana_deflect");
    public static final Identifier COMBO_SYNC_ID = new Identifier("shinobicore", "combo_sync");
    /** P1-5: отдельный канал синхронизации комбо катаны (своя машина состояний). */
    public static final Identifier KATANA_COMBO_SYNC_ID = new Identifier("shinobicore", "katana_combo_sync");
    public static final Identifier HIT_STOP_ID = new Identifier("shinobicore", "hit_stop");

    // Movement
    public static final Identifier DODGE_ID = new Identifier("shinobicore", "dodge");
    public static final Identifier POSE_SYNC_ID = new Identifier("shinobicore", "pose_sync");
    public static final Identifier PARKOUR_ACTION_ID = new Identifier("shinobicore", "parkour_action");

    // Sensory
    public static final Identifier SENSORY_TOGGLE_ID = new Identifier("shinobicore", "sensory_toggle");
    public static final Identifier RASENGAN_STRIKE_ID = new Identifier("shinobicore", "rasengan_strike");
    public static final Identifier RASENGAN_SYNC_ID = new Identifier("shinobicore", "rasengan_sync");
    public static final Identifier DANGER_SYNC_ID = new Identifier("shinobicore", "danger_sync");

    // Casting
    public static final Identifier CAST_FX_ID = new Identifier("shinobicore", "cast_fx");
    public static final Identifier CAST_START_ID = new Identifier("shinobicore", "cast_start");
    public static final Identifier CAST_INTERRUPT_ID = new Identifier("shinobicore", "cast_interrupt");

    // Cooldown
    public static final Identifier COOLDOWN_SYNC_ID = new Identifier("shinobicore", "cooldown_sync");

    // Combat Pack v1 (1.1.4): боевой раж
    public static final Identifier FRENZY_SYNC_ID = new Identifier("shinobicore", "frenzy_sync");

    /**
     * Called from ShinobiCore.onInitialize() to register all handler classes.
     * Each handler registers its own packets — no duplicates.
     */
    public static void register() {
        ChakraPacketHandlers.register();
        CombatPacketHandlers.register();
        LoadoutPacketHandlers.register();
        MovementPacketHandlers.register();
        ProgressionPacketHandlers.register();
        SensoryPacketHandlers.register();
    }
}
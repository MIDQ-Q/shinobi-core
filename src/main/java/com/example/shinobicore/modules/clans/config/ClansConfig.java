package com.example.shinobicore.modules.clans.config;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.google.gson.JsonObject;
public final class ClansConfig {
    public static boolean ENABLED = true;
    public static boolean DEBUG = false;
    public static boolean ALLOW_OPERATOR_CHANGE = true;
    public static boolean ALLOW_PLAYER_CHANGE = false;
    public static boolean RANDOM_ASSIGN_ON_JOIN = false;
    public static boolean RESET_REPUTATION_ON_CHANGE = true;
    public static boolean REMOVE_CLAN_JUTSU_ON_CHANGE = true;
    public static boolean RESET_DOJUTSU_ON_CHANGE = true;
    public static boolean REPUTATION_ENABLED = true;
    public static int MAX_REPUTATION = 1000;
    public static int MIN_REPUTATION = -1000;
    public static int DEFAULT_REPUTATION = 0;
    public static boolean LOG_CLAN_CHANGES = true;
    public static boolean LOG_REPUTATION_CHANGES = false;
    public static boolean LOG_JUTSU_LOCKS = true;

    public static void load(JsonObject config) {
        if (config == null) return;
        try {
            if (config.has("debug")) DEBUG = config.get("debug").getAsBoolean();
            if (config.has("selection")) {
                JsonObject sel = config.getAsJsonObject("selection");
                if (sel.has("allowOperatorChange")) ALLOW_OPERATOR_CHANGE = sel.get("allowOperatorChange").getAsBoolean();
                if (sel.has("allowPlayerChange")) ALLOW_PLAYER_CHANGE = sel.get("allowPlayerChange").getAsBoolean();
                if (sel.has("randomAssignOnJoin")) RANDOM_ASSIGN_ON_JOIN = sel.get("randomAssignOnJoin").getAsBoolean();
            }
            if (config.has("change")) {
                JsonObject ch = config.getAsJsonObject("change");
                if (ch.has("resetReputationOnChange")) RESET_REPUTATION_ON_CHANGE = ch.get("resetReputationOnChange").getAsBoolean();
                if (ch.has("removeClanJutsuOnChange")) REMOVE_CLAN_JUTSU_ON_CHANGE = ch.get("removeClanJutsuOnChange").getAsBoolean();
                if (ch.has("resetDojutsuOnChange")) RESET_DOJUTSU_ON_CHANGE = ch.get("resetDojutsuOnChange").getAsBoolean();
            }
            if (config.has("reputation")) {
                JsonObject rep = config.getAsJsonObject("reputation");
                if (rep.has("enabled")) REPUTATION_ENABLED = rep.get("enabled").getAsBoolean();
                if (rep.has("maxReputation")) MAX_REPUTATION = rep.get("maxReputation").getAsInt();
                if (rep.has("minReputation")) MIN_REPUTATION = rep.get("minReputation").getAsInt();
                if (rep.has("defaultReputation")) DEFAULT_REPUTATION = rep.get("defaultReputation").getAsInt();
            }
            if (config.has("logging")) {
                JsonObject log = config.getAsJsonObject("logging");
                if (log.has("logClanChanges")) LOG_CLAN_CHANGES = log.get("logClanChanges").getAsBoolean();
                if (log.has("logReputationChanges")) LOG_REPUTATION_CHANGES = log.get("logReputationChanges").getAsBoolean();
                if (log.has("logJutsuLocks")) LOG_JUTSU_LOCKS = log.get("logJutsuLocks").getAsBoolean();
            }
            ShinobiLogger.module("clans", "Config loaded successfully.");
        } catch (Exception e) {
            ShinobiLogger.error("clans", "Failed to parse config, using defaults.", e);
        }
    }
}
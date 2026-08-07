package com.example.shinobicore.client;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

public class ClientNinjaState {
    public static final String[] loadoutA = new String[5];
    public static final String[] loadoutB = new String[5];
    public static int activeA = 0;
    public static int activeB = 0;

    public static final Map<String, String> catalog = new HashMap<>(); // id -> name
    public static final Set<String> learned = new HashSet<>();

    public static int skillPoints = 0;
    public static int reserveLevel = 1;
    public static int reserveXp = 0;
    public static final Map<String, Integer> statLevels = new HashMap<>();
    public static final Map<String, Integer> statXp = new HashMap<>();
    public static final Map<String, Integer> natureLevels = new HashMap<>();
    public static final Map<String, Integer> natureXp = new HashMap<>();
    public static final Map<String, Boolean> natureUnlocked = new HashMap<>();

    public static int hpLevel = 0;
    public static int speedLevel = 0;
    public static int jumpLevel = 0;
    public static boolean chakraMode = false;
    public static String clanId = "none";
    public static String affinityId = null;

    public static String[] loadout(int set) { return set == 0 ? loadoutA : loadoutB; }
    public static int active(int set) { return set == 0 ? activeA : activeB; }
    public static String activeJutsuId(int set) { return loadout(set)[active(set)]; }

    public static String name(String id) {
        if (id == null) return "";
        return catalog.getOrDefault(id, id);
    }
}
package com.example.shinobicore.client;

import java.util.HashMap;
import java.util.Map;

public class ClientNinjaState {
    public static final String[] loadout = new String[5];
    public static int activeSlot = 0;

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

    public static String activeJutsuId() {
        return loadout[activeSlot];
    }
}
package com.example.shinobicore.client;

/**
 * COMPATIBILITY DELEGATE.
 * All access goes through ClientNinjaStateHolder.
 * This class will be removed in a future sprint.
 * DO NOT add new fields here.
 */
public class ClientNinjaState {
    private static final ClientNinjaStateHolder H = ClientNinjaStateHolder.get();

    // === Fields via getters/setters ===
    public static boolean chakraMode() { return H.isChakraMode(); }
    public static void setChakraMode(boolean v) { H.setChakraMode(v); }
    public static boolean dangerSense() { return H.isDangerSense(); }
    public static void setDangerSense(boolean v) { H.setDangerSense(v); }
    public static boolean sensoryEnabled() { return H.isSensoryEnabled(); }
    public static void setSensoryEnabled(boolean v) { H.setSensoryEnabled(v); }
    public static boolean meditating() { return H.isMeditating(); }
    public static void setMeditating(boolean v) { H.setMeditating(v); }
    public static String kenjutsuStance() { return H.getKenjutsuStance(); }
    public static void setKenjutsuStance(String v) { H.setKenjutsuStance(v); }
    public static boolean deflectHeld() { return H.isDeflectHeld(); }
    public static void setDeflectHeld(boolean v) { H.setDeflectHeld(v); }
    public static String clanId() { return H.getClanId(); }
    public static void setClanId(String v) { H.setClanId(v); }
    public static String affinityId() { return H.getAffinityId(); }
    public static void setAffinityId(String v) { H.setAffinityId(v); }
    public static int skillPoints() { return H.getSkillPoints(); }
    public static void setSkillPoints(int v) { H.setSkillPoints(v); }
    public static int reserveLevel() { return H.getReserveLevel(); }
    public static void setReserveLevel(int v) { H.setReserveLevel(v); }
    public static int reserveXp() { return H.getReserveXp(); }
    public static void setReserveXp(int v) { H.setReserveXp(v); }
    public static int hpLevel() { return H.getHpLevel(); }
    public static void setHpLevel(int v) { H.setHpLevel(v); }
    public static int speedLevel() { return H.getSpeedLevel(); }
    public static void setSpeedLevel(int v) { H.setSpeedLevel(v); }
    public static int jumpLevel() { return H.getJumpLevel(); }
    public static void setJumpLevel(int v) { H.setJumpLevel(v); }

    // === Collection access ===
    public static java.util.Map<String, Integer> statLevels() { return H.getStatLevels(); }
    public static java.util.Map<String, Integer> statXp() { return H.getStatXp(); }
    public static java.util.Map<String, Integer> natureLevels() { return H.getNatureLevels(); }
    public static java.util.Map<String, Integer> natureXp() { return H.getNatureXp(); }
    public static java.util.Map<String, Boolean> natureUnlocked() { return H.getNatureUnlocked(); }
    public static java.util.Map<String, String> catalog() { return H.getCatalog(); }
    public static java.util.Set<String> learned() { return H.getLearned(); }
    public static java.util.Set<String> unlockedNodes() { return H.getUnlockedNodes(); }

    // === Methods ===
    public static String[] loadout(int set) { return H.getLoadout(set); }
    public static int active(int set) { return H.getActive(set); }
    public static String activeJutsuId(int set) { return H.getActiveJutsuId(set); }
    public static String name(String id) { return H.getName(id); }
    public static void cycleLoadout(int set) { H.cycleLoadout(set); }
    public static void castActiveJutsu(int set) { H.castActiveJutsu(set); }
}
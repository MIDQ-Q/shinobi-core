package com.example.shinobicore.stat;

import net.minecraft.nbt.NbtCompound;
import net.minecraft.nbt.NbtList;
import net.minecraft.nbt.NbtString;

import java.util.EnumMap;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

public class NinjaPlayerData {
    public static final int MAX_LEVEL = 100;

    private float currentChakra = 100f;
    private int reserveLevel = 1;
    private int reserveXp = 0;
    private float fatigue = 0f;
    private boolean exhausted = false;
    private boolean meditating = false;

    private final EnumMap<StatType, Integer> statLevels = new EnumMap<>(StatType.class);
    private final EnumMap<StatType, Integer> statXp = new EnumMap<>(StatType.class);
    private final EnumMap<ElementType, Integer> natureLevels = new EnumMap<>(ElementType.class);
    private final EnumMap<ElementType, Integer> natureXp = new EnumMap<>(ElementType.class);
    private final EnumMap<ElementType, Boolean> natureUnlocked = new EnumMap<>(ElementType.class);

    private ElementType affinity = null;
    private ClanType clan = ClanType.NONE;
    private boolean clanChosen = false;
    private int skillPoints = 0;

    private int hpLevel = 0;
    private int speedLevel = 0;
    private int jumpLevel = 0;
    private boolean chakraMode = false;

    // ДВА лоаута по 5 слотов
    private final String[] loadoutA = new String[5];
    private final String[] loadoutB = new String[5];
    private int activeSlotA = 0;
    private int activeSlotB = 0;

    private final Set<String> learnedJutsus = new HashSet<>();
    private final Map<String, Integer> jutsuUsage = new HashMap<>();

    // Анти-абуз (не сохраняется)
    private final Map<String, Integer> xpBudget = new HashMap<>();
    private long xpWindowStart = System.currentTimeMillis();

    // Для event-синхронизации (не сохраняется)
    private boolean statsDirty = true;
    private boolean wasOnGround = true;

    public NinjaPlayerData() {
        for (StatType s : StatType.values()) { statLevels.put(s, 0); statXp.put(s, 0); }
        for (ElementType e : ElementType.values()) { natureLevels.put(e, 0); natureXp.put(e, 0); natureUnlocked.put(e, false); }
    }

    // === Геттеры ===
    public float getCurrentChakra() { return currentChakra; }
    public int getReserveLevel() { return reserveLevel; }
    public int getReserveXp() { return reserveXp; }
    public float getFatigue() { return fatigue; }
    public boolean isExhausted() { return exhausted; }
    public boolean isMeditating() { return meditating; }
    public ClanType getClan() { return clan; }
    public ElementType getAffinity() { return affinity; }
    public boolean isClanChosen() { return clanChosen; }
    public int getSkillPoints() { return skillPoints; }
    public int getHpLevel() { return hpLevel; }
    public int getSpeedLevel() { return speedLevel; }
    public int getJumpLevel() { return jumpLevel; }
    public boolean isChakraMode() { return chakraMode; }
    public boolean wasOnGround() { return wasOnGround; }
    public Set<String> getLearnedJutsus() { return learnedJutsus; }

    public int getStatLevel(StatType s) { return statLevels.getOrDefault(s, 0); }
    public int getStatXp(StatType s) { return statXp.getOrDefault(s, 0); }
    public int getNatureLevel(ElementType e) { return natureLevels.getOrDefault(e, 0); }
    public int getNatureXp(ElementType e) { return natureXp.getOrDefault(e, 0); }
    public boolean isNatureUnlocked(ElementType e) { return natureUnlocked.getOrDefault(e, false); }
    public int getJutsuUsage(String id) { return jutsuUsage.getOrDefault(id, 0); }

    public String getLoadoutSlot(int set, int i) { return (set == 0 ? loadoutA : loadoutB)[i]; }
    public int getActiveSlot(int set) { return set == 0 ? activeSlotA : activeSlotB; }

    // === Сеттеры ===
    public void setCurrentChakra(float v) { this.currentChakra = Math.max(0, Math.min(v, NinjaFormula.maxChakra(this))); }
    public void setReserveLevel(int v) { reserveLevel = Math.max(1, Math.min(v, MAX_LEVEL)); statsDirty = true; }
    public void setReserveXp(int v) { reserveXp = Math.max(0, v); statsDirty = true; }
    public void setFatigue(float v) { this.fatigue = Math.max(0, Math.min(v, 100f)); this.exhausted = this.fatigue >= 100f; }
    public void setMeditating(boolean v) { this.meditating = v; }
    public void setClan(ClanType c) { this.clan = c; statsDirty = true; }
    public void setAffinity(ElementType e) { this.affinity = e; statsDirty = true; }
    public void setClanChosen(boolean v) { this.clanChosen = v; }
    public void addSkillPoints(int n) { this.skillPoints = Math.max(0, this.skillPoints + n); statsDirty = true; }
    public void setHpLevel(int v) { hpLevel = Math.max(0, Math.min(v, 7)); statsDirty = true; }
    public void setSpeedLevel(int v) { speedLevel = Math.max(0, Math.min(v, 7)); statsDirty = true; }
    public void setJumpLevel(int v) { jumpLevel = Math.max(0, Math.min(v, 7)); statsDirty = true; }
    public void setChakraMode(boolean v) { this.chakraMode = v; }
    public void setWasOnGround(boolean v) { this.wasOnGround = v; }

    public void setStatLevel(StatType s, int v) { statLevels.put(s, Math.max(0, Math.min(v, MAX_LEVEL))); statsDirty = true; }
    public void setStatXp(StatType s, int v) { statXp.put(s, Math.max(0, v)); statsDirty = true; }
    public void setNatureLevel(ElementType e, int v) { natureLevels.put(e, Math.max(0, Math.min(v, MAX_LEVEL))); statsDirty = true; }
    public void setNatureXp(ElementType e, int v) { natureXp.put(e, Math.max(0, v)); statsDirty = true; }
    public void setNatureUnlocked(ElementType e, boolean v) { natureUnlocked.put(e, v); statsDirty = true; }

    public void addJutsuUsage(String id, int n) { jutsuUsage.put(id, getJutsuUsage(id) + n); statsDirty = true; }

    public void learnJutsu(String id) { learnedJutsus.add(id); statsDirty = true; }

    public void setLoadoutSlot(int set, int i, String id) { (set == 0 ? loadoutA : loadoutB)[i] = id; }
    public void setActiveSlot(int set, int s) { if (set == 0) activeSlotA = Math.max(0, Math.min(4, s)); else activeSlotB = Math.max(0, Math.min(4, s)); }

    public boolean consumeStatsDirty() { boolean d = statsDirty; statsDirty = false; return d; }

    // === Анти-абуз ===
    public boolean tryConsumeXpBudget(String key, int amount, int cap) {
        long now = System.currentTimeMillis();
        if (now - xpWindowStart > 60_000L) { xpBudget.clear(); xpWindowStart = now; }
        int used = xpBudget.getOrDefault(key, 0);
        if (used + amount > cap) return false;
        xpBudget.put(key, used + amount);
        return true;
    }

    // === NBT ===
    public NbtCompound writeNbt() {
        NbtCompound nbt = new NbtCompound();
        nbt.putFloat("Chakra", currentChakra);
        nbt.putInt("ReserveLevel", reserveLevel);
        nbt.putInt("ReserveXp", reserveXp);
        nbt.putFloat("Fatigue", fatigue);
        nbt.putBoolean("Exhausted", exhausted);
        nbt.putBoolean("Meditating", meditating);
        nbt.putString("Clan", clan.getId());
        nbt.putBoolean("ClanChosen", clanChosen);
        nbt.putInt("SkillPoints", skillPoints);
        nbt.putInt("HpLevel", hpLevel);
        nbt.putInt("SpeedLevel", speedLevel);
        nbt.putInt("JumpLevel", jumpLevel);
        nbt.putBoolean("ChakraMode", chakraMode);
        if (affinity != null) nbt.putString("Affinity", affinity.getId());

        NbtCompound stats = new NbtCompound();
        for (StatType s : StatType.values()) {
            NbtCompound c = new NbtCompound();
            c.putInt("Level", statLevels.get(s)); c.putInt("Xp", statXp.get(s));
            stats.put(s.getId(), c);
        }
        nbt.put("Stats", stats);

        NbtCompound natures = new NbtCompound();
        for (ElementType e : ElementType.values()) {
            NbtCompound c = new NbtCompound();
            c.putInt("Level", natureLevels.get(e)); c.putInt("Xp", natureXp.get(e)); c.putBoolean("Unlocked", natureUnlocked.get(e));
            natures.put(e.getId(), c);
        }
        nbt.put("Natures", natures);

        NbtList learned = new NbtList();
        for (String id : learnedJutsus) learned.add(NbtString.of(id));
        nbt.put("LearnedJutsus", learned);

        NbtCompound usage = new NbtCompound();
        for (Map.Entry<String, Integer> en : jutsuUsage.entrySet()) usage.putInt(en.getKey(), en.getValue());
        nbt.put("JutsuUsage", usage);

        nbt.put("LoadoutA", writeLoadout(loadoutA));
        nbt.put("LoadoutB", writeLoadout(loadoutB));
        nbt.putInt("ActiveSlotA", activeSlotA);
        nbt.putInt("ActiveSlotB", activeSlotB);
        return nbt;
    }

    private NbtList writeLoadout(String[] arr) {
        NbtList list = new NbtList();
        for (String s : arr) list.add(NbtString.of(s == null ? "" : s));
        return list;
    }

    private void readLoadout(NbtList list, String[] arr) {
        for (int i = 0; i < 5 && i < list.size(); i++) {
            String s = list.getString(i);
            arr[i] = s.isEmpty() ? null : s;
        }
    }

    public void readNbt(NbtCompound nbt) {
        if (nbt == null) return;
        currentChakra = nbt.getFloat("Chakra");
        reserveLevel = Math.max(1, nbt.getInt("ReserveLevel"));
        reserveXp = nbt.getInt("ReserveXp");
        fatigue = nbt.getFloat("Fatigue");
        exhausted = nbt.getBoolean("Exhausted");
        meditating = nbt.getBoolean("Meditating");
        String clanId = nbt.getString("Clan");
        for (ClanType c : ClanType.values()) if (c.getId().equals(clanId)) { clan = c; break; }
        clanChosen = nbt.getBoolean("ClanChosen");
        skillPoints = nbt.getInt("SkillPoints");
        hpLevel = nbt.getInt("HpLevel");
        speedLevel = nbt.getInt("SpeedLevel");
        jumpLevel = nbt.getInt("JumpLevel");
        chakraMode = nbt.getBoolean("ChakraMode");
        if (nbt.contains("Affinity")) {
            String a = nbt.getString("Affinity");
            for (ElementType e : ElementType.values()) if (e.getId().equals(a)) { affinity = e; break; }
        }
        if (nbt.contains("Stats")) {
            NbtCompound stats = nbt.getCompound("Stats");
            for (StatType s : StatType.values()) if (stats.contains(s.getId())) {
                NbtCompound c = stats.getCompound(s.getId());
                statLevels.put(s, c.getInt("Level")); statXp.put(s, c.getInt("Xp"));
            }
        }
        if (nbt.contains("Natures")) {
            NbtCompound nat = nbt.getCompound("Natures");
            for (ElementType e : ElementType.values()) if (nat.contains(e.getId())) {
                NbtCompound c = nat.getCompound(e.getId());
                natureLevels.put(e, c.getInt("Level")); natureXp.put(e, c.getInt("Xp")); natureUnlocked.put(e, c.getBoolean("Unlocked"));
            }
        }
        if (nbt.contains("LearnedJutsus")) {
            NbtList list = nbt.getList("LearnedJutsus", 8);
            for (int i = 0; i < list.size(); i++) learnedJutsus.add(list.getString(i));
        }
        if (nbt.contains("JutsuUsage")) {
            NbtCompound u = nbt.getCompound("JutsuUsage");
            for (String k : u.getKeys()) jutsuUsage.put(k, u.getInt(k));
        }
        if (nbt.contains("LoadoutA")) readLoadout(nbt.getList("LoadoutA", 8), loadoutA);
        else if (nbt.contains("Loadout")) readLoadout(nbt.getList("Loadout", 8), loadoutA); // миграция со старой версии
        if (nbt.contains("LoadoutB")) readLoadout(nbt.getList("LoadoutB", 8), loadoutB);
        activeSlotA = nbt.getInt("ActiveSlotA");
        activeSlotB = nbt.getInt("ActiveSlotB");
    }
}
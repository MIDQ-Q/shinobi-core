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

    // Чакра
    private float currentChakra = 100f;
    private int reserveLevel = 1;
    private int reserveXp = 0;
    private float fatigue = 0f;
    private boolean exhausted = false;
    private boolean meditating = false;

    // Основные статы
    private final EnumMap<StatType, Integer> statLevels = new EnumMap<>(StatType.class);
    private final EnumMap<StatType, Integer> statXp = new EnumMap<>(StatType.class);

    // Стихии
    private final EnumMap<ElementType, Integer> natureLevels = new EnumMap<>(ElementType.class);
    private final EnumMap<ElementType, Integer> natureXp = new EnumMap<>(ElementType.class);
    private final EnumMap<ElementType, Boolean> natureUnlocked = new EnumMap<>(ElementType.class);

    // Прочее
    private ElementType affinity = null;
    private ClanType clan = ClanType.NONE;
    private boolean clanChosen = false;
    private int skillPoints = 0;
    private int hpLevel = 0;
    private int speedLevel = 0;
    private int jumpLevel = 0;
    private boolean chakraMode = false;
    private boolean wasOnGround = true; // для детекции начала прыжка
    // Дзюцу
    private final Set<String> learnedJutsus = new HashSet<>();
    private final Map<String, Integer> jutsuUsage = new HashMap<>();
    private final String[] loadout = new String[5];
    private int activeSlot = 0;

    // === Анти-абуз (не сохраняется в NBT) ===
    private final Map<String, Integer> xpBudget = new HashMap<>();
    private long xpWindowStart = System.currentTimeMillis();

    public NinjaPlayerData() {
        for (StatType stat : StatType.values()) {
            statLevels.put(stat, 0);
            statXp.put(stat, 0);
        }
        for (ElementType element : ElementType.values()) {
            natureLevels.put(element, 0);
            natureXp.put(element, 0);
            natureUnlocked.put(element, false);
        }
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
    public boolean wasOnGround() { return wasOnGround; }
    public void setWasOnGround(boolean value) { this.wasOnGround = value; }
    public int getHpLevel() { return hpLevel; }
    public int getSpeedLevel() { return speedLevel; }
    public int getJumpLevel() { return jumpLevel; }
    public boolean isChakraMode() { return chakraMode; }
    
    public void setHpLevel(int level) { this.hpLevel = Math.max(0, Math.min(level, 7)); }
    public void setSpeedLevel(int level) { this.speedLevel = Math.max(0, Math.min(level, 7)); }
    public void setJumpLevel(int level) { this.jumpLevel = Math.max(0, Math.min(level, 7)); }
    public void setChakraMode(boolean value) { this.chakraMode = value; }

    public void addSkillPoints(int amount) {
        this.skillPoints = Math.max(0, this.skillPoints + amount);
    }
    public int getStatLevel(StatType stat) {
        return statLevels.getOrDefault(stat, 0);
    }

    public int getStatXp(StatType stat) {
        return statXp.getOrDefault(stat, 0);
    }

    public int getNatureLevel(ElementType element) {
        return natureLevels.getOrDefault(element, 0);
    }

    public int getNatureXp(ElementType element) {
        return natureXp.getOrDefault(element, 0);
    }

    public boolean isNatureUnlocked(ElementType element) {
        return natureUnlocked.getOrDefault(element, false);
    }

    public Set<String> getLearnedJutsus() { return learnedJutsus; }

    public int getJutsuUsage(String id) {
        return jutsuUsage.getOrDefault(id, 0);
    }

    public String getLoadoutSlot(int i) { return loadout[i]; }
    public int getActiveSlot() { return activeSlot; }

    // === Сеттеры ===
    public void setCurrentChakra(float value) {
        this.currentChakra = Math.max(0, Math.min(value, com.example.shinobicore.stat.NinjaFormula.maxChakra(this)));
    }

    public void setReserveLevel(int level) {
        this.reserveLevel = Math.max(1, Math.min(level, MAX_LEVEL));
    }

    public void setReserveXp(int xp) {
        this.reserveXp = Math.max(0, xp);
    }

    public void setFatigue(float value) {
        this.fatigue = Math.max(0, Math.min(value, 100f));
        this.exhausted = this.fatigue >= 100f;
    }

    public void setMeditating(boolean value) {
        this.meditating = value;
    }

    public void setClan(ClanType clan) {
        this.clan = clan;
    }

    public void setAffinity(ElementType affinity) {
        this.affinity = affinity;
    }

    public void setClanChosen(boolean value) {
        this.clanChosen = value;
    }

    public void setStatLevel(StatType stat, int level) {
        statLevels.put(stat, Math.max(0, Math.min(level, MAX_LEVEL)));
    }

    public void setStatXp(StatType stat, int xp) {
        statXp.put(stat, Math.max(0, xp));
    }

    public void setNatureLevel(ElementType element, int level) {
        natureLevels.put(element, Math.max(0, Math.min(level, MAX_LEVEL)));
    }

    public void setNatureXp(ElementType element, int xp) {
        natureXp.put(element, Math.max(0, xp));
    }

    public void setNatureUnlocked(ElementType element, boolean unlocked) {
        natureUnlocked.put(element, unlocked);
    }

    public void addJutsuUsage(String id, int amount) {
        jutsuUsage.put(id, getJutsuUsage(id) + amount);
    }

    public void setLoadoutSlot(int i, String id) { loadout[i] = id; }
    public void setActiveSlot(int s) { this.activeSlot = Math.max(0, Math.min(4, s)); }

    // === Анти-абуз ===
    public boolean tryConsumeXpBudget(String key, int amount, int cap) {
        long now = System.currentTimeMillis();
        if (now - xpWindowStart > 60_000L) {
            xpBudget.clear();
            xpWindowStart = now;
        }
        int used = xpBudget.getOrDefault(key, 0);
        if (used + amount > cap) return false;
        xpBudget.put(key, used + amount);
        return true;
    }

    // === NBT (сохранение/загрузка) ===
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
        for (StatType stat : StatType.values()) {
            NbtCompound statNbt = new NbtCompound();
            statNbt.putInt("Level", statLevels.get(stat));
            statNbt.putInt("Xp", statXp.get(stat));
            stats.put(stat.getId(), statNbt);
        }
        nbt.put("Stats", stats);

        NbtCompound natures = new NbtCompound();
        for (ElementType element : ElementType.values()) {
            NbtCompound natNbt = new NbtCompound();
            natNbt.putInt("Level", natureLevels.get(element));
            natNbt.putInt("Xp", natureXp.get(element));
            natNbt.putBoolean("Unlocked", natureUnlocked.get(element));
            natures.put(element.getId(), natNbt);
        }
        nbt.put("Natures", natures);

        NbtList learnedList = new NbtList();
        for (String id : learnedJutsus) {
            learnedList.add(NbtString.of(id));
        }
        nbt.put("LearnedJutsus", learnedList);

        NbtCompound usageNbt = new NbtCompound();
        for (Map.Entry<String, Integer> entry : jutsuUsage.entrySet()) {
            usageNbt.putInt(entry.getKey(), entry.getValue());
        }
        nbt.put("JutsuUsage", usageNbt);

        NbtList loadoutList = new NbtList();
        for (String s : loadout) {
            loadoutList.add(NbtString.of(s == null ? "" : s));
        }
        nbt.put("Loadout", loadoutList);
        nbt.putInt("ActiveSlot", activeSlot);

        return nbt;
    }

    public void readNbt(NbtCompound nbt) {
        if (nbt == null) return;
        currentChakra = nbt.getFloat("Chakra");
        reserveLevel = nbt.getInt("ReserveLevel");
        if (reserveLevel < 1) reserveLevel = 1;
        reserveXp = nbt.getInt("ReserveXp");
        fatigue = nbt.getFloat("Fatigue");
        exhausted = nbt.getBoolean("Exhausted");
        meditating = nbt.getBoolean("Meditating");
        skillPoints = nbt.getInt("SkillPoints");
        hpLevel = nbt.getInt("HpLevel");
        speedLevel = nbt.getInt("SpeedLevel");
        jumpLevel = nbt.getInt("JumpLevel");
        chakraMode = nbt.getBoolean("ChakraMode");
        String clanId = nbt.getString("Clan");
        for (ClanType c : ClanType.values()) {
            if (c.getId().equals(clanId)) { clan = c; break; }
        }
        clanChosen = nbt.getBoolean("ClanChosen");

        if (nbt.contains("Affinity")) {
            String affId = nbt.getString("Affinity");
            for (ElementType e : ElementType.values()) {
                if (e.getId().equals(affId)) { affinity = e; break; }
            }
        }

        if (nbt.contains("Stats")) {
            NbtCompound stats = nbt.getCompound("Stats");
            for (StatType stat : StatType.values()) {
                if (stats.contains(stat.getId())) {
                    NbtCompound statNbt = stats.getCompound(stat.getId());
                    statLevels.put(stat, statNbt.getInt("Level"));
                    statXp.put(stat, statNbt.getInt("Xp"));
                }
            }
        }

        if (nbt.contains("Natures")) {
            NbtCompound natures = nbt.getCompound("Natures");
            for (ElementType element : ElementType.values()) {
                if (natures.contains(element.getId())) {
                    NbtCompound natNbt = natures.getCompound(element.getId());
                    natureLevels.put(element, natNbt.getInt("Level"));
                    natureXp.put(element, natNbt.getInt("Xp"));
                    natureUnlocked.put(element, natNbt.getBoolean("Unlocked"));
                }
            }
        }

        if (nbt.contains("LearnedJutsus")) {
            NbtList learnedList = nbt.getList("LearnedJutsus", 8); // 8 = String type
            for (int i = 0; i < learnedList.size(); i++) {
                learnedJutsus.add(learnedList.getString(i));
            }
        }
        if (nbt.contains("JutsuUsage")) {
            NbtCompound usageNbt = nbt.getCompound("JutsuUsage");
            for (String key : usageNbt.getKeys()) {
                jutsuUsage.put(key, usageNbt.getInt(key));
            }
        }

        if (nbt.contains("Loadout")) {
            NbtList list = nbt.getList("Loadout", 8);
            for (int i = 0; i < 5 && i < list.size(); i++) {
                String s = list.getString(i);
                loadout[i] = s.isEmpty() ? null : s;
            }
        }
        activeSlot = nbt.getInt("ActiveSlot");
    }
}
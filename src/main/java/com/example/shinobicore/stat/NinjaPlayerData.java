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

    private float currentChakra = 2000f;
    private float currentStamina = 100f;
    private float maxStamina = 100f;
    private float modeBuffer = 0f;
    private boolean isBlocking = false;
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
    // === РАСЕНГАН: состояние зарядки ===
    private boolean rasenganCharging = false;
    private int rasenganChargeTicks = 0;
    private int rasenganChargeTarget = 300; // 15 сек по умолчанию
    private boolean rasenganReady = false;
    private int rasenganReadyTicks = 0;
    private boolean lastDangerState = false;
    private com.example.shinobicore.dojutsu.SharinganComponent sharinganComponent = new com.example.shinobicore.dojutsu.SharinganComponent();
    private com.example.shinobicore.sensory.SensoryComponent sensoryComponent = new com.example.shinobicore.sensory.SensoryComponent();
    // === S1-08: PASSIVE DRIFT ===
    private int passiveXpToday = 0;
    private long lastPassiveDay = 0;
    private long lastPassiveXpTimeMs = 0;
    private final Map<Integer, Long> tierCooldowns = new HashMap<>();
    private final Set<String> teacherApprovedNodes = new HashSet<>();
    private String clanId = "none";
    private boolean clanChosen = false;

    private final Map<String, Integer> appliedClanStatBonuses = new HashMap<>();
    private final Map<String, Integer> appliedClanNatureBonuses = new HashMap<>();

    private int skillPoints = 0;
    private int hpLevel = 0;
    private int speedLevel = 0;
    private int jumpLevel = 0;
    private boolean chakraMode = false;
    private String activeDojutsu = null;
    private boolean sensoryEnabled = true;

    // === НОВОЕ: серверное состояние тай-дзюцу ===
    private int serverComboStep = 0;
    private long lastAttackTimeMs = 0;
    private String currentStyleId = "standard";
    private int katanaComboStep = 0;
    private long katanaLastAttackMs = 0;
    private String katanaStanceId = "aggressive";
    private long katanaDeflectUntil = 0;
    private boolean katanaDeflectHeld = false;
    private long lastDeflectReflectMs = 0;
    // === PHASE3: Chakra-melee integration ===
    private int chakraComboCounter = 0;
    private long lastChakraHitMs = 0;

    private final String[] loadoutA = new String[5];
    private final String[] loadoutB = new String[5];
    private int activeSlotA = 0;
    private int activeSlotB = 0;
    private final Set<String> learnedJutsus = new HashSet<>();
    private final Map<String, Integer> jutsuUsage = new HashMap<>();

    private final Map<String, Integer> xpBudget = new HashMap<>();
    private long xpWindowStart = System.currentTimeMillis();

    private boolean statsDirty = true;
    private boolean wasOnGround = true;
    private final Set<String> unlockedNodes = new HashSet<>();

    public NinjaPlayerData() {
        for (StatType s : StatType.values()) { statLevels.put(s, 0); statXp.put(s, 0); }
        for (ElementType e : ElementType.values()) { natureLevels.put(e, 0); natureXp.put(e, 0); natureUnlocked.put(e, false); }
    }

    // === Геттеры ===
    public float getCurrentChakra() { return currentChakra; }
    public float getCurrentStamina() { return currentStamina; }
    public void setCurrentStamina(float v) { this.currentStamina = Math.max(0, Math.min(v, maxStamina)); }
    public float getMaxStamina() { return maxStamina; }
    public void setMaxStamina(float v) { this.maxStamina = Math.max(1, v); }
    public float getModeBuffer() { return modeBuffer; }
    public void setModeBuffer(float v) { this.modeBuffer = Math.max(0, v); }
    public boolean isBlocking() { return isBlocking; }
    public void setBlocking(boolean v) { this.isBlocking = v; }
    public int getReserveLevel() { return reserveLevel; }
    public int getReserveXp() { return reserveXp; }
    public float getFatigue() { return fatigue; }
    public boolean isExhausted() { return exhausted; }
    public boolean isMeditating() { return meditating; }
    public String getClanId() { return clanId; }
    public ElementType getAffinity() { return affinity; }
    public boolean isClanChosen() { return clanChosen; }
    public int getSkillPoints() { return skillPoints; }
    public int getHpLevel() { return hpLevel; }
    public int getSpeedLevel() { return speedLevel; }
    public int getJumpLevel() { return jumpLevel; }
    public long getLastCastTimeForTier(int tier) { return tierCooldowns.getOrDefault(tier, 0L); }
    public void setLastCastTimeForTier(int tier, long time) { tierCooldowns.put(tier, time); }
    public Set<String> getTeacherApprovedNodes() { return teacherApprovedNodes; }
    public void approveTeacherNode(String nodeId) { teacherApprovedNodes.add(nodeId); statsDirty = true; }
    public boolean isChakraMode() { return chakraMode; }
    public String getActiveDojutsu() { return activeDojutsu; }
    public void setActiveDojutsu(String d) { this.activeDojutsu = d; statsDirty = true; }
    public boolean isSensoryEnabled() { return sensoryEnabled; }
    public void setSensoryEnabled(boolean v) { this.sensoryEnabled = v; statsDirty = true; }
        // === РАСЕНГАН: геттеры/сеттеры ===
    public boolean isRasenganCharging() { return rasenganCharging; }
    public void setRasenganCharging(boolean v) { this.rasenganCharging = v; }
    public int getRasenganChargeTicks() { return rasenganChargeTicks; }
    public void setRasenganChargeTicks(int v) { this.rasenganChargeTicks = v; }
    public int getRasenganChargeTarget() { return rasenganChargeTarget; }
    public void setRasenganChargeTarget(int v) { this.rasenganChargeTarget = v; }
    public boolean isRasenganReady() { return rasenganReady; }
    public void setRasenganReady(boolean v) { this.rasenganReady = v; }
    public int getRasenganReadyTicks() { return rasenganReadyTicks; }
    public void setRasenganReadyTicks(int v) { this.rasenganReadyTicks = v; }
    public boolean getLastDangerState() { return lastDangerState; }
    public com.example.shinobicore.dojutsu.SharinganComponent getSharinganComponent() { return sharinganComponent; }
    public com.example.shinobicore.sensory.SensoryComponent getSensoryComponent() { return sensoryComponent; }
    public void setLastDangerState(boolean v) { this.lastDangerState = v; }

    public float getRasenganChargeProgress() {
        if (rasenganChargeTarget <= 0) return 1.0f;
        return Math.min(1.0f, (float) rasenganChargeTicks / rasenganChargeTarget);
    }
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

    // === НОВОЕ: геттеры для тай-дзюцу ===
    public int getServerComboStep() { return serverComboStep; }
    public long getLastAttackTimeMs() { return lastAttackTimeMs; }
    public String getCurrentStyleId() { return currentStyleId; }
    public Set<String> getUnlockedNodes() { return unlockedNodes; }
    public boolean isNodeUnlocked(String nodeId) { return unlockedNodes.contains(nodeId); }
    public void unlockNode(String nodeId) { unlockedNodes.add(nodeId); statsDirty = true; }

    // === Сеттеры ===
    public void setCurrentChakra(float v) { this.currentChakra = Math.max(0, Math.min(v, NinjaFormula.maxChakra(this))); }
    public void setReserveLevel(int v) { reserveLevel = Math.max(1, Math.min(v, MAX_LEVEL)); statsDirty = true; }
    public void setReserveXp(int v) { reserveXp = Math.max(0, v); statsDirty = true; }
    public void setFatigue(float v) { this.fatigue = Math.max(0, Math.min(v, 100f)); this.exhausted = this.fatigue >= 100f; }
    public void setMeditating(boolean v) { this.meditating = v; }
    // === S2-04: Kawarimi State ===
    private long kawarimiWindowEndMs = 0;
    private long kawarimiCooldownEndMs = 0;

    public boolean isKawarimiWindowActive() { return System.currentTimeMillis() < kawarimiWindowEndMs; }
    public void setKawarimiWindow(long durationMs) { this.kawarimiWindowEndMs = System.currentTimeMillis() + durationMs; }
    public boolean isKawarimiOnCooldown() { return System.currentTimeMillis() < kawarimiCooldownEndMs; }
    public void setKawarimiCooldown(long durationMs) { this.kawarimiCooldownEndMs = System.currentTimeMillis() + durationMs; }

    public void setClanId(String id) {
        String newId = id != null ? id : "none";
        String oldId = this.clanId;
        if (oldId != null && !oldId.equals("none")) {
            removeClanBonuses();
        }
        this.clanId = newId;
        if (!newId.equals("none")) {
            applyClanBonuses(newId);
        }
        statsDirty = true;
    }

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

    // === НОВОЕ: сеттеры для тай-дзюцу ===
    public void setServerComboStep(int step) { this.serverComboStep = step; }
    public void advanceComboStep() {
        this.serverComboStep = (this.serverComboStep + 1) % com.example.shinobicore.combat.TaijutsuCombo.MAX_STEPS;
    }
    public void advanceKatanaComboStep() {
        this.katanaComboStep = (this.katanaComboStep + 1) % com.example.shinobicore.combat.KenjutsuFormulas.MAX_COMBO_STEPS;
    }
    public void resetCombo() { this.serverComboStep = 0; }
    public void setLastAttackTimeMs(long time) { this.lastAttackTimeMs = time; }
    public void setCurrentStyleId(String id) { this.currentStyleId = id != null ? id : "standard"; }
    public int getKatanaComboStep() { return katanaComboStep; }
    public void setKatanaComboStep(int v) { this.katanaComboStep = v; }
    public long getKatanaLastAttackMs() { return katanaLastAttackMs; }
    public void setKatanaLastAttackMs(long v) { this.katanaLastAttackMs = v; }
    public String getKatanaStanceId() { return katanaStanceId; }
    public void setKatanaStanceId(String v) { this.katanaStanceId = v != null ? v : "aggressive"; }
    public long getKatanaDeflectUntil() { return katanaDeflectUntil; }
    public void setKatanaDeflectUntil(long v) { this.katanaDeflectUntil = v; }
    public boolean isKatanaDeflectHeld() { return katanaDeflectHeld; }
    public void setKatanaDeflectHeld(boolean v) { this.katanaDeflectHeld = v; }
    public long getLastDeflectReflectMs() { return lastDeflectReflectMs; }
    public void setLastDeflectReflectMs(long v) { this.lastDeflectReflectMs = v; }
    // === PHASE3 ===
    public int getChakraComboCounter() { return chakraComboCounter; }
    public void setChakraComboCounter(int v) { this.chakraComboCounter = v; }
    public void incrementChakraCombo() { this.chakraComboCounter++; }
    public void resetChakraCombo() { this.chakraComboCounter = 0; }
    public long getLastChakraHitMs() { return lastChakraHitMs; }
    public void setLastChakraHitMs(long v) { this.lastChakraHitMs = v; }

    // === Бонусы клана ===
    private void applyClanBonuses(String clanId) {
        com.example.shinobicore.clan.ClanDefinition clan = com.example.shinobicore.clan.ClanRegistry.get(clanId);
        if (clan == null) return;

        for (Map.Entry<String, Integer> entry : clan.statBonuses().entrySet()) {
            String key = entry.getKey();
            int bonus = entry.getValue();
            for (StatType s : StatType.values()) {
                if (s.getId().equals(key)) {
                    int current = statLevels.getOrDefault(s, 0);
                    statLevels.put(s, current + bonus);
                    appliedClanStatBonuses.put(key, bonus);
                    break;
                }
            }
        }

        for (Map.Entry<String, Integer> entry : clan.natureBonuses().entrySet()) {
            String key = entry.getKey();
            int bonus = entry.getValue();
            for (ElementType e : ElementType.values()) {
                if (e.getId().equals(key)) {
                    int current = natureLevels.getOrDefault(e, 0);
                   // S0-05: Apply starting jutsu
        if (clan.startingJutsu() != null) {
            for (String jutsuId : clan.startingJutsu()) {
                if (!learnedJutsus.contains(jutsuId)) {
                    learnedJutsus.add(jutsuId);
                    statsDirty = true;
                }
            }
        }
         natureLevels.put(e, current + bonus);
                    natureUnlocked.put(e, true);
                    appliedClanNatureBonuses.put(key, bonus);
                    break;
                }
            }
        }
    }

    private void removeClanBonuses() {
        for (Map.Entry<String, Integer> entry : appliedClanStatBonuses.entrySet()) {
            String key = entry.getKey();
            int bonus = entry.getValue();
            for (StatType s : StatType.values()) {
                if (s.getId().equals(key)) {
                    int current = statLevels.getOrDefault(s, 0);
                    statLevels.put(s, Math.max(0, current - bonus));
                    break;
                }
            }
        }
        for (Map.Entry<String, Integer> entry : appliedClanNatureBonuses.entrySet()) {
            String key = entry.getKey();
            int bonus = entry.getValue();
            for (ElementType e : ElementType.values()) {
                if (e.getId().equals(key)) {
                    int current = natureLevels.getOrDefault(e, 0);
                    natureLevels.put(e, Math.max(0, current - bonus));
                    break;
                }
            }
        }
        appliedClanStatBonuses.clear();
        appliedClanNatureBonuses.clear();
    }

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
        nbt.putFloat("Stamina", currentStamina);
        nbt.putFloat("MaxStamina", maxStamina);
        nbt.putFloat("ModeBuffer", modeBuffer);
        nbt.putInt("ReserveLevel", reserveLevel);
        nbt.putInt("ReserveXp", reserveXp);
        nbt.putFloat("Fatigue", fatigue);
        nbt.putBoolean("Exhausted", exhausted);
        nbt.putBoolean("Meditating", meditating);
        nbt.putString("Clan", clanId);
        nbt.putBoolean("ClanChosen", clanChosen);
        nbt.putInt("SkillPoints", skillPoints);
        nbt.putInt("HpLevel", hpLevel);
        nbt.putInt("SpeedLevel", speedLevel);
        nbt.putInt("JumpLevel", jumpLevel);
        nbt.putBoolean("ChakraMode", chakraMode);
        if (activeDojutsu != null) nbt.putString("ActiveDojutsu", activeDojutsu);
        nbt.putBoolean("SensoryEnabled", sensoryEnabled);
        nbt.putBoolean("RasenganCharging", rasenganCharging);
        nbt.putInt("RasenganChargeTicks", rasenganChargeTicks);
        nbt.putInt("RasenganChargeTarget", rasenganChargeTarget);
        nbt.putBoolean("RasenganReady", rasenganReady);
nbt.putInt("PassiveXpToday", passiveXpToday);
nbt.putLong("LastPassiveDay", lastPassiveDay);
nbt.putLong("LastPassiveXpTimeMs", lastPassiveXpTimeMs);
        // === НОВОЕ: сохраняем стиль ===
        nbt.putString("Style", currentStyleId);
        nbt.putString("KatanaStance", katanaStanceId);
        nbt.putInt("ChakraComboCounter", chakraComboCounter);
        
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
        NbtCompound csb = new NbtCompound();
        for (Map.Entry<String, Integer> en : appliedClanStatBonuses.entrySet()) csb.putInt(en.getKey(), en.getValue());
        nbt.put("ClanStatBonuses", csb);
        NbtCompound cnb = new NbtCompound();
        for (Map.Entry<String, Integer> en : appliedClanNatureBonuses.entrySet()) cnb.putInt(en.getKey(), en.getValue());
        nbt.put("ClanNatureBonuses", cnb);
        NbtList nodes = new NbtList();
        for (String nodeId : unlockedNodes) nodes.add(NbtString.of(nodeId));
        nbt.put("UnlockedNodes", nodes);
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
        currentStamina = nbt.contains("Stamina") ? nbt.getFloat("Stamina") : 100f;
        maxStamina = nbt.contains("MaxStamina") ? nbt.getFloat("MaxStamina") : 100f;
        modeBuffer = nbt.getFloat("ModeBuffer");
        reserveLevel = Math.max(1, nbt.getInt("ReserveLevel"));
        reserveXp = nbt.getInt("ReserveXp");
        fatigue = nbt.getFloat("Fatigue");
        exhausted = nbt.getBoolean("Exhausted");
        meditating = nbt.getBoolean("Meditating");

        String clanIdRead = nbt.getString("Clan");
        this.clanId = clanIdRead.isEmpty() ? "none" : clanIdRead;

        clanChosen = nbt.getBoolean("ClanChosen");
        skillPoints = nbt.getInt("SkillPoints");
        hpLevel = nbt.getInt("HpLevel");
        speedLevel = nbt.getInt("SpeedLevel");
        jumpLevel = nbt.getInt("JumpLevel");
        chakraMode = nbt.getBoolean("ChakraMode");
        if (nbt.contains("ActiveDojutsu")) activeDojutsu = nbt.getString("ActiveDojutsu");
        sensoryEnabled = !nbt.contains("SensoryEnabled") || nbt.getBoolean("SensoryEnabled");
        rasenganCharging = nbt.getBoolean("RasenganCharging");
        rasenganChargeTicks = nbt.getInt("RasenganChargeTicks");
        rasenganChargeTarget = nbt.getInt("RasenganChargeTarget");
        rasenganReady = nbt.getBoolean("RasenganReady");
passiveXpToday = nbt.getInt("PassiveXpToday");
lastPassiveDay = nbt.getLong("LastPassiveDay");
lastPassiveXpTimeMs = nbt.getLong("LastPassiveXpTimeMs");
long currentDayCheck = System.currentTimeMillis() / 86400000L;
if (currentDayCheck != lastPassiveDay) {
    passiveXpToday = 0;
    lastPassiveDay = currentDayCheck;
}
        // === НОВОЕ: читаем стиль ===
        if (nbt.contains("Style")) {
            currentStyleId = nbt.getString("Style");
        }
        
        if (nbt.contains("KatanaStance")) katanaStanceId = nbt.getString("KatanaStance");
        if (nbt.contains("ChakraComboCounter")) chakraComboCounter = nbt.getInt("ChakraComboCounter");
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
        else if (nbt.contains("Loadout")) readLoadout(nbt.getList("Loadout", 8), loadoutA);
        if (nbt.contains("LoadoutB")) readLoadout(nbt.getList("LoadoutB", 8), loadoutB);
        activeSlotA = nbt.getInt("ActiveSlotA");
        activeSlotB = nbt.getInt("ActiveSlotB");
        if (nbt.contains("UnlockedNodes")) {
            NbtList nodeList = nbt.getList("UnlockedNodes", 8);
            for (int i = 0; i < nodeList.size(); i++) unlockedNodes.add(nodeList.getString(i));
        }

        appliedClanStatBonuses.clear();
        if (nbt.contains("ClanStatBonuses")) {
            NbtCompound csb = nbt.getCompound("ClanStatBonuses");
            for (String k : csb.getKeys()) appliedClanStatBonuses.put(k, csb.getInt(k));
        }
        appliedClanNatureBonuses.clear();
        if (nbt.contains("ClanNatureBonuses")) {
            NbtCompound cnb = nbt.getCompound("ClanNatureBonuses");
            for (String k : cnb.getKeys()) appliedClanNatureBonuses.put(k, cnb.getInt(k));
        }
    }
}
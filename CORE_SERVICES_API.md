```markdown
# SHINOBICORE 4.0.0 - CORE SERVICES API

This file describes all core services, data components, and formulas
that will be available to modules.

IMPORTANT: Some services are not yet implemented (Sprint 2).
Modules must code against these interfaces and handle the case
where a service is not yet available.

---

## 1. SERVICE REGISTRY

All services are accessed through `CoreServices`:

```java
// Get a service (returns Optional)
Optional<ChakraApi> chakra = CoreServices.get(ChakraApi.class);

// Get a service (throws if missing)
ChakraApi chakra = CoreServices.require(ChakraApi.class);

// Safe pattern for modules:
CoreServices.get(ChakraApi.class).ifPresent(chakra -> {
    float current = chakra.getCurrent(player);
});
```

If a service is not registered, the module must handle it gracefully
(not crash, not NPE).

---

## 2. CHAKRA SERVICE

Interface: `ChakraApi`

```java
public interface ChakraApi {
    float getCurrent(PlayerEntity player);
    float getMax(PlayerEntity player);
    float getFatigue(PlayerEntity player);
    boolean isExhausted(PlayerEntity player);
    boolean isChakraModeActive(PlayerEntity player);
    boolean isMeditating(PlayerEntity player);
    float getReserved(PlayerEntity player);

    boolean trySpend(PlayerEntity player, float amount);
    void add(PlayerEntity player, float amount);
    void setCurrent(PlayerEntity player, float value);
    void setMax(PlayerEntity player, float value);
    void addFatigue(PlayerEntity player, float amount);
    void setChakraMode(PlayerEntity player, boolean active);
    void setMeditating(PlayerEntity player, boolean meditating);
    void resetToDefaults(PlayerEntity player);
}
```

### Formulas

```text
maxChakra = BASE_MAX_CHAKRA
          + reserve * RESERVE_GAIN
          + spiritual * SPIRITUAL_GAIN
          + physical * PHYSICAL_GAIN
          + altarChakraBonus

regenPerTick = BASE_REGEN
             * meditationMultiplier
             * clanRegenMultiplier
             * fatiguePenalty

fatiguePenalty = 1.0 - (fatigue / MAX_FATIGUE) * FATIGUE_PENALTY_SCALE
```

### Constants (defaults, configurable)

```text
BASE_MAX_CHAKRA = 100.0
BASE_REGEN = 0.5 (per tick)
MAX_FATIGUE = 100.0
FATIGUE_PENALTY_SCALE = 0.5
MEDITATION_REGEN_MULTIPLIER = 3.0
MEDITATION_FATIGUE_REDUCTION = 2.0
```

---

## 3. STATS SERVICE

Interface: `StatsApi`

```java
public interface StatsApi {
    int getStatLevel(PlayerEntity player, String statId);
    float getStatValue(PlayerEntity player, String statId);
    void addStatXp(PlayerEntity player, String statId, float xp);
    Map<String, Integer> getAllStats(PlayerEntity player);
}
```

### Stat IDs

```text
control       - chakra control
ninjutsu      - ninjutsu power
taijutsu      - taijutsu power
genjutsu      - genjutsu power
medical       - medical ninjutsu
space_time    - space-time ninjutsu
perception    - sensory/perception
reserve       - chakra reserve
speed         - movement speed
jump          - jump power
physical      - physical stat
spiritual     - spiritual stat
focus         - focus (reduces jutsu cost)
willpower     - willpower (reduces fatigue gain)
insight       - insight (genjutsu resistance)
```

---

## 4. PROGRESSION SERVICE

Interface: `ProgressionApi`

```java
public interface ProgressionApi {
    int getPlayerLevel(PlayerEntity player);
    int getCurrentXp(PlayerEntity player);
    int getXpToNextLevel(PlayerEntity player);
    int getAvailableSp(PlayerEntity player);

    void addXp(PlayerEntity player, int amount, String source);
    void addSp(PlayerEntity player, int amount);
    boolean spendSp(PlayerEntity player, int amount, String reason);

    int getJutsuLevel(PlayerEntity player, String jutsuId);
    int getJutsuUses(PlayerEntity player, String jutsuId);
    void addJutsuUse(PlayerEntity player, String jutsuId);

    boolean isNodeUnlocked(PlayerEntity player, String nodeId);
    boolean unlockNode(PlayerEntity player, String nodeId);

    float getAttunementProgress(PlayerEntity player, String elementId);
    boolean isElementUnlocked(PlayerEntity player, String elementId);
}
```

### XP curve formula

```text
xpToNextLevel = BASE_XP * pow(level, EXPONENT)

BASE_XP = 100
EXPONENT = 1.5
```

### Level-up rewards

```text
spPerLevelUp = 1 (configurable)
```

---

## 5. CLAN SERVICE

Interface: `ClanApi`

```java
public interface ClanApi {
    String getClanId(PlayerEntity player);
    boolean hasClan(PlayerEntity player);
    String getClanName(PlayerEntity player);
    String getClanColor(PlayerEntity player);

    float getCostMultiplier(PlayerEntity player, String jutsuId);
    float getStatBonus(PlayerEntity player, String statId);
    float getFatigueMultiplier(PlayerEntity player);
    boolean isClanJutsu(PlayerEntity player, String jutsuId);

    void setClan(PlayerEntity player, String clanId);
    void clearClan(PlayerEntity player);
}
```

---

## 6. JUTSU CAST GATEWAY

Interface: `JutsuCastGatewayApi`

This is used by the AI module to cast jutsu through the jutsu module.

```java
public interface JutsuCastGatewayApi {
    boolean tryCast(LivingEntity caster, String jutsuId, Entity target);
    boolean isJutsuAvailable(String jutsuId);
}
```

The jutsu module registers this service. If the jutsu module is disabled,
the service will not be available and AI must handle that.

---

## 7. FORMULA SERVICE

Interface: `FormulaApi`

```java
public interface FormulaApi {
    float calcMaxChakra(PlayerEntity player);
    float calcJutsuCost(PlayerEntity player, String jutsuId);
    float calcMeleeDamage(PlayerEntity player, float baseDamage);
    float calcRangedDamage(PlayerEntity player, float baseDamage);
    float calcFatigueGain(PlayerEntity player, float baseStrain);
    float calcRegenRate(PlayerEntity player);
    float calcMovementSpeed(PlayerEntity player);
    float calcJumpHeight(PlayerEntity player);
}
```

### Key formulas

```text
jutsuCost = baseCost
          * clanCostMultiplier
          * focusReduction
          * masteryReduction
          * fatiguePenalty

focusReduction = 1.0 - (focusLevel * FOCUS_REDUCTION_PER_LEVEL)
fatiguePenalty = 1.0 + (fatigue / MAX_FATIGUE) * FATIGUE_COST_SCALE

meleeDamage = baseDamage
            * (1 + taijutsuLevel * TAIJUTSU_DAMAGE_PER_LEVEL)
            * clanMeleeMultiplier
            * comboMultiplier
            * chakraModeMultiplier
            * fatiguePenalty

movementSpeed = baseSpeed
              * (1 + speedLevel * SPEED_GAIN_PER_LEVEL)
              * chakraModeMultiplier

jumpHeight = baseJump
           * (1 + jumpLevel * JUMP_GAIN_PER_LEVEL)
           * chakraModeMultiplier
```

---

## 8. DATA COMPONENTS (Cardinal Components)

Components store player data and persist across game sessions.
Modules do NOT create their own CCA components.
All player-shared data goes through core components.

### 8.1. Planned components (Sprint 2)

```text
shinobicore:chakra       - chakra, fatigue, meditation, chakra mode
shinobicore:stats        - stat levels, stat XP
shinobicore:progression  - player level, XP, SP
shinobicore:clan         - clan ID, clan reputation
shinobicore:jutsu        - learned jutsu, jutsu levels, loadout slots
shinobicore:combat       - stance, combo, block state, cooldowns
shinobicore:movement     - parkour state, action flags
shinobicore:reputation   - faction reputation values
```

### 8.2. Component data persistence

All components:
- Save to NBT on world save
- Load on world load
- Sync to client when values change (not every tick)
- Persist across death, respawn, dimension change, game restart

### 8.3. Module-specific data

If a module needs to store its own data that is NOT shared with other modules,
it may register its own CCA component through the core.
But shared data (chakra, stats, progression) MUST go through core components.

---

## 9. CORE COMMANDS (already available)

```text
/shinobicore systems          - show all module states
/shinobicore modules list     - same as systems
/shinobicore version          - show mod version
```

---

## 10. LOGGING

Use `ShinobiLogger` for all logging:

```java
ShinobiLogger.core("Core message");
ShinobiLogger.module("movement", "Movement message");
ShinobiLogger.error("movement", "Something failed", exception);
```

Log files are created in `logs/shinobicore/`:
- `core-1.log`, `core-2.log`, `core-3.log` (rotation, max 3)
- `<module_id>-1.log`, `<module_id>-2.log`, `<module_id>-3.log`

NEVER use `System.out.println()`.

---

## END OF CORE SERVICES API
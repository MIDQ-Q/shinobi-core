# ТЗ #4: Progression (Прогрессия)

Сохранить как: `team_packages/TZ_PROGRESSION.md`

---

```markdown
# TECHNICAL SPECIFICATION: Progression Module

**Module ID:** `progression`
**Module Name:** ShinobiCore - Progression & Skill Tree
**Priority:** 2 (second wave, alongside clans, HUD, visual)
**Core dependency:** Sprint 1 (ModuleManager) + Sprint 2 (Chakra, Stats, Clan, Formula services)

---

## 1. PURPOSE

Implement the complete player progression system:

- Player level and XP
- Skill Points (SP) earned on level-up
- Stat levels and stat XP (ninjutsu, taijutsu, genjutsu, control, medical, space-time, perception)
- Body stats (speed, jump, vitality, reserve, endurance)
- Jutsu levels and mastery (XP from usage)
- Skill Tree with elemental branches (fire, water, wind, lightning, earth)
- Special combined elements (Kekkei Genkai)
- Attunement system (unlock elements via mini-game)
- Training mini-games (optional, training post gives bonus XP)
- Reputation with villages/factions
- Progression persists across death, respawn, dimension change, and game restart
- NO progression reset (by design)

**NOT in scope** (belong to other modules):
- Chakra management → core ChakraApi
- Jutsu casting behavior → Jutsu module (we only track levels/unlocks)
- Combat damage formulas → Combat module (consumes our data)
- Visual effects → Visual module
- HUD rendering → HUD module (reads our view)
- Training post block → World module (publishes interaction event)

---

## 2. FILE OWNERSHIP

The progression team may ONLY create and modify files in these locations:

```
src/main/java/com/example/shinobicore/modules/progression/
src/main/resources/data/shinobicore/progression/       (JSON: tree nodes, attunement, mini-games)
src/main/resources/assets/shinobicore/progression/     (textures, sounds, UI assets)
config/shinobicore/modules/progression.json            (generated at runtime)
```

The progression team MUST NOT modify:
- Any file under `core/`
- `ShinobiCoreMod.java` or `ShinobiCoreClient.java`
- Any file belonging to another module
- `fabric.mod.json` (entrypoint addition is done by core team)

---

## 3. ARCHITECTURE

### 3.1 Package structure

```
modules/progression/
├── ProgressionModule.java                     (entry point, implements ClientAwareModule)
├── config/
│   ├── ProgressionConfig.java
│   └── ProgressionConfigLoader.java
├── data/
│   ├── TreeNodeDefinition.java                (record: tree node JSON)
│   ├── AttunementDefinition.java              (record: attunement config)
│   ├── MiniGameDefinition.java                (record: mini-game JSON)
│   ├── ProgressionDataLoader.java
│   ├── TreeNodeRegistry.java
│   ├── AttunementRegistry.java
│   ├── MiniGameRegistry.java
│   └── ProgressionJsonValidator.java
├── service/
│   ├── XpSourceService.java                   (awards XP from various sources)
│   ├── LevelService.java                      (level-up logic, SP grants)
│   ├── StatService.java                       (stat level management)
│   ├── BodyStatService.java                   (body stats: speed, jump, vitality, etc.)
│   ├── SpService.java                         (SP spend/refund)
│   ├── JutsuMasteryService.java               (jutsu levels, mastery XP)
│   ├── SkillTreeService.java                  (unlock tree nodes)
│   ├── AttunementService.java                 (element unlock logic)
│   ├── ReputationService.java                 (faction reputation)
│   └── ProgressionFormula.java
├── minigame/
│   ├── MiniGameScreen.java                    (abstract base)
│   ├── MiniGameRegistry.java
│   ├── TimingMiniGame.java                    (timing bar)
│   ├── TargetMiniGame.java                    (hit target)
│   ├── QteMiniGame.java                       (quick-time event)
│   ├── PulseCircleMiniGame.java               (attunement pulse circle)
│   └── TrainingPostBonus.java                 (bonus multiplier near training post)
├── component/
│   ├── ProgressionComponentKey.java           (CCA component key)
│   ├── ProgressionComponentImpl.java          (CCA implementation)
│   └── ProgressionComponentInitializer.java
├── client/
│   ├── ProgressionClientState.java
│   ├── ProgressionKeyBindings.java
│   └── ProgressionInputHandler.java
├── ui/
│   ├── ProgressionHubTab.java                 (tab in K-screen)
│   ├── SkillTreeTab.java                      (tree view with zoom/pan)
│   ├── AttunementTab.java                     (attunement view)
│   ├── StatsTab.java                          (stats overview)
│   ├── JutsuSlotsTab.java                     (jutsu slot assignment)
│   ├── ClanTab.java                           (clan info, read-only)
│   └── widgets/
│       ├── ProgressBar.java
│       ├── StatRow.java
│       ├── TreeNodeWidget.java
│       ├── AttunementCircleWidget.java
│       └── TooltipCard.java
├── network/
│   ├── ProgressionPackets.java                (packet registry)
│   ├── ProgressionActionPacket.java           (client -> server: spend SP, unlock node)
│   ├── AttunementAttemptPacket.java           (client -> server: attunement result)
│   ├── MiniGameResultPacket.java              (client -> server: mini-game result)
│   ├── ProgressionStateSyncPacket.java        (server -> client: full state)
│   ├── LevelUpPacket.java                     (server -> client: level-up event)
│   └── StatChangedPacket.java                 (server -> client: stat change)
└── view/
    └── ProgressionVisualViewImpl.java         (implements ProgressionVisualView)
```

### 3.2 Module entry point

```java
public class ProgressionModule implements ClientAwareModule {
    public static final String ID = "progression";

    @Override public String id() { return ID; }

    @Override
    public void onRegister(ModuleContext ctx) {
        ProgressionComponentKey.register();
    }

    @Override
    public void onEnable(ModuleContext ctx) {
        ProgressionConfig.load(ctx.configs().readModuleConfig(ID));

        // Load data
        ProgressionDataLoader.load();
        TreeNodeRegistry.build();
        AttunementRegistry.build();
        MiniGameRegistry.build();
        ProgressionJsonValidator.validateAll();

        // Init services
        XpSourceService.init();
        LevelService.init();
        StatService.init();
        BodyStatService.init();
        SpService.init();
        JutsuMasteryService.init();
        SkillTreeService.init();
        AttunementService.init();
        ReputationService.init();

        ProgressionPackets.registerServer();
    }

    @Override
    public void registerEvents(ModuleContext ctx) {
        // XP sources
        ctx.events().subscribe(JutsuCastFinishedEvent.class, e -> {
            if (e.success()) XpSourceService.onJutsuCast(e.caster(), e.jutsuId());
        });
        ctx.events().subscribe(CombatHitEvent.class, e -> {
            XpSourceService.onCombatHit(e.attacker(), e.damage());
        });
        ctx.events().subscribe(PlayerDiedEvent.class, e -> {
            // Progression persists across death (no reset)
        });
        ctx.events().subscribe(PlayerRespawnedEvent.class, e -> {
            // Sync full state to client
        });
        ctx.events().subscribe(PlayerChangedDimensionEvent.class, e -> {
            // Sync full state to client
        });

        // Training post interaction (from World module)
        ctx.events().subscribe(WorldBlockInteractedEvent.class, e -> {
            if ("training_post".equals(e.blockId())) {
                TrainingPostBonus.applyBonus(e.player());
            }
        });
    }

    @Override
    public void registerViews(ModuleContext ctx) {
        ctx.views().register(ProgressionVisualView.class, player ->
            Optional.of(new ProgressionVisualViewImpl(player)));
    }

    @Override
    public void registerCommands(ModuleContext ctx, CommandDispatcher<ServerCommandSource> d) {
        ProgressionCommands.register(d);
    }

    @Override
    public void onClientInit(ModuleContext ctx) {
        ProgressionKeyBindings.register();
        ProgressionInputHandler.init();
        ProgressionPackets.registerClient();
    }

    @Override
    public void onClientTick(ModuleContext ctx) {
        ProgressionInputHandler.tick();
    }

    @Override
    public void onServerTick(ModuleContext ctx, MinecraftServer server) {
        LevelService.serverTick(server);
        ReputationService.serverTick(server);
    }
}
```

---

## 4. CORE API TO USE

### 4.1 ChakraApi

```java
CoreServices.get(ChakraApi.class).ifPresent(chakra -> {
    float max = chakra.getMax(player);
    // Progression affects max chakra via formula
});
```

### 4.2 StatsApi

```java
CoreServices.get(StatsApi.class).ifPresent(stats -> {
    int ninjutsu = stats.getStatLevel(player, "ninjutsu");
    // Stat levels drive formulas in other modules
});
```

### 4.3 ClanApi

```java
CoreServices.get(ClanApi.class).ifPresent(clan -> {
    String clanId = clan.getClanId(player);
    // Clan may grant free element attunement (extraAffinityCount)
    int extraAffinities = clan.getExtraAffinityCount(player);
});
```

### 4.4 FormulaApi

```java
CoreServices.get(FormulaApi.class).ifPresent(f -> {
    float maxChakra = f.calcMaxChakra(player);
    float jutsuCost = f.calcJutsuCost(player, jutsuId);
    // These formulas READ progression data internally
});
```

### 4.5 Events to publish

```java
public record XpGainedEvent(ServerPlayerEntity player, int amount, String source) {}
public record LevelChangedEvent(ServerPlayerEntity player, int oldLevel, int newLevel) {}
public record SpGainedEvent(ServerPlayerEntity player, int amount) {}
public record SpSpentEvent(ServerPlayerEntity player, int amount, String reason) {}
public record StatLevelChangedEvent(ServerPlayerEntity player, String statId, int oldLevel, int newLevel) {}
public record BodyStatChangedEvent(ServerPlayerEntity player, String bodyStatId, int oldLevel, int newLevel) {}
public record JutsuLevelChangedEvent(ServerPlayerEntity player, String jutsuId, int oldLevel, int newLevel) {}
public record TreeNodeUnlockedEvent(ServerPlayerEntity player, String nodeId) {}
public record ElementAttunedEvent(ServerPlayerEntity player, String elementId) {}
public record ReputationChangedEvent(ServerPlayerEntity player, String factionId, int old, int current) {}
public record MiniGameCompletedEvent(ServerPlayerEntity player, String gameId, boolean success, int xpEarned) {}
```

### 4.6 Events to subscribe

```
JutsuCastFinishedEvent     -> award XP on successful cast
CombatHitEvent             -> award XP on hit
PlayerDiedEvent            -> no reset (progression persists)
PlayerRespawnedEvent       -> sync state
PlayerChangedDimensionEvent -> sync state
WorldBlockInteractedEvent  -> training post bonus
```

---

## 5. VIEWS TO REGISTER

Register one view:

```java
public interface ProgressionVisualView {
    int getPlayerLevel();
    int getCurrentXp();
    int getXpToNextLevel();
    int getAvailableSp();
    float getProgressToNextLevel();  // 0.0 - 1.0

    int getStatLevel(String statId);
    int getBodyStatLevel(String bodyStatId);
    int getJutsuLevel(String jutsuId);

    boolean isNodeUnlocked(String nodeId);
    boolean isElementUnlocked(String elementId);
    float getAttunementProgress(String elementId);  // 0.0 - 1.0

    int getReputation(String factionId);
}
```

---

## 6. MECHANICS — DETAILED BEHAVIOR

### 6.1 Player level and XP

**XP curve:**
```
xpForLevel(N) = BASE_XP * pow(N, EXPONENT)
```

Configurable:
- `BASE_XP = 100`
- `EXPONENT = 1.5`

**XP sources:**
| Source | XP amount | Notes |
|--------|-----------|-------|
| Successful jutsu cast | `xpPerCast` (config) | Per cast, not per damage |
| Damage dealt by jutsu | `damage * xpPerDamage` | Scales with damage |
| Kill by jutsu | `xpPerKill` | Bonus on top of damage XP |
| Combat hit (melee) | `xpPerMeleeHit` | Small amount per hit |
| Combat kill (melee) | `xpPerMeleeKill` | Bonus |
| Meditation | `xpPerMeditationTick` | Passive, slow |
| Mini-game success | `minigame.baseXp * multiplier` | Varies by game |
| Training post bonus | `* trainingPostMultiplier` | Multiplier on any XP source |
| Quest completion | `quest.xpReward` | Future |

**Level-up:**
- On level-up: grant `spPerLevelUp` SP (default: 1)
- Publish `LevelChangedEvent`
- Sync to client
- Client plays level-up animation/sound

### 6.2 Skill Points (SP)

- Earned on level-up
- Spent on:
  - Stat level increases
  - Body stat level increases
  - Tree node unlocks
  - Attunement attempts

**SP is NOT refundable** (by design, no reset).

### 6.3 Stats

**Primary stats:**
```
control       - chakra control, reduces jutsu cost, increases cast speed
ninjutsu      - ninjutsu damage, jutsu effectiveness
taijutsu      - melee damage, kick damage, unarmed damage
genjutsu      - genjutsu power, genjutsu resistance
medical       - healing effectiveness, medical jutsu power
space_time    - teleportation range, space-time jutsu power
perception    - sensory range, parry window, dodge chance
```

**Body stats:**
```
speed         - movement speed multiplier
jump          - jump height multiplier
vitality      - max HP bonus
reserve       - max chakra bonus
endurance     - fatigue resistance, chakra mode drain reduction
```

**Stat leveling:**
- Each stat level costs SP
- Cost increases with level: `spCost = baseSpCost + (level / 10)`
- Max level: configurable (default 100)
- Each level grants a small bonus via FormulaApi

**Stat XP:**
- Stats gain XP through use (casting jutsu of that type, melee hits, etc.)
- Stat XP does NOT increase stat level directly
- Stat XP is used for mastery within a stat (future: stat-specific perks)

### 6.4 Jutsu levels and mastery

- Each jutsu has its own level (0..maxLevel, default 10)
- Jutsu level increases through use (via `ProgressionApi.addJutsuUse`)
- Each level grants:
  - +damage (per `scaling.damagePerLevel` in jutsu JSON)
  - -cost (per `scaling.costReductionPerLevel`)
  - -cooldown (per `scaling.cooldownReductionPerLevel`)
- Jutsu level is stored in the progression component

**Mastery XP curve:**
```
xpForJutsuLevel(N) = baseJutsuXp * pow(N, jutsuXpExponent)
```

### 6.5 Skill Tree

The skill tree is a directed acyclic graph of nodes organized by elemental branches.

**Branches:**
```
general       - basic jutsu, utility, movement
fire          - fire release jutsu
water         - water release jutsu
wind          - wind release jutsu
lightning     - lightning release jutsu
earth         - earth release jutsu
special       - combined elements (Kekkei Genkai)
```

**Node types:**
```
jutsu         - unlocks a jutsu (jutsuId field)
passive       - grants a passive bonus (e.g., +5% fire damage)
stat_boost    - permanently increases a stat by N
element       - unlocks an element (alternative to attunement)
```

**Node definition (JSON):**
```json
{
  "id": "fire_basic",
  "branch": "fire",
  "distance": 1,
  "type": "jutsu",
  "jutsuId": "shinobicore:fireball_basic",
  "spCost": 3,
  "requires": [],
  "icon": "F",
  "name": "Fireball Jutsu",
  "description": "Basic fireball projectile"
}
```

**Unlock rules:**
1. All `requires` nodes must be unlocked first
2. Player must have enough SP
3. If `clanRequired` is set, player must be in that clan
4. If node type is `jutsu`, the jutsu must exist in registry
5. Element must be attuned (unless node type is `element`)

**Tree layout:**
- Nodes are positioned by `distance` (radial distance from center) and `angleOffset`
- Tree is rendered as a radial graph in the K-screen
- Zoom and pan supported
- 60+ FPS required with 100+ nodes visible

### 6.6 Attunement (element unlock)

**Elements:**
```
fire
water
wind
lightning
earth
```

**Special combined elements (Kekkei Genkai):**
```
scorch         (fire + wind)
ice            (water + wind)
lava           (earth + fire)
mud            (water + earth)
plasma         (lightning + fire)
vacuum         (wind + lightning)
```

**Attunement rules:**
1. First element (affinity) is free, determined by clan or random
2. Additional elements require attunement
3. Clans with `extraAffinityCount > 0` get extra free elements
4. Attunement requires:
   - SP cost (increases per element)
   - Minimum `control` stat level
   - Successful mini-game (pulse circle)
5. Attunement progress is saved (partial progress persists)

**Attunement cost:**
```
spCost = baseAttunementSp + (elementIndex * spCostIncrement)
controlRequired = baseControlRequired + (elementIndex * controlIncrement)
```

**Pulse circle mini-game:**
- A circle pulses (grows and shrinks)
- Player must click when the circle is at the target size
- Success window shrinks with each subsequent element
- On success: element unlocked
- On failure: partial progress saved, can retry

### 6.7 Training mini-games

Training is done via mini-games. Training post block is optional (gives bonus multiplier).

**Mini-game types:**
```
timing        - press key when marker reaches target zone
target        - click moving targets
qte           - quick-time event (press sequence)
pulse_circle  - attunement pulse circle
```

**Mini-game definition (JSON):**
```json
{
  "id": "attunement_fire",
  "type": "pulse_circle",
  "params": {
    "speed": 2.0,
    "targetSize": 0.5,
    "tolerance": 0.1,
    "duration": 10
  },
  "reward": {
    "xp": 100,
    "stat": "control",
    "element": "fire"
  }
}
```

**Training post bonus:**
- When player is within `trainingPostRadius` of a training post block
- All XP earned is multiplied by `trainingPostMultiplier` (default 2.0)
- Bonus is active for `trainingPostDurationTicks` after last interaction
- Training post is NOT required for training (just gives bonus)

### 6.8 Reputation

**Factions:**
```
village_id    - reputation with each village
clan_id       - reputation with each clan (if not member)
```

**Reputation effects:**
- Access to village shops
- Quest availability
- Clan-specific jutsu access (if not clan member)
- Future: village defense, alliances

**Reputation changes:**
- Quests: +reputation
- Killing village guards: -reputation
- Helping village: +reputation
- Clan change: reset clan reputation

### 6.9 Progression persistence

Progression is stored in a CCA component and persists:
- After death (no reset)
- After respawn
- After dimension change
- After game restart
- After server restart

**NO progression reset is implemented** (by design).

---

## 7. CLIENT-SERVER AUTHORITY

```
CLIENT (authoritative for UI):
- Renders progression screen (K key)
- Renders skill tree with zoom/pan
- Renders attunement mini-game
- Renders training mini-games
- Sends packets:
  - ProgressionActionPacket (spend SP, unlock node)
  - AttunementAttemptPacket (attunement result)
  - MiniGameResultPacket (mini-game result)

SERVER (authoritative for truth):
- Validates all SP spends
- Validates all node unlocks
- Validates all attunement attempts
- Awards XP
- Levels up player
- Syncs full state to client
- Soft-corrects on desync (log + adjust, never crash)
```

### CRITICAL PACKET RULE

```java
ServerPlayNetworking.registerGlobalReceiver(ID, (server, player, handler, buf, sender) -> {
    // STEP 1: Read ALL data from buffer FIRST
    final int action = buf.readInt();
    final String payload = buf.readString();

    // STEP 2: Execute on server thread
    server.execute(() -> {
        ProgressionActionHandler.handle(player, action, payload);
    });
});
```

NEVER read `buf` inside `server.execute()`.

---

## 8. FULL CONFIG TEMPLATE

File: `config/shinobicore/modules/progression.json` (auto-created on first run)

```json
{
  "enabled": true,
  "debug": false,

  "xp": {
    "baseXp": 100,
    "exponent": 1.5,
    "xpPerCast": 5,
    "xpPerDamage": 0.5,
    "xpPerKill": 50,
    "xpPerMeleeHit": 1,
    "xpPerMeleeKill": 20,
    "xpPerMeditationTick": 0.1,
    "xpPerMiniGameBase": 100
  },

  "sp": {
    "spPerLevelUp": 1,
    "baseSpCostPerStat": 1,
    "spCostIncrementPerLevel": 0.1,
    "maxStatLevel": 100,
    "maxBodyStatLevel": 100
  },

  "jutsu": {
    "maxLevel": 10,
    "baseJutsuXp": 50,
    "jutsuXpExponent": 1.3,
    "xpPerUse": 5,
    "xpPerDamage": 0.3,
    "xpPerKill": 30
  },

  "tree": {
    "enabled": true,
    "maxNodesVisible": 200,
    "zoomMin": 0.5,
    "zoomMax": 3.0,
    "panSpeed": 1.0
  },

  "attunement": {
    "enabled": true,
    "baseAttunementSp": 5,
    "spCostIncrement": 3,
    "baseControlRequired": 5,
    "controlIncrement": 5,
    "successWindowBase": 0.15,
    "successWindowDecrement": 0.02,
    "minSuccessWindow": 0.05,
    "freeAffinityCount": 1
  },

  "minigames": {
    "enabled": true,
    "trainingPostMultiplier": 2.0,
    "trainingPostRadius": 5.0,
    "trainingPostDurationTicks": 200
  },

  "reputation": {
    "enabled": true,
    "maxReputation": 1000,
    "minReputation": -1000
  },

  "client": {
    "showXpBar": true,
    "showLevelUpAnimation": true,
    "showStatChangeAnimation": true
  },

  "logging": {
    "logXpGains": false,
    "logLevelUps": true,
    "logSpSpends": false,
    "logNodeUnlocks": true,
    "logAttunements": true
  }
}
```

### JSON data files

Progression team is responsible for these data directories:

```
data/shinobicore/progression/
├── tree/
│   ├── general.json
│   ├── fire.json
│   ├── water.json
│   ├── wind.json
│   ├── lightning.json
│   ├── earth.json
│   └── special.json
├── attunement/
│   ├── elements.json
│   └── combined_elements.json
├── minigames/
│   ├── timing_basic.json
│   ├── target_basic.json
│   ├── qte_basic.json
│   └── pulse_circle.json
└── balance/
    ├── xp_curve.json
    ├── sp_costs.json
    └── reputation_thresholds.json
```

### Config rules

1. Config is read ONCE at module load.
2. Missing file -> default is created.
3. Missing field -> default used (module must NOT crash).
4. Invalid JSON -> log error, use defaults, module continues.
5. No hot reload.

---

## 9. COMMANDS

```
/shinobicore progression info           - show level, XP, SP, all stats
/shinobicore progression statinfo       - show detailed stat breakdown
/shinobicore progression addxp <amount> - add XP (operator)
/shinobicore progression addsp <amount> - add SP (operator)
/shinobicore progression setlevel <lvl> - set player level (operator)
/shinobicore progression setstat <stat> <level> - set stat level (operator)
/shinobicore progression statxp <stat> <amount> - add stat XP (operator)
/shinobicore progression unlock <nodeId> - force-unlock tree node (operator)
/shinobicore progression attune <element> - force-attune element (operator)
/shinobicore progression reputation <faction> <amount> - set reputation (operator)
/shinobicore progression minigame <gameId> - start mini-game (for testing)
/shinobicore progression sync           - force sync state to client
/shinobicore progression debug           - toggle debug overlay
```

---

## 10. FORBIDDEN PATTERNS

Progression team MUST NOT do any of these:

1. **DO NOT** manage chakra directly. Use `ChakraApi`.
2. **DO NOT** implement progression reset. Progression is permanent.
3. **DO NOT** use `System.out.println`. Use `ShinobiLogger.module("progression", ...)`.
4. **DO NOT** hold player state in `static Map<UUID, State>` without cleanup on player disconnect.
5. **DO NOT** read `PacketByteBuf` inside `server.execute()`.
6. **DO NOT** crash on malformed tree/attunement/minigame JSON. Log error, skip, continue.
7. **DO NOT** grant XP without going through `XpSourceService` (single source of truth).
8. **DO NOT** create god-classes (>300 lines). Decompose by responsibility.
9. **DO NOT** import classes from other modules. Use core events/services/views only.
10. **DO NOT** make the module crash if another module is disabled. Handle missing services gracefully.
11. **DO NOT** render tree with >200 nodes without optimization (60 FPS requirement).
12. **DO NOT** hardcode tree nodes in Java. Read from JSON.

---

## 11. DEFINITION OF DONE

The progression module is complete when:

1. ✅ Module loads via `shinobicore:module` entrypoint
2. ✅ `/shinobicore systems` shows `progression: ENABLED`
3. ✅ Player level and XP work (XP curve, level-up, SP grant)
4. ✅ SP can be spent on stat levels
5. ✅ SP can be spent on body stat levels
6. ✅ All 7 primary stats work
7. ✅ All 5 body stats work
8. ✅ Jutsu levels increase through use
9. ✅ Jutsu levels grant damage/cost/cooldown bonuses
10. ✅ Skill tree loads from JSON
11. ✅ Skill tree renders with zoom/pan at 60+ FPS with 100+ nodes
12. ✅ Tree nodes can be unlocked with SP
13. ✅ Tree node prerequisites work (requires, clanRequired)
14. ✅ Attunement works (pulse circle mini-game)
15. ✅ First element is free (affinity)
16. ✅ Additional elements cost SP + control requirement
17. ✅ Clans with extraAffinityCount get free elements
18. ✅ Combined elements (Kekkei Genkai) can be unlocked
19. ✅ Training mini-games work (timing, target, QTE)
20. ✅ Training post gives bonus XP multiplier (optional, not required)
21. ✅ Reputation system works
22. ✅ Progression persists across death, respawn, dimension change, game restart
23. ✅ No progression reset exists
24. ✅ `ProgressionVisualView` registered and readable by HUD module
25. ✅ K-screen tabs work (Progression, Tree, Attunement, Stats)
26. ✅ Commands work (`info`, `addxp`, `addsp`, `setlevel`, `unlock`, `attune`, `sync`)
27. ✅ Log files `logs/shinobicore/progression-1.log` created and rotated
28. ✅ Module does not crash when other modules are disabled
29. ✅ Config file `progression.json` created on first run with defaults
30. ✅ Broken JSON does not crash the game
31. ✅ All network packets follow "read first, execute second" rule
32. ✅ Build passes: `.\gradlew.bat build`

---

## 12. EXAMPLE CODE SNIPPETS

### 12.1 XP curve

```java
public final class ProgressionFormula {
    public static int xpForLevel(int level, ProgressionConfig cfg) {
        return (int) (cfg.xp.baseXp * Math.pow(level, cfg.xp.exponent));
    }

    public static int xpForJutsuLevel(int level, ProgressionConfig cfg) {
        return (int) (cfg.jutsu.baseJutsuXp * Math.pow(level, cfg.jutsu.jutsuXpExponent));
    }

    public static int spCostForStatLevel(int level, ProgressionConfig cfg) {
        return cfg.sp.baseSpCostPerStat + (int)(level * cfg.sp.spCostIncrementPerLevel);
    }

    public static int attunementSpCost(int elementIndex, ProgressionConfig cfg) {
        return cfg.attunement.baseAttunementSp + (elementIndex * cfg.attunement.spCostIncrement);
    }

    public static int attunementControlRequired(int elementIndex, ProgressionConfig cfg) {
        return cfg.attunement.baseControlRequired + (elementIndex * cfg.attunement.controlIncrement);
    }

    public static float attunementSuccessWindow(int elementIndex, ProgressionConfig cfg) {
        float window = cfg.attunement.successWindowBase
            - (elementIndex * cfg.attunement.successWindowDecrement);
        return Math.max(cfg.attunement.minSuccessWindow, window);
    }
}
```

### 12.2 Level-up service

```java
public final class LevelService {
    public static void addXp(ServerPlayerEntity player, int amount, String source) {
        Optional<ProgressionComponent> compOpt = ProgressionComponentKey.get(player);
        if (compOpt.isEmpty()) return;
        ProgressionComponent comp = compOpt.get();

        int oldLevel = comp.getPlayerLevel();
        comp.addXp(amount);

        // Check for level-ups (may be multiple)
        while (comp.getCurrentXp() >= ProgressionFormula.xpForLevel(
                comp.getPlayerLevel() + 1, ProgressionConfig.get())) {
            comp.subtractXp(ProgressionFormula.xpForLevel(
                comp.getPlayerLevel(), ProgressionConfig.get()));
            comp.setPlayerLevel(comp.getPlayerLevel() + 1);
            comp.addSp(ProgressionConfig.get().sp.spPerLevelUp);

            CoreEvents.publish(new LevelChangedEvent(player,
                comp.getPlayerLevel() - 1, comp.getPlayerLevel()));
            CoreEvents.publish(new SpGainedEvent(player,
                ProgressionConfig.get().sp.spPerLevelUp));
        }

        CoreEvents.publish(new XpGainedEvent(player, amount, source));

        // Sync to client
        ProgressionPackets.sendStateSync(player);
    }
}
```

### 12.3 Tree node unlock

```java
public final class SkillTreeService {
    public static boolean unlockNode(ServerPlayerEntity player, String nodeId) {
        TreeNodeDefinition node = TreeNodeRegistry.get(nodeId).orElse(null);
        if (node == null) {
            ShinobiLogger.module("progression", "Unknown tree node: " + nodeId);
            return false;
        }

        Optional<ProgressionComponent> compOpt = ProgressionComponentKey.get(player);
        if (compOpt.isEmpty()) return false;
        ProgressionComponent comp = compOpt.get();

        // Check already unlocked
        if (comp.isNodeUnlocked(nodeId)) return false;

        // Check prerequisites
        for (String req : node.requires()) {
            if (!comp.isNodeUnlocked(req)) {
                ShinobiLogger.module("progression",
                    "Prerequisite not met: " + req + " for " + nodeId);
                return false;
            }
        }

        // Check clan requirement
        if (node.clanRequired() != null) {
            Optional<ClanApi> clanOpt = CoreServices.get(ClanApi.class);
            if (clanOpt.isPresent()) {
                String playerClan = clanOpt.get().getClanId(player);
                if (!node.clanRequired().equals(playerClan)) {
                    return false;
                }
            }
        }

        // Check SP
        if (comp.getAvailableSp() < node.spCost()) {
            return false;
        }

        // Check element attunement (for jutsu nodes)
        if ("jutsu".equals(node.type())) {
            JutsuDefinition jutsuDef = JutsuRegistry.get(node.jutsuId()).orElse(null);
            if (jutsuDef != null && !"none".equals(jutsuDef.element().name())) {
                if (!comp.isElementUnlocked(jutsuDef.element().name())) {
                    return false;
                }
            }
        }

        // Unlock
        comp.spendSp(node.spCost());
        comp.unlockNode(nodeId);

        CoreEvents.publish(new TreeNodeUnlockedEvent(player, nodeId));
        CoreEvents.publish(new SpSpentEvent(player, node.spCost(), "tree_node:" + nodeId));

        ProgressionPackets.sendStateSync(player);
        return true;
    }
}
```

### 12.4 Attunement service

```java
public final class AttunementService {
    public static boolean attemptAttunement(ServerPlayerEntity player, String elementId) {
        Optional<ProgressionComponent> compOpt = ProgressionComponentKey.get(player);
        if (compOpt.isEmpty()) return false;
        ProgressionComponent comp = compOpt.get();

        // Check already unlocked
        if (comp.isElementUnlocked(elementId)) return false;

        // Check if it's the free affinity
        Optional<ClanApi> clanOpt = CoreServices.get(ClanApi.class);
        int freeAffinities = ProgressionConfig.get().attunement.freeAffinityCount;
        if (clanOpt.isPresent()) {
            freeAffinities += clanOpt.get().getExtraAffinityCount(player);
        }
        int unlockedCount = comp.getUnlockedElementCount();
        if (unlockedCount < freeAffinities) {
            // Free attunement
            comp.unlockElement(elementId);
            CoreEvents.publish(new ElementAttunedEvent(player, elementId));
            ProgressionPackets.sendStateSync(player);
            return true;
        }

        // Paid attunement: check SP and control
        int elementIndex = unlockedCount - freeAffinities;
        int spCost = ProgressionFormula.attunementSpCost(elementIndex, ProgressionConfig.get());
        int controlReq = ProgressionFormula.attunementControlRequired(elementIndex, ProgressionConfig.get());

        if (comp.getAvailableSp() < spCost) return false;

        Optional<StatsApi> statsOpt = CoreServices.get(StatsApi.class);
        if (statsOpt.isPresent()) {
            int control = statsOpt.get().getStatLevel(player, "control");
            if (control < controlReq) return false;
        }

        // Spend SP
        comp.spendSp(spCost);
        comp.unlockElement(elementId);

        CoreEvents.publish(new ElementAttunedEvent(player, elementId));
        CoreEvents.publish(new SpSpentEvent(player, spCost, "attunement:" + elementId));

        ProgressionPackets.sendStateSync(player);
        return true;
    }
}
```

### 12.5 Pulse circle mini-game (client-side)

```java
public final class PulseCircleMiniGame extends MiniGameScreen {
    private float circleSize = 0.0f;
    private float targetSize = 0.5f;
    private float tolerance = 0.1f;
    private boolean growing = true;
    private float speed = 2.0f;

    @Override
    public void start() {
        state = State.PLAYING;
        circleSize = 0.0f;
        growing = true;
    }

    @Override
    public void tick() {
        if (state != State.PLAYING) return;

        if (growing) {
            circleSize += speed / 20.0f;
            if (circleSize >= 1.0f) growing = false;
        } else {
            circleSize -= speed / 20.0f;
            if (circleSize <= 0.0f) {
                // Missed the window
                state = State.FAILURE;
            }
        }
    }

    @Override
    public boolean mouseClicked(double mouseX, double mouseY, int button) {
        if (state != State.PLAYING) return false;

        // Check if click is within target window
        float diff = Math.abs(circleSize - targetSize);
        if (diff <= tolerance) {
            state = State.SUCCESS;
            // Send success to server
            AttunementAttemptPacket.send(elementId, true);
        } else {
            state = State.FAILURE;
            AttunementAttemptPacket.send(elementId, false);
        }
        return true;
    }

    @Override
    public void render(DrawContext ctx, int mouseX, int mouseY, float delta) {
        renderBackground(ctx);

        int cx = width / 2;
        int cy = height / 2;
        int maxRadius = 80;

        // Draw target ring
        int targetRadius = (int)(maxRadius * targetSize);
        drawCircle(ctx, cx, cy, targetRadius, 0x44FFFFFF);

        // Draw tolerance zone
        int tolRadius = (int)(maxRadius * tolerance);
        drawCircle(ctx, cx, cy, targetRadius + tolRadius, 0x2200FF00);
        drawCircle(ctx, cx, cy, targetRadius - tolRadius, 0x2200FF00);

        // Draw current circle
        int currentRadius = (int)(maxRadius * circleSize);
        int color = (Math.abs(circleSize - targetSize) <= tolerance)
            ? 0xFF00FF00 : 0xFFFF0000;
        drawCircle(ctx, cx, cy, currentRadius, color);

        super.render(ctx, mouseX, mouseY, delta);
    }
}
```

---

## 13. HANDOFF

When the progression team finishes, they must:

1. Run `.\gradlew.bat build` — must pass with 0 errors.
2. Run `.\gradlew.bat runClient` and manually verify:
   - XP gain from jutsu cast / combat hit
   - Level-up grants SP
   - SP can be spent on stats
   - Skill tree renders, zoom/pan works
   - Tree nodes unlock with prerequisites
   - Attunement mini-game works
   - Training mini-games work
   - Progression persists after death/relog
3. Verify that disabling the module via `progression.json` (`enabled: false`) does not break the game.
4. Verify that other modules (jutsu, combat, HUD) load correctly and handle missing progression data gracefully.
5. Verify that invalid tree/attunement/minigame JSON does not crash the game.
6. Create a brief `modules/progression/README.md` describing non-obvious behaviors.
7. Notify the core team that the module is ready for integration review.

---

## END OF PROGRESSION TECHNICAL SPECIFICATION
```

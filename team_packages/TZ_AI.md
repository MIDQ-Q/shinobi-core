# ТЗ #8: AI (ИИ врагов)

Сохранить как: `team_packages/TZ_AI.md`

---

```markdown
# TECHNICAL SPECIFICATION: AI Module

**Module ID:** `ai`
**Module Name:** ShinobiCore - Enemy AI System
**Priority:** 3 (third wave, alongside worldgen, world)
**Core dependency:** Sprint 1 (ModuleManager) + Sprint 2 (all core services) + Jutsu module gateway

---

## 1. PURPOSE

Implement the complete enemy AI system:

- Enemy entity (NinjaEnemyEntity) with configurable stats
- 5 rank tiers: genin, chunin, jonin, special, boss
- Finite State Machine (FSM) combat controller
- Tactical behavior: patrol, approach, telegraph, attack, block, parry, retreat, flee
- Real jutsu casting via JutsuCastGatewayApi (from Jutsu module)
- Simplified chakra component for enemies (not shared with players)
- Rank-based stat scaling (HP, damage, speed, reaction, jutsu count)
- Rank-based loot tables
- Natural spawning (biome-based, night-based)
- Structure-based spawning (enemy camps, training camps)
- Active enemy limits (performance)
- Telegraph system (visual warning before attacks)
- Kawarimi (substitution jutsu) as escape mechanic
- Block and parry behavior (defensive AI)

**NOT in scope** (belong to other modules):
- Jutsu casting logic → Jutsu module (we call their gateway)
- Player chakra management → core ChakraApi
- Visual effects → Visual module
- HUD rendering → HUD module
- World generation (enemy camp structures) → Worldgen module
- Combat formulas for player → Combat module

---

## 2. FILE OWNERSHIP

The AI team may ONLY create and modify files in these locations:

```
src/main/java/com/example/shinobicore/modules/ai/
src/main/resources/data/shinobicore/ai/              (rank JSON, spawn rules, loot tables)
src/main/resources/assets/shinobicore/ai/            (textures, models, sounds)
config/shinobicore/modules/ai.json                   (generated at runtime)
```

The AI team MUST NOT modify:
- Any file under `core/`
- `ShinobiCoreMod.java` or `ShinobiCoreClient.java`
- Any file belonging to another module
- `fabric.mod.json` (entrypoint addition is done by core team)

---

## 3. ARCHITECTURE

### 3.1 Package structure

```
modules/ai/
├── AiModule.java                             (entry point, implements ShinobiModule)
├── config/
│   ├── AiConfig.java
│   └── AiConfigLoader.java
├── data/
│   ├── RankDefinition.java                   (record: rank JSON)
│   ├── SpawnRuleDefinition.java              (record: spawn rule JSON)
│   ├── LootTableDefinition.java              (record: loot table JSON)
│   ├── AiDataLoader.java
│   ├── RankRegistry.java
│   ├── SpawnRuleRegistry.java
│   ├── LootTableRegistry.java
│   └── AiJsonValidator.java
├── entity/
│   ├── NinjaEnemyEntity.java                 (main enemy entity)
│   ├── EnemyAttributeBuilder.java            (attribute scaling by rank)
│   ├── EnemyChakraComponent.java             (simplified chakra for enemies)
│   ├── EnemyChakraComponentImpl.java
│   └── EnemyChakraComponentKey.java
├── ai/
│   ├── EnemyAiController.java                (FSM controller)
│   ├── EnemyState.java                       (enum: FSM states)
│   ├── EnemyBlackboard.java                  (shared AI memory)
│   ├── StateHandlers/
│   │   ├── IdleStateHandler.java
│   │   ├── PatrolStateHandler.java
│   │   ├── ApproachStateHandler.java
│   │   ├── TelegraphStateHandler.java
│   │   ├── AttackStateHandler.java
│   │   ├── BlockStateHandler.java
│   │   ├── ParryStateHandler.java
│   │   ├── CastStateHandler.java
│   │   ├── KawarimiStateHandler.java
│   │   ├── RetreatStateHandler.java
│   │   └── FleeStateHandler.java
│   ├── TargetSelectionService.java
│   ├── AttackTimingService.java
│   ├── JutsuSelectionService.java
│   └── EscapeDecisionService.java
├── spawn/
│   ├── EnemySpawnService.java
│   ├── NaturalSpawnHandler.java
│   ├── StructureSpawnHandler.java
│   ├── NightSpawnHandler.java
│   └── SpawnLimiter.java
├── loot/
│   ├── EnemyLootService.java
│   └── LootRoller.java
├── component/
│   ├── EnemyComponentKey.java
│   ├── EnemyComponentImpl.java
│   └── EnemyComponentInitializer.java
├── network/
│   ├── AiPackets.java
│   ├── EnemyStateSyncPacket.java             (server -> client)
│   └── EnemyTelegraphPacket.java             (server -> client)
├── client/
│   ├── EnemyStateRenderer.java               (state indicator above head)
│   ├── TelegraphRenderer.java                (telegraph warning visual)
│   └── EnemyRenderer.java                    (entity renderer)
└── view/
    └── EnemyVisualViewImpl.java              (implements EnemyVisualView)
```

### 3.2 Module entry point

```java
public class AiModule implements ShinobiModule {
    public static final String ID = "ai";

    @Override public String id() { return ID; }

    @Override
    public void onRegister(ModuleContext ctx) {
        EnemyComponentKey.register();
        EnemyChakraComponentKey.register();
    }

    @Override
    public void onEnable(ModuleContext ctx) {
        AiConfig.load(ctx.configs().readModuleConfig(ID));

        // Load data
        AiDataLoader.load();
        RankRegistry.build();
        SpawnRuleRegistry.build();
        LootTableRegistry.build();
        AiJsonValidator.validateAll();

        // Init services
        EnemySpawnService.init();
        EnemyLootService.init();
        EnemyAiController.init();
        TargetSelectionService.init();
        JutsuSelectionService.init();

        // Register entity
        ModEntities.registerNinjaEnemy();

        AiPackets.registerServer();
    }

    @Override
    public void registerEvents(ModuleContext ctx) {
        ctx.events().subscribe(PlayerJoinEvent.class, e -> {
            // Sync active enemy count to client
        });
        ctx.events().subscribe(PlayerDiedEvent.class, e -> {
            // Enemies may flee or continue attacking
        });
    }

    @Override
    public void registerViews(ModuleContext ctx) {
        ctx.views().register(EnemyVisualView.class, player ->
            Optional.of(new EnemyVisualViewImpl(player)));
    }

    @Override
    public void registerCommands(ModuleContext ctx, CommandDispatcher<ServerCommandSource> d) {
        AiCommands.register(d);
    }

    @Override
    public void onServerTick(ModuleContext ctx, MinecraftServer server) {
        EnemySpawnService.serverTick(server);
        EnemyAiController.serverTick(server);
    }
}
```

---

## 4. CORE API TO USE

### 4.1 JutsuCastGatewayApi (from Jutsu module)

```java
CoreServices.get(JutsuCastGatewayApi.class).ifPresent(gateway -> {
    if (gateway.isJutsuAvailable("shinobicore:fireball")) {
        gateway.tryCast(enemy, "shinobicore:fireball", targetPlayer);
    }
});
```

If Jutsu module is disabled, `JutsuCastGatewayApi` will not be registered, and enemies will not cast jutsu (melee only).

### 4.2 ChakraApi (for enemy chakra)

Enemies use a simplified chakra component, NOT the player chakra component:

```java
Optional<EnemyChakraComponent> chakraOpt = EnemyChakraComponentKey.get(enemy);
chakraOpt.ifPresent(chakra -> {
    float current = chakra.getCurrent();
    boolean spent = chakra.trySpend(cost);
});
```

### 4.3 Events to publish

```java
public record EnemySpawnedEvent(NinjaEnemyEntity enemy, String rankId) {}
public record EnemyStateChangedEvent(NinjaEnemyEntity enemy, EnemyState oldState, EnemyState newState) {}
public record EnemyCastEvent(NinjaEnemyEntity enemy, String jutsuId, Entity target) {}
public record EnemyKilledEvent(NinjaEnemyEntity enemy, Entity killer, String rankId) {}
public record EnemyTelegraphEvent(NinjaEnemyEntity enemy, Entity target, int telegraphTicks) {}
public record EnemyFledEvent(NinjaEnemyEntity enemy) {}
```

### 4.4 Events to subscribe

```
PlayerJoinEvent         -> sync enemy count
PlayerDiedEvent         -> enemies may flee or continue
PlayerRespawnedEvent    -> reset enemy aggression
```

---

## 5. VIEWS TO REGISTER

Register one view (for Visual module to read enemy state):

```java
public interface EnemyVisualView {
    boolean isAlive();
    String getRank();
    EnemyState getCurrentState();
    boolean isCasting();
    boolean isBlocking();
    boolean isTelegraphing();
    float getTelegraphProgress();   // 0.0 - 1.0
    int getTelegraphTicksRemaining();
    Entity getTarget();
}
```

---

## 6. MECHANICS — DETAILED BEHAVIOR

### 6.1 Rank definitions (JSON)

```json
{
  "id": "genin",
  "name": "Genin",
  "color": "#44AA44",
  "maxHp": 40.0,
  "meleeDamage": 5.0,
  "movementSpeed": 0.28,
  "followRange": 24.0,
  "reactionTicks": 20,
  "blockChance": 0.1,
  "parryChance": 0.05,
  "kawarimiChance": 0.0,
  "jutsuCount": 1,
  "jutsuCooldownTicks": 120,
  "jutsus": ["shinobicore:test_projectile"],
  "lootTable": "genin_loot",
  "xpReward": 10
}
```

### 6.2 All 5 ranks

| Rank | HP | Damage | Speed | Reaction | Block% | Parry% | Kawarimi% | Jutsu Count | XP |
|------|-----|--------|-------|----------|--------|--------|-----------|-------------|-----|
| genin | 40 | 5 | 0.28 | 20 | 10% | 5% | 0% | 1 | 10 |
| chunin | 60 | 7 | 0.30 | 15 | 20% | 10% | 5% | 2 | 25 |
| jonin | 90 | 10 | 0.32 | 10 | 30% | 20% | 10% | 3 | 50 |
| special | 120 | 12 | 0.34 | 8 | 40% | 30% | 15% | 4 | 75 |
| boss | 200 | 15 | 0.36 | 5 | 50% | 40% | 20% | 5 | 150 |

### 6.3 FSM states

```java
public enum EnemyState {
    IDLE,           // Standing still, no target
    PATROL,         // Walking around spawn point
    APPROACH,       // Moving toward target
    TELEGRAPH,      // Warning before attack (visual indicator)
    ATTACK,         // Melee attack
    CAST,           // Casting jutsu
    BLOCK,          // Blocking incoming attacks
    PARRY,          // Parrying incoming attacks
    KAWARIMI,       // Substitution jutsu (escape)
    RETREAT,        // Backing away (low HP or chakra)
    FLEE            // Running away (critical HP or no chakra)
}
```

### 6.4 FSM transitions

```
IDLE -> PATROL          (after idleTicks > idleDuration)
PATROL -> APPROACH      (target detected within followRange)
APPROACH -> TELEGRAPH   (within attackRange)
TELEGRAPH -> ATTACK     (after telegraphTicks)
TELEGRAPH -> CAST       (if jutsu available and chakra sufficient)
ATTACK -> BLOCK         (if incoming attack detected and blockChance roll succeeds)
ATTACK -> PARRY         (if incoming attack detected and parryChance roll succeeds)
ATTACK -> KAWARIMI      (if HP < kawarimiThreshold and kawarimiChance roll succeeds)
ATTACK -> RETREAT       (if HP < retreatThreshold)
RETREAT -> FLEE         (if HP < fleeThreshold or chakra == 0)
FLEE -> IDLE            (after fleeDuration or out of followRange)
ANY -> APPROACH         (if target lost and re-detected)
```

### 6.5 State behaviors

**IDLE:**
- Stand still
- Look around randomly
- No movement
- Transition to PATROL after `idleDuration` ticks

**PATROL:**
- Walk around spawn point (radius: `patrolRadius`)
- Random direction changes every `patrolDirectionChangeTicks`
- Detect targets within `followRange`
- Transition to APPROACH when target detected

**APPROACH:**
- Move toward target using pathfinding
- Maintain distance based on rank (melee: 1-2 blocks, ranged: 5-10 blocks)
- Transition to TELEGRAPH when within attack range
- Transition to CAST if jutsu available and target out of melee range

**TELEGRAPH:**
- Stop moving
- Display telegraph indicator (visual warning above head)
- Duration: `telegraphTicks` (varies by rank: genin=20, chunin=15, jonin=10, special=8, boss=5)
- Transition to ATTACK or CAST after telegraph completes
- Can be interrupted if player dodges out of range

**ATTACK:**
- Execute melee attack
- Apply damage via `EnemyAttributeBuilder.getMeleeDamage(rank)`
- Apply knockback
- Transition back to APPROACH or BLOCK

**CAST:**
- Select jutsu via `JutsuSelectionService`
- Call `JutsuCastGatewayApi.tryCast(enemy, jutsuId, target)`
- Deduct chakra from `EnemyChakraComponent`
- Transition to APPROACH after cast

**BLOCK:**
- Reduce incoming damage by `blockDamageReduction`
- Duration: `blockDurationTicks`
- Transition back to ATTACK or APPROACH

**PARRY:**
- Negate incoming damage
- Stagger attacker (player)
- Duration: `parryWindowTicks`
- Transition back to ATTACK or APPROACH

**KAWARIMI:**
- Teleport to random location within `kawarimiRadius`
- Spawn smoke particles
- Brief invulnerability (`kawarimiInvulnTicks`)
- Transition to RETREAT or FLEE

**RETREAT:**
- Move away from target
- Maintain distance > `retreatDistance`
- Transition to FLEE if HP < fleeThreshold

**FLEE:**
- Run away from target at max speed
- Duration: `fleeDurationTicks`
- Transition to IDLE if out of followRange or after fleeDuration

### 6.6 Target selection

```java
public final class TargetSelectionService {
    public static ServerPlayerEntity selectTarget(NinjaEnemyEntity enemy) {
        ServerWorld world = (ServerWorld) enemy.getWorld();
        double followRange = enemy.getAttributeValue(EntityAttributes.GENERIC_FOLLOW_RANGE);

        // Find closest player within followRange
        PlayerEntity closest = world.getClosestPlayer(
            enemy.getX(), enemy.getY(), enemy.getZ(),
            followRange, null);

        if (closest instanceof ServerPlayerEntity sp && !sp.isSpectator()) {
            return sp;
        }
        return null;
    }
}
```

### 6.7 Jutsu selection

```java
public final class JutsuSelectionService {
    public static Optional<String> selectJutsu(NinjaEnemyEntity enemy, Entity target) {
        Optional<JutsuCastGatewayApi> gatewayOpt = CoreServices.get(JutsuCastGatewayApi.class);
        if (gatewayOpt.isEmpty()) return Optional.empty();

        Optional<EnemyChakraComponent> chakraOpt = EnemyChakraComponentKey.get(enemy);
        if (chakraOpt.isEmpty()) return Optional.empty();

        RankDefinition rank = RankRegistry.get(enemy.getRankId()).orElse(null);
        if (rank == null) return Optional.empty();

        // Filter jutsu by chakra cost and cooldown
        List<String> available = rank.jutsus().stream()
            .filter(jutsuId -> gatewayOpt.get().isJutsuAvailable(jutsuId))
            .filter(jutsuId -> !enemy.isJutsuOnCooldown(jutsuId))
            .filter(jutsuId -> {
                float cost = getJutsuCost(jutsuId);
                return chakraOpt.get().getCurrent() >= cost;
            })
            .toList();

        if (available.isEmpty()) return Optional.empty();

        // Random selection (or weighted by distance to target)
        return Optional.of(available.get(enemy.getRandom().nextInt(available.size())));
    }
}
```

### 6.8 Spawn rules

**Natural spawning:**
- Biome-based: certain biomes have higher spawn rates
- Night-based: higher spawn rate at night (max `nightSpawnLimit` per night)
- Light-based: spawn only in light level < `maxLightLevel`
- Distance-based: spawn only if player within `spawnRadius`

**Structure spawning:**
- Enemy camps: spawn `enemyCampSpawnCount` enemies
- Training camps: spawn `trainingCampSpawnCount` enemies
- Spawn on structure load

**Spawn limits:**
- `maxActiveEnemies`: global limit (default 12)
- `maxEnemiesPerPlayer`: per-player limit (default 4)
- `spawnCooldownTicks`: cooldown between spawn attempts

### 6.9 Loot tables

```json
{
  "id": "genin_loot",
  "entries": [
    { "item": "shinobicore:kunai", "weight": 30, "minCount": 1, "maxCount": 2 },
    { "item": "shinobicore:shuriken", "weight": 30, "minCount": 2, "maxCount": 4 },
    { "item": "shinobicore:scroll_fragment", "weight": 10, "minCount": 1, "maxCount": 1 },
    { "item": "minecraft:emerald", "weight": 20, "minCount": 1, "maxCount": 3 },
    { "item": "minecraft:iron_ingot", "weight": 10, "minCount": 1, "maxCount": 2 }
  ]
}
```

### 6.10 Telegraph system

Telegraph is a visual warning before attack:

```
Trigger: EnemyState.TELEGRAPH
Duration: telegraphTicks (varies by rank)
Visual: Red/orange indicator above enemy head
Sound: "shinobicore:telegraph_melee" or "shinobicore:telegraph_ranged"
```

Client renders telegraph via `TelegraphRenderer`:
- Progress bar above enemy head
- Color changes from yellow to red as telegraph completes
- Sound plays on telegraph start

---

## 7. CLIENT-SERVER AUTHORITY

```
SERVER (authoritative for AI):
- All FSM logic runs on server
- Enemy movement, attacks, jutsu casting
- Spawn/despawn logic
- Loot generation
- State sync to client

CLIENT (read-only):
- Renders enemy state (via EnemyVisualView)
- Renders telegraph indicators
- Renders state indicators (blocking, casting, etc.)
- No AI logic on client
```

### CRITICAL PACKET RULE

```java
ServerPlayNetworking.registerGlobalReceiver(ID, (server, player, handler, buf, sender) -> {
    // STEP 1: Read ALL data from buffer FIRST
    final int entityId = buf.readInt();

    // STEP 2: Execute on server thread
    server.execute(() -> {
        // Handle packet
    });
});
```

NEVER read `buf` inside `server.execute()`.

---

## 8. FULL CONFIG TEMPLATE

File: `config/shinobicore/modules/ai.json` (auto-created on first run)

```json
{
  "enabled": true,
  "debug": false,

  "ranks": {
    "genin": { "enabled": true },
    "chunin": { "enabled": true },
    "jonin": { "enabled": true },
    "special": { "enabled": true },
    "boss": { "enabled": true }
  },

  "spawn": {
    "enabled": true,
    "maxActiveEnemies": 12,
    "maxEnemiesPerPlayer": 4,
    "spawnCooldownTicks": 100,
    "spawnRadius": 32.0,
    "maxLightLevel": 7,
    "nightSpawnMultiplier": 2.0,
    "nightSpawnLimit": 5,
    "biomeSpawnWeights": {
      "minecraft:forest": 10,
      "minecraft:plains": 8,
      "minecraft:taiga": 6,
      "minecraft:swamp": 12
    }
  },

  "structureSpawn": {
    "enabled": true,
    "enemyCampSpawnCount": 3,
    "trainingCampSpawnCount": 2
  },

  "ai": {
    "idleDurationTicks": 60,
    "patrolRadius": 8.0,
    "patrolDirectionChangeTicks": 40,
    "telegraphTicks": {
      "genin": 20,
      "chunin": 15,
      "jonin": 10,
      "special": 8,
      "boss": 5
    },
    "blockDamageReduction": 0.4,
    "parryWindowTicks": 10,
    "kawarimiRadius": 8.0,
    "kawarimiInvulnTicks": 20,
    "retreatThreshold": 0.3,
    "fleeThreshold": 0.15,
    "fleeDurationTicks": 100
  },

  "jutsu": {
    "enabled": true,
    "jutsuCooldownMultiplier": 1.0
  },

  "logging": {
    "logSpawns": false,
    "logStateChanges": false,
    "logJutsuCasts": false,
    "logDeaths": true
  }
}
```

### JSON data files

AI team is responsible for these data directories:

```
data/shinobicore/ai/
├── ranks/
│   ├── genin.json
│   ├── chunin.json
│   ├── jonin.json
│   ├── special.json
│   └── boss.json
├── spawn/
│   ├── natural_spawn.json
│   └── structure_spawn.json
├── loot/
│   ├── genin_loot.json
│   ├── chunin_loot.json
│   ├── jonin_loot.json
│   ├── special_loot.json
│   └── boss_loot.json
└── balance/
    ├── reaction_scaling.json
    └── jutsu_selection.json
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
/shinobicore ai spawn <rank>              - spawn enemy of given rank
/shinobicore ai spawn <rank> <count>      - spawn multiple enemies
/shinobicore ai info                      - show active enemy count, spawn stats
/shinobicore ai test                      - spawn one of each rank for testing
/shinobicore ai clear                     - despawn all AI enemies
/shinobicore ai debug                     - toggle debug overlay (show FSM states)
/shinobicore ai validate                  - validate all AI JSON (report errors)
```

---

## 10. FORBIDDEN PATTERNS

AI team MUST NOT do any of these:

1. **DO NOT** implement jutsu casting logic. Use `JutsuCastGatewayApi`.
2. **DO NOT** use player chakra component for enemies. Use `EnemyChakraComponent`.
3. **DO NOT** use `System.out.println`. Use `ShinobiLogger.module("ai", ...)`.
4. **DO NOT** hold enemy state in `static Map<UUID, State>` without cleanup on entity death.
5. **DO NOT** read `PacketByteBuf` inside `server.execute()`.
6. **DO NOT** crash on malformed rank/spawn/loot JSON. Log error, skip, continue.
7. **DO NOT** spawn unlimited enemies. Enforce `maxActiveEnemies` and `maxEnemiesPerPlayer`.
8. **DO NOT** create god-classes (>300 lines). Decompose by responsibility.
9. **DO NOT** import classes from other modules. Use core events/services/views only.
10. **DO NOT** make the module crash if Jutsu module is disabled. Handle missing `JutsuCastGatewayApi` gracefully.
11. **DO NOT** run AI logic on client. All FSM logic is server-side.
12. **DO NOT** spawn enemies in loaded chunks without checking spawn limits.

---

## 11. DEFINITION OF DONE

The AI module is complete when:

1. ✅ Module loads via `shinobicore:module` entrypoint
2. ✅ `/shinobicore systems` shows `ai: ENABLED`
3. ✅ All 5 rank JSON definitions load from `data/shinobicore/ai/ranks/`
4. ✅ Invalid JSON logs error, does not crash game
5. ✅ `NinjaEnemyEntity` spawns with correct stats per rank
6. ✅ FSM controller works (IDLE → PATROL → APPROACH → TELEGRAPH → ATTACK)
7. ✅ Enemies block incoming attacks (probability-based)
8. ✅ Enemies parry incoming attacks (probability-based)
9. ✅ Enemies use kawarimi to escape (probability-based)
10. ✅ Enemies retreat when HP low
11. ✅ Enemies flee when HP critical
12. ✅ Enemies cast jutsu via `JutsuCastGatewayApi` (when Jutsu module present)
13. ✅ Enemies do NOT crash when Jutsu module is disabled
14. ✅ Enemy chakra component works (spend on jutsu cast)
15. ✅ Natural spawning works (biome-based, night-based)
16. ✅ Structure spawning works (enemy camps, training camps)
17. ✅ Spawn limits enforced (`maxActiveEnemies`, `maxEnemiesPerPlayer`)
18. ✅ Loot tables work (rank-based loot)
19. ✅ Telegraph system works (visual warning before attack)
20. ✅ `EnemyVisualView` registered and readable by Visual module
21. ✅ Commands work (`spawn`, `info`, `test`, `clear`, `debug`, `validate`)
22. ✅ Log files `logs/shinobicore/ai-1.log` created and rotated
23. ✅ Module does not crash when other modules are disabled
24. ✅ Config file `ai.json` created on first run with defaults
25. ✅ Broken JSON does not crash the game
26. ✅ Build passes: `.\gradlew.bat build`

---

## 12. EXAMPLE CODE SNIPPETS

### 12.1 Enemy FSM controller

```java
public final class EnemyAiController {
    private static final Map<Integer, EnemyAiController> CONTROLLERS = new ConcurrentHashMap<>();

    public static void serverTick(MinecraftServer server) {
        for (ServerWorld world : server.getWorlds()) {
            for (Entity entity : world.getEntities()) {
                if (!(entity instanceof NinjaEnemyEntity enemy)) continue;

                EnemyAiController controller = CONTROLLERS.computeIfAbsent(
                    enemy.getId(), id -> new EnemyAiController(enemy));
                controller.tick();
            }
        }
    }

    private final NinjaEnemyEntity enemy;
    private EnemyState state = EnemyState.IDLE;
    private int stateTicks = 0;
    private ServerPlayerEntity target;

    private EnemyAiController(NinjaEnemyEntity enemy) {
        this.enemy = enemy;
    }

    public void tick() {
        stateTicks++;

        // Refresh target
        target = TargetSelectionService.selectTarget(enemy);

        switch (state) {
            case IDLE -> handleIdle();
            case PATROL -> handlePatrol();
            case APPROACH -> handleApproach();
            case TELEGRAPH -> handleTelegraph();
            case ATTACK -> handleAttack();
            case CAST -> handleCast();
            case BLOCK -> handleBlock();
            case PARRY -> handleParry();
            case KAWARIMI -> handleKawarimi();
            case RETREAT -> handleRetreat();
            case FLEE -> handleFlee();
        }
    }

    private void setState(EnemyState newState) {
        EnemyState oldState = this.state;
        this.state = newState;
        this.stateTicks = 0;
        CoreEvents.publish(new EnemyStateChangedEvent(enemy, oldState, newState));
    }

    private void handleIdle() {
        if (stateTicks > AiConfig.get().ai.idleDurationTicks) {
            setState(EnemyState.PATROL);
        }
    }

    private void handlePatrol() {
        if (target != null) {
            setState(EnemyState.APPROACH);
            return;
        }
        // Patrol logic: random movement around spawn point
    }

    private void handleApproach() {
        if (target == null) {
            setState(EnemyState.PATROL);
            return;
        }

        double distance = enemy.getPos().distanceTo(target.getPos());
        double attackRange = 2.0; // melee range

        if (distance <= attackRange) {
            setState(EnemyState.TELEGRAPH);
        } else {
            // Move toward target
            enemy.getMoveControl().moveTo(target.getX(), target.getY(), target.getZ(), 1.0);
        }
    }

    private void handleTelegraph() {
        int telegraphTicks = AiConfig.get().ai.telegraphTicks.get(enemy.getRankId());
        if (stateTicks >= telegraphTicks) {
            // Decide: attack or cast
            Optional<String> jutsuOpt = JutsuSelectionService.selectJutsu(enemy, target);
            if (jutsuOpt.isPresent()) {
                setState(EnemyState.CAST);
            } else {
                setState(EnemyState.ATTACK);
            }
        }
    }

    private void handleAttack() {
        if (target == null) {
            setState(EnemyState.APPROACH);
            return;
        }

        // Execute melee attack
        float damage = EnemyAttributeBuilder.getMeleeDamage(enemy.getRankId());
        target.damage(enemy.getDamageSources().mobAttack(enemy), damage);

        // Apply knockback
        Vec3d knockback = target.getPos().subtract(enemy.getPos()).normalize().multiply(0.5);
        target.addVelocity(knockback.x, 0.1, knockback.z);

        setState(EnemyState.APPROACH);
    }

    private void handleCast() {
        Optional<String> jutsuOpt = JutsuSelectionService.selectJutsu(enemy, target);
        if (jutsuOpt.isEmpty()) {
            setState(EnemyState.APPROACH);
            return;
        }

        String jutsuId = jutsuOpt.get();
        CoreServices.get(JutsuCastGatewayApi.class).ifPresent(gateway -> {
            boolean cast = gateway.tryCast(enemy, jutsuId, target);
            if (cast) {
                CoreEvents.publish(new EnemyCastEvent(enemy, jutsuId, target));
            }
        });

        setState(EnemyState.APPROACH);
    }
}
```

### 12.2 Enemy entity

```java
public class NinjaEnemyEntity extends PathAwareEntity {
    private String rankId = "genin";

    public NinjaEnemyEntity(EntityType<? extends PathAwareEntity> type, World world) {
        super(type, world);
    }

    public static DefaultAttributeContainer.Builder createNinjaEnemyAttributes() {
        return PathAwareEntity.createMobAttributes()
            .add(EntityAttributes.GENERIC_MAX_HEALTH, 40.0)
            .add(EntityAttributes.GENERIC_MOVEMENT_SPEED, 0.28)
            .add(EntityAttributes.GENERIC_FOLLOW_RANGE, 24.0)
            .add(EntityAttributes.GENERIC_ATTACK_DAMAGE, 5.0);
    }

    @Override
    protected void initGoals() {
        this.goalSelector.add(0, new SwimGoal(this));
        this.goalSelector.add(7, new WanderAroundFarGoal(this, 1.0));
        this.goalSelector.add(8, new LookAroundGoal(this));
    }

    public void setRankId(String rankId) {
        this.rankId = rankId;
        RankDefinition rank = RankRegistry.get(rankId).orElse(null);
        if (rank != null) {
            EnemyAttributeBuilder.applyRank(this, rank);
        }
    }

    public String getRankId() { return rankId; }

    @Override
    public void onDeath(DamageSource source) {
        super.onDeath(source);
        CoreEvents.publish(new EnemyKilledEvent(this, source.getAttacker(), rankId));
        EnemyLootService.dropLoot(this, rankId);
    }
}
```

### 12.3 Enemy chakra component

```java
public interface EnemyChakraComponent extends ComponentV3 {
    float getCurrent();
    float getMax();
    boolean trySpend(float amount);
    void add(float amount);
    void setCurrent(float value);
}

public final class EnemyChakraComponentImpl implements EnemyChakraComponent {
    private float current = 100.0f;
    private float max = 100.0f;

    @Override public float getCurrent() { return current; }
    @Override public float getMax() { return max; }

    @Override
    public boolean trySpend(float amount) {
        if (current < amount) return false;
        current -= amount;
        return true;
    }

    @Override
    public void add(float amount) {
        current = Math.min(max, current + amount);
    }

    @Override
    public void setCurrent(float value) {
        current = Math.max(0, Math.min(max, value));
    }

    @Override
    public void readFromNbt(NbtCompound tag) {
        current = tag.getFloat("current");
        max = tag.getFloat("max");
    }

    @Override
    public void writeToNbt(NbtCompound tag) {
        tag.putFloat("current", current);
        tag.putFloat("max", max);
    }
}
```

### 12.4 Spawn service

```java
public final class EnemySpawnService {
    private static int activeEnemyCount = 0;

    public static void serverTick(MinecraftServer server) {
        if (!AiConfig.get().spawn.enabled) return;

        // Check spawn cooldown
        if (spawnCooldown > 0) {
            spawnCooldown--;
            return;
        }

        // Check global limit
        if (activeEnemyCount >= AiConfig.get().spawn.maxActiveEnemies) return;

        // Try to spawn
        for (ServerPlayerEntity player : server.getPlayerManager().getPlayerList()) {
            if (getEnemiesNearPlayer(player) >= AiConfig.get().spawn.maxEnemiesPerPlayer) {
                continue;
            }

            Optional<BlockPos> spawnPosOpt = findSpawnPosition(player);
            if (spawnPosOpt.isEmpty()) continue;

            BlockPos spawnPos = spawnPosOpt.get();
            String rankId = selectRandomRank();

            NinjaEnemyEntity enemy = ModEntities.NINJA_ENEMY.create(player.getWorld());
            if (enemy == null) continue;

            enemy.setPosition(spawnPos.getX() + 0.5, spawnPos.getY(), spawnPos.getZ() + 0.5);
            enemy.setRankId(rankId);
            player.getWorld().spawnEntity(enemy);

            activeEnemyCount++;
            CoreEvents.publish(new EnemySpawnedEvent(enemy, rankId));

            spawnCooldown = AiConfig.get().spawn.spawnCooldownTicks;
            break; // One spawn per tick
        }
    }

    private static Optional<BlockPos> findSpawnPosition(ServerPlayerEntity player) {
        World world = player.getWorld();
        Random random = world.getRandom();

        for (int attempts = 0; attempts < 10; attempts++) {
            int dx = random.nextInt(32) - 16;
            int dz = random.nextInt(32) - 16;
            BlockPos pos = player.getBlockPos().add(dx, 0, dz);

            // Find ground
            while (pos.getY() > 0 && world.isAir(pos)) {
                pos = pos.down();
            }
            pos = pos.up();

            // Check light level
            if (world.getLightLevel(pos) > AiConfig.get().spawn.maxLightLevel) {
                continue;
            }

            // Check if spawnable
            if (world.getBlockState(pos.down()).isSolid() && world.isAir(pos)) {
                return Optional.of(pos);
            }
        }
        return Optional.empty();
    }

    private static String selectRandomRank() {
        // Weighted random selection
        // genin: 50%, chunin: 30%, jonin: 15%, special: 4%, boss: 1%
        double roll = Math.random();
        if (roll < 0.50) return "genin";
        if (roll < 0.80) return "chunin";
        if (roll < 0.95) return "jonin";
        if (roll < 0.99) return "special";
        return "boss";
    }
}
```

---

## 13. HANDOFF

When the AI team finishes, they must:

1. Run `.\gradlew.bat build` — must pass with 0 errors.
2. Run `.\gradlew.bat runClient` and manually verify:
   - `/shinobicore ai spawn genin` spawns a genin enemy
   - Enemy patrols, approaches, telegraphs, attacks
   - Enemy blocks/parries incoming attacks (probability-based)
   - Enemy casts jutsu (when Jutsu module present)
   - Enemy retreats/flees when HP low
   - `/shinobicore ai test` spawns one of each rank
   - Loot drops on enemy death
3. Verify that disabling the module via `ai.json` (`enabled: false`) does not break the game.
4. Verify that enemies do NOT crash when Jutsu module is disabled.
5. Verify that invalid rank/spawn/loot JSON does not crash the game.
6. Create a brief `modules/ai/README.md` describing non-obvious behaviors.
7. Notify the core team that the module is ready for integration review.

---

## END OF AI TECHNICAL SPECIFICATION
```

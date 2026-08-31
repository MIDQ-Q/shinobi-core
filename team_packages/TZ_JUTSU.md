# ТЗ #3: Jutsu (Техники)

Сохранить как: `team_packages/TZ_JUTSU.md`

---

```markdown
# TECHNICAL SPECIFICATION: Jutsu Module

**Module ID:** `jutsu`
**Module Name:** ShinobiCore - Jutsu System
**Priority:** 1 (first wave, alongside movement and combat)
**Core dependency:** Sprint 1 (ModuleManager) + Sprint 2 (Chakra, Stats, Clan, Progression, Formula services)

---

## 1. PURPOSE

Implement a complete shinobi technique (jutsu) system:

- Jutsu registry loaded from JSON (parameters) + Java behaviors
- Cast lifecycle: prepare → charge → release → cooldown
- Loadout slots (A / B / quick-select)
- Cast queue (buffer next cast while current is finishing)
- Interrupt mechanics (damage, movement, manual cancel)
- Cooldown tracking per jutsu per player
- Requirements validation (chakra, element, stats, clan, tree node, scroll, dojutsu)
- Jutsu levels and mastery (XP from usage)
- Projectile / AoE / Dash / Wall / Genjutsu / Utility / Melee buffer behaviors
- 2 test jutsu in first version (`test_projectile`, `test_dash`)
- Client prediction for responsive feel
- Server as authoritative source of truth
- AI-friendly cast gateway (for enemy module)
- Visual-friendly view (for visual/HUD modules)

**NOT in scope** (belong to other modules):
- Chakra management → core ChakraApi
- Stat / clan / progression data → core services
- Visual effects / particles / camera shake → Visual module (reads our view)
- HUD rendering → HUD module (reads our view)
- Enemy AI using jutsu → AI module (calls our gateway)
- Katana sheath / weapon imbue logic itself → Combat module (consumes our gateway)

---

## 2. FILE OWNERSHIP

The jutsu team may ONLY create and modify files in these locations:

```
src/main/java/com/example/shinobicore/modules/jutsu/
src/main/resources/data/shinobicore/jutsu/          (jutsu JSON definitions)
src/main/resources/data/shinobicore/jutsu_behaviors/ (behavior configs)
src/main/resources/assets/shinobicore/jutsu/        (textures, sounds, particles)
config/shinobicore/modules/jutsu.json               (generated at runtime)
```

The jutsu team MUST NOT modify:
- Any file under `core/`
- `ShinobiCoreMod.java` or `ShinobiCoreClient.java`
- Any file belonging to another module
- `fabric.mod.json` (entrypoint addition is done by core team)

---

## 3. ARCHITECTURE

### 3.1 Package structure

```
modules/jutsu/
├── JutsuModule.java                          (entry point, implements ClientAwareModule)
├── config/
│   ├── JutsuConfig.java                      (parsed JSON)
│   └── JutsuConfigLoader.java
├── data/
│   ├── JutsuDefinition.java                  (record: all JSON-loaded fields)
│   ├── JutsuRegistry.java                    (runtime registry)
│   ├── JutsuLoader.java                      (loads JSON from data/jutsu/)
│   ├── JutsuJsonValidator.java               (validates definitions)
│   └── JutsuElement.java                     (enum: fire, water, wind, lightning, earth, none)
├── behavior/
│   ├── JutsuBehavior.java                    (interface)
│   ├── BehaviorContext.java                  (context passed to behaviors)
│   ├── BehaviorRegistry.java                 (registry of behavior types)
│   ├── ProjectileBehavior.java
│   ├── AoeBehavior.java
│   ├── DashBehavior.java
│   ├── WallBehavior.java
│   ├── GenjutsuBehavior.java
│   ├── UtilityBehavior.java
│   └── MeleeBufferBehavior.java
├── cast/
│   ├── JutsuCastService.java                 (main cast orchestrator)
│   ├── JutsuCastSession.java                 (per-cast state)
│   ├── CastPhase.java                        (enum: IDLE, PREPARE, CHARGE, RELEASE, COOLDOWN)
│   ├── CastQueue.java                        (queue next cast while current finishes)
│   └── CastInterruptHandler.java             (damage/movement interrupts)
├── slot/
│   ├── JutsuSlotService.java                 (loadout management)
│   ├── JutsuLoadout.java                     (record: slots A/B/C)
│   └── JutsuSlotCycle.java                   (cycle through slots)
├── cooldown/
│   ├── JutsuCooldownService.java             (per-player per-jutsu cooldowns)
│   └── CooldownEntry.java                    (record)
├── requirement/
│   ├── JutsuRequirementService.java          (checks all requirements)
│   ├── RequirementCheckResult.java           (record)
│   └── Requirement.java                      (sealed interface + variants)
├── level/
│   ├── JutsuLevelService.java                (levels + mastery XP)
│   └── MasteryCurve.java                     (XP curve per jutsu)
├── gateway/
│   └── JutsuCastGatewayImpl.java             (implements JutsuCastGatewayApi for AI)
├── component/
│   ├── JutsuComponentKey.java                (CCA component key)
│   ├── JutsuComponentImpl.java               (CCA implementation)
│   └── JutsuComponentInitializer.java
├── client/
│   ├── JutsuClientState.java
│   ├── JutsuClientController.java            (client cast input handling)
│   ├── JutsuCastPrediction.java              (client-side prediction)
│   └── JutsuKeyBindings.java
├── network/
│   ├── JutsuPackets.java                     (packet registry)
│   ├── JutsuCastRequestPacket.java           (client -> server)
│   ├── JutsuCastCancelPacket.java            (client -> server)
│   ├── JutsuSlotChangePacket.java            (client -> server)
│   ├── JutsuStateSyncPacket.java             (server -> client)
│   └── JutsuCooldownSyncPacket.java          (server -> client)
└── view/
    └── JutsuVisualViewImpl.java              (implements JutsuVisualView)
```

### 3.2 Module entry point

```java
public class JutsuModule implements ClientAwareModule {
    public static final String ID = "jutsu";

    @Override public String id() { return ID; }

    @Override
    public void onRegister(ModuleContext ctx) {
        JutsuComponentKey.register();
    }

    @Override
    public void onEnable(ModuleContext ctx) {
        JutsuConfig.load(ctx.configs().readModuleConfig(ID));

        // Register behaviors BEFORE loading definitions
        BehaviorRegistry.registerDefaults();

        // Load jutsu definitions from JSON
        JutsuLoader.load();
        JutsuJsonValidator.validateAll();

        // Register core gateway service (for AI module)
        CoreServices.register(JutsuCastGatewayApi.class, new JutsuCastGatewayImpl());

        // Init services
        JutsuCastService.init();
        JutsuSlotService.init();
        JutsuCooldownService.init();
        JutsuRequirementService.init();
        JutsuLevelService.init();
        CastInterruptHandler.init();

        JutsuPackets.registerServer();
    }

    @Override
    public void registerEvents(ModuleContext ctx) {
        ctx.events().subscribe(ChakraChangedEvent.class, e -> {
            // If chakra drops below current cast cost -> cancel
            CastInterruptHandler.onChakraChanged(e.player());
        });
        ctx.events().subscribe(PlayerDiedEvent.class, e -> {
            JutsuCastService.cancelAll(e.player());
            JutsuCooldownService.resetAll(e.player());
        });
        ctx.events().subscribe(PlayerRespawnedEvent.class, e -> {
            JutsuSlotService.resetToDefaults(e.player());
        });
    }

    @Override
    public void registerViews(ModuleContext ctx) {
        ctx.views().register(JutsuVisualView.class, player ->
            Optional.of(new JutsuVisualViewImpl(player)));
    }

    @Override
    public void registerCommands(ModuleContext ctx, CommandDispatcher<ServerCommandSource> d) {
        JutsuCommands.register(d);
    }

    @Override
    public void onClientInit(ModuleContext ctx) {
        JutsuKeyBindings.register();
        JutsuClientController.init();
        JutsuPackets.registerClient();
    }

    @Override
    public void onClientTick(ModuleContext ctx) {
        JutsuClientController.tick();
    }

    @Override
    public void onServerTick(ModuleContext ctx, MinecraftServer server) {
        JutsuCastService.serverTick(server);
        JutsuCooldownService.serverTick(server);
        JutsuSlotService.serverTick(server);
    }
}
```

---

## 4. CORE API TO USE

### 4.1 ChakraApi

```java
CoreServices.get(ChakraApi.class).ifPresent(chakra -> {
    float current = chakra.getCurrent(player);
    boolean trySpend = chakra.trySpend(player, cost);  // atomic spend
});
```

### 4.2 StatsApi

```java
CoreServices.get(StatsApi.class).ifPresent(stats -> {
    int ninjutsu = stats.getStatLevel(player, "ninjutsu");
    int control  = stats.getStatLevel(player, "control");
});
```

### 4.3 ClanApi

```java
CoreServices.get(ClanApi.class).ifPresent(clan -> {
    float costMult = clan.getCostMultiplier(player, jutsuId);  // e.g., 0.8 for clan jutsu
    boolean clanJutsu = clan.isClanJutsu(player, jutsuId);
});
```

### 4.4 ProgressionApi

```java
CoreServices.get(ProgressionApi.class).ifPresent(prog -> {
    int level = prog.getJutsuLevel(player, jutsuId);
    int uses = prog.getJutsuUses(player, jutsuId);
    prog.addJutsuUse(player, jutsuId);  // +1 use, may trigger level-up
    boolean nodeUnlocked = prog.isNodeUnlocked(player, nodeId);
    boolean elementUnlocked = prog.isElementUnlocked(player, elementId);
});
```

### 4.5 FormulaApi

```java
CoreServices.get(FormulaApi.class).ifPresent(f -> {
    float cost = f.calcJutsuCost(player, jutsuId);
});
```

### 4.6 Events to publish

```java
public record JutsuCastStartedEvent(ServerPlayerEntity caster, String jutsuId, int slot) {}
public record JutsuCastTickEvent(ServerPlayerEntity caster, String jutsuId, CastPhase phase, float progress) {}
public record JutsuCastFinishedEvent(ServerPlayerEntity caster, String jutsuId, boolean success) {}
public record JutsuCastCancelledEvent(ServerPlayerEntity caster, String jutsuId, String reason) {}
public record JutsuProjectileSpawnedEvent(ServerPlayerEntity caster, Entity projectile, String jutsuId) {}
public record JutsuAreaCreatedEvent(ServerPlayerEntity caster, Vec3d center, float radius, String jutsuId) {}
public record JutsuWallCreatedEvent(ServerPlayerEntity caster, BlockPos origin, Direction facing, String jutsuId) {}
public record JutsuCooldownChangedEvent(ServerPlayerEntity player, String jutsuId, int remainingTicks) {}
public record JutsuLearnedEvent(ServerPlayerEntity player, String jutsuId) {}
public record JutsuForgottenEvent(ServerPlayerEntity player, String jutsuId) {}
public record JutsuSlotChangedEvent(ServerPlayerEntity player, int slot, String jutsuId) {}
```

### 4.7 Events to subscribe

```
ChakraChangedEvent            -> cancel cast if chakra too low
ChakraModeEnabledEvent        -> optional: speed up cast / boost
ChakraModeDisabledEvent       -> optional: revert bonuses
FatigueChangedEvent           -> may increase cost / slow cast
PlayerDiedEvent               -> cancel cast, reset cooldowns
PlayerRespawnedEvent          -> reset loadout to defaults
PlayerChangedDimensionEvent   -> cancel cast
```

---

## 5. GATEWAY API (for AI and Combat modules)

The jutsu module MUST register this service in `CoreServices`:

```java
public interface JutsuCastGatewayApi {
    /**
     * Try to cast a jutsu as a non-player entity (e.g., enemy).
     * Returns true if cast was initiated.
     */
    boolean tryCast(LivingEntity caster, String jutsuId, @Nullable Entity target);

    /**
     * Check if a jutsu is registered and available (even if caster cannot use it).
     */
    boolean isJutsuAvailable(String jutsuId);

    /**
     * Get a list of jutsu IDs available for a given rank (for AI loadout).
     */
    List<String> getJutsuByRank(String rank);
}
```

AI module calls:

```java
CoreServices.get(JutsuCastGatewayApi.class).ifPresent(gateway -> {
    if (gateway.isJutsuAvailable("shinobicore:fireball")) {
        gateway.tryCast(enemy, "shinobicore:fireball", targetPlayer);
    }
});
```

If jutsu module is disabled, the service is not registered, and AI must handle gracefully (Optional pattern).

---

## 6. VIEWS TO REGISTER

Register one view:

```java
public interface JutsuVisualView {
    // Cast state
    boolean isCasting();
    float getCastProgress();          // 0.0 - 1.0
    CastPhase getCurrentPhase();
    String getCurrentJutsuId();
    String getCurrentElementId();
    boolean isCharging();
    boolean isQueued();
    String getQueuedJutsuId();        // or null

    // Projectiles/zones currently active (for this player)
    List<ProjectileView> getActiveProjectiles();
    List<ZoneView> getActiveZones();
    List<WallView> getActiveWalls();

    // Loadout
    String getSlotJutsuId(int slot);  // slot 0..N
    int getSelectedSlot();
    int getSlotCount();

    // Cooldowns
    int getCooldownTicks(String jutsuId);
    int getMaxCooldownTicks(String jutsuId);
    float getCooldownProgress(String jutsuId);  // 0.0 - 1.0
}

public record ProjectileView(Entity entity, String jutsuId, String elementId, int ageTicks) {}
public record ZoneView(Vec3d center, float radius, String jutsuId, int remainingTicks) {}
public record WallView(BlockPos origin, Direction facing, String jutsuId, int remainingTicks) {}
```

---

## 7. MECHANICS — DETAILED BEHAVIOR

### 7.1 Jutsu definition (JSON)

```json
{
  "id": "shinobicore:fireball_basic",
  "name": "Fireball Jutsu",
  "element": "fire",
  "behavior": "projectile",
  "baseCost": 20.0,
  "cooldownTicks": 60,
  "prepareTicks": 10,
  "chargeTicks": 20,
  "releaseTicks": 5,
  "maxChargeMultiplier": 2.0,

  "requirements": {
    "minPlayerLevel": 5,
    "elements": ["fire"],
    "stats": { "ninjutsu": 3, "control": 2 },
    "clanJutsu": false,
    "treeNode": "fireball_basic_node",
    "scroll": null,
    "dojutsu": null
  },

  "behaviorData": {
    "projectileSpeed": 1.5,
    "projectileDamage": 6.0,
    "projectileGravity": 0.02,
    "projectileLifetimeTicks": 80,
    "impactRadius": 1.5,
    "fireTicksOnHit": 60
  },

  "scaling": {
    "damagePerLevel": 0.5,
    "costReductionPerLevel": 0.02,
    "cooldownReductionPerLevel": 2
  },

  "visual": {
    "castHandSeals": ["ram", "snake", "tiger"],
    "particleColor": "#FF6600",
    "soundCast": "shinobicore:jutsu_fireball_cast",
    "soundImpact": "shinobicore:jutsu_fireball_impact"
  }
}
```

Required fields: `id`, `name`, `element`, `behavior`, `baseCost`, `cooldownTicks`.
All other fields have defaults (see `JutsuDefinition` defaults).

### 7.2 Jutsu behavior interface

```java
public interface JutsuBehavior {
    String id();  // "projectile", "aoe", "dash", etc.

    /** Called when cast enters RELEASE phase. Spawns entities, applies effects. */
    void onRelease(BehaviorContext ctx);

    /** Called every tick while the behavior's spawned entities are alive. */
    void onTick(BehaviorContext ctx);

    /** Called when behavior's entities expire or are removed. */
    void onExpire(BehaviorContext ctx);

    /** Optional: custom interrupt logic. Return true to cancel cast. */
    default boolean shouldInterrupt(BehaviorContext ctx) { return false; }
}
```

### 7.3 BehaviorContext

```java
public final class BehaviorContext {
    public final LivingEntity caster;         // player or enemy
    public final String jutsuId;
    public final JutsuDefinition definition;
    public final JsonObject behaviorData;
    public final @Nullable Entity target;     // for AI-cast or targeted cast
    public final int casterLevel;             // jutsu level
    public final float chargeMultiplier;      // 1.0 = normal, up to maxChargeMultiplier
    public final ServerWorld world;

    // Helper to spawn entities registered by this behavior
    public void spawnProjectile(ProjectileEntity p);
    public void spawnZone(ZoneEntity z);
    public void spawnWall(WallEntity w);
}
```

### 7.4 Cast lifecycle

```
IDLE -> PREPARE -> CHARGE -> RELEASE -> COOLDOWN -> IDLE
         (ticks)  (ticks)  (ticks)     (ticks)
```

- **PREPARE**: hand seals animation, no effect yet, chakra not yet spent (or partial reserve)
- **CHARGE**: player holds cast key, builds charge (optional, some jutsu have 0 charge time)
- **RELEASE**: chakra spent, behavior's `onRelease()` called, projectile/zone/wall spawned
- **COOLDOWN**: jutsu cannot be recast until cooldown expires

Interrupt points:
- Damage taken during PREPARE or CHARGE -> cancel (configurable chance)
- Movement input during PREPARE (if not move-castable) -> cancel
- Manual cancel (release key before RELEASE phase) -> cancel, partial chakra refund
- Death -> cancel

### 7.5 Loadout slots

Default: 3 slots (A, B, C). Configurable.

```java
public record JutsuLoadout(
    String slotA,  // jutsuId or null
    String slotB,
    String slotC,
    int selected   // 0..2
) {}
```

Player actions:
- Press slot hotkey → select slot
- Press cast key → cast selected slot's jutsu
- Cycle slot key → next slot
- Set slot key + open screen → assign jutsu to slot

Only LEARNED jutsu (via `ProgressionApi.isNodeUnlocked(player, nodeId)`) can be assigned to slots.

### 7.6 Cast queue

While a cast is in RELEASE or COOLDOWN phase, player can press cast key for another slot:
- The next cast is queued
- When current cast finishes (or is interrupted), queued cast starts automatically
- Queue size: 1 (configurable)
- Queued cast goes through same lifecycle

This enables fluid combo casting without spam-clicking.

### 7.7 Requirements validation

`JutsuRequirementService` checks (in order):

1. Jutsu exists in registry
2. Player has learned it (via `ProgressionApi.isNodeUnlocked(nodeId)`)
3. Element unlocked (via `ProgressionApi.isElementUnlocked(element)`)
4. Player level >= minPlayerLevel
5. Required stats at required levels
6. Clan requirement met (if `clanJutsu=true`, must match player clan)
7. Scroll requirement (item in inventory, optional)
8. Dojutsu requirement (active dojutsu, optional — future)
9. Not on cooldown
10. Has enough chakra (after formula modifiers)

Returns `RequirementCheckResult`:
```java
public record RequirementCheckResult(
    boolean ok,
    String failReason,        // "insufficient_chakra" | "cooldown" | "not_learned" | ...
    float chakraNeeded        // only if failReason == "insufficient_chakra"
) {}
```

### 7.8 Cooldown tracking

Per-player, per-jutsu:
```java
public record CooldownEntry(String jutsuId, int remainingTicks, int maxTicks) {}
```

Cooldown reduction via:
- Jutsu level (`scaling.cooldownReductionPerLevel`)
- Clan bonuses (via ClanApi)
- Stats (control, focus)

Minimum cooldown: 1 tick (never 0, prevent spam).

### 7.9 Jutsu levels and mastery

XP sources (via `ProgressionApi.addJutsuUse`):
- Successful cast: +1 use
- Damage dealt by jutsu: +XP proportional to damage
- Kill by jutsu: +bonus XP
- Training (mini-game): +bonus XP

Leveling:
```
xpForLevel(N) = base * pow(N, exponent)
```

Each level grants:
- +damage (per `scaling.damagePerLevel`)
- -cost (per `scaling.costReductionPerLevel`)
- -cooldown (per `scaling.cooldownReductionPerLevel`)

Max level: configurable (default 10).

### 7.10 Test jutsu (v1)

**`test_projectile`** (element: fire, behavior: projectile)
- Basic fireball
- Cost: 10, cooldown: 40 ticks, charge: 15 ticks
- Damage: 4, range: 30 blocks
- No special requirements (always available if module loaded)

**`test_dash`** (element: none, behavior: dash)
- Short forward dash
- Cost: 5, cooldown: 20 ticks, instant release
- Distance: 5 blocks
- Grants 4 i-frames during dash
- No special requirements

These two serve as:
- Proof that the full cast lifecycle works
- Proof that behaviors can spawn entities and apply effects
- Proof that requirements, cooldowns, levels, slots all work together
- Test harness for visual module and HUD module

---

## 8. CLIENT-SERVER AUTHORITY

```
CLIENT (authoritative for feel):
- Cast input (press/hold/release keys)
- Slot selection
- Visual prediction (hand seals, charge glow, particle buildup)
- Sends packets:
  - JutsuCastRequestPacket (slot, pressTimestamp)
  - JutsuCastCancelPacket (reason)
  - JutsuSlotChangePacket (slot, jutsuId)

SERVER (authoritative for truth):
- Validates requirements
- Validates chakra (via ChakraApi)
- Drives actual cast lifecycle
- Spawns entities (projectile, zone, wall)
- Applies damage/effects via behavior
- Syncs state to client
- Soft-corrects on desync (log + adjust, never crash)
```

### CRITICAL PACKET RULE

```java
ServerPlayNetworking.registerGlobalReceiver(ID, (server, player, handler, buf, sender) -> {
    // STEP 1: Read ALL data from buffer FIRST
    final int slot = buf.readInt();
    final long pressTimestampMs = buf.readLong();
    final float yaw = buf.readFloat();
    final float pitch = buf.readFloat();

    // STEP 2: Execute on server thread
    server.execute(() -> {
        JutsuCastService.requestCast(player, slot, pressTimestampMs, yaw, pitch);
    });
});
```

NEVER read `buf` inside `server.execute()`.

---

## 9. FULL CONFIG TEMPLATE

File: `config/shinobicore/modules/jutsu.json` (auto-created on first run)

```json
{
  "enabled": true,
  "debug": false,

  "slots": {
    "count": 3,
    "cycleOrder": ["A", "B", "C"]
  },

  "cast": {
    "queueSize": 1,
    "interruptOnDamageChance": 0.5,
    "interruptOnMovement": true,
    "moveCastable": false,
    "partialRefundOnCancel": 0.3,
    "minChakraReserveToStart": 5.0
  },

  "cooldown": {
    "minCooldownTicks": 1,
    "globalCooldownTicks": 5
  },

  "levels": {
    "maxLevel": 10,
    "baseXp": 100,
    "exponent": 1.5,
    "xpPerDamage": 0.5,
    "xpPerKill": 50
  },

  "behaviors": {
    "projectile": { "enabled": true },
    "aoe": { "enabled": true },
    "dash": { "enabled": true },
    "wall": { "enabled": true },
    "genjutsu": { "enabled": false },
    "utility": { "enabled": true },
    "melee_buffer": { "enabled": true }
  },

  "test": {
    "includeTestJutsu": true,
    "testProjectileId": "shinobicore:test_projectile",
    "testDashId": "shinobicore:test_dash"
  },

  "client": {
    "predictCastVisuals": true,
    "predictCooldowns": true,
    "showChargeBar": true
  },

  "logging": {
    "logCasts": false,
    "logInterrupts": false,
    "logRequirementFails": false
  }
}
```

### Config rules

1. Config is read ONCE at module load.
2. Missing file -> default is created.
3. Missing field -> default used (module must NOT crash).
4. Invalid JSON -> log error, use defaults, module continues.
5. No hot reload.

---

## 10. COMMANDS

```
/shinobicore jutsu list                     - list all registered jutsu
/shinobicore jutsu list learned            - list jutsu player has learned
/shinobicore jutsu info <id>                - show jutsu details
/shinobicore jutsu learn <id>               - force-learn a jutsu (operator)
/shinobicore jutsu forget <id>              - force-forget a jutsu (operator)
/shinobicore jutsu select <slot>            - select slot (0..N-1)
/shinobicore jutsu assign <slot> <id>       - assign jutsu to slot
/shinobicore jutsu cast <slot>              - force cast (operator, bypass requirements)
/shinobicore jutsu setlevel <id> <level>    - set jutsu level (operator)
/shinobicore jutsu resetcooldowns           - reset all cooldowns
/shinobicore jutsu validate                 - validate all jutsu JSON (report errors)
/shinobicore jutsu reload                   - reload jutsu JSON (operator, dev-only)
/shinobicore jutsu debug                    - toggle debug overlay
```

---

## 11. FORBIDDEN PATTERNS

Jutsu team MUST NOT do any of these:

1. **DO NOT** manage chakra directly. Always use `ChakraApi.trySpend` / `ChakraApi.add`.
2. **DO NOT** store player jutsu data (learned, levels, loadout) in the jutsu module. Use `ProgressionApi` (owned by core / progression module).
3. **DO NOT** use `System.out.println`. Use `ShinobiLogger.module("jutsu", ...)`.
4. **DO NOT** hold player state in `static Map<UUID, State>` without cleanup on player disconnect.
5. **DO NOT** read `PacketByteBuf` inside `server.execute()`.
6. **DO NOT** crash on malformed jutsu JSON. Log error, skip jutsu, continue loading others.
7. **DO NOT** spawn projectiles/zones/walls client-side without server authority. Client only predicts visuals.
8. **DO NOT** create god-classes (>300 lines). Decompose by responsibility.
9. **DO NOT** import classes from other modules. Use core events/services/views only.
10. **DO NOT** make the module crash if another module is disabled. Always handle missing services gracefully.
11. **DO NOT** allow behaviors to directly call visual/HUD code. Publish events instead.
12. **DO NOT** hardcode jutsu stats in Java. Read from JSON.

---

## 12. DEFINITION OF DONE

The jutsu module is complete when:

1. ✅ Module loads via `shinobicore:module` entrypoint
2. ✅ `/shinobicore systems` shows `jutsu: ENABLED`
3. ✅ JSON jutsu definitions load from `data/shinobicore/jutsu/`
4. ✅ Invalid JSON logs error, does not crash game
5. ✅ All 7 behavior types are registered (even if not all used in v1)
6. ✅ 2 test jutsu (`test_projectile`, `test_dash`) work end-to-end
7. ✅ Cast lifecycle works: PREPARE → CHARGE → RELEASE → COOLDOWN
8. ✅ Cast queue works (queue next while current finishes)
9. ✅ Interrupt on damage works (configurable chance)
10. ✅ Interrupt on movement works (configurable)
11. ✅ Manual cancel refunds partial chakra
12. ✅ Cooldowns tracked per-player per-jutsu
13. ✅ All requirements validated before cast
14. ✅ Insufficient chakra → cast rejected with clear feedback
15. ✅ Slots work (A/B/C, cycle, assign, select)
16. ✅ Jutsu levels work (XP from use, scaling damage/cost/cooldown)
17. ✅ `JutsuCastGatewayApi` registered and works for AI-style callers
18. ✅ `JutsuVisualView` registered and readable by visual/HUD modules
19. ✅ Client prediction feels responsive
20. ✅ Server soft-validates actions, does not crash on anomaly
21. ✅ Commands work (`list`, `learn`, `forget`, `select`, `cast`, `setlevel`, `validate`)
22. ✅ Log files `logs/shinobicore/jutsu-1.log` created and rotated
23. ✅ Module does not crash when other modules are disabled
24. ✅ Config file `jutsu.json` created on first run with defaults
25. ✅ Broken JSON does not crash the game
26. ✅ All network packets follow "read first, execute second" rule
27. ✅ Build passes: `.\gradlew.bat build`

---

## 13. EXAMPLE CODE SNIPPETS

### 13.1 JutsuDefinition record

```java
public record JutsuDefinition(
    String id,
    String name,
    JutsuElement element,
    String behaviorId,
    float baseCost,
    int cooldownTicks,
    int prepareTicks,
    int chargeTicks,
    int releaseTicks,
    float maxChargeMultiplier,
    Requirements requirements,
    JsonObject behaviorData,
    Scaling scaling,
    VisualData visual
) {
    public record Requirements(
        int minPlayerLevel,
        List<String> elements,
        Map<String, Integer> stats,
        boolean clanJutsu,
        @Nullable String treeNode,
        @Nullable String scroll,
        @Nullable String dojutsu
    ) {
        public static Requirements DEFAULT = new Requirements(
            1, List.of(), Map.of(), false, null, null, null);
    }

    public record Scaling(
        float damagePerLevel,
        float costReductionPerLevel,
        int cooldownReductionPerLevel
    ) {
        public static Scaling DEFAULT = new Scaling(0.0f, 0.0f, 0);
    }

    public record VisualData(
        List<String> castHandSeals,
        String particleColor,
        String soundCast,
        String soundImpact
    ) {
        public static VisualData DEFAULT = new VisualData(List.of(), "#FFFFFF", "", "");
    }
}
```

### 13.2 Cast lifecycle state machine

```java
public final class JutsuCastSession {
    private final ServerPlayerEntity caster;
    private final String jutsuId;
    private final JutsuDefinition def;
    private final int slot;

    private CastPhase phase = CastPhase.PREPARE;
    private int ticksInPhase = 0;
    private float chargeMultiplier = 1.0f;
    private long startTimeMs;

    public void tick() {
        ticksInPhase++;

        switch (phase) {
            case PREPARE -> {
                if (ticksInPhase >= def.prepareTicks()) advanceToCharge();
            }
            case CHARGE -> {
                // Charge grows while player holds cast key
                if (ticksInPhase >= def.chargeTicks() || !casterHoldingKey()) {
                    advanceToRelease();
                }
            }
            case RELEASE -> {
                if (ticksInPhase == 1) executeRelease();
                if (ticksInPhase >= def.releaseTicks()) advanceToCooldown();
            }
            case COOLDOWN -> {
                if (ticksInPhase >= def.cooldownTicks()) finish();
            }
        }
    }

    private void executeRelease() {
        // Spend chakra
        float cost = CoreServices.require(FormulaApi.class)
            .calcJutsuCost(caster, jutsuId);
        ChakraApi chakra = CoreServices.require(ChakraApi.class);
        if (!chakra.trySpend(caster, cost)) {
            cancel("insufficient_chakra_at_release");
            return;
        }

        // Dispatch to behavior
        JutsuBehavior behavior = BehaviorRegistry.get(def.behaviorId());
        BehaviorContext ctx = new BehaviorContext(
            caster, jutsuId, def, def.behaviorData(), null,
            JutsuLevelService.getLevel(caster, jutsuId),
            chargeMultiplier, (ServerWorld) caster.getWorld());
        behavior.onRelease(ctx);

        // Publish event
        CoreEvents.publish(new JutsuCastFinishedEvent(caster, jutsuId, true));

        // Grant XP / use count
        CoreServices.get(ProgressionApi.class).ifPresent(p ->
            p.addJutsuUse(caster, jutsuId));
    }

    public void cancel(String reason) {
        // Partial refund
        float refund = JutsuConfig.get().cast.partialRefundOnCancel;
        if (refund > 0 && phase != CastPhase.PREPARE) {
            float cost = CoreServices.require(FormulaApi.class)
                .calcJutsuCost(caster, jutsuId);
            CoreServices.require(ChakraApi.class).add(caster, cost * refund);
        }
        CoreEvents.publish(new JutsuCastCancelledEvent(caster, jutsuId, reason));
    }
}
```

### 13.3 Behavior example: projectile

```java
public final class ProjectileBehavior implements JutsuBehavior {
    public static final String ID = "projectile";

    @Override public String id() { return ID; }

    @Override
    public void onRelease(BehaviorContext ctx) {
        JsonObject d = ctx.behaviorData();
        float speed = d.has("projectileSpeed") ? d.get("projectileSpeed").getAsFloat() : 1.5f;
        float damage = d.has("projectileDamage") ? d.get("projectileDamage").getAsFloat() : 4.0f;
        int lifetime = d.has("projectileLifetimeTicks")
            ? d.get("projectileLifetimeTicks").getAsInt() : 80;

        // Apply level scaling
        damage += ctx.casterLevel() * ctx.definition().scaling().damagePerLevel();
        damage *= ctx.chargeMultiplier();

        // Spawn projectile
        ShinobiProjectileEntity proj = new ShinobiProjectileEntity(
            ctx.world(), ctx.caster(),
            ctx.jutsuId(), ctx.definition().element().name(),
            damage, lifetime);

        Vec3d dir = ctx.caster().getRotationVector();
        proj.setVelocity(dir.x * speed, dir.y * speed, dir.z * speed);
        proj.setPos(
            ctx.caster().getX() + dir.x * 1.5,
            ctx.caster().getEyeY(),
            ctx.caster().getZ() + dir.z * 1.5);

        ctx.world().spawnEntity(proj);
        ctx.spawnProjectile(proj);

        CoreEvents.publish(new JutsuProjectileSpawnedEvent(
            (ServerPlayerEntity) ctx.caster(), proj, ctx.jutsuId()));
    }

    @Override public void onTick(BehaviorContext ctx) { /* nothing */ }
    @Override public void onExpire(BehaviorContext ctx) { /* cleanup */ }
}
```

### 13.4 Gateway for AI

```java
public final class JutsuCastGatewayImpl implements JutsuCastGatewayApi {

    @Override
    public boolean tryCast(LivingEntity caster, String jutsuId, @Nullable Entity target) {
        JutsuDefinition def = JutsuRegistry.get(jutsuId).orElse(null);
        if (def == null) {
            ShinobiLogger.module("jutsu", "Gateway: unknown jutsu " + jutsuId);
            return false;
        }

        // For non-player casters (enemies), we skip loadout/slot logic
        // and go straight to the cast service
        return JutsuCastService.startCastForEntity(caster, def, target);
    }

    @Override
    public boolean isJutsuAvailable(String jutsuId) {
        return JutsuRegistry.get(jutsuId).isPresent();
    }

    @Override
    public List<String> getJutsuByRank(String rank) {
        return JutsuRegistry.all().stream()
            .filter(d -> isAllowedForRank(d, rank))
            .map(JutsuDefinition::id)
            .toList();
    }

    private boolean isAllowedForRank(JutsuDefinition d, String rank) {
        // Simple heuristic: jutsu with higher baseCost / minPlayerLevel
        // are for higher ranks
        // AI team can refine this by reading ai.json rank loadouts
        return true; // permissive default
    }
}
```

### 13.5 JSON validator

```java
public final class JutsuJsonValidator {
    private static int errorCount = 0;

    public static void validateAll() {
        errorCount = 0;
        for (JutsuDefinition def : JutsuRegistry.all()) {
            validate(def);
        }
        if (errorCount > 0) {
            ShinobiLogger.error("jutsu",
                "Validation completed with " + errorCount + " errors. " +
                "Some jutsu may behave incorrectly.", null);
        } else {
            ShinobiLogger.module("jutsu", "All " + JutsuRegistry.size() +
                " jutsu validated successfully.");
        }
    }

    private static void validate(JutsuDefinition def) {
        if (def.baseCost() < 0) error(def, "baseCost < 0");
        if (def.cooldownTicks() < 0) error(def, "cooldownTicks < 0");
        if (def.prepareTicks() < 0) error(def, "prepareTicks < 0");
        if (def.chargeTicks() < 0) error(def, "chargeTicks < 0");
        if (def.releaseTicks() < 0) error(def, "releaseTicks < 0");
        if (def.maxChargeMultiplier() < 1.0f)
            error(def, "maxChargeMultiplier < 1.0");

        if (!BehaviorRegistry.isRegistered(def.behaviorId())) {
            error(def, "unknown behavior: " + def.behaviorId());
        }

        // Check element is valid
        if (def.element() == null) error(def, "null element");

        // Check stats are valid IDs
        for (String stat : def.requirements().stats().keySet()) {
            if (!StatsApi.VALID_STAT_IDS.contains(stat)) {
                error(def, "unknown stat id: " + stat);
            }
        }
    }

    private static void error(JutsuDefinition def, String msg) {
        ShinobiLogger.error("jutsu",
            "Validation error in " + def.id() + ": " + msg, null);
        errorCount++;
    }
}
```

---

## 14. HANDOFF

When the jutsu team finishes, they must:

1. Run `.\gradlew.bat build` — must pass with 0 errors.
2. Run `.\gradlew.bat runClient` and manually verify:
   - Cast `test_projectile`: fireball spawns, travels, impacts
   - Cast `test_dash`: player dashes with i-frames
   - Cooldowns prevent spam
   - Chakra is deducted
   - Slot cycling works
   - Jutsu levels increase with usage
3. Verify that disabling the module via `jutsu.json` (`enabled: false`) does not break the game.
4. Verify that other modules (combat, AI) load correctly and handle missing `JutsuCastGatewayApi` gracefully.
5. Verify that invalid jutsu JSON does not crash the game.
6. Create a brief `modules/jutsu/README.md` describing non-obvious behaviors.
7. Notify the core team that the module is ready for integration review.

---

## END OF JUTSU TECHNICAL SPECIFICATION
```

---

**Готово!** ТЗ для **Jutsu** написано. Это третий (и последний) модуль приоритета 1.

Следующие модули по плану:
1. ✅ Movement (готово)
2. ✅ Combat (готово)
3. ✅ Jutsu (готово)
4. **Progression** (приоритет 2)
5. **Clans** (приоритет 2)
6. **HUD** (приоритет 2)
7. **Visual** (приоритет 2)
8. AI (приоритет 3)
9. Worldgen (приоритет 3)
10. World (приоритет 3)

Скажи **"дальше"** — и я напишу ТЗ для **Progression** (следующий модуль приоритета 2).

```markdown
# SHINOBICORE 4.0.0 - CORE DOCUMENTATION

This file contains all architectural documentation for the ShinobiCore kernel.
Read this BEFORE writing any module code.

---

## 1. ARCHITECTURE OVERVIEW

### 1.1. High-level structure

```text
ShinobiCore (core kernel)
|
+-- Module Manager (auto-loads modules via Fabric entrypoint)
+-- CoreEvents (event bus)
+-- CoreViews (view registry for HUD/Visual)
+-- CoreServices (service registry for shared data)
+-- ShinobiLogger (rotating file logs)
+-- ModuleConfigLoader (per-module JSON configs)
+-- CoreCommands (diagnostic commands)
+-- CompatibilityChecker (dependency validation)
```

### 1.2. Module lifecycle

```text
1. Fabric loads ShinobiCoreMod.onInitialize()
2. Core initializes: Logger -> Config -> ModuleManager
3. ModuleManager discovers modules via entrypoint "shinobicore:module"
4. For each module:
   a. onRegister(ctx)     - module registers itself
   b. registerEvents(ctx)  - module subscribes to events
   c. registerViews(ctx)   - module registers view factories
   d. Check config enabled
   e. onEnable(ctx)        - module starts working
5. CommandRegistrationCallback:
   a. CoreCommands.register()
   b. For each enabled module: registerCommands(ctx, dispatcher)
6. ServerLifecycleEvents:
   a. SERVER_STARTING -> module.onServerStarting()
   b. END_SERVER_TICK -> module.onServerTick()
   c. SERVER_STOPPED  -> module.onServerStopping()
7. Client (if ClientAwareModule):
   a. onClientInit(ctx)
   b. END_CLIENT_TICK -> onClientTick(ctx)
```

### 1.3. Module isolation rules

```text
ALLOWED:
  module -> core API
  module -> core events
  module -> core services
  module -> registered views

FORBIDDEN:
  module -> another module's internal classes
  module -> direct modification of another module's data
  module -> direct method call to another module
```

### 1.4. Package structure

```text
com.example.shinobicore/
+-- ShinobiCoreMod.java          (main entry)
+-- ShinobiCoreClient.java       (client entry)
+-- core/
|   +-- api/                     (module interfaces)
|   +-- module/                  (module manager)
|   +-- event/                   (event bus)
|   +-- view/                    (view registry)
|   +-- service/                 (service registry)
|   +-- log/                     (logger)
|   +-- config/                  (config loader)
|   +-- command/                 (core commands)
|   +-- compat/                  (dependency checker)
+-- modules/
|   +-- <module_id>/             (each team's module)
+-- compat/                      (external mod adapters)
```

### 1.5. File ownership

Each team may ONLY modify files in their own module directory:

```text
modules/<module_id>/           - Java code
data/shinobicore/<module_id>/  - JSON data files
assets/shinobicore/<module_id>/ - textures, models, sounds
config/shinobicore/modules/<module_id>.json - module config
```

No team may modify:
- Anything in `core/`
- `ShinobiCoreMod.java`
- `ShinobiCoreClient.java`
- `fabric.mod.json` (entrypoint additions are done by core team)
- Another team's module directory

---

## 2. EVENTS SYSTEM

### 2.1. How events work

The core provides a simple typed event bus:

```java
// Subscribe (in your module's registerEvents method):
ctx.events().subscribe(MyEvent.class, event -> {
    // handle event
});

// Publish (anywhere in your module):
ctx.events().publish(new MyEvent(data));
```

Events are synchronous and execute on the thread that publishes them.
All event classes must be simple Java classes (records or POJOs).

### 2.2. Core lifecycle events (published by core)

| Event class | When published | Fields |
|------------|---------------|--------|
| `ModuleEnabledEvent` | Module enabled | `String moduleId` |
| `ModuleDisabledEvent` | Module disabled | `String moduleId, String reason` |

### 2.3. Player events (to be published by core in Sprint 2)

| Event class | When published | Fields |
|------------|---------------|--------|
| `PlayerJoinEvent` | Player joins world | `ServerPlayerEntity player` |
| `PlayerLeaveEvent` | Player leaves | `ServerPlayerEntity player` |
| `PlayerDiedEvent` | Player dies | `ServerPlayerEntity player` |
| `PlayerRespawnedEvent` | Player respawns | `ServerPlayerEntity player` |
| `PlayerChangedDimensionEvent` | Dimension change | `ServerPlayerEntity player` |

### 2.4. Chakra events (to be published by core in Sprint 2)

| Event class | When published | Fields |
|------------|---------------|--------|
| `ChakraChangedEvent` | Chakra value changed | `PlayerEntity player, float old, float current, float max` |
| `ChakraModeEnabledEvent` | Chakra mode ON | `PlayerEntity player` |
| `ChakraModeDisabledEvent` | Chakra mode OFF | `PlayerEntity player` |
| `FatigueChangedEvent` | Fatigue changed | `PlayerEntity player, float old, float current` |
| `ExhaustionChangedEvent` | Exhaustion state changed | `PlayerEntity player, boolean exhausted` |
| `MeditationStartedEvent` | Meditation started | `PlayerEntity player` |
| `MeditationStoppedEvent` | Meditation stopped | `PlayerEntity player` |

### 2.5. Progression events (to be published by core in Sprint 2)

| Event class | When published | Fields |
|------------|---------------|--------|
| `XpGainedEvent` | XP added | `ServerPlayerEntity player, int amount, String source` |
| `LevelChangedEvent` | Level up/down | `ServerPlayerEntity player, int oldLevel, int newLevel` |
| `SpGainedEvent` | SP added | `ServerPlayerEntity player, int amount` |
| `SpSpentEvent` | SP spent | `ServerPlayerEntity player, int amount, String reason` |
| `StatLevelChangedEvent` | Stat level changed | `ServerPlayerEntity player, String stat, int old, int current` |
| `JutsuLevelChangedEvent` | Jutsu level changed | `ServerPlayerEntity player, String jutsuId, int old, int current` |
| `ReputationChangedEvent` | Reputation changed | `ServerPlayerEntity player, String faction, int old, int current` |

### 2.6. Clan events (to be published by core in Sprint 2)

| Event class | When published | Fields |
|------------|---------------|--------|
| `ClanSelectedEvent` | Clan chosen | `ServerPlayerEntity player, String clanId` |
| `ClanChangedEvent` | Clan changed by operator | `ServerPlayerEntity player, String oldClan, String newClan` |

### 2.7. Module-specific events

Each module publishes its own events. See individual TZ documents.

### 2.8. Event naming convention

```text
<WhatHappened>Event
```

Examples:
- `WaterWalkStartedEvent`
- `CombatBlockedEvent`
- `JutsuCastFinishedEvent`

---

## 3. VIEWS SYSTEM

### 3.1. How views work

Views allow HUD and Visual modules to read data from other modules
without direct dependencies.

A module registers a ViewFactory during `registerViews()`:

```java
ctx.views().register(JutsuVisualView.class, player -> {
    return Optional.of(new JutsuVisualViewImpl(player));
});
```

The Visual or HUD module reads the view:

```java
Optional<JutsuVisualView> view = CoreViews.get(player, JutsuVisualView.class);
view.ifPresent(v -> {
    float progress = v.getCastProgress();
    // render progress bar
});
```

### 3.2. View contracts

Each view is an interface defined in the module that provides data.
The Visual/HUD modules depend on these interfaces, NOT on implementations.

### 3.3. Required views by module

| Module | View interface | Purpose |
|--------|---------------|---------|
| movement | `MovementVisualView` | Parkour state for visual/HUD |
| combat | `CombatVisualView` | Stance, block, combo for visual/HUD |
| jutsu | `JutsuVisualView` | Cast progress, projectiles for visual |
| progression | `ProgressionVisualView` | Level, XP for HUD |
| clans | `ClanVisualView` | Clan info for HUD |
| ai | `EnemyVisualView` | Enemy state for visual |

### 3.4. View interface templates

```java
// MovementVisualView
public interface MovementVisualView {
    boolean isWaterWalking();
    boolean isWallRunning();
    boolean isSliding();
    boolean isRolling();
    boolean isDodging();
    boolean isChargingJump();
    boolean isEdgeGrabbing();
    float getMoveSpeed();
    float getActionProgress(); // 0.0 - 1.0
}

// CombatVisualView
public interface CombatVisualView {
    String getCurrentStance();
    boolean isBlocking();
    boolean isParrying();
    int getComboStep();
    boolean isSheathed();
    boolean isThrowing();
    float getBlockProgress();
}

// JutsuVisualView
public interface JutsuVisualView {
    boolean isCasting();
    float getCastProgress(); // 0.0 - 1.0
    String getCurrentJutsuId();
    String getElementId();
    boolean isCharging();
    int getProjectileCount();
    int getZoneCount();
}

// ProgressionVisualView
public interface ProgressionVisualView {
    int getPlayerLevel();
    int getCurrentXp();
    int getXpToNextLevel();
    int getAvailableSp();
    float getProgressToNextLevel(); // 0.0 - 1.0
}

// ClanVisualView
public interface ClanVisualView {
    String getClanId();
    boolean hasClan();
    String getClanName();
    String getClanColor();
}

// EnemyVisualView
public interface EnemyVisualView {
    boolean isAlive();
    String getRank();
    String getCurrentState(); // idle, patrol, chase, attack, cast, retreat
    boolean isCasting();
}
```

---

## 4. CONFIG TEMPLATE

### 4.1. Config file location

Each module has its own config file:

```text
config/shinobicore/modules/<module_id>.json
```

### 4.2. Base config template

Every module config MUST include these fields:

```json
{
  "enabled": true,
  "debug": false
}
```

### 4.3. Config rules

1. Config is read ONCE at module load time.
2. No hot reload (game restart required).
3. If config file is missing, a default is created.
4. If config file is broken (invalid JSON), the module logs an error and uses defaults.
5. The module MUST NOT crash on bad config.

### 4.4. Reading config in your module

```java
@Override
public void onEnable(ModuleContext ctx) {
    JsonObject config = ctx.configs().readModuleConfig(id());

    boolean myFlag = true; // default
    if (config.has("myFlag")) {
        myFlag = config.get("myFlag").getAsBoolean();
    }

    float myValue = 1.0f; // default
    if (config.has("myValue")) {
        myValue = config.get("myValue").getAsFloat();
    }
}
```

### 4.5. Full config templates per module

See individual TZ documents for complete config templates.

---

## 5. NETWORK RULES

### 5.1. Packet ID naming

Each module uses its own packet ID prefix:

```text
shinobicore:<module_id>_<packet_name>
```

Examples:
```text
shinobicore:movement_action
shinobicore:movement_state_sync
shinobicore:combat_stance_change
shinobicore:combat_block_start
shinobicore:jutsu_cast_request
shinobicore:jutsu_cast_result
shinobicore:ai_enemy_state
```

### 5.2. Packet registration

Each module registers its own packets in `onEnable()` or `onClientInit()`.

```java
// Server-bound packet
ServerPlayNetworking.registerGlobalReceiver(MY_PACKET_ID, (server, player, handler, buf, sender) -> {
    // STEP 1: Read ALL data from buffer FIRST
    final int value = buf.readInt();
    final float speed = buf.readFloat();
    final String action = buf.readString();

    // STEP 2: Execute on server thread
    server.execute(() -> {
        // Server logic here
        // NEVER read buf here
    });
});
```

### 5.3. CRITICAL PACKET RULE

```text
NEVER read PacketByteBuf inside server.execute().
ALWAYS read all fields BEFORE server.execute().
Store read values in final local variables.
```

WRONG:
```java
ServerPlayNetworking.registerGlobalReceiver(ID, (server, player, handler, buf, sender) -> {
    server.execute(() -> {
        int value = buf.readInt(); // BUG: buf may be recycled
    });
});
```

CORRECT:
```java
ServerPlayNetworking.registerGlobalReceiver(ID, (server, player, handler, buf, sender) -> {
    final int value = buf.readInt(); // Read FIRST
    server.execute(() -> {
        // Use value here
    });
});
```

### 5.4. Client-server authority

```text
CLIENT:
- Fast response (movement, animations, HUD)
- Prediction
- Visual effects
- Input handling

SERVER (integrated server in singleplayer):
- Data persistence
- Sanity validation
- State saving
- Soft correction of anomalies

The client simulates. The server mirrors and saves.
```

### 5.5. Sync rules

Send packets ONLY when:
- State actually changed
- Value changed beyond a threshold
- Player joins/leaves/dies/changes dimension
- Admin command forces sync

Do NOT send packets:
- Every tick without changes
- For microscopic value changes below threshold

---

## 6. FORBIDDEN PATTERNS

### 6.1. Absolute prohibitions

| # | Forbidden | Why |
|---|-----------|-----|
| 1 | Import another module's internal classes | Breaks module isolation |
| 2 | Direct modification of shared data (chakra, stats, etc.) | Must go through core services |
| 3 | `System.out.println()` | Use `ShinobiLogger` |
| 4 | Static Maps by UUID without cleanup | Memory leak on player disconnect |
| 5 | Reading PacketByteBuf inside `server.execute()` | Buffer recycling bug |
| 6 | Hot config reload | Not supported, causes desync |
| 7 | Crashing the game on bad JSON/config | Must log error and use defaults |
| 8 | Classes over 300 lines | Decompose into smaller classes |
| 9 | God-classes doing everything | Single responsibility principle |
| 10 | Mixing client and server logic without checks | Use `world.isClient` guards |

### 6.2. Minecraft API pitfalls

| DO NOT | USE INSTEAD |
|--------|-------------|
| `block == Blocks.WOOL` | `block instanceof WoolBlock` |
| Cancel `tickMovement` in mixins | Apply movement modifiers safely |
| Aggressive client movement intercepts | Use client prediction + server mirror |
| Camera roll mixins | Not needed, do not add |

### 6.3. Architecture violations

```text
FORBIDDEN:
  modules/movement -> modules/combat (direct import)
  modules/jutsu -> modules/clans (direct import)
  modules/ai -> modules/jutsu internal classes

ALLOWED:
  modules/movement -> core.api, core.event, core.service, core.view
  modules/ai -> CoreServices.get(JutsuCastGatewayApi.class)
  modules/visual -> CoreViews.get(player, JutsuVisualView.class)
```

### 6.4. Resource rules

1. All game files (Java, JSON, resources) must be UTF-8 without BOM.
2. PowerShell scripts must be ASCII-only (no Cyrillic, no special chars in code).
3. New item = minimum 3 files (Java class, model JSON, texture PNG).
4. Lang files must be updated together with keybinds.
5. Do not duplicate code blocks - extract into methods.
6. Full imports required - no wildcard imports.
7. Avoid nested ternaries - use if/else.
8. Test files go only in `src/test/java`.

### 6.5. Build rules

1. One change = one build. Always run `.\gradlew.bat build` after changes.
2. Related changes must be atomic: declaration + registration together.
3. Scripts must be idempotent: check if patch already applied.
4. If a script cannot find a pattern, it must STOP with error.
5. All versions must match: build.gradle, gradle.properties, fabric.mod.json.

---

## END OF CORE DOCUMENTATION
```

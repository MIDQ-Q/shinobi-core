# ТЗ #9: Worldgen (Генерация мира)

Сохранить как: `team_packages/TZ_WORLDGEN.md`

---

```markdown
# TECHNICAL SPECIFICATION: Worldgen Module

**Module ID:** `worldgen`
**Module Name:** ShinobiCore - World Generation
**Priority:** 3 (third wave, alongside AI, World)
**Core dependency:** Sprint 1 (ModuleManager) + Sprint 2 (config, logger, commands, events)

---

## 1. PURPOSE

Implement the complete world generation layer for ShinobiCore:

- Modification of vanilla biomes (no mandatory new biomes in v1)
- Custom structures:
  - clan village
  - enemy camp
  - training camp
- Optional future structures:
  - onsen site
  - chakra altar site
  - road segments
  - shrines
  - bamboo groves
- Datapack-friendly structure definitions
- Optional external datapack compatibility: `Sengoku Jidai`
- Fallback to ShinobiCore's own structures if external datapack is missing or broken
- Built-in budgeted chunk pregeneration service
- World border setup for the target world size: `48000 x 48000`
- Structure placement logging
- Full disable support without crashing the game

**NOT in scope** (belong to other modules):
- Custom blocks, items, training post, altar block behavior → World module
- Enemy spawning inside camps → AI module
- Visual effects → Visual module
- HUD → HUD module
- Progression/training logic → Progression module
- Clan logic → Clans module

**IMPORTANT:**  
Worldgen must be as independent as possible. In v1, structures should prefer vanilla blocks so the module does not hard-depend on the World module.

---

## 2. FILE OWNERSHIP

The worldgen team may ONLY create and modify files in these locations:

```
src/main/java/com/example/shinobicore/modules/worldgen/
src/main/resources/data/shinobicore/worldgen/        (structure JSON, pools, features, biome modifiers)
src/main/resources/data/shinobicore/tags/worldgen/   (biome/structure tags)
config/shinobicore/modules/worldgen.json             (generated at runtime)
```

The worldgen team MUST NOT modify:
- Any file under `core/`
- `ShinobiCoreMod.java` or `ShinobiCoreClient.java`
- Any file belonging to another module
- `fabric.mod.json` (entrypoint addition is done by core team)

---

## 3. ARCHITECTURE

### 3.1 Package structure

```
modules/worldgen/
├── WorldgenModule.java                         (entry point, server-side module)
├── config/
│   ├── WorldgenConfig.java
│   └── WorldgenConfigLoader.java
├── compat/
│   ├── SengokuJidaiCompat.java
│   └── ExternalDatapackState.java
├── structure/
│   ├── StructureDefinitions.java
│   ├── StructureLoader.java
│   ├── StructurePlacementService.java
│   ├── StructureLogger.java
│   └── StructureTestService.java
├── biome/
│   ├── BiomeModifierService.java
│   └── BiomeModifierValidator.java
├── border/
│   └── WorldBorderService.java
├── pregen/
│   ├── WorldPregenService.java
│   ├── PregenProgress.java
│   ├── PregenProgressStorage.java
│   └── PregenCommands.java
├── event/
│   └── WorldgenEvents.java
└── command/
    └── WorldgenCommands.java
```

### 3.2 Module entry point

Worldgen is a server-side module. It does NOT need client tick logic.

```java
public class WorldgenModule implements ShinobiModule {
    public static final String ID = "worldgen";

    @Override public String id() { return ID; }

    @Override
    public void onRegister(ModuleContext ctx) {
        // No CCA component needed
    }

    @Override
    public void onEnable(ModuleContext ctx) {
        WorldgenConfig.load(ctx.configs().readModuleConfig(ID));
        StructureDefinitions.init();
        StructureLoader.validate();
        BiomeModifierValidator.validate();
        WorldPregenService.init();
    }

    @Override
    public void registerEvents(ModuleContext ctx) {
        // Worldgen mostly publishes events.
        // It does not need to subscribe to many events.
    }

    @Override
    public void registerViews(ModuleContext ctx) {
        // Worldgen does not register views.
    }

    @Override
    public void registerCommands(ModuleContext ctx, CommandDispatcher<ServerCommandSource> d) {
        WorldgenCommands.register(d);
    }

    @Override
    public void onServerStarting(ModuleContext ctx, MinecraftServer server) {
        SengokuJidaiCompat.detect(server);
        WorldBorderService.applyOnServerStarting(server);
        WorldPregenService.loadProgress(server);
        StructurePlacementService.onServerStarting(server);
    }

    @Override
    public void onServerStopping(ModuleContext ctx, MinecraftServer server) {
        WorldPregenService.saveProgress(server);
        WorldPregenService.stop();
    }

    @Override
    public void onServerTick(ModuleContext ctx, MinecraftServer server) {
        WorldPregenService.serverTick(server);
        StructureLogger.serverTick(server);
    }
}
```

---

## 4. CORE API TO USE

### 4.1 Logger

```java
ShinobiLogger.module("worldgen", "Pregen started");
ShinobiLogger.error("worldgen", "Failed to load pregen progress", exception);
```

### 4.2 Config

```java
JsonObject config = ctx.configs().readModuleConfig(ID);
WorldgenConfig.load(config);
```

### 4.3 Events to publish

```java
public record WorldgenStructureGeneratedEvent(
    String structureId,
    BlockPos pos,
    ServerWorld world
) {}

public record WorldgenPregenStartedEvent(
    int totalChunks
) {}

public record WorldgenPregenProgressEvent(
    int generatedChunks,
    int totalChunks
) {}

public record WorldgenPregenStoppedEvent(
    String reason
) {}

public record WorldgenBorderAppliedEvent(
    int size
) {}
```

Publish via:

```java
CoreEvents.publish(new WorldgenStructureGeneratedEvent(id, pos, world));
```

### 4.4 Events to subscribe

Worldgen usually does not need to subscribe to gameplay events.

Optional:

```
ModuleEnabledEvent
ModuleDisabledEvent
```

Only if future diagnostics are needed.

---

## 5. VIEWS

Worldgen does NOT register any visual view.

Worldgen is server-side and does not expose per-player view data.

---

## 6. STRUCTURES — FIRST VERSION

### 6.1 Required structures

| Structure ID | Purpose | Notes |
|--------------|---------|-------|
| `shinobicore:clan_village` | Large settlement for clan/world content | Use village-like layout |
| `shinobicore:enemy_camp` | Small hostile camp | AI module may later use it |
| `shinobicore:training_camp` | Training area | Progression/AI may later use it |

### 6.2 Rules for v1 structures

1. Prefer vanilla blocks only.
2. Do NOT hard-require custom blocks from the World module.
3. If a custom block would be desired, use a vanilla fallback block in v1.
4. Structures must not crash if another module is disabled.
5. Structures should be datapack-driven:
   - structure JSON
   - template pool JSON
   - structure set JSON
   - optional biome tags
6. Structures should generate only in new chunks.
7. Do NOT retroactively modify already-generated chunks in v1.

### 6.3 Suggested structure themes

#### clan_village

```text
- Houses
- Central hall
- Paths
- Fences / lanterns
- Small training corner
- Optional villagers (vanilla only)
```

Recommended biomes:

```text
minecraft:plains
minecraft:forest
minecraft:taiga
minecraft:savanna
```

#### enemy_camp

```text
- Campfire
- Tents or simple shelters
- Barrels / crates
- Fences
- Small watchtower
```

Recommended biomes:

```text
minecraft:taiga
minecraft:swamp
minecraft:dark_forest
minecraft:windswept_hills
```

#### training_camp

```text
- Target blocks
- Hay bales
- Fences
- Simple obstacle course
- Small open arena
```

Recommended biomes:

```text
minecraft:plains
minecraft:forest
minecraft:savanna
```

---

## 7. BIOME MODIFICATION

### 7.1 Goal

Modify vanilla biomes instead of creating many new biomes.

Possible modifications:

```text
- Add tree patches
- Add flower patches
- Add grass patches
- Add bamboo patches
- Add stone lantern surface features (future, requires World module)
- Add sakura-like vegetation using vanilla blocks in v1
```

### 7.2 Rules

1. Biome modifications must be additive.
2. Do NOT replace vanilla terrain generation.
3. Do NOT remove vanilla features in v1.
4. Must be datapack-driven where possible.
5. Must be safe if external `Sengoku Jidai` datapack is present.
6. If external datapack is active and `preferExternalBiomeChanges=true`, ShinobiCore biome modifications should be disabled or reduced.

---

## 8. SENGOKU JIDAI COMPATIBILITY

### 8.1 Assumption

`Sengoku Jidai` is an external datapack.

It is NOT a required mod.  
It is NOT a hard dependency.

### 8.2 Detection

Detection happens on server starting:

```java
public final class SengokuJidaiCompat {
    private static boolean active = false;

    public static void detect(MinecraftServer server) {
        if (!WorldgenConfig.get().sengokuJidai.enabled) {
            active = false;
            return;
        }

        String namespace = WorldgenConfig.get().sengokuJidai.namespace;

        try {
            boolean datapackPresent = server.getDataPackManager()
                .getNames()
                .stream()
                .anyMatch(name -> name.toLowerCase().contains(namespace.toLowerCase()));

            active = datapackPresent;

            if (active) {
                ShinobiLogger.module("worldgen",
                    "Sengoku Jidai datapack detected: " + namespace);
            } else {
                ShinobiLogger.module("worldgen",
                    "Sengoku Jidai datapack not detected. Using fallback structures.");
            }
        } catch (Throwable t) {
            active = false;
            ShinobiLogger.error("worldgen",
                "Failed to detect Sengoku Jidai datapack. Using fallback.", t);
        }
    }

    public static boolean isActive() {
        return active;
    }
}
```

### 8.3 Compatibility rules

```text
If Sengoku Jidai is absent:
  -> Use ShinobiCore fallback structures and biome modifications.

If Sengoku Jidai is present:
  -> If preferExternalStructures=true:
       disable or reduce ShinobiCore equivalent structures.
  -> If preferExternalBiomeChanges=true:
       disable or reduce ShinobiCore biome modifications.

If Sengoku Jidai is present but broken:
  -> Log error.
  -> Do not crash.
  -> Fall back to ShinobiCore generation.
```

### 8.4 Important limitation

The team must design structure enable/disable logic so that external datapack compatibility does not require editing another team's files.

Recommended implementation:

```text
Worldgen has its own placement service / conditional structure registry.
Config and external datapack state decide which structure sets are active.
```

If pure datapack JSON cannot be disabled at runtime, the team must provide a safe fallback:

```text
- Use conditional resource/data injection if available
- Or use config-driven custom placement
- Or provide clear operator instructions for disabling conflicting datapacks
```

The module MUST NOT crash because of this.

---

## 9. WORLD BORDER

### 9.1 Target world size

```text
48000 x 48000 blocks
```

This is the vanilla world border diameter.

### 9.2 Behavior

On server starting:

```text
if worldBorder.enabled:
    set border center to worldBorder.centerX / worldBorder.centerZ
    set border size to worldBorder.size
    do not shrink or animate unless explicitly configured
    log result
```

### 9.3 Rules

1. Use vanilla world border.
2. Do NOT implement custom per-tick boundary checks.
3. Do NOT teleport players by default.
4. Do NOT destroy blocks outside border.
5. Border application must be safe on server restart.
6. Border must be optional.

---

## 10. PREGENERATION

### 10.1 Goal

Provide a built-in budgeted chunk pregeneration service.

This is NOT a synchronous freeze.  
This is NOT a multithreaded world mutation system.  
This is a background service that generates a limited number of chunks per tick.

### 10.2 Important warning

```text
48000 x 48000 = 9,000,000 chunks.

Full pregeneration can take hours or days.
It must be disabled by default.
It must be started only by operator command.
```

### 10.3 Pregen modes

```text
disabled
structures_first
full_square
```

#### disabled

No pregeneration.

#### structures_first

Generate only a limited radius around located structures.

This is the recommended default if pregen is enabled.

#### full_square

Generate the full configured square.

This is dangerous and must remain operator-only.

### 10.4 Pregen state

```java
public final class PregenProgress {
    public boolean running;
    public boolean paused;
    public int centerX;
    public int centerZ;
    public int sizeChunks;
    public int generatedChunks;
    public int totalChunks;
    public long startedAtMs;
    public long lastSaveMs;
}
```

### 10.5 Pregen behavior

Every server tick:

```text
if module disabled:
    return

if pregen disabled:
    return

if not running:
    return

if paused:
    return

if server TPS below pauseWhenTpsBelow:
    pause automatically
    log once
    return

start timing

while generatedThisTick < chunksPerTick:
    if elapsed time > maxMsPerTick:
        break

    generate next chunk in spiral/square order
    generatedChunks++
    generatedThisTick++

if generatedChunks % saveEveryChunks == 0:
    save progress

if generatedChunks >= totalChunks:
    stop
    save
    log completion
```

### 10.6 Chunk generation safety

Rules:

1. All block/world changes happen on the server thread.
2. Do NOT mutate world from another thread.
3. Do NOT load/generate unlimited chunks per tick.
4. Respect `maxMsPerTick`.
5. If a chunk generation call blocks too long, reduce budget and log.
6. Only pregenerate the configured dimension (default: overworld).

### 10.7 Pregen progress storage

Progress is stored per world:

```text
<world>/shinobicore/worldgen/pregen.json
```

Example:

```json
{
  "running": false,
  "paused": false,
  "mode": "structures_first",
  "centerX": 0,
  "centerZ": 0,
  "sizeChunks": 3000,
  "generatedChunks": 1234,
  "totalChunks": 9000000,
  "startedAtMs": 1730000000000,
  "lastSaveMs": 1730000000000
}
```

---

## 11. STRUCTURE LOGGING

### 11.1 Goal

Log generated structures for testing and debugging.

### 11.2 Rules

1. Do NOT log every chunk.
2. Log only structure starts or meaningful placements.
3. Rate-limit logs.
4. Use `ShinobiLogger.module("worldgen", ...)`.
5. If logging cannot hook into structure placement safely, provide a fallback:
   - log when a structure is located/tested
   - log pregen milestones
   - do not crash trying to hook unsupported events

Example log:

```text
[worldgen] Generated shinobicore:enemy_camp at [120, 72, -340] in minecraft:taiga
```

---

## 12. CLIENT-SERVER AUTHORITY

```text
SERVER:
- All world generation
- Structure placement
- Border setup
- Pregen service
- Progress storage

CLIENT:
- No worldgen logic
- No packets required in v1
```

Worldgen does NOT send custom network packets in v1.

---

## 13. FULL CONFIG TEMPLATE

File: `config/shinobicore/modules/worldgen.json`

```json
{
  "enabled": true,
  "debug": false,

  "worldBorder": {
    "enabled": true,
    "centerX": 0,
    "centerZ": 0,
    "size": 48000,
    "applyOnServerStart": true,
    "log": true
  },

  "biomeModifiers": {
    "enabled": true,
    "addVanillaFriendlyFeatures": true,
    "disableWhenExternalDatapackActive": true
  },

  "structures": {
    "enabled": true,
    "logGeneration": true,
    "logRateLimitTicks": 100,

    "clan_village": {
      "enabled": true,
      "spacing": 32,
      "separation": 8,
      "weight": 1
    },

    "enemy_camp": {
      "enabled": true,
      "spacing": 18,
      "separation": 6,
      "weight": 3
    },

    "training_camp": {
      "enabled": true,
      "spacing": 24,
      "separation": 8,
      "weight": 2
    }
  },

  "sengokuJidai": {
    "enabled": true,
    "namespace": "sengoku_jidai",
    "preferExternalStructures": true,
    "preferExternalBiomeChanges": true,
    "fallbackOnError": true
  },

  "pregen": {
    "enabled": false,
    "defaultMode": "structures_first",
    "dimension": "minecraft:overworld",
    "centerX": 0,
    "centerZ": 0,
    "size": 48000,
    "structuresFirstRadiusChunks": 16,
    "chunksPerTick": 2,
    "maxMsPerTick": 6,
    "pauseWhenTpsBelow": 18.0,
    "saveEveryChunks": 1000,
    "logEveryChunks": 1000,
    "allowFullSquarePregen": false
  },

  "logging": {
    "logStructures": true,
    "logPregenProgress": true,
    "logBorder": true,
    "logCompat": true
  }
}
```

### Config rules

1. Config is read ONCE at module load.
2. Missing file -> default is created.
3. Missing field -> default used.
4. Invalid JSON -> log error, use defaults, module continues.
5. No hot reload.
6. Pregen is disabled by default.
7. Full square pregen is disabled by default.

---

## 14. JSON DATA FILES

Worldgen team is responsible for these directories:

```
data/shinobicore/worldgen/
├── structure/
│   ├── clan_village.json
│   ├── enemy_camp.json
│   └── training_camp.json
├── structure_set/
│   └── shinobicore_structures.json
├── template_pool/
│   ├── clan_village/
│   │   ├── start.json
│   │   └── buildings.json
│   ├── enemy_camp/
│   │   ├── start.json
│   │   └── pieces.json
│   └── training_camp/
│       ├── start.json
│       └── pieces.json
├── placed_feature/
├── configured_feature/
└── biome_modifier/
```

Tags:

```
data/shinobicore/tags/worldgen/biome/
├── has_structure/clan_village.json
├── has_structure/enemy_camp.json
└── has_structure/training_camp.json
```

---

## 15. JSON EXAMPLES

### 15.1 Structure JSON

File:

```text
data/shinobicore/worldgen/structure/enemy_camp.json
```

```json
{
  "type": "minecraft:jigsaw",
  "biomes": "#shinobicore:has_structure/enemy_camp",
  "step": "surface_structures",
  "spawn_overrides": {},
  "terrain_adaptation": "beard_thin",
  "start_pool": "shinobicore:enemy_camp/start",
  "size": 4,
  "start_height": {
    "absolute": 0
  },
  "project_start_to_heightmap": "WORLD_SURFACE_WG",
  "max_distance_from_center": 64,
  "use_expansion_hack": false
}
```

### 15.2 Structure set JSON

File:

```text
data/shinobicore/worldgen/structure_set/shinobicore_structures.json
```

```json
{
  "structures": [
    {
      "structure": "shinobicore:clan_village",
      "weight": 1
    },
    {
      "structure": "shinobicore:enemy_camp",
      "weight": 3
    },
    {
      "structure": "shinobicore:training_camp",
      "weight": 2
    }
  ],
  "placement": {
    "type": "minecraft:random_spread",
    "spacing": 24,
    "separation": 8,
    "salt": 884317
  }
}
```

### 15.3 Template pool JSON

File:

```text
data/shinobicore/worldgen/template_pool/enemy_camp/start.json
```

```json
{
  "fallback": "minecraft:empty",
  "elements": [
    {
      "weight": 1,
      "element": {
        "element_type": "minecraft:single_pool_element",
        "location": "shinobicore:enemy_camp/start",
        "projection": "rigid",
        "processors": "minecraft:empty"
      }
    }
  ]
}
```

### 15.4 Biome tag JSON

File:

```text
data/shinobicore/tags/worldgen/biome/has_structure/enemy_camp.json
```

```json
{
  "replace": false,
  "values": [
    "minecraft:taiga",
    "minecraft:swamp",
    "minecraft:dark_forest",
    "minecraft:windswept_hills"
  ]
}
```

### 15.5 Fabric biome modifier example

File:

```text
data/shinobicore/fabric/biome_modifier/forest_decorations.json
```

```json
{
  "type": "fabric:add_features",
  "biomes": "#minecraft:is_forest",
  "features": [
    "shinobicore:forest_decoration_patch"
  ],
  "step": "vegetal_decoration"
}
```

---

## 16. COMMANDS

```
/shinobicore worldgen status
/shinobicore worldgen validate
/shinobicore worldgen locate <structureId>
/shinobicore worldgen test <structureId>
/shinobicore worldgen border set
/shinobicore worldgen pregen start
/shinobicore worldgen pregen stop
/shinobicore worldgen pregen pause
/shinobicore worldgen pregen resume
/shinobicore worldgen pregen status
/shinobicore worldgen debug
```

### Permissions

```text
status              -> everyone
validate            -> operator
locate              -> operator
test                -> operator
border set          -> operator
pregen start        -> operator
pregen stop         -> operator
pregen pause        -> operator
pregen resume       -> operator
pregen status       -> everyone
debug               -> operator
```

### Command behavior

#### status

Prints:

```text
worldgen enabled
Sengoku Jidai active
structures enabled
border size
pregen state
pregen progress
```

#### locate

Wraps vanilla locate logic where possible:

```text
/locate structure shinobicore:enemy_camp
```

#### test

Places the requested structure near the operator for testing.

Recommended implementation:

```text
Use server command dispatcher to execute:
/place structure <structureId> <pos>
```

Do NOT manually instantiate complex structure internals if a safe command exists.

---

## 17. FORBIDDEN PATTERNS

Worldgen team MUST NOT do any of these:

1. **DO NOT** generate structures by directly mutating chunks from arbitrary threads.
2. **DO NOT** block the server thread for long time without budget.
3. **DO NOT** automatically start full pregeneration.
4. **DO NOT** require custom blocks from World module in v1 structures.
5. **DO NOT** crash if Sengoku Jidai datapack is missing.
6. **DO NOT** crash if Sengoku Jidai datapack is broken.
7. **DO NOT** use `System.out.println`. Use `ShinobiLogger.module("worldgen", ...)`.
8. **DO NOT** spam logs for every chunk.
9. **DO NOT** modify already-generated chunks unless explicitly required and configured.
10. **DO NOT** create god-classes (>300 lines).
11. **DO NOT** import classes from other modules.
12. **DO NOT** make AI spawn enemies. Worldgen only provides structures/locations/events.
13. **DO NOT** implement custom world border physics. Use vanilla border.
14. **DO NOT** hot-reload worldgen config.

---

## 18. DEFINITION OF DONE

The worldgen module is complete when:

1. ✅ Module loads via `shinobicore:module` entrypoint
2. ✅ `/shinobicore systems` shows `worldgen: ENABLED`
3. ✅ Config file `worldgen.json` created on first run
4. ✅ Broken config does not crash the game
5. ✅ World border can be applied on server start
6. ✅ World border is optional
7. ✅ World border size defaults to 48000
8. ✅ Three v1 structures exist:
   - clan_village
   - enemy_camp
   - training_camp
9. ✅ Structures use datapack JSON
10. ✅ Structures prefer vanilla blocks
11. ✅ Structures do not require World module to be enabled
12. ✅ Structure tags exist for biome filtering
13. ✅ `/shinobicore worldgen locate <id>` works
14. ✅ `/shinobicore worldgen test <id>` works for operator
15. ✅ `/shinobicore worldgen validate` reports JSON issues
16. ✅ Structure logging works or safely degrades
17. ✅ Sengoku Jidai detection works on server start
18. ✅ If Sengoku Jidai is absent, fallback structures are used
19. ✅ If Sengoku Jidai is present, compat mode is logged
20. ✅ Pregen is disabled by default
21. ✅ Pregen can be started only by operator
22. ✅ Pregen respects chunks per tick limit
23. ✅ Pregen respects max milliseconds per tick
24. ✅ Pregen pauses when TPS is too low
25. ✅ Pregen progress is saved per world
26. ✅ Pregen progress survives server restart
27. ✅ Pregen can be stopped/paused/resumed
28. ✅ Full square pregen is disabled by default
29. ✅ Module does not crash when other modules are disabled
30. ✅ Build passes: `.\gradlew.bat build`

---

## 19. EXAMPLE CODE SNIPPETS

### 19.1 Worldgen commands skeleton

```java
public final class WorldgenCommands {

    public static void register(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(CommandManager.literal("shinobicore")
            .then(CommandManager.literal("worldgen")
                .then(CommandManager.literal("status")
                    .executes(WorldgenCommands::status))
                .then(CommandManager.literal("validate")
                    .requires(s -> s.hasPermissionLevel(2))
                    .executes(WorldgenCommands::validate))
                .then(CommandManager.literal("locate")
                    .requires(s -> s.hasPermissionLevel(2))
                    .then(CommandManager.argument("structure", StringArgumentType.word())
                        .executes(WorldgenCommands::locate)))
                .then(CommandManager.literal("test")
                    .requires(s -> s.hasPermissionLevel(2))
                    .then(CommandManager.argument("structure", StringArgumentType.word())
                        .executes(WorldgenCommands::test)))
                .then(CommandManager.literal("border")
                    .then(CommandManager.literal("set")
                        .requires(s -> s.hasPermissionLevel(2))
                        .executes(WorldgenCommands::setBorder)))
                .then(CommandManager.literal("pregen")
                    .then(CommandManager.literal("start")
                        .requires(s -> s.hasPermissionLevel(2))
                        .executes(WorldgenCommands::pregenStart))
                    .then(CommandManager.literal("stop")
                        .requires(s -> s.hasPermissionLevel(2))
                        .executes(WorldgenCommands::pregenStop))
                    .then(CommandManager.literal("pause")
                        .requires(s -> s.hasPermissionLevel(2))
                        .executes(WorldgenCommands::pregenPause))
                    .then(CommandManager.literal("resume")
                        .requires(s -> s.hasPermissionLevel(2))
                        .executes(WorldgenCommands::pregenResume))
                    .then(CommandManager.literal("status")
                        .executes(WorldgenCommands::pregenStatus)))
            )
        );
    }

    private static int status(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource src = ctx.getSource();
        src.sendFeedback(() -> Text.literal("=== ShinobiCore Worldgen ==="), false);
        src.sendFeedback(() -> Text.literal("Enabled: " + WorldgenConfig.get().enabled), false);
        src.sendFeedback(() -> Text.literal("Sengoku Jidai active: " + SengokuJidaiCompat.isActive()), false);
        src.sendFeedback(() -> Text.literal("Border size: " + WorldgenConfig.get().worldBorder.size), false);
        src.sendFeedback(() -> Text.literal("Pregen: " + WorldPregenService.getStatusLine()), false);
        return 1;
    }

    private static int validate(CommandContext<ServerCommandSource> ctx) {
        StructureLoader.validate();
        BiomeModifierValidator.validate();
        ctx.getSource().sendFeedback(() -> Text.literal("Worldgen validation complete."), false);
        return 1;
    }

    private static int locate(CommandContext<ServerCommandSource> ctx) {
        String structure = StringArgumentType.getString(ctx, "structure");
        ServerCommandSource src = ctx.getSource();

        String command = "locate structure shinobicore:" + structure;
        src.getServer().getCommandManager().executeWithPrefix(
            src.getServer().getCommandSource(), command);

        return 1;
    }

    private static int test(CommandContext<ServerCommandSource> ctx) {
        String structure = StringArgumentType.getString(ctx, "structure");
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) return 0;

        String command = String.format(
            "place structure shinobicore:%s %d %d %d",
            structure,
            player.getBlockX(),
            player.getBlockY(),
            player.getBlockZ()
        );

        ctx.getSource().getServer().getCommandManager().executeWithPrefix(
            ctx.getSource().getServer().getCommandSource(), command);

        return 1;
    }

    private static int setBorder(CommandContext<ServerCommandSource> ctx) {
        WorldBorderService.applyNow(ctx.getSource().getServer());
        ctx.getSource().sendFeedback(() -> Text.literal("World border applied."), false);
        return 1;
    }

    private static int pregenStart(CommandContext<ServerCommandSource> ctx) {
        WorldPregenService.start(ctx.getSource().getServer());
        return 1;
    }

    private static int pregenStop(CommandContext<ServerCommandSource> ctx) {
        WorldPregenService.stop();
        return 1;
    }

    private static int pregenPause(CommandContext<ServerCommandSource> ctx) {
        WorldPregenService.pause();
        return 1;
    }

    private static int pregenResume(CommandContext<ServerCommandSource> ctx) {
        WorldPregenService.resume();
        return 1;
    }

    private static int pregenStatus(CommandContext<ServerCommandSource> ctx) {
        ctx.getSource().sendFeedback(
            () -> Text.literal(WorldPregenService.getStatusLine()), false);
        return 1;
    }
}
```

### 19.2 World border service

```java
public final class WorldBorderService {

    public static void applyOnServerStarting(MinecraftServer server) {
        if (!WorldgenConfig.get().worldBorder.enabled) return;
        if (!WorldgenConfig.get().worldBorder.applyOnServerStart) return;

        applyNow(server);
    }

    public static void applyNow(MinecraftServer server) {
        WorldgenConfig.WorldBorderConfig cfg = WorldgenConfig.get().worldBorder;

        ServerWorld overworld = server.getWorld(World.OVERWORLD);
        if (overworld == null) return;

        WorldBorder border = overworld.getWorldBorder();
        border.setCenter(cfg.centerX, cfg.centerZ);
        border.setSize(cfg.size);

        if (cfg.log) {
            ShinobiLogger.module("worldgen",
                "World border applied: center=" + cfg.centerX + "," + cfg.centerZ +
                " size=" + cfg.size);
        }

        CoreEvents.publish(new WorldgenBorderAppliedEvent(cfg.size));
    }
}
```

### 19.3 Pregen service skeleton

```java
public final class WorldPregenService {
    private static PregenProgress progress = new PregenProgress();
    private static int tickCounter = 0;

    public static void init() {
        progress = new PregenProgress();
    }

    public static void loadProgress(MinecraftServer server) {
        progress = PregenProgressStorage.load(server);
    }

    public static void saveProgress(MinecraftServer server) {
        PregenProgressStorage.save(server, progress);
    }

    public static void start(MinecraftServer server) {
        WorldgenConfig.PregenConfig cfg = WorldgenConfig.get().pregen;

        if (!cfg.enabled) {
            ShinobiLogger.module("worldgen", "Pregen is disabled in config.");
            return;
        }

        if (progress.running) {
            ShinobiLogger.module("worldgen", "Pregen already running.");
            return;
        }

        progress.running = true;
        progress.paused = false;
        progress.centerX = cfg.centerX;
        progress.centerZ = cfg.centerZ;
        progress.sizeChunks = cfg.size / 16;
        progress.totalChunks = progress.sizeChunks * progress.sizeChunks;
        progress.generatedChunks = 0;
        progress.startedAtMs = System.currentTimeMillis();

        saveProgress(server);

        ShinobiLogger.module("worldgen",
            "Pregen started. Total chunks: " + progress.totalChunks);

        CoreEvents.publish(new WorldgenPregenStartedEvent(progress.totalChunks));
    }

    public static void stop() {
        if (!progress.running) return;
        progress.running = false;
        progress.paused = false;
        ShinobiLogger.module("worldgen",
            "Pregen stopped at " + progress.generatedChunks + " chunks.");
        CoreEvents.publish(new WorldgenPregenStoppedEvent("manual_stop"));
    }

    public static void pause() {
        if (!progress.running) return;
        progress.paused = true;
    }

    public static void resume() {
        if (!progress.running) return;
        progress.paused = false;
    }

    public static void serverTick(MinecraftServer server) {
        if (!WorldgenConfig.get().enabled) return;
        if (!WorldgenConfig.get().pregen.enabled) return;
        if (!progress.running) return;
        if (progress.paused) return;

        // Auto-pause on low TPS
        double tps = getAverageTps(server);
        if (tps < WorldgenConfig.get().pregen.pauseWhenTpsBelow) {
            if (!progress.paused) {
                progress.paused = true;
                ShinobiLogger.module("worldgen",
                    "Pregen auto-paused due to low TPS: " + tps);
            }
            return;
        }

        WorldgenConfig.PregenConfig cfg = WorldgenConfig.get().pregen;

        ServerWorld world = server.getWorld(World.OVERWORLD);
        if (world == null) return;

        long startNs = System.nanoTime();
        int generatedThisTick = 0;

        while (generatedThisTick < cfg.chunksPerTick) {
            long elapsedMs = (System.nanoTime() - startNs) / 1_000_000L;
            if (elapsedMs > cfg.maxMsPerTick) break;

            if (progress.generatedChunks >= progress.totalChunks) {
                progress.running = false;
                saveProgress(server);
                ShinobiLogger.module("worldgen", "Pregen complete.");
                CoreEvents.publish(new WorldgenPregenStoppedEvent("complete"));
                break;
            }

            int[] chunk = nextChunk(progress);
            world.getChunkManager().getChunk(chunk[0], chunk[1], ChunkStatus.FULL, true);

            progress.generatedChunks++;
            generatedThisTick++;

            if (progress.generatedChunks % cfg.saveEveryChunks == 0) {
                saveProgress(server);
            }

            if (progress.generatedChunks % cfg.logEveryChunks == 0) {
                ShinobiLogger.module("worldgen",
                    "Pregen progress: " + progress.generatedChunks + "/" + progress.totalChunks);
                CoreEvents.publish(new WorldgenPregenProgressEvent(
                    progress.generatedChunks, progress.totalChunks));
            }
        }
    }

    private static int[] nextChunk(PregenProgress p) {
        // Simple square spiral placeholder.
        // Real implementation must deterministically walk the full square.
        int index = p.generatedChunks;
        int side = (int) Math.sqrt(index);
        int x = p.centerX + (index % side);
        int z = p.centerZ + (side / 2);
        return new int[]{x, z};
    }

    private static double getAverageTps(MinecraftServer server) {
        long[] times = server.lastTickLengths;
        if (times == null || times.length == 0) return 20.0;

        long sum = 0;
        for (long t : times) sum += t;
        double avgMs = sum / (double) times.length / 1_000_000.0;
        if (avgMs <= 0) return 20.0;
        return Math.min(20.0, 1000.0 / avgMs);
    }

    public static String getStatusLine() {
        if (!progress.running) return "idle";
        if (progress.paused) return "paused";
        return "running " + progress.generatedChunks + "/" + progress.totalChunks;
    }
}
```

### 19.4 Pregen progress storage

```java
public final class PregenProgressStorage {
    private static final Gson GSON = new GsonBuilder().setPrettyPrinting().create();

    public static Path getFile(MinecraftServer server) {
        return server.getSavePath(WorldSavePath.ROOT)
            .resolve("shinobicore")
            .resolve("worldgen")
            .resolve("pregen.json");
    }

    public static PregenProgress load(MinecraftServer server) {
        Path file = getFile(server);
        if (!Files.exists(file)) return new PregenProgress();

        try {
            String raw = Files.readString(file, StandardCharsets.UTF_8);
            PregenProgress p = GSON.fromJson(raw, PregenProgress.class);
            return p != null ? p : new PregenProgress();
        } catch (Throwable t) {
            ShinobiLogger.error("worldgen", "Failed to load pregen progress", t);
            return new PregenProgress();
        }
    }

    public static void save(MinecraftServer server, PregenProgress progress) {
        Path file = getFile(server);

        try {
            Files.createDirectories(file.getParent());
            Files.writeString(file, GSON.toJson(progress), StandardCharsets.UTF_8);
        } catch (Throwable t) {
            ShinobiLogger.error("worldgen", "Failed to save pregen progress", t);
        }
    }
}
```

---

## 20. HANDOFF

When the worldgen team finishes, they must:

1. Run `.\gradlew.bat build` — must pass with 0 errors.
2. Run `.\gradlew.bat runClient` and create a new world.
3. Verify:
   - `/shinobicore worldgen status` works
   - `/shinobicore worldgen locate enemy_camp` works
   - `/shinobicore worldgen test enemy_camp` places structure
   - world border is applied if enabled
   - pregen does NOT start automatically
   - pregen can be started/stopped/paused by operator
   - pregen progress saves
4. Verify that disabling the module via `worldgen.json` (`enabled: false`) does not break the game.
5. Verify that structures do not require World module.
6. Verify that missing Sengoku Jidai datapack does not crash the game.
7. Create a brief `modules/worldgen/README.md`.
8. Notify the core team that the module is ready for integration review.

---

## END OF WORLDGEN TECHNICAL SPECIFICATION
```

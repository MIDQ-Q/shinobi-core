# ТЗ #10: World (Мир / Блоки / Интерактивные объекты)

Сохранить как: `team_packages/TZ_WORLD.md`

---

```markdown
# TECHNICAL SPECIFICATION: World Module

**Module ID:** `world`
**Module Name:** ShinobiCore - World Content
**Priority:** 3 (third wave, alongside AI, Worldgen)
**Core dependency:** Sprint 1 (ModuleManager) + Sprint 2 (config, logger, commands, events)

---

## 1. PURPOSE

Implement the decorative and interactive world content for ShinobiCore:

- Japanese-style decorative blocks
- Sakura / bamboo vegetation blocks
- Lanterns and lighting blocks
- Stone paths and flooring
- Tatami and shoji blocks
- Simple interactive objects:
  - training post
  - chakra altar
  - onsen steam / decorative onsen object
- Recipes for all added blocks/items
- Simple models and blockstates
- Loot tables
- Lang entries
- Simple interaction events for other modules
- Optional creative tab

**Primary rule for v1:**

```text
World module is mostly decorative.
Interactive behavior is simple and event-driven.
No complex block entities in v1.
No GUI screens in v1.
No hard dependency on Worldgen, Progression, or Clans.
```

**NOT in scope** (belong to other modules):
- Natural structure generation → Worldgen module
- Training XP logic → Progression module
- Clan logic → Clans module
- Enemy spawning → AI module
- Visual particles beyond basic block interaction → Visual module
- HUD → HUD module

---

## 2. FILE OWNERSHIP

The world team may ONLY create and modify files in these locations:

```
src/main/java/com/example/shinobicore/modules/world/
src/main/resources/data/shinobicore/loot_tables/blocks/
src/main/resources/data/shinobicore/recipes/
src/main/resources/data/shinobicore/tags/blocks/
src/main/resources/assets/shinobicore/blockstates/
src/main/resources/assets/shinobicore/models/block/
src/main/resources/assets/shinobicore/models/item/
src/main/resources/assets/shinobicore/textures/block/
src/main/resources/assets/shinobicore/textures/item/
src/main/resources/assets/shinobicore/lang/
config/shinobicore/modules/world.json
```

The world team MUST NOT modify:
- Any file under `core/`
- `ShinobiCoreMod.java` or `ShinobiCoreClient.java`
- Any file belonging to another module
- `fabric.mod.json` (entrypoint addition is done by core team)

---

## 3. ARCHITECTURE

### 3.1 Package structure

```
modules/world/
├── WorldModule.java                         (entry point, implements ClientAwareModule)
├── config/
│   ├── WorldConfig.java
│   └── WorldConfigLoader.java
├── block/
│   ├── WorldBlocks.java                     (block registry)
│   ├── WorldItems.java                      (item registry)
│   ├── WorldBlockSettings.java              (shared block settings)
│   ├── SakuraLogBlock.java
│   ├── SakuraLeavesBlock.java
│   ├── BambooBlock.java
│   ├── LanternBlock.java
│   ├── StonePathBlock.java
│   ├── TatamiBlock.java
│   ├── ShojiBlock.java
│   ├── TrainingPostBlock.java
│   ├── ChakraAltarBlock.java
│   └── OnsenSteamBlock.java
├── item/
│   └── WorldItemGroup.java                  (optional creative tab)
├── interaction/
│   ├── BlockInteractionDispatcher.java
│   ├── TrainingPostInteraction.java
│   ├── ChakraAltarInteraction.java
│   └── OnsenInteraction.java
├── client/
│   ├── WorldClientHandlers.java
│   └── WorldParticleHandlers.java
├── network/
│   └── WorldPackets.java                    (optional, only if needed)
└── event/
    └── WorldEvents.java
```

### 3.2 Module entry point

```java
public class WorldModule implements ClientAwareModule {
    public static final String ID = "world";

    @Override public String id() { return ID; }

    @Override
    public void onRegister(ModuleContext ctx) {
        // Blocks and items are registered during mod initialization.
        WorldBlocks.register();
        WorldItems.register();
        WorldItemGroup.register();
    }

    @Override
    public void onEnable(ModuleContext ctx) {
        WorldConfig.load(ctx.configs().readModuleConfig(ID));
        BlockInteractionDispatcher.init();
    }

    @Override
    public void registerEvents(ModuleContext ctx) {
        // World module mostly publishes events.
        // It does not need to subscribe to many events.
    }

    @Override
    public void registerViews(ModuleContext ctx) {
        // World module does not register views in v1.
    }

    @Override
    public void registerCommands(ModuleContext ctx, CommandDispatcher<ServerCommandSource> d) {
        WorldCommands.register(d);
    }

    @Override
    public void onClientInit(ModuleContext ctx) {
        WorldClientHandlers.init();
        WorldParticleHandlers.init();
    }

    @Override
    public void onClientTick(ModuleContext ctx) {
        WorldParticleHandlers.clientTick();
    }
}
```

---

## 4. CORE API TO USE

### 4.1 Logger

```java
ShinobiLogger.module("world", "Registered block: shinobicore:training_post");
ShinobiLogger.error("world", "Failed to load world config", exception);
```

### 4.2 Config

```java
JsonObject config = ctx.configs().readModuleConfig(ID);
WorldConfig.load(config);
```

### 4.3 Events to publish

```java
public record WorldBlockInteractedEvent(
    ServerPlayerEntity player,
    BlockPos pos,
    String blockId,
    Hand hand
) {}

public record TrainingPostUsedEvent(
    ServerPlayerEntity player,
    BlockPos pos
) {}

public record ChakraAltarUsedEvent(
    ServerPlayerEntity player,
    BlockPos pos
) {}

public record OnsenEnteredEvent(
    ServerPlayerEntity player,
    BlockPos pos
) {}

public record OnsenExitedEvent(
    ServerPlayerEntity player,
    BlockPos pos
) {}
```

Publish via:

```java
CoreEvents.publish(new TrainingPostUsedEvent(player, pos));
```

### 4.4 Events to subscribe

World module does not need to subscribe to gameplay events in v1.

Optional future:

```
PlayerJoinEvent
PlayerRespawnedEvent
```

Only if interaction cooldowns or client state become necessary.

---

## 5. VIEWS

World module does NOT register views in v1.

If future HUD or Visual needs world state, a view can be added later.

---

## 6. BLOCK LIST — FIRST VERSION

### 6.1 Decorative blocks

| Block ID | Purpose | Notes |
|----------|---------|-------|
| `shinobicore:sakura_log` | Sakura wood log | Simple log-like block |
| `shinobicore:sakura_leaves` | Sakura leaves | Decorative leaves |
| `shinobicore:sakura_planks` | Sakura planks | Basic building block |
| `shinobicore:bamboo_block` | Bamboo block | Decorative vertical block |
| `shinobicore:stone_lantern` | Stone lantern | Light source |
| `shinobicore:paper_lantern` | Paper lantern | Light source |
| `shinobicore:stone_path` | Stone path | Flat decorative path |
| `shinobicore:tatami` | Tatami floor | Decorative flooring |
| `shinobicore:shoji` | Shoji panel | Thin wall/door-like decorative block |
| `shinobicore:zen_stone` | Zen stone | Decorative stone |

### 6.2 Interactive blocks

| Block ID | Purpose | Interaction |
|----------|---------|-------------|
| `shinobicore:training_post` | Training post | Publishes TrainingPostUsedEvent |
| `shinobicore:chakra_altar` | Chakra altar | Publishes ChakraAltarUsedEvent |
| `shinobicore:onsen_steam` | Onsen steam source | Publishes OnsenEnteredEvent / OnsenExitedEvent |

### 6.3 v1 interaction rules

1. Training post does NOT directly give XP.
2. Chakra altar does NOT directly modify chakra.
3. Onsen does NOT directly apply regeneration.
4. World module only publishes events.
5. Progression, core, or future modules decide what happens.
6. If no module listens, interaction should still play a simple sound/particle.

---

## 7. BLOCK BEHAVIOR DETAILS

### 7.1 Sakura log

```text
Hardness: 2.0
Resistance: 2.0
Sound: wood
Tool: axe
Flammable: yes
```

### 7.2 Sakura leaves

```text
Hardness: 0.2
Resistance: 0.2
Sound: grass
Transparent: yes
Opaque: no
Can decay: optional, disabled in v1 for simplicity
```

### 7.3 Lanterns

```text
stone_lantern:
  Hardness: 1.5
  Light level: 12
  Shape: custom simple model

paper_lantern:
  Hardness: 0.5
  Light level: 14
  Shape: custom simple model
```

Do NOT implement complex dynamic lighting. Use vanilla light level.

### 7.4 Tatami

```text
Hardness: 0.6
Sound: wool
Full block or slightly lowered top surface optional
```

### 7.5 Shoji

```text
Hardness: 0.4
Transparent: yes
Opaque: no
Custom thin model
```

Do NOT implement door opening/closing in v1.

### 7.6 Training post

```text
Hardness: 2.0
Sound: wood
Shape: non-full block
Interaction:
  right-click -> play sound, spawn small particles, publish TrainingPostUsedEvent
```

No GUI.  
No internal XP logic.  
No block entity.

### 7.7 Chakra altar

```text
Hardness: 3.0
Sound: stone
Light level: 6
Shape: non-full block
Interaction:
  right-click -> play sound, spawn particles, publish ChakraAltarUsedEvent
```

No GUI.  
No direct chakra modification.  
No block entity.

### 7.8 Onsen steam

```text
Hardness: 0.0 or 0.2
Transparent: yes
Non-solid or decorative
Interaction:
  player enters block area -> publish OnsenEnteredEvent
  player leaves block area -> publish OnsenExitedEvent
```

Implementation recommendation:

```text
Use a simple decorative steam block, not a full custom fluid.
If full onsen water is needed later, add it in a future sprint.
```

---

## 8. RECIPES

Every obtainable block must have a recipe.

Examples:

```text
sakura_planks:
  1 sakura_log -> 4 sakura_planks

tatami:
  2 wheat + 1 wool -> 4 tatami

stone_lantern:
  4 stone + 1 torch -> 1 stone_lantern

paper_lantern:
  6 paper + 1 torch -> 1 paper_lantern

shoji:
  4 sticks + 2 paper -> 4 shoji

training_post:
  3 oak_fence + 2 straw/hay -> 1 training_post

chakra_altar:
  4 polished_andesite + 1 lapis_block -> 1 chakra_altar
```

Recipes must be JSON-driven.

Do NOT register recipes in Java unless absolutely necessary.

---

## 9. LOOT TABLES

Every block that can be broken must have a loot table.

Rules:

```text
decorative blocks drop themselves
silk touch optional, not required in v1
training post drops itself
chakra altar drops itself
lanterns drop themselves
leaves may drop themselves or saplings later
```

Example:

```json
{
  "type": "minecraft:block",
  "pools": [
    {
      "rolls": 1,
      "entries": [
        {
          "type": "minecraft:item",
          "name": "shinobicore:training_post"
        }
      ],
      "conditions": [
        {
          "condition": "minecraft:survives_explosion"
        }
      ]
    }
  ]
}
```

---

## 10. MODELS AND BLOCKSTATES

### 10.1 Rules

1. Use simple JSON models.
2. Do NOT use animated models in v1.
3. Do NOT use block entities for rendering.
4. Prefer vanilla-style cube, slab, fence, wall, or custom simple baked models.
5. All models must be lightweight for weak PCs.

### 10.2 Example blockstate

File:

```text
assets/shinobicore/blockstates/training_post.json
```

```json
{
  "variants": {
    "": {
      "model": "shinobicore:block/training_post"
    }
  }
}
```

### 10.3 Example item model

File:

```text
assets/shinobicore/models/item/training_post.json
```

```json
{
  "parent": "shinobicore:block/training_post"
}
```

### 10.4 Example simple block model

File:

```text
assets/shinobicore/models/block/training_post.json
```

```json
{
  "parent": "minecraft:block/cube_all",
  "textures": {
    "all": "shinobicore:block/training_post"
  }
}
```

For non-full blocks, use a custom elements model. Keep it simple.

---

## 11. LANG

Required lang files:

```text
assets/shinobicore/lang/en_us.json
assets/shinobicore/lang/ru_ru.json
```

Example entries:

```json
{
  "block.shinobicore.sakura_log": "Sakura Log",
  "block.shinobicore.sakura_leaves": "Sakura Leaves",
  "block.shinobicore.sakura_planks": "Sakura Planks",
  "block.shinobicore.bamboo_block": "Bamboo Block",
  "block.shinobicore.stone_lantern": "Stone Lantern",
  "block.shinobicore.paper_lantern": "Paper Lantern",
  "block.shinobicore.stone_path": "Stone Path",
  "block.shinobicore.tatami": "Tatami",
  "block.shinobicore.shoji": "Shoji",
  "block.shinobicore.training_post": "Training Post",
  "block.shinobicore.chakra_altar": "Chakra Altar",
  "block.shinobicore.onsen_steam": "Onsen Steam",
  "itemGroup.shinobicore.world": "ShinobiCore World"
}
```

Russian example:

```json
{
  "block.shinobicore.sakura_log": "Бревно сакуры",
  "block.shinobicore.sakura_leaves": "Листва сакуры",
  "block.shinobicore.sakura_planks": "Доски сакуры",
  "block.shinobicore.bamboo_block": "Бамбуковый блок",
  "block.shinobicore.stone_lantern": "Каменный фонарь",
  "block.shinobicore.paper_lantern": "Бумажный фонарь",
  "block.shinobicore.stone_path": "Каменная дорожка",
  "block.shinobicore.tatami": "Татами",
  "block.shinobicore.shoji": "Сёдзи",
  "block.shinobicore.training_post": "Тренировочный столб",
  "block.shinobicore.chakra_altar": "Алтарь чакры",
  "block.shinobicore.onsen_steam": "Пар онсэна",
  "itemGroup.shinobicore.world": "ShinobiCore - Мир"
}
```

---

## 12. CLIENT-SERVER AUTHORITY

```text
SERVER:
- Block registration
- Interaction validation
- Event publishing
- Loot drops
- Recipes

CLIENT:
- Simple interaction particles
- Simple interaction sounds
- No gameplay decisions
```

World module should NOT require custom packets in v1.

If a packet is absolutely needed later, it must follow:

```java
ServerPlayNetworking.registerGlobalReceiver(ID, (server, player, handler, buf, sender) -> {
    // STEP 1: Read ALL data from buffer FIRST
    final int value = buf.readInt();

    // STEP 2: Execute on server thread
    server.execute(() -> {
        // logic
    });
});
```

NEVER read `buf` inside `server.execute()`.

---

## 13. FULL CONFIG TEMPLATE

File: `config/shinobicore/modules/world.json`

```json
{
  "enabled": true,
  "debug": false,

  "blocks": {
    "registerDecorativeBlocks": true,
    "registerInteractiveBlocks": true,
    "registerLanterns": true,
    "registerVegetation": true
  },

  "interactions": {
    "trainingPostEnabled": true,
    "trainingPostParticles": true,
    "trainingPostSound": true,

    "chakraAltarEnabled": true,
    "chakraAltarParticles": true,
    "chakraAltarSound": true,

    "onsenEnabled": true,
    "onsenParticles": true
  },

  "creativeTab": {
    "enabled": true
  },

  "logging": {
    "logBlockRegistration": true,
    "logInteractions": false
  }
}
```

### Config rules

1. Config is read ONCE at module load.
2. Missing file -> default is created.
3. Missing field -> default used.
4. Invalid JSON -> log error, use defaults, module continues.
5. No hot reload.

---

## 14. COMMANDS

```
/shinobicore world info
/shinobicore world list
/shinobicore world give <blockId>
/shinobicore world giveall
/shinobicore world test training_post
/shinobicore world test chakra_altar
/shinobicore world test onsen
/shinobicore world validate
```

### Permissions

```text
info        -> everyone
list        -> operator
give        -> operator
giveall     -> operator
test        -> operator
validate    -> operator
```

### Command behavior

#### info

Prints:

```text
world module enabled
registered block count
interactive blocks enabled
creative tab enabled
```

#### list

Lists all registered ShinobiCore world blocks.

#### give

Gives one block item to the operator.

#### giveall

Gives one of each registered world block.

#### test

Places or gives the requested test block near the operator and logs the interaction event.

---

## 15. FORBIDDEN PATTERNS

World team MUST NOT do any of these:

1. **DO NOT** directly give XP, chakra, stats, or progression.
2. **DO NOT** implement training logic inside World module.
3. **DO NOT** implement altar buff logic inside World module.
4. **DO NOT** create block entities in v1 unless absolutely necessary.
5. **DO NOT** create GUI screens in v1.
6. **DO NOT** use `System.out.println`. Use `ShinobiLogger.module("world", ...)`.
7. **DO NOT** hardcode recipes in Java. Use JSON.
8. **DO NOT** create heavy animated models.
9. **DO NOT** register blocks that require Worldgen module to be enabled.
10. **DO NOT** make blocks crash if another module is disabled.
11. **DO NOT** create custom fluids in v1.
12. **DO NOT** add complex collision logic unless required for safety.
13. **DO NOT** modify other modules' files.
14. **DO NOT** create god-classes (>300 lines).

---

## 16. DEFINITION OF DONE

The world module is complete when:

1. ✅ Module loads via `shinobicore:module` entrypoint
2. ✅ `/shinobicore systems` shows `world: ENABLED`
3. ✅ Config file `world.json` created on first run
4. ✅ Broken config does not crash the game
5. ✅ All decorative blocks are registered
6. ✅ All blocks have blockstates
7. ✅ All blocks have block models
8. ✅ All blocks have item models
9. ✅ All blocks have loot tables
10. ✅ All obtainable blocks have recipes
11. ✅ Lang entries exist for `en_us`
12. ✅ Lang entries exist for `ru_ru`
13. ✅ Creative tab works if enabled
14. ✅ Training post publishes `TrainingPostUsedEvent`
15. ✅ Chakra altar publishes `ChakraAltarUsedEvent`
16. ✅ Onsen steam publishes enter/exit events
17. ✅ Interactions do not crash if no listener exists
18. ✅ Interactions play simple sound/particle feedback
19. ✅ Blocks do not require Progression module
20. ✅ Blocks do not require Worldgen module
21. ✅ Blocks do not require Clans module
22. ✅ Commands work (`info`, `list`, `give`, `giveall`, `test`, `validate`)
23. ✅ No block entities used in v1
24. ✅ No GUI screens used in v1
25. ✅ Build passes: `.\gradlew.bat build`

---

## 17. EXAMPLE CODE SNIPPETS

### 17.1 Block registry

```java
public final class WorldBlocks {
    private WorldBlocks() {}

    public static Block SAKURA_LOG;
    public static Block SAKURA_LEAVES;
    public static Block SAKURA_PLANKS;
    public static Block BAMBOO_BLOCK;
    public static Block STONE_LANTERN;
    public static Block PAPER_LANTERN;
    public static Block STONE_PATH;
    public static Block TATAMI;
    public static Block SHOJI;
    public static Block TRAINING_POST;
    public static Block CHAKRA_ALTAR;
    public static Block ONSEN_STEAM;

    public static void register() {
        SAKURA_LOG = register("sakura_log",
            new PillarBlock(WorldBlockSettings.wood()));

        SAKURA_LEAVES = register("sakura_leaves",
            new LeavesBlock(WorldBlockSettings.leaves()));

        SAKURA_PLANKS = register("sakura_planks",
            new Block(WorldBlockSettings.wood()));

        BAMBOO_BLOCK = register("bamboo_block",
            new PillarBlock(WorldBlockSettings.wood()));

        STONE_LANTERN = register("stone_lantern",
            new LanternBlock(WorldBlockSettings.stone().luminance(state -> 12)));

        PAPER_LANTERN = register("paper_lantern",
            new LanternBlock(WorldBlockSettings.paper().luminance(state -> 14)));

        STONE_PATH = register("stone_path",
            new StonePathBlock(WorldBlockSettings.stonePath()));

        TATAMI = register("tatami",
            new TatamiBlock(WorldBlockSettings.tatami()));

        SHOJI = register("shoji",
            new ShojiBlock(WorldBlockSettings.shoji()));

        TRAINING_POST = register("training_post",
            new TrainingPostBlock(WorldBlockSettings.trainingPost()));

        CHAKRA_ALTAR = register("chakra_altar",
            new ChakraAltarBlock(WorldBlockSettings.chakraAltar()));

        ONSEN_STEAM = register("onsen_steam",
            new OnsenSteamBlock(WorldBlockSettings.onsenSteam()));

        ShinobiLogger.module("world", "World blocks registered");
    }

    private static Block register(String name, Block block) {
        Identifier id = new Identifier("shinobicore", name);
        return Registry.register(Registries.BLOCK, id, block);
    }
}
```

### 17.2 Block settings

```java
public final class WorldBlockSettings {
    private WorldBlockSettings() {}

    public static AbstractBlock.Settings wood() {
        return AbstractBlock.Settings.create()
            .strength(2.0f, 2.0f)
            .sounds(BlockSoundGroup.WOOD);
    }

    public static AbstractBlock.Settings leaves() {
        return AbstractBlock.Settings.create()
            .strength(0.2f, 0.2f)
            .sounds(BlockSoundGroup.GRASS)
            .nonOpaque();
    }

    public static AbstractBlock.Settings stone() {
        return AbstractBlock.Settings.create()
            .strength(1.5f, 3.0f)
            .sounds(BlockSoundGroup.STONE);
    }

    public static AbstractBlock.Settings paper() {
        return AbstractBlock.Settings.create()
            .strength(0.5f, 0.5f)
            .sounds(BlockSoundGroup.WOOL);
    }

    public static AbstractBlock.Settings stonePath() {
        return AbstractBlock.Settings.create()
            .strength(1.8f, 3.0f)
            .sounds(BlockSoundGroup.STONE);
    }

    public static AbstractBlock.Settings tatami() {
        return AbstractBlock.Settings.create()
            .strength(0.6f, 0.6f)
            .sounds(BlockSoundGroup.WOOL);
    }

    public static AbstractBlock.Settings shoji() {
        return AbstractBlock.Settings.create()
            .strength(0.4f, 0.4f)
            .sounds(BlockSoundGroup.WOOD)
            .nonOpaque();
    }

    public static AbstractBlock.Settings trainingPost() {
        return AbstractBlock.Settings.create()
            .strength(2.0f, 2.0f)
            .sounds(BlockSoundGroup.WOOD)
            .nonOpaque();
    }

    public static AbstractBlock.Settings chakraAltar() {
        return AbstractBlock.Settings.create()
            .strength(3.0f, 4.0f)
            .sounds(BlockSoundGroup.STONE)
            .luminance(state -> 6)
            .nonOpaque();
    }

    public static AbstractBlock.Settings onsenSteam() {
        return AbstractBlock.Settings.create()
            .strength(0.0f, 0.0f)
            .sounds(BlockSoundGroup.WOOL)
            .nonOpaque()
            .noCollision();
    }
}
```

### 17.3 Training post block

```java
public class TrainingPostBlock extends Block {

    public TrainingPostBlock(Settings settings) {
        super(settings);
    }

    @Override
    public ActionResult onUse(
        BlockState state,
        World world,
        BlockPos pos,
        PlayerEntity player,
        Hand hand,
        BlockHitResult hit
    ) {
        if (world.isClient) {
            // Simple client feedback
            return ActionResult.SUCCESS;
        }

        if (!(player instanceof ServerPlayerEntity serverPlayer)) {
            return ActionResult.PASS;
        }

        if (!WorldConfig.get().interactions.trainingPostEnabled) {
            return ActionResult.PASS;
        }

        if (WorldConfig.get().interactions.trainingPostSound) {
            world.playSound(
                null,
                pos,
                SoundEvents.BLOCK_WOOD_HIT,
                SoundCategory.BLOCKS,
                0.8f,
                1.0f
            );
        }

        CoreEvents.publish(new TrainingPostUsedEvent(serverPlayer, pos));
        CoreEvents.publish(new WorldBlockInteractedEvent(
            serverPlayer, pos, "shinobicore:training_post", hand));

        if (WorldConfig.get().logging.logInteractions) {
            ShinobiLogger.module("world",
                "Training post used by " + serverPlayer.getName().getString() +
                " at " + pos.toShortString());
        }

        return ActionResult.SUCCESS;
    }
}
```

### 17.4 Chakra altar block

```java
public class ChakraAltarBlock extends Block {

    public ChakraAltarBlock(Settings settings) {
        super(settings);
    }

    @Override
    public ActionResult onUse(
        BlockState state,
        World world,
        BlockPos pos,
        PlayerEntity player,
        Hand hand,
        BlockHitResult hit
    ) {
        if (world.isClient) {
            return ActionResult.SUCCESS;
        }

        if (!(player instanceof ServerPlayerEntity serverPlayer)) {
            return ActionResult.PASS;
        }

        if (!WorldConfig.get().interactions.chakraAltarEnabled) {
            return ActionResult.PASS;
        }

        if (WorldConfig.get().interactions.chakraAltarSound) {
            world.playSound(
                null,
                pos,
                SoundEvents.BLOCK_AMETHYST_BLOCK_CHIME,
                SoundCategory.BLOCKS,
                0.7f,
                1.2f
            );
        }

        CoreEvents.publish(new ChakraAltarUsedEvent(serverPlayer, pos));
        CoreEvents.publish(new WorldBlockInteractedEvent(
            serverPlayer, pos, "shinobicore:chakra_altar", hand));

        if (WorldConfig.get().logging.logInteractions) {
            ShinobiLogger.module("world",
                "Chakra altar used by " + serverPlayer.getName().getString() +
                " at " + pos.toShortString());
        }

        return ActionResult.SUCCESS;
    }
}
```

### 17.5 Item registry

```java
public final class WorldItems {
    private WorldItems() {}

    public static void register() {
        registerBlockItem(WorldBlocks.SAKURA_LOG);
        registerBlockItem(WorldBlocks.SAKURA_LEAVES);
        registerBlockItem(WorldBlocks.SAKURA_PLANKS);
        registerBlockItem(WorldBlocks.BAMBOO_BLOCK);
        registerBlockItem(WorldBlocks.STONE_LANTERN);
        registerBlockItem(WorldBlocks.PAPER_LANTERN);
        registerBlockItem(WorldBlocks.STONE_PATH);
        registerBlockItem(WorldBlocks.TATAMI);
        registerBlockItem(WorldBlocks.SHOJI);
        registerBlockItem(WorldBlocks.TRAINING_POST);
        registerBlockItem(WorldBlocks.CHAKRA_ALTAR);
        registerBlockItem(WorldBlocks.ONSEN_STEAM);

        ShinobiLogger.module("world", "World items registered");
    }

    private static void registerBlockItem(Block block) {
        Identifier id = Registries.BLOCK.getId(block);
        Item item = new BlockItem(block, new Item.Settings());
        Registry.register(Registries.ITEM, id, item);
    }
}
```

### 17.6 Optional creative tab

```java
public final class WorldItemGroup {
    private WorldItemGroup() {}

    public static void register() {
        if (!WorldConfig.get().creativeTab.enabled) return;

        Registry.register(
            Registries.ITEM_GROUP,
            new Identifier("shinobicore", "world"),
            FabricItemGroup.builder()
                .displayName(Text.translatable("itemGroup.shinobicore.world"))
                .icon(() -> new ItemStack(WorldBlocks.STONE_LANTERN))
                .entries((context, entries) -> {
                    entries.add(WorldBlocks.SAKURA_LOG);
                    entries.add(WorldBlocks.SAKURA_LEAVES);
                    entries.add(WorldBlocks.SAKURA_PLANKS);
                    entries.add(WorldBlocks.BAMBOO_BLOCK);
                    entries.add(WorldBlocks.STONE_LANTERN);
                    entries.add(WorldBlocks.PAPER_LANTERN);
                    entries.add(WorldBlocks.STONE_PATH);
                    entries.add(WorldBlocks.TATAMI);
                    entries.add(WorldBlocks.SHOJI);
                    entries.add(WorldBlocks.TRAINING_POST);
                    entries.add(WorldBlocks.CHAKRA_ALTAR);
                    entries.add(WorldBlocks.ONSEN_STEAM);
                })
                .build()
        );
    }
}
```

### 17.7 Recipe JSON example

File:

```text
data/shinobicore/recipes/training_post.json
```

```json
{
  "type": "minecraft:crafting_shaped",
  "pattern": [
    " F ",
    " F ",
    " H "
  ],
  "key": {
    "F": {
      "item": "minecraft:oak_fence"
    },
    "H": {
      "item": "minecraft:hay_block"
    }
  },
  "result": {
    "item": "shinobicore:training_post",
    "count": 1
  }
}
```

---

## 18. HANDOFF

When the world team finishes, they must:

1. Run `.\gradlew.bat build` — must pass with 0 errors.
2. Run `.\gradlew.bat runClient`.
3. Verify:
   - all blocks are present in creative tab
   - blocks can be placed
   - blocks can be broken
   - blocks drop themselves
   - recipes work
   - training post logs/publishes event
   - chakra altar logs/publishes event
   - onsen steam enter/exit events work
4. Verify that disabling the module via `world.json` (`enabled: false`) does not break the game.
5. Verify that Worldgen, Progression, Clans, and AI modules still load correctly.
6. Verify that interactions do not crash when no listener exists.
7. Create a brief `modules/world/README.md`.
8. Notify the core team that the module is ready for integration review.

---

## END OF WORLD TECHNICAL SPECIFICATION
```

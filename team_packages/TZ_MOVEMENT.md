# ТЗ #1: Movement (Паркур / Движение)


```markdown
# TECHNICAL SPECIFICATION: Movement Module

**Module ID:** `movement`
**Module Name:** ShinobiCore - Parkour & Movement
**Priority:** 1 (first wave, alongside combat and jutsu)
**Core dependency:** Sprint 1 (ModuleManager) + Sprint 2 (Chakra, Stats, Formula services)

---

## 1. PURPOSE

Implement a complete shinobi-style movement system:

- Water walking (chakra mode only)
- Wall running / wall sticking
- Wall jumping
- Sliding
- Crawling (double-tap Shift)
- Rolling (i-frames)
- Dodging (quick dash)
- Double jump
- Charged jump
- Edge grabbing
- Naruto-run visual (sprinting with arms back in chakra mode)
- Meditation pose (optional, as movement state)

**NOT in scope** (these belong to other modules):
- Specific elemental dashes (e.g., Wind Release: Passing Gale) → Jutsu module
- Combat dodges that grant combat buffs → Combat module
- Any form of flying / levitation

---

## 2. FILE OWNERSHIP

The movement team may ONLY create and modify files in these locations:

```
src/main/java/com/example/shinobicore/modules/movement/
src/main/resources/data/shinobicore/movement/       (if needed later)
src/main/resources/assets/shinobicore/movement/     (textures, sounds, animations)
config/shinobicore/modules/movement.json            (generated at runtime)
```

The movement team MUST NOT modify:
- Any file under `core/`
- `ShinobiCoreMod.java` or `ShinobiCoreClient.java`
- Any file belonging to another module
- `fabric.mod.json` (entrypoint addition is done by core team)

---

## 3. ARCHITECTURE

### 3.1 Package structure

```
modules/movement/
├── MovementModule.java                 (entry point, implements ClientAwareModule)
├── config/
│   └── MovementConfig.java             (parsed JSON)
├── common/
│   ├── MovementActions.java            (constants: action IDs)
│   └── MovementPose.java               (enum: poses)
├── client/
│   ├── ClientMovementController.java   (main client tick)
│   ├── WaterWalkService.java
│   ├── WallRunService.java
│   ├── WallJumpService.java
│   ├── SlideService.java
│   ├── CrawlService.java
│   ├── RollService.java
│   ├── DodgeService.java
│   ├── DoubleJumpService.java
│   ├── ChargedJumpService.java
│   ├── EdgeGrabService.java
│   ├── NarutoRunRenderer.java
│   ├── input/
│   │   └── MovementKeyBindings.java
│   └── util/
│       ├── WallDetector.java           (raycast-based)
│       └── WaterSurfaceDetector.java   (FluidState-based)
├── server/
│   ├── MovementServerMirror.java       (soft validation)
│   └── DrainAccumulator.java           (chakra drain per second)
├── network/
│   ├── MovementPackets.java            (packet registry)
│   ├── MovementActionPacket.java       (client -> server: action triggered)
│   └── MovementStateSyncPacket.java    (server -> client: state snapshot)
├── data/
│   └── MovementComponentImpl.java      (CCA component, if needed for server mirror)
└── view/
    └── MovementVisualViewImpl.java     (implements MovementVisualView)
```

### 3.2 Module entry point

```java
public class MovementModule implements ClientAwareModule {
    public static final String ID = "movement";

    @Override public String id() { return ID; }

    @Override
    public void onRegister(ModuleContext ctx) {
        // Register CCA component if needed
    }

    @Override
    public void onEnable(ModuleContext ctx) {
        MovementConfig.load(ctx.configs().readModuleConfig(ID));
        MovementServerMirror.init();
        MovementPackets.registerServer();
    }

    @Override
    public void registerEvents(ModuleContext ctx) {
        ctx.events().subscribe(ChakraModeEnabledEvent.class, e -> { /* ... */ });
        ctx.events().subscribe(ChakraModeDisabledEvent.class, e -> { /* ... */ });
        ctx.events().subscribe(ChakraChangedEvent.class, e -> { /* ... */ });
        ctx.events().subscribe(FatigueChangedEvent.class, e -> { /* ... */ });
        ctx.events().subscribe(PlayerDiedEvent.class, e -> { /* ... */ });
        ctx.events().subscribe(PlayerRespawnedEvent.class, e -> { /* ... */ });
    }

    @Override
    public void registerViews(ModuleContext ctx) {
        ctx.views().register(MovementVisualView.class, player ->
            Optional.of(new MovementVisualViewImpl(player)));
    }

    @Override
    public void registerCommands(ModuleContext ctx, CommandDispatcher<ServerCommandSource> d) {
        MovementCommands.register(d);
    }

    @Override
    public void onClientInit(ModuleContext ctx) {
        MovementKeyBindings.register();
        ClientMovementController.init();
        MovementPackets.registerClient();
    }

    @Override
    public void onClientTick(ModuleContext ctx) {
        ClientMovementController.tick();
    }

    @Override
    public void onServerTick(ModuleContext ctx, MinecraftServer server) {
        MovementServerMirror.tick(server);
    }
}
```

Register the module in `fabric.mod.json` under `"shinobicore:module"` entrypoint (core team will do this).

---

## 4. CORE API TO USE

### 4.1 ChakraApi (service)

```java
CoreServices.get(ChakraApi.class).ifPresent(chakra -> {
    float current = chakra.getCurrent(player);
    float max     = chakra.getMax(player);
    boolean mode  = chakra.isChakraModeActive(player);
    boolean ex    = chakra.isExhausted(player);
    chakra.trySpend(player, 1.0f);   // returns false if insufficient
});
```

### 4.2 StatsApi (service)

```java
CoreServices.get(StatsApi.class).ifPresent(stats -> {
    int jumpLevel   = stats.getStatLevel(player, "jump");
    int speedLevel  = stats.getStatLevel(player, "speed");
    int controlLvl  = stats.getStatLevel(player, "control");
});
```

### 4.3 FormulaApi (service)

Use for derived values:
- `calcMovementSpeed(player)` → final speed multiplier
- `calcJumpHeight(player)` → final jump boost
- `calcFatigueGain(player, baseStrain)` → final fatigue added per second

### 4.4 Events to publish

```java
// Define these as records inside modules/movement/common/
public record WaterWalkStartedEvent(PlayerEntity player) {}
public record WaterWalkStoppedEvent(PlayerEntity player) {}
public record WallRunStartedEvent(PlayerEntity player, Vec3d normal) {}
public record WallRunStoppedEvent(PlayerEntity player) {}
public record WallJumpedEvent(PlayerEntity player, Vec3d normal) {}
public record SlideStartedEvent(PlayerEntity player) {}
public record SlideStoppedEvent(PlayerEntity player) {}
public record RollStartedEvent(PlayerEntity player) {}
public record RollStoppedEvent(PlayerEntity player) {}
public record DodgeEvent(PlayerEntity player, Vec3d direction) {}
public record DoubleJumpedEvent(PlayerEntity player) {}
public record ChargedJumpReleasedEvent(PlayerEntity player, float chargeTime) {}
public record EdgeGrabStartedEvent(PlayerEntity player) {}
public record EdgeGrabStoppedEvent(PlayerEntity player) {}
```

Publish via: `CoreEvents.publish(new WaterWalkStartedEvent(player));`

### 4.5 Events to subscribe

```
ChakraModeEnabledEvent
ChakraModeDisabledEvent
ChakraChangedEvent        (disable parkour when currentChakra reaches 0)
FatigueChangedEvent        (disable parkour when fully exhausted)
ExhaustionChangedEvent
PlayerDiedEvent
PlayerRespawnedEvent
PlayerChangedDimensionEvent
```

---

## 5. VIEWS TO REGISTER

Register one view:

```java
public interface MovementVisualView {
    boolean isWaterWalking();
    boolean isWallRunning();
    boolean isSliding();
    boolean isCrawling();
    boolean isRolling();
    boolean isDodging();
    boolean isChargingJump();
    boolean isEdgeGrabbing();
    float   getMoveSpeed();
    float   getActionProgress();  // 0.0 - 1.0
    Vec3d   getWallNormal();      // or null if not on wall
}
```

Implementation `MovementVisualViewImpl` reads the current pose from the module's internal state and exposes it.

---

## 6. MECHANICS — DETAILED BEHAVIOR

### 6.1 Water Walking

Trigger conditions (ALL must be true):
- Player is in chakra mode (via `ChakraApi.isChakraModeActive(player)`)
- Player has `currentChakra > 0`
- Player is NOT exhausted
- Player is above a water source or flowing water block
- Player is NOT fully submerged (feet Y between surface and surface + 0.05)
- Player is NOT sneaking
- Player is NOT swimming

Behavior:
- Keep player's Y at `surfaceY + small offset` (no sinking, no popping up)
- Allow normal horizontal movement (sprint, walk)
- Reset fall distance to 0
- Drain chakra at `waterWalkDrainPerSecond` from config
- If chakra reaches 0 → exit water walking immediately

Detection logic:
```java
BlockPos below = player.getBlockPos().down();
FluidState fs = world.getFluidState(below);
boolean isWater = fs.isOf(Fluids.WATER) || fs.isOf(Fluids.FLOWING_WATER);
// Make sure not to stand on KELP or other waterlogged blocks as if they were water surface
```

### 6.2 Wall Running / Sticking

Trigger conditions:
- Player in chakra mode
- Player has chakra
- Player is NOT exhausted
- Player is NOT on ground
- Player is moving horizontally (not falling straight down)
- `WallDetector.getWallNormal(player)` returns a non-null normal
- Horizontal collision detected OR player is moving toward a wall

Behavior:
- Cancel velocity INTO the wall (velocity dot normal < 0 → subtract)
- Align movement to wall plane (keep gravity component, convert horizontal to wall-parallel)
- Apply reduced gravity (configurable `wallGravity`)
- Allow upward/downward movement along wall
- Drain chakra at `wallRunDrainPerSecond`
- Cooldown 1 second (20 ticks) after exiting wall before re-sticking
- Soft camera tilt optional (NOT aggressive camera roll)

### 6.3 Wall Jump

Trigger:
- Player was wall-running
- Player presses jump key

Behavior:
- Push away from wall: `velocity = wallNormal * wallJumpPush + upBoost`
- Enter cooldown (cannot re-stick for `wallJumpCooldownTicks`)
- Consume fatigue

### 6.4 Sliding

Trigger:
- Player is sprinting
- Player presses sneak while moving fast
- OR enters a 1.5-block gap

Behavior:
- Change pose to SWIMMING (hitbox 0.6 high) for sliding under blocks
- Maintain forward velocity, apply friction
- Duration: `slideDurationTicks` from config
- No chakra cost

### 6.5 Crawling

Trigger:
- Double-tap sneak (Shift) within `DOUBLE_TAP_MS` (250ms) while stationary

Behavior:
- Switch to SWIMMING pose
- Slow movement
- Double-tap again to exit
- No chakra cost

### 6.6 Rolling

Trigger:
- Dedicated keybind (configurable, default: R or Alt)

Behavior:
- 12-tick animation
- 8 i-frames (damage immunity)
- Roll direction = look direction + forward input
- Cooldown: `rollCooldownTicks`
- No chakra cost

### 6.7 Dodging

Trigger:
- Single tap sneak + directional input (forward/back/left/right)

Behavior:
- Quick dash in input direction
- ~8 blocks distance (configurable `dashStrength`)
- 4 i-frames
- Cooldown: `dodgeCooldownTicks`
- Small chakra cost (optional)

### 6.8 Double Jump

Trigger:
- Press jump while in air AND NOT falling yet (velocity.y >= 0)
- Has double-jump charges remaining (default 1 extra jump)

Behavior:
- Reset vertical velocity
- Apply `doubleJumpBoost`
- Reset charge on ground contact
- No chakra cost

### 6.9 Charged Jump

Trigger:
- Hold jump while standing still for `chargeTimeTicks`

Behavior:
- Visual charging indicator
- On release, jump with `chargedJumpMultiplier * normalJump`
- Small chakra cost

### 6.10 Edge Grab

Trigger:
- Player falling (velocity.y < 0)
- Horizontal collision with block
- Block above is air (can climb)
- Within `edgeGrabReach` distance

Behavior:
- Freeze player at edge
- On jump key → climb up (teleport +1 block Y)
- On sneak key → release, fall
- Small chakra cost

---

## 7. DRAIN ACCUMULATOR PATTERN

All chakra drains happen **once per second**, not every tick:

```java
public class DrainAccumulator {
    private double accumulator = 0.0;
    private final double perSecond;

    public DrainAccumulator(double perSecond) {
        this.perSecond = perSecond;
    }

    /** Called every tick. Returns the whole amount to spend now. */
    public int tick(double deltaTimeSeconds) {
        accumulator += perSecond * deltaTimeSeconds;
        int toSpend = (int) accumulator;
        accumulator -= toSpend;
        return toSpend;
    }

    public void reset() { accumulator = 0.0; }
}
```

Tick rate: `deltaTimeSeconds = 1.0 / 20.0` per server/client tick.

---

## 8. CLIENT-SERVER AUTHORITY

```
CLIENT (authoritative for feel):
- Detects water, walls, edges
- Applies velocity changes immediately
- Updates pose state
- Sends action packet to server (e.g., WALL_JUMP)
- Plays sounds and particles

SERVER (mirror + soft validation):
- Receives action packets
- Updates its own MovementComponent state
- Drains chakra at configured rate (once per second)
- Validates:
  - Player is actually in chakra mode
  - Player had enough chakra
  - Action is not spamming beyond rate limits
- If anomaly detected: log warning, gently correct, do NOT crash
- Does NOT replicate physics calculations
```

### CRITICAL PACKET RULE

```java
ServerPlayNetworking.registerGlobalReceiver(ID, (server, player, handler, buf, sender) -> {
    // STEP 1: Read ALL data from buffer FIRST
    final int actionId = buf.readInt();
    final float yaw = buf.readFloat();
    final double vx = buf.readDouble();
    final double vz = buf.readDouble();

    // STEP 2: Execute on server thread
    server.execute(() -> {
        MovementServerMirror.handleAction(player, actionId, yaw, vx, vz);
    });
});
```

NEVER read `buf` inside `server.execute()`.

---

## 9. FULL CONFIG TEMPLATE

File: `config/shinobicore/modules/movement.json` (auto-created on first run)

```json
{
  "enabled": true,
  "debug": false,

  "waterWalk": {
    "enabled": true,
    "drainPerSecond": 1.5,
    "surfaceOffset": 0.05,
    "minHorizontalSpeed": 0.02
  },

  "wallRun": {
    "enabled": true,
    "drainPerSecond": 1.5,
    "gravityMultiplier": 0.3,
    "maxDurationTicks": 120,
    "stickCooldownTicks": 20,
    "minHorizontalSpeed": 0.1,
    "raycastDistance": 0.6
  },

  "wallJump": {
    "enabled": true,
    "pushStrength": 0.6,
    "upBoost": 0.45,
    "cooldownTicks": 20
  },

  "slide": {
    "enabled": true,
    "durationTicks": 20,
    "minSprintSpeed": 0.18,
    "friction": 0.92
  },

  "crawl": {
    "enabled": true,
    "doubleTapMs": 250,
    "speedMultiplier": 0.4
  },

  "roll": {
    "enabled": true,
    "durationTicks": 12,
    "iframeTicks": 8,
    "cooldownTicks": 40,
    "distance": 3.0
  },

  "dodge": {
    "enabled": true,
    "strength": 3.2,
    "iframeTicks": 4,
    "cooldownTicks": 30,
    "chakraCost": 2.0
  },

  "doubleJump": {
    "enabled": true,
    "boost": 0.42,
    "maxCharges": 1,
    "chakraCost": 1.0
  },

  "chargedJump": {
    "enabled": true,
    "chargeTicks": 30,
    "maxMultiplier": 2.5,
    "chakraCost": 3.0
  },

  "edgeGrab": {
    "enabled": true,
    "reachDistance": 0.6,
    "chakraCost": 1.0,
    "climbBoost": 1.0
  },

  "narutoRun": {
    "enabled": true,
    "minSprintSpeed": 0.18,
    "maxSprintSpeed": 0.45
  },

  "formula": {
    "jumpGainPerLevel": 0.02,
    "speedGainPerLevel": 0.015,
    "chakraModeJumpMultiplier": 1.3,
    "chakraModeSpeedMultiplier": 1.15
  },

  "logging": {
    "logActions": false,
    "logDrains": false
  }
}
```

### Config rules

1. File is read ONCE at module load.
2. Missing file → default is created.
3. Missing field → default used (module must NOT crash).
4. Invalid JSON → log error, use defaults, module continues.
5. No hot reload.

---

## 10. COMMANDS

```
/shinobicore movement state            - show current pose + flags
/shinobicore movement test             - spawn test structures (water pool, walls)
/shinobicore movement debug           - toggle debug overlay for this module
/shinobicore movement reset            - reset pose to NORMAL
```

These are diagnostic tools. Command `state` must print a compact snapshot:

```
=== Movement State ===
Pose: WALL_RUNNING
Chakra: 85/100 (mode: ON)
Wall normal: (0.0, 0.0, 1.0)
Water surface: N/A
Drain acc: 0.42
Cooldowns: wall=0, roll=12, dodge=0
```

---

## 11. FORBIDDEN PATTERNS

Movement team MUST NOT do any of these:

1. **DO NOT** cancel vanilla `tickMovement` via mixin. Apply velocity changes on top of vanilla movement.
2. **DO NOT** use aggressive camera roll mixins.
3. **DO NOT** store player data in `static Map<UUID, State>` without cleanup on player disconnect.
4. **DO NOT** drain chakra on the server AND the client separately (double drain bug). Client predicts visually; server is authoritative for actual drain.
5. **DO NOT** use `System.out.println`. Use `ShinobiLogger.module("movement", ...)`.
6. **DO NOT** import classes from other modules (combat, jutsu, etc.). Use core events/services only.
7. **DO NOT** write god-classes (>300 lines). Decompose.
8. **DO NOT** read PacketByteBuf inside `server.execute()`.
9. **DO NOT** hardcode blocks by `==` comparison. Use `instanceof` or tags.
10. **DO NOT** create mixins that globally intercept all movement without guards.

---

## 12. ANIMATIONS

Use `PlayerAnimator` for:
- Water walk pose (arms slightly raised, feet tapping)
- Wall run pose (tilted toward wall)
- Slide pose (low crouch)
- Roll animation
- Dodge animation (blur + quick shift)
- Charged jump crouch
- Edge grab hang
- Naruto run (arms back)

Register animations via the `compat/PlayerAnimatorCompat.java` adapter (provided by core).

---

## 13. DEFINITION OF DONE

The movement module is complete when:

1. ✅ Module loads via `shinobicore:module` entrypoint
2. ✅ `/shinobicore systems` shows `movement: ENABLED`
3. ✅ Water walking works only in chakra mode with chakra > 0
4. ✅ Wall running works with stable physics (no magnet/jitter)
5. ✅ Wall jump pushes player away from wall correctly
6. ✅ Slide, crawl, roll, dodge each have distinct triggers and behaviors
7. ✅ Double jump resets on ground contact
8. ✅ Charged jump charges while holding key, releases with boost
9. ✅ Edge grab works on block edges
10. ✅ Chakra drains once per second (accumulator pattern), not every tick
11. ✅ At chakra = 0, all parkour disables automatically
12. ✅ At full fatigue/exhaustion, all parkour disables automatically
13. ✅ No double chakra drain (client+server)
14. ✅ Server soft-validates actions, does not crash on anomaly
15. ✅ Animations present for all major actions
16. ✅ Commands `/shinobicore movement state|test|debug` work
17. ✅ Log files `logs/shinobicore/movement-1.log` created and rotated
18. ✅ Module does not crash when other modules are disabled
19. ✅ No `System.out.println` in production code
20. ✅ Config file `movement.json` is created on first run with defaults
21. ✅ Broken JSON does not crash the game
22. ✅ All network packets follow "read first, execute second" rule
23. ✅ `MovementVisualView` registered and readable by visual module
24. ✅ Build passes: `.\gradlew.bat build`

---

## 14. EXAMPLE CODE SNIPPETS

### 14.1 Water surface detection

```java
public final class WaterSurfaceDetector {
    public static Optional<Double> getSurfaceY(ClientPlayerEntity player) {
        World world = player.getWorld();
        BlockPos feet = player.getBlockPos();

        for (int dy = 0; dy >= -2; dy--) {
            BlockPos check = feet.down(-dy);
            FluidState fs = world.getFluidState(check);
            if (!fs.isEmpty() && (fs.isOf(Fluids.WATER) || fs.isOf(Fluids.FLOWING_WATER))) {
                double surfaceY = check.getY() + fs.getHeight(world, check);
                double playerFeetY = player.getY();
                if (playerFeetY >= surfaceY - 0.05 && playerFeetY <= surfaceY + 0.25) {
                    return Optional.of(surfaceY);
                }
            }
        }
        return Optional.empty();
    }
}
```

### 14.2 Wall detector (simplified)

```java
public final class WallDetector {
    private static final double RAYCAST_DIST = 0.6;
    private static final int[][] DIRS = {{1,0},{-1,0},{0,1},{0,-1}};

    public static Vec3d getWallNormal(ClientPlayerEntity player) {
        World world = player.getWorld();
        Vec3d feet = player.getPos().add(0, 0.2, 0);
        Vec3d body = player.getPos().add(0, 1.2, 0);

        for (int[] d : DIRS) {
            Vec3d dir = new Vec3d(d[0], 0, d[1]);
            if (hitsWall(world, feet, dir)) return new Vec3d(-d[0], 0, -d[1]);
            if (hitsWall(world, body, dir)) return new Vec3d(-d[0], 0, -d[1]);
        }
        return null;
    }

    private static boolean hitsWall(World world, Vec3d origin, Vec3d dir) {
        Vec3d end = origin.add(dir.multiply(RAYCAST_DIST));
        BlockHitResult hit = world.raycast(new RaycastContext(
            origin, end,
            RaycastContext.ShapeType.COLLIDER,
            RaycastContext.FluidHandling.NONE,
            null  // entity = null for pure block raycast
        ));
        return hit.getType() != HitResult.Type.MISS;
    }
}
```

### 14.3 Drain accumulator usage in server mirror

```java
public final class MovementServerMirror {
    private static final Map<UUID, DrainAccumulator> DRAIN = new ConcurrentHashMap<>();

    public static void tick(MinecraftServer server) {
        for (ServerPlayerEntity p : server.getPlayerManager().getPlayerList()) {
            Optional<ChakraApi> chakraOpt = CoreServices.get(ChakraApi.class);
            if (chakraOpt.isEmpty()) continue;
            ChakraApi chakra = chakraOpt.get();

            if (!chakra.isChakraModeActive(p)) {
                DRAIN.remove(p.getUuid());
                continue;
            }

            // Determine which drain rate applies
            double rate = getActiveDrainRate(p);
            if (rate <= 0) {
                DRAIN.remove(p.getUuid());
                continue;
            }

            DrainAccumulator acc = DRAIN.computeIfAbsent(p.getUuid(),
                id -> new DrainAccumulator(rate));
            int toSpend = acc.tick(1.0 / 20.0);

            if (toSpend > 0) {
                if (!chakra.trySpend(p, toSpend)) {
                    // Chakra depleted - disable parkour via event
                    CoreEvents.publish(new ChakraDepletedEvent(p));
                }
            }
        }
    }

    private static double getActiveDrainRate(ServerPlayerEntity p) {
        // Read current pose from movement component, return appropriate rate
        // waterWalkDrainPerSecond, wallRunDrainPerSecond, or 0
        return 0.0; // placeholder
    }
}
```

---

## 15. HANDOFF

When the movement team finishes, they must:

1. Run `.\gradlew.bat build` — must pass with 0 errors.
2. Run `.\gradlew.bat runClient` and manually verify all 11 mechanics.
3. Verify that disabling the module via `config/shinobicore/modules/movement.json` (`enabled: false`) does not break the game.
4. Verify that other modules (when present) still load correctly.
5. Create a brief `modules/movement/README.md` describing any non-obvious behaviors.
6. Notify the core team that the module is ready for integration review.

---

## END OF MOVEMENT TECHNICAL SPECIFICATION
```

# ТЗ #7: Visual (Визуал / Эффекты)

Сохранить как: `team_packages/TZ_VISUAL.md`

---

```markdown
# TECHNICAL SPECIFICATION: Visual Module

**Module ID:** `visual`
**Module Name:** ShinobiCore - Visual Effects
**Priority:** 2 (second wave, alongside progression, clans, HUD)
**Core dependency:** Sprint 1 (ModuleManager) + Sprint 2 (all core services) + all other modules' views

---

## 1. PURPOSE

Implement the complete visual effects system:

- Particles (casting, impact, trail, aura)
- Trail rendering (weapon swings, movement dashes)
- Aura rendering (chakra mode, dojutsu, clan auras)
- Camera shake (impact, explosion, heavy hits)
- Screen flash (cast completion, level up)
- Cast visual effects (hand seal animation, charge glow)
- Movement visual effects (water ripple, wall run dust, slide dust)
- Combat visual effects (hit sparks, block flash, parry flash)
- Enemy visual effects (state indicators, telegraph warnings)
- Particle pooling and reuse
- Particle limits and culling
- Effect cooldowns (anti-spam)
- Quality preset stub (for future low/medium/high settings)

**NOT in scope** (belong to other modules):
- Chakra/stat/progression data management → core services
- Jutsu casting logic → Jutsu module (we only read their view)
- Combat logic → Combat module (we only read their view)
- Movement logic → Movement module (we only read their view)
- HUD rendering → HUD module
- Sound effects → separate audio module (future)
- GeckoLib model rendering → GeckoLibAdapter (core compat layer)

**CRITICAL: Visual module is READ-ONLY for game state.** It never modifies any game state. It only reads views and renders effects.

---

## 2. FILE OWNERSHIP

The visual team may ONLY create and modify files in these locations:

```
src/main/java/com/example/shinobicore/modules/visual/
src/main/resources/assets/shinobicore/visual/      (textures, particles, shaders)
config/shinobicore/modules/visual.json             (generated at runtime)
```

The visual team MUST NOT modify:
- Any file under `core/`
- `ShinobiCoreMod.java` or `ShinobiCoreClient.java`
- Any file belonging to another module
- `fabric.mod.json` (entrypoint addition is done by core team)
- Any game state (chakra, stats, progression, etc.)

---

## 3. ARCHITECTURE

### 3.1 Package structure

```
modules/visual/
├── VisualModule.java                          (entry point, implements ClientAwareModule)
├── config/
│   ├── VisualConfig.java
│   └── VisualConfigLoader.java
├── pool/
│   ├── ParticlePool.java                      (object pool for particles)
│   ├── TrailPool.java                         (object pool for trails)
│   └── EffectHandle.java                      (handle to a pooled effect)
├── particle/
│   ├── ParticleService.java                   (main particle orchestrator)
│   ├── ParticleEmitter.java                   (emits particles)
│   ├── ParticleDefinition.java                (record: particle type config)
│   ├── CastParticleEmitter.java
│   ├── ImpactParticleEmitter.java
│   ├── TrailParticleEmitter.java
│   └── AuraParticleEmitter.java
├── trail/
│   ├── TrailService.java                      (weapon swing trails)
│   ├── TrailRenderer.java
│   └── TrailDefinition.java
├── aura/
│   ├── AuraService.java                       (chakra mode aura, dojutsu aura)
│   ├── AuraRenderer.java
│   └── AuraDefinition.java
├── camera/
│   ├── CameraShakeService.java                (camera shake on impact)
│   └── CameraShakeDefinition.java
├── screen/
│   ├── ScreenFlashService.java                (screen flash on events)
│   └── ScreenFlashDefinition.java
├── culling/
│   ├── EffectCullingService.java              (disable distant effects)
│   └── EffectDistanceCalculator.java
├── listener/
│   ├── MovementVisualListener.java            (listens to movement events)
│   ├── CombatVisualListener.java              (listens to combat events)
│   ├── JutsuVisualListener.java               (listens to jutsu events)
│   ├── EnemyVisualListener.java               (listens to enemy events)
│   └── ProgressionVisualListener.java         (listens to progression events)
├── view/
│   └── VisualViewConsumer.java                (reads all views from core)
└── util/
    ├── ParticleColors.java                    (color constants)
    └── EffectRateLimiter.java                 (cooldown between effects)
```

### 3.2 Module entry point

```java
public class VisualModule implements ClientAwareModule {
    public static final String ID = "visual";

    @Override public String id() { return ID; }

    @Override
    public void onRegister(ModuleContext ctx) {
        // No CCA component needed (read-only module)
    }

    @Override
    public void onEnable(ModuleContext ctx) {
        VisualConfig.load(ctx.configs().readModuleConfig(ID));

        // Init pools
        ParticlePool.init(VisualConfig.get().pool.particlePoolSize);
        TrailPool.init(VisualConfig.get().pool.trailPoolSize);

        // Init services
        ParticleService.init();
        TrailService.init();
        AuraService.init();
        CameraShakeService.init();
        ScreenFlashService.init();
        EffectCullingService.init();
        EffectRateLimiter.init();

        // Init listeners
        MovementVisualListener.init();
        CombatVisualListener.init();
        JutsuVisualListener.init();
        EnemyVisualListener.init();
        ProgressionVisualListener.init();
    }

    @Override
    public void registerEvents(ModuleContext ctx) {
        // Subscribe to events that trigger visual effects
        ctx.events().subscribe(JutsuCastStartedEvent.class, e ->
            JutsuVisualListener.onCastStarted(e));
        ctx.events().subscribe(JutsuCastFinishedEvent.class, e ->
            JutsuVisualListener.onCastFinished(e));
        ctx.events().subscribe(JutsuProjectileSpawnedEvent.class, e ->
            JutsuVisualListener.onProjectileSpawned(e));
        ctx.events().subscribe(JutsuAreaCreatedEvent.class, e ->
            JutsuVisualListener.onAreaCreated(e));
        ctx.events().subscribe(JutsuWallCreatedEvent.class, e ->
            JutsuVisualListener.onWallCreated(e));

        ctx.events().subscribe(CombatHitEvent.class, e ->
            CombatVisualListener.onHit(e));
        ctx.events().subscribe(CombatBlockedEvent.class, e ->
            CombatVisualListener.onBlocked(e));
        ctx.events().subscribe(CombatParriedEvent.class, e ->
            CombatVisualListener.onParried(e));
        ctx.events().subscribe(CombatKickEvent.class, e ->
            CombatVisualListener.onKick(e));
        ctx.events().subscribe(ThrowableThrownEvent.class, e ->
            CombatVisualListener.onThrown(e));

        ctx.events().subscribe(WaterWalkStartedEvent.class, e ->
            MovementVisualListener.onWaterWalkStarted(e));
        ctx.events().subscribe(WallRunStartedEvent.class, e ->
            MovementVisualListener.onWallRunStarted(e));
        ctx.events().subscribe(SlideStartedEvent.class, e ->
            MovementVisualListener.onSlideStarted(e));
        ctx.events().subscribe(RollStartedEvent.class, e ->
            MovementVisualListener.onRollStarted(e));
        ctx.events().subscribe(DodgeEvent.class, e ->
            MovementVisualListener.onDodge(e));

        ctx.events().subscribe(ChakraModeEnabledEvent.class, e ->
            AuraService.onChakraModeEnabled(e));
        ctx.events().subscribe(ChakraModeDisabledEvent.class, e ->
            AuraService.onChakraModeDisabled(e));

        ctx.events().subscribe(LevelChangedEvent.class, e ->
            ProgressionVisualListener.onLevelUp(e));
    }

    @Override
    public void registerViews(ModuleContext ctx) {
        // Visual does NOT register views. It only consumes them.
    }

    @Override
    public void registerCommands(ModuleContext ctx, CommandDispatcher<ServerCommandSource> d) {
        VisualCommands.register(d);
    }

    @Override
    public void onClientInit(ModuleContext ctx) {
        VisualViewConsumer.init(ctx);
        ParticleRenderer.register();
        TrailRenderer.register();
        AuraRenderer.register();
    }

    @Override
    public void onClientTick(ModuleContext ctx) {
        VisualViewConsumer.pollViews();
        ParticleService.tick();
        TrailService.tick();
        AuraService.tick();
        CameraShakeService.tick();
        ScreenFlashService.tick();
        EffectRateLimiter.tick();
    }
}
```

---

## 4. CORE API TO USE (READ-ONLY)

### 4.1 Views to consume

Visual reads views registered by other modules:

```java
// Movement (from movement module)
CoreViews.get(player, MovementVisualView.class).ifPresent(movement -> {
    boolean waterWalking = movement.isWaterWalking();
    boolean wallRunning = movement.isWallRunning();
    boolean sliding = movement.isSliding();
    boolean rolling = movement.isRolling();
    boolean dodging = movement.isDodging();
    Vec3d wallNormal = movement.getWallNormal();
});

// Combat (from combat module)
CoreViews.get(player, CombatVisualView.class).ifPresent(combat -> {
    String stance = combat.getCurrentStance();
    boolean blocking = combat.isBlocking();
    boolean parrying = combat.isParrying();
    int comboStep = combat.getComboStep();
    boolean sheathed = combat.isSheathed();
});

// Jutsu (from jutsu module)
CoreViews.get(player, JutsuVisualView.class).ifPresent(jutsu -> {
    boolean casting = jutsu.isCasting();
    float castProgress = jutsu.getCastProgress();
    String currentJutsu = jutsu.getCurrentJutsuId();
    String elementId = jutsu.getCurrentElementId();
    List<ProjectileView> projectiles = jutsu.getActiveProjectiles();
    List<ZoneView> zones = jutsu.getActiveZones();
    List<WallView> walls = jutsu.getActiveWalls();
});

// Progression (from progression module)
CoreViews.get(player, ProgressionVisualView.class).ifPresent(prog -> {
    int level = prog.getPlayerLevel();
    // Optional: level-up visual effect
});

// Clan (from clans module)
CoreViews.get(player, ClanVisualView.class).ifPresent(clan -> {
    String clanColor = clan.getClanColor();
    // Optional: clan-specific aura color
});

// Enemy (from AI module)
CoreViews.get(player, EnemyVisualView.class).ifPresent(enemy -> {
    String state = enemy.getCurrentState();
    boolean casting = enemy.isCasting();
    // Optional: enemy state indicator
});
```

### 4.2 Events to subscribe

```
JutsuCastStartedEvent         -> cast particle effect
JutsuCastFinishedEvent        -> impact particle effect
JutsuProjectileSpawnedEvent   -> projectile trail
JutsuAreaCreatedEvent         -> zone particle effect
JutsuWallCreatedEvent         -> wall particle effect
CombatHitEvent                -> hit spark
CombatBlockedEvent            -> block flash
CombatParriedEvent            -> parry flash
CombatKickEvent               -> kick dust
ThrowableThrownEvent          -> throw trail
WaterWalkStartedEvent         -> water ripple
WallRunStartedEvent           -> wall run dust
SlideStartedEvent             -> slide dust
RollStartedEvent              -> roll dust
DodgeEvent                    -> dodge blur
ChakraModeEnabledEvent        -> chakra aura on
ChakraModeDisabledEvent       -> chakra aura off
LevelChangedEvent             -> level-up screen flash
```

---

## 5. VISUAL EFFECTS — DETAILED BEHAVIOR

### 5.1 Particle system

**Particle types:**

| Type | Trigger | Color | Lifetime | Count |
|------|---------|-------|----------|-------|
| Cast | Jutsu cast start | Element color | 20-40 ticks | 10-30 |
| Impact | Jutsu cast finish | Element color | 10-20 ticks | 20-50 |
| Projectile trail | Projectile movement | Element color | 5-10 ticks | 1-3 per tick |
| Zone | Zone creation | Element color | 40-60 ticks | 30-60 |
| Wall | Wall creation | Element color | 40-60 ticks | 30-60 |
| Hit spark | Combat hit | White/yellow | 5-10 ticks | 5-15 |
| Block flash | Combat block | Blue | 3-5 ticks | 10-20 |
| Parry flash | Combat parry | Gold | 3-5 ticks | 15-25 |
| Kick dust | Combat kick | Brown | 10-15 ticks | 5-10 |
| Throw trail | Throwable thrown | Gray | 5-10 ticks | 1-2 per tick |
| Water ripple | Water walk start | Blue | 10-20 ticks | 10-20 |
| Wall run dust | Wall run | Gray | 5-10 ticks | 2-5 per tick |
| Slide dust | Slide | Brown | 5-10 ticks | 3-6 |
| Roll dust | Roll | Brown | 5-10 ticks | 5-10 |
| Dodge blur | Dodge | White | 3-5 ticks | 10-15 |
| Chakra aura | Chakra mode | Blue | Continuous | 2-5 per tick |
| Level-up flash | Level up | Gold | 20-30 ticks | Screen flash |

**Particle pooling:**

```java
public final class ParticlePool {
    private static final List<PooledParticle> pool = new ArrayList<>();
    private static int activeCount = 0;

    public static void init(int poolSize) {
        for (int i = 0; i < poolSize; i++) {
            pool.add(new PooledParticle());
        }
    }

    public static PooledParticle acquire() {
        if (activeCount >= pool.size()) {
            return null; // Pool exhausted, skip effect
        }
        PooledParticle p = pool.get(activeCount);
        activeCount++;
        return p;
    }

    public static void release(PooledParticle p) {
        activeCount--;
        p.reset();
    }

    public static int getActiveCount() { return activeCount; }
    public static int getPoolSize() { return pool.size(); }
}
```

**Particle limits:**

```java
public final class ParticleService {
    private static final int MAX_PARTICLES_PER_FRAME = 50;
    private static final int MAX_PARTICLES_PER_SECOND = 200;
    private static int particlesThisFrame = 0;
    private static int particlesThisSecond = 0;

    public static boolean canSpawnParticle() {
        if (particlesThisFrame >= MAX_PARTICLES_PER_FRAME) return false;
        if (particlesThisSecond >= MAX_PARTICLES_PER_SECOND) return false;
        return true;
    }

    public static void onParticleSpawned() {
        particlesThisFrame++;
        particlesThisSecond++;
    }

    public static void tick() {
        particlesThisFrame = 0;
        // Reset per-second counter every 20 ticks
        if (tickCounter % 20 == 0) {
            particlesThisSecond = 0;
        }
        tickCounter++;
    }
}
```

### 5.2 Trail rendering

**Weapon swing trails:**

```
Trigger: Combat attack (via CombatHitEvent)
Shape: Curved arc following weapon swing
Color: Weapon element color or white
Lifetime: 5-10 ticks
Width: Tapers from 3px to 0px
```

**Movement dash trails:**

```
Trigger: Dodge (via DodgeEvent)
Shape: Straight line following dodge direction
Color: White with alpha fade
Lifetime: 3-5 ticks
Width: 2px
```

**Projectile trails:**

```
Trigger: Projectile movement (via JutsuProjectileSpawnedEvent)
Shape: Line following projectile position
Color: Jutsu element color
Lifetime: 5-10 ticks
Width: 1-2px
```

**Trail pooling:**

```java
public final class TrailPool {
    private static final List<PooledTrail> pool = new ArrayList<>();
    private static int activeCount = 0;

    public static void init(int poolSize) {
        for (int i = 0; i < poolSize; i++) {
            pool.add(new PooledTrail());
        }
    }

    public static PooledTrail acquire() {
        if (activeCount >= pool.size()) {
            return null; // Pool exhausted
        }
        PooledTrail t = pool.get(activeCount);
        activeCount++;
        return t;
    }

    public static void release(PooledTrail t) {
        activeCount--;
        t.reset();
    }
}
```

### 5.3 Aura rendering

**Chakra mode aura:**

```
Trigger: ChakraModeEnabledEvent
Shape: Sphere around player (radius 1.5 blocks)
Color: Blue (0xFF4499FF) with alpha pulse
Lifetime: Continuous while chakra mode active
Particle rate: 2-5 per tick
```

**Dojutsu aura (future):**

```
Trigger: DojutsuHookAppliedEvent (when Dojutsu module exists)
Shape: Eyes glow + subtle aura
Color: Clan-specific (Sharingan red, Byakugan white)
Lifetime: Continuous while dojutsu active
```

**Clan aura (optional):**

```
Trigger: ClanSelectedEvent
Shape: Subtle glow around player
Color: Clan color
Lifetime: Continuous
Particle rate: 1-2 per tick
```

### 5.4 Camera shake

**Impact shake:**

```
Trigger: CombatHitEvent (heavy hits only)
Intensity: 0.5-2.0 (based on damage)
Duration: 5-10 ticks
Decay: Linear
```

**Explosion shake:**

```
Trigger: JutsuAreaCreatedEvent (explosive jutsu)
Intensity: 2.0-5.0 (based on radius)
Duration: 10-20 ticks
Decay: Exponential
```

**Implementation:**

```java
public final class CameraShakeService {
    private static float shakeIntensity = 0.0f;
    private static int shakeDuration = 0;
    private static int shakeTick = 0;

    public static void shake(float intensity, int durationTicks) {
        // Only apply if new shake is stronger than current
        if (intensity > shakeIntensity) {
            shakeIntensity = intensity;
            shakeDuration = durationTicks;
            shakeTick = 0;
        }
    }

    public static void tick() {
        if (shakeDuration <= 0) return;

        shakeTick++;
        if (shakeTick >= shakeDuration) {
            shakeIntensity = 0.0f;
            shakeDuration = 0;
            return;
        }

        // Linear decay
        float progress = (float) shakeTick / shakeDuration;
        float currentIntensity = shakeIntensity * (1.0f - progress);

        // Apply to camera (via mixin or Fabric API)
        applyCameraShake(currentIntensity);
    }

    private static void applyCameraShake(float intensity) {
        // Implementation via camera offset mixin
        // or Fabric API camera events
    }
}
```

### 5.5 Screen flash

**Level-up flash:**

```
Trigger: LevelChangedEvent
Color: Gold (0xFFFFD700)
Duration: 10-20 ticks
Alpha: 0.3 -> 0.0 (fade out)
```

**Cast completion flash:**

```
Trigger: JutsuCastFinishedEvent (high-tier jutsu only)
Color: Jutsu element color
Duration: 5-10 ticks
Alpha: 0.2 -> 0.0 (fade out)
```

### 5.6 Effect culling

**Distance-based culling:**

```java
public final class EffectCullingService {
    private static final double CULL_DISTANCE = 32.0; // blocks

    public static boolean shouldRenderEffect(Vec3d effectPos) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return false;

        double distance = client.player.getPos().distanceTo(effectPos);
        return distance <= CULL_DISTANCE;
    }
}
```

**Rate limiting:**

```java
public final class EffectRateLimiter {
    private static final Map<String, Long> lastEffectTime = new HashMap<>();
    private static final long DEFAULT_COOLDOWN_MS = 100; // 100ms between same effects

    public static boolean canPlayEffect(String effectId) {
        long now = System.currentTimeMillis();
        long last = lastEffectTime.getOrDefault(effectId, 0L);
        return (now - last) >= DEFAULT_COOLDOWN_MS;
    }

    public static void onEffectPlayed(String effectId) {
        lastEffectTime.put(effectId, System.currentTimeMillis());
    }
}
```

---

## 6. CLIENT-SERVER AUTHORITY

```
CLIENT (authoritative for rendering):
- Reads views from core
- Spawns particles, trails, auras
- Applies camera shake
- Renders screen flash
- No game state modification

SERVER (not involved):
- Visual is purely client-side
- No packets sent from Visual module
- No server-side logic
```

### NO PACKETS

Visual module does NOT send or receive any packets. It only reads views that are already synced by other modules.

---

## 7. FULL CONFIG TEMPLATE

File: `config/shinobicore/modules/visual.json` (auto-created on first run)

```json
{
  "enabled": true,
  "debug": false,

  "qualityPreset": "default",

  "particles": {
    "enabled": true,
    "maxParticlesPerFrame": 50,
    "maxParticlesPerSecond": 200,
    "particlePoolSize": 512,
    "cullDistance": 32.0,
    "cooldownMs": 100
  },

  "trails": {
    "enabled": true,
    "trailPoolSize": 64,
    "weaponTrailLifetime": 8,
    "dashTrailLifetime": 5,
    "projectileTrailLifetime": 8
  },

  "auras": {
    "enabled": true,
    "chakraAuraParticleRate": 3,
    "chakraAuraColor": "0xFF4499FF",
    "dojutsuAuraEnabled": false,
    "clanAuraEnabled": false
  },

  "cameraShake": {
    "enabled": true,
    "maxIntensity": 5.0,
    "impactShakeIntensity": 1.0,
    "explosionShakeIntensity": 3.0
  },

  "screenFlash": {
    "enabled": true,
    "levelUpFlashColor": "0xFFFFD700",
    "levelUpFlashDuration": 15,
    "castFlashEnabled": true
  },

  "movement": {
    "waterRippleEnabled": true,
    "wallRunDustEnabled": true,
    "slideDustEnabled": true,
    "rollDustEnabled": true,
    "dodgeBlurEnabled": true
  },

  "combat": {
    "hitSparkEnabled": true,
    "blockFlashEnabled": true,
    "parryFlashEnabled": true,
    "kickDustEnabled": true,
    "throwTrailEnabled": true
  },

  "futurePresets": {
    "low": {
      "maxParticlesPerFrame": 20,
      "maxParticlesPerSecond": 80,
      "cullDistance": 16.0,
      "cameraShakeEnabled": false,
      "trailsEnabled": false
    },
    "medium": {
      "maxParticlesPerFrame": 35,
      "maxParticlesPerSecond": 140,
      "cullDistance": 24.0,
      "cameraShakeEnabled": true,
      "trailsEnabled": true
    },
    "high": {
      "maxParticlesPerFrame": 50,
      "maxParticlesPerSecond": 200,
      "cullDistance": 32.0,
      "cameraShakeEnabled": true,
      "trailsEnabled": true
    }
  },

  "logging": {
    "logParticleSpawns": false,
    "logPoolExhaustion": true,
    "logCulledEffects": false
  }
}
```

### Config rules

1. Config is read ONCE at module load.
2. Missing file -> default is created.
3. Missing field -> default used (module must NOT crash).
4. Invalid JSON -> log error, use defaults, module continues.
5. No hot reload.
6. `qualityPreset` is a stub for future. Currently only "default" is supported.

---

## 8. COMMANDS

```
/shinobicore visual info           - show active particle count, pool usage
/shinobicore visual test           - spawn test particles/trails/auras
/shinobicore visual clear          - clear all active effects
/shinobicore visual debug          - toggle debug overlay (show effect counts)
/shinobicore visual preset <name>  - set quality preset (stub, only "default" works)
```

---

## 9. FORBIDDEN PATTERNS

Visual team MUST NOT do any of these:

1. **DO NOT** modify any game state (chakra, stats, progression, etc.). Visual is READ-ONLY.
2. **DO NOT** send or receive any network packets.
3. **DO NOT** use `System.out.println`. Use `ShinobiLogger.module("visual", ...)`.
4. **DO NOT** create new particle objects every frame. Use particle pools.
5. **DO NOT** spawn unlimited particles. Enforce per-frame and per-second limits.
6. **DO NOT** render effects beyond cull distance.
7. **DO NOT** spam the same effect. Use rate limiter with cooldown.
8. **DO NOT** create god-classes (>300 lines). Decompose by responsibility.
9. **DO NOT** import classes from other modules. Use core views only.
10. **DO NOT** make the module crash if another module is disabled. Handle missing views gracefully.
11. **DO NOT** drop below 60 FPS on weak PC with all effects active.
12. **DO NOT** implement quality presets fully (stub only, future work).

---

## 10. DEFINITION OF DONE

The visual module is complete when:

1. ✅ Module loads via `shinobicore:module` entrypoint
2. ✅ `/shinobicore systems` shows `visual: ENABLED`
3. ✅ Particle pool works (acquire/release, no GC pressure)
4. ✅ Particle limits enforced (per-frame, per-second)
5. ✅ Cast particles render during jutsu cast
6. ✅ Impact particles render on jutsu completion
7. ✅ Projectile trails render during projectile flight
8. ✅ Zone/wall particles render on zone/wall creation
9. ✅ Hit sparks render on combat hit
10. ✅ Block/parry flash renders on block/parry
11. ✅ Weapon swing trails render during combat
12. ✅ Dodge blur renders during dodge
13. ✅ Chakra aura renders during chakra mode
14. ✅ Camera shake works on impact/explosion
15. ✅ Screen flash works on level-up
16. ✅ Effect culling works (distant effects not rendered)
17. ✅ Rate limiter works (no effect spam)
18. ✅ Visual does not modify any game state
19. ✅ Visual does not send or receive any packets
20. ✅ Visual handles missing views gracefully (other modules disabled)
21. ✅ Commands work (`info`, `test`, `clear`, `debug`, `preset`)
22. ✅ Log files `logs/shinobicore/visual-1.log` created and rotated
23. ✅ Module does not crash when other modules are disabled
24. ✅ Config file `visual.json` created on first run with defaults
25. ✅ Broken JSON does not crash the game
26. ✅ 60+ FPS on weak PC with all effects active
27. ✅ Quality preset stub exists (future low/medium/high)
28. ✅ Build passes: `.\gradlew.bat build`

---

## 11. EXAMPLE CODE SNIPPETS

### 11.1 Particle emitter (cast particles)

```java
public final class CastParticleEmitter {
    private static final int PARTICLE_COUNT = 20;
    private static final int LIFETIME_TICKS = 30;

    public static void emitCastParticles(PlayerEntity player, String elementId) {
        if (!ParticleService.canSpawnParticle()) return;
        if (!EffectRateLimiter.canPlayEffect("cast_" + elementId)) return;

        int color = ParticleColors.getElementColor(elementId);
        Vec3d pos = player.getPos().add(0, 1.0, 0);

        for (int i = 0; i < PARTICLE_COUNT; i++) {
            PooledParticle p = ParticlePool.acquire();
            if (p == null) break; // Pool exhausted

            // Random direction
            float angle = (float)(Math.random() * Math.PI * 2);
            float speed = 0.1f + (float)(Math.random() * 0.2f);
            float vx = (float)Math.cos(angle) * speed;
            float vz = (float)Math.sin(angle) * speed;
            float vy = 0.1f + (float)(Math.random() * 0.15f);

            p.init(pos.x, pos.y, pos.z, vx, vy, vz, color, LIFETIME_TICKS);
            ParticleService.addParticle(p);
            ParticleService.onParticleSpawned();
        }

        EffectRateLimiter.onEffectPlayed("cast_" + elementId);
    }
}
```

### 11.2 Trail renderer

```java
public final class TrailRenderer {
    public static void register() {
        // Register as a WorldRenderEvents.AFTER_ENTITIES callback
        WorldRenderEvents.AFTER_ENTITIES.register(context -> {
            renderTrails(context.matrixStack(), context.consumers());
        });
    }

    private static void renderTrails(MatrixStack matrices, VertexConsumerProvider consumers) {
        for (PooledTrail trail : TrailPool.getActiveTrails()) {
            if (trail.isExpired()) {
                TrailPool.release(trail);
                continue;
            }

            // Cull distant trails
            if (!EffectCullingService.shouldRenderEffect(trail.getPos())) {
                continue;
            }

            renderTrail(matrices, consumers, trail);
        }
    }

    private static void renderTrail(MatrixStack matrices, VertexConsumerProvider consumers,
                                    PooledTrail trail) {
        matrices.push();

        // Translate to trail position
        matrices.translate(trail.getX(), trail.getY(), trail.getZ());

        // Get vertex consumer
        VertexConsumer vertexConsumer = consumers.getBuffer(
            RenderLayer.getLines());

        // Draw trail segments
        List<Vec3d> points = trail.getPoints();
        for (int i = 0; i < points.size() - 1; i++) {
            Vec3d p1 = points.get(i);
            Vec3d p2 = points.get(i + 1);

            float alpha = 1.0f - ((float)i / points.size());
            int color = trail.getColor();
            int r = (color >> 16) & 0xFF;
            int g = (color >> 8) & 0xFF;
            int b = color & 0xFF;

            vertexConsumer.vertex(matrices.peek().getPositionMatrix(),
                (float)p1.x, (float)p1.y, (float)p1.z)
                .color(r, g, b, (int)(alpha * 255))
                .next();
            vertexConsumer.vertex(matrices.peek().getPositionMatrix(),
                (float)p2.x, (float)p2.y, (float)p2.z)
                .color(r, g, b, (int)(alpha * 255))
                .next();
        }

        matrices.pop();
    }
}
```

### 11.3 Aura renderer

```java
public final class AuraRenderer {
    public static void register() {
        // Register as a WorldRenderEvents.AFTER_ENTITIES callback
        WorldRenderEvents.AFTER_ENTITIES.register(context -> {
            renderAuras(context.matrixStack(), context.consumers());
        });
    }

    private static void renderAuras(MatrixStack matrices, VertexConsumerProvider consumers) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;

        // Check if chakra mode is active
        Optional<ChakraApi> chakraOpt = CoreServices.get(ChakraApi.class);
        if (chakraOpt.isEmpty()) return;
        ChakraApi chakra = chakraOpt.get();

        if (!chakra.isChakraModeActive(client.player)) return;

        // Render chakra aura
        renderChakraAura(matrices, consumers, client.player);
    }

    private static void renderChakraAura(MatrixStack matrices, VertexConsumerProvider consumers,
                                         PlayerEntity player) {
        matrices.push();

        // Translate to player position
        matrices.translate(player.getX(), player.getY(), player.getZ());

        // Get vertex consumer
        VertexConsumer vertexConsumer = consumers.getBuffer(
            RenderLayer.getEntityTranslucent(new Identifier("shinobicore", "textures/visual/aura.png")));

        // Draw sphere (simplified as billboard)
        float radius = 1.5f;
        float time = (float)(System.currentTimeMillis() % 2000) / 2000.0f;
        float pulse = 0.8f + 0.2f * (float)Math.sin(time * Math.PI * 2);

        // Draw billboard quad
        Matrix4f matrix = matrices.peek().getPositionMatrix();
        int color = VisualConfig.get().auras.chakraAuraColor;
        int r = (color >> 16) & 0xFF;
        int g = (color >> 8) & 0xFF;
        int b = color & 0xFF;
        int a = (int)(128 * pulse);

        vertexConsumer.vertex(matrix, -radius, 0, -radius).color(r, g, b, a).next();
        vertexConsumer.vertex(matrix, radius, 0, -radius).color(r, g, b, a).next();
        vertexConsumer.vertex(matrix, radius, 2 * radius, -radius).color(r, g, b, a).next();
        vertexConsumer.vertex(matrix, -radius, 2 * radius, -radius).color(r, g, b, a).next();

        matrices.pop();
    }
}
```

### 11.4 View consumer

```java
public final class VisualViewConsumer {
    private static ModuleContext ctx;

    public static void init(ModuleContext context) {
        ctx = context;
    }

    public static void pollViews() {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;

        // Poll movement
        CoreViews.get(client.player, MovementVisualView.class).ifPresent(movement -> {
            if (movement.isWaterWalking()) {
                MovementVisualListener.emitWaterRipple(client.player);
            }
            if (movement.isWallRunning()) {
                MovementVisualListener.emitWallRunDust(client.player);
            }
        });

        // Poll combat
        CoreViews.get(client.player, CombatVisualView.class).ifPresent(combat -> {
            if (combat.isBlocking()) {
                CombatVisualListener.emitBlockAura(client.player);
            }
        });

        // Poll jutsu
        CoreViews.get(client.player, JutsuVisualView.class).ifPresent(jutsu -> {
            if (jutsu.isCasting()) {
                JutsuVisualListener.emitCastParticles(client.player, jutsu.getCurrentElementId());
            }
            for (ProjectileView proj : jutsu.getActiveProjectiles()) {
                JutsuVisualListener.emitProjectileTrail(proj);
            }
        });
    }
}
```

---

## 12. HANDOFF

When the visual team finishes, they must:

1. Run `.\gradlew.bat build` — must pass with 0 errors.
2. Run `.\gradlew.bat runClient` and manually verify:
   - Cast particles render during jutsu cast
   - Impact particles render on jutsu completion
   - Projectile trails render during projectile flight
   - Hit sparks render on combat hit
   - Block/parry flash renders on block/parry
   - Chakra aura renders during chakra mode
   - Camera shake works on impact
   - Screen flash works on level-up
   - Effect culling works (distant effects not rendered)
   - Rate limiter works (no effect spam)
3. Verify that disabling the module via `visual.json` (`enabled: false`) does not break the game.
4. Verify that other modules load correctly and visual handles missing views gracefully.
5. Verify that visual does not modify any game state.
6. Verify that visual does not send or receive any packets.
7. Verify 60+ FPS on weak PC with all effects active.
8. Create a brief `modules/visual/README.md` describing non-obvious behaviors.
9. Notify the core team that the module is ready for integration review.

---

## END OF VISUAL TECHNICAL SPECIFICATION
```
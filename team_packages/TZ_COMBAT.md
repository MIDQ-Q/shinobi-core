# ТЗ #2: Combat (Боевая система)

Сохранить как: `team_packages/TZ_COMBAT.md`

---

```markdown
# TECHNICAL SPECIFICATION: Combat Module

**Module ID:** `combat`
**Module Name:** ShinobiCore - Combat System
**Priority:** 1 (first wave, alongside movement and jutsu)
**Core dependency:** Sprint 1 (ModuleManager) + Sprint 2 (Chakra, Stats, Clan, Formula, JutsuCastGateway services)

---

## 1. PURPOSE

Implement a complete shinobi-style combat system on top of Better Combat:

- Two stances: Aggressive / Defensive
- Blocking (Aggressive stance + melee weapon)
- Parrying (Defensive stance + any weapon, narrow timing window)
- Projectile deflection via parry
- Kick (taijutsu-based, combo finisher + standalone)
- Combo system extending Better Combat's combos with shinobi bonuses
- Katana sheath mechanic (unsheathe/sheathe)
- Quick weapon slot (cycle katana / kunai / shuriken)
- Throwable weapons (shuriken, kunai)
- Imbue system (apply jutsu to throwable weapons)
- Unarmed combat (simple punches, no complex chains)
- Client prediction for responsive feel
- Server as authoritative source of truth

**NOT in scope** (belong to other modules):
- Jutsu casting logic → Jutsu module
- Clan bonuses application → core ClanApi (consumed by combat)
- Enemy AI behavior → AI module (uses JutsuCastGatewayApi)
- Visual effects / particles / camera shake → Visual module
- HUD rendering → HUD module

---

## 2. FILE OWNERSHIP

The combat team may ONLY create and modify files in these locations:

```
src/main/java/com/example/shinobicore/modules/combat/
src/main/resources/data/shinobicore/combat/          (JSON balance, stances, weapons)
src/main/resources/data/shinobicore/weapon_attributes/   (Better Combat datapack files)
src/main/resources/assets/shinobicore/combat/        (textures, models, sounds)
config/shinobicore/modules/combat.json               (generated at runtime)
```

The combat team MUST NOT modify:
- Any file under `core/`
- `ShinobiCoreMod.java` or `ShinobiCoreClient.java`
- Any file belonging to another module
- `fabric.mod.json` (entrypoint addition is done by core team)
- Better Combat, PlayerAnimator, GeckoLib, Cloth Config sources (use via adapter)

---

## 3. ARCHITECTURE

### 3.1 Package structure

```
modules/combat/
├── CombatModule.java                          (entry point, implements ClientAwareModule)
├── compat/
│   ├── CombatCompatibilityChecker.java        (validate dependencies)
│   ├── BetterCombatAdapter.java               (isolate ALL BC API usage)
│   ├── BetterCombatBridge.java                (event bridge from BC to us)
│   ├── PlayerAnimatorAdapter.java             (animation dispatch)
│   ├── GeckoLibAdapter.java                   (if GeckoLib needed for models)
│   └── ClothConfigAdapter.java                (client settings screen)
├── config/
│   ├── CombatConfig.java                      (parsed JSON)
│   └── CombatConfigLoader.java
├── data/
│   ├── CombatDataLoader.java                  (load JSON from data/combat/)
│   ├── CombatRegistries.java                  (registry for stances/weapons/thrown)
│   ├── CombatJsonValidator.java
│   ├── StanceDefinition.java
│   ├── WeaponDefinition.java
│   ├── ThrownDefinition.java
│   └── ImbueRule.java
├── component/
│   ├── CombatComponentKey.java                (CCA component key)
│   ├── CombatComponentImpl.java               (CCA implementation)
│   └── CombatComponentInitializer.java
├── service/
│   ├── StanceService.java
│   ├── BlockService.java
│   ├── ParryService.java
│   ├── ProjectileDeflectService.java
│   ├── KickService.java
│   ├── MeleeCombatService.java
│   ├── ComboTracker.java
│   ├── ThrowableService.java
│   ├── SheathService.java
│   ├── QuickWeaponSlotService.java
│   ├── UnarmedCombatService.java
│   ├── ImbueService.java
│   ├── CombatFormula.java
│   └── DamageInterceptionService.java
├── input/
│   ├── CombatInputDispatcher.java             (RIGHT-CLICK priority logic)
│   ├── CombatKeyBindings.java
│   └── CombatInputHandler.java                (client-side)
├── client/
│   ├── CombatClientState.java
│   ├── CombatPredictionService.java
│   └── CombatHudDataBridge.java               (exposes state to HUD)
├── network/
│   ├── CombatPackets.java                     (packet registry)
│   ├── CombatStanceChangePacket.java
│   ├── CombatBlockStatePacket.java
│   ├── CombatParryAttemptPacket.java
│   ├── CombatKickPacket.java
│   ├── CombatThrowPacket.java
│   ├── CombatSheathTogglePacket.java
│   └── CombatStateSyncPacket.java             (server -> client)
├── render/
│   ├── SheathFeatureRenderer.java             (katana on back/waist)
│   ├── SheathModel.java
│   ├── ThrownWeaponRenderer.java
│   └── ImbuedItemRenderer.java
├── audio/
│   └── CombatSoundEvents.java
└── view/
    └── CombatVisualViewImpl.java              (implements CombatVisualView)
```

### 3.2 Module entry point

```java
public class CombatModule implements ClientAwareModule {
    public static final String ID = "combat";

    @Override public String id() { return ID; }

    @Override
    public void onRegister(ModuleContext ctx) {
        CombatComponentKey.register();
    }

    @Override
    public void onEnable(ModuleContext ctx) {
        CombatConfig.load(ctx.configs().readModuleConfig(ID));

        // Hard requirement: Better Combat MUST be present
        if (!CombatCompatibilityChecker.isBetterCombatOk()) {
            ShinobiLogger.error(ID,
                "Better Combat is REQUIRED but not detected. " +
                "Disabling combat module.", null);
            ctx.events().publish(new ModuleDisabledEvent(ID,
                "Missing required mod: bettercombat"));
            // Request self-disable via core:
            ModuleManager.disable(ID, "Missing Better Combat");
            return;
        }

        CombatDataLoader.load();
        CombatRegistries.build();
        CombatFormula.sanityCheck();

        CombatPackets.registerServer();
        BlockService.init();
        ParryService.init();
        KickService.init();
        ProjectileDeflectService.init();
        SheathService.init();
    }

    @Override
    public void registerEvents(ModuleContext ctx) {
        ctx.events().subscribe(ChakraModeEnabledEvent.class, e -> { /* stance boost */ });
        ctx.events().subscribe(ChakraModeDisabledEvent.class, e -> { /* reset */ });
        ctx.events().subscribe(FatigueChangedEvent.class, e -> { /* weaken block */ });
        ctx.events().subscribe(PlayerDiedEvent.class, e -> { /* reset stance, sheath */ });
        ctx.events().subscribe(PlayerRespawnedEvent.class, e -> { /* default state */ });
    }

    @Override
    public void registerViews(ModuleContext ctx) {
        ctx.views().register(CombatVisualView.class, player ->
            Optional.of(new CombatVisualViewImpl(player)));
    }

    @Override
    public void registerCommands(ModuleContext ctx, CommandDispatcher<ServerCommandSource> d) {
        CombatCommands.register(d);
    }

    @Override
    public void onClientInit(ModuleContext ctx) {
        CombatKeyBindings.register();
        CombatInputHandler.init();
        CombatPackets.registerClient();
        SheathFeatureRenderer.register();
    }

    @Override
    public void onClientTick(ModuleContext ctx) {
        CombatInputHandler.tick();
    }

    @Override
    public void onServerTick(ModuleContext ctx, MinecraftServer server) {
        BlockService.serverTick(server);
        ParryService.serverTick(server);
        ProjectileDeflectService.serverTick(server);
        ComboTracker.serverTick(server);
    }
}
```

---

## 4. CORE API TO USE

### 4.1 ChakraApi

```java
CoreServices.get(ChakraApi.class).ifPresent(chakra -> {
    float current = chakra.getCurrent(player);
    boolean mode  = chakra.isChakraModeActive(player);
    chakra.trySpend(player, cost);
});
```

### 4.2 StatsApi

```java
CoreServices.get(StatsApi.class).ifPresent(stats -> {
    int taijutsu   = stats.getStatLevel(player, "taijutsu");
    int kenjutsu   = stats.getStatLevel(player, "kenjutsu");   // or ninjutsu
    int control    = stats.getStatLevel(player, "control");
    int perception = stats.getStatLevel(player, "perception"); // parry window
});
```

### 4.3 ClanApi

```java
CoreServices.get(ClanApi.class).ifPresent(clan -> {
    float clanDmgMult    = clan.getStatBonus(player, "meleeDamage");
    float clanFatigueMult = clan.getFatigueMultiplier(player);
});
```

### 4.4 FormulaApi

Use for derived values:
- `calcMeleeDamage(player, baseDamage)` → final shinobi bonus damage
- `calcRangedDamage(player, baseDamage)` → final thrown damage
- `calcFatigueGain(player, baseStrain)` → fatigue added by block/parry

### 4.5 ProgressionApi

Use for XP rewards:
- `addXp(player, amount, "combat_attack")` on successful hit
- `addXp(player, amount, "combat_parry")` on successful parry

### 4.6 JutsuCastGatewayApi (consumed, not registered by combat)

```java
CoreServices.get(JutsuCastGatewayApi.class).ifPresent(gateway -> {
    if (gateway.isJutsuAvailable("shinobicore:fireball")) {
        // Used by ImbueService to execute imbued jutsu on projectile hit
    }
});
```

### 4.7 Events to publish

Define these as records inside `modules/combat/common/`:

```java
public record CombatAttackEvent(ServerPlayerEntity attacker, Entity target, float totalDamage, int comboStep) {}
public record CombatHitEvent(ServerPlayerEntity attacker, LivingEntity target, float damage) {}
public record CombatBlockedEvent(ServerPlayerEntity blocker, Entity attacker, float reducedDamage) {}
public record CombatParriedEvent(ServerPlayerEntity parrier, Entity attacker, boolean reflected) {}
public record CombatKickEvent(ServerPlayerEntity kicker, Entity target, float damage) {}
public record CombatStanceChangedEvent(ServerPlayerEntity player, String oldStance, String newStance) {}
public record CombatComboChangedEvent(ServerPlayerEntity player, int oldStep, int newStep, String weaponClass) {}
public record ThrowableThrownEvent(ServerPlayerEntity thrower, Entity projectile, String weaponId) {}
public record WeaponSheathedEvent(ServerPlayerEntity player, boolean sheathed, String itemId) {}
public record WeaponDrawnEvent(ServerPlayerEntity player, String itemId) {}
public record ProjectileDeflectedEvent(ServerPlayerEntity defender, Entity projectile) {}
```

### 4.8 Events to subscribe

```
ChakraModeEnabledEvent         -> stance damage/speed multiplier
ChakraModeDisabledEvent        -> reset stance bonuses
FatigueChangedEvent            -> weaken block at high fatigue
ExhaustionChangedEvent        -> disable block/parry if exhausted
PlayerDiedEvent                -> reset stance, sheath weapon, reset combo
PlayerRespawnedEvent           -> set default state
PlayerChangedDimensionEvent    -> reset combo
```

---

## 5. VIEWS TO REGISTER

Register one view:

```java
public interface CombatVisualView {
    String getCurrentStance();          // "aggressive" | "defensive" | null
    boolean isBlocking();
    boolean isParrying();               // within parry window
    int getComboStep();                 // 0..N
    boolean isSheathed();               // katana sheathed
    boolean isThrowing();               // throwing animation playing
    float getBlockProgress();           // 0.0-1.0 block stamina usage
    float getParryWindowProgress();     // 0.0-1.0 remaining window
    String getWeaponClass();            // "katana" | "kunai" | "shuriken" | "unarmed" | null
}
```

---

## 6. MECHANICS — DETAILED BEHAVIOR

### 6.1 RIGHT-CLICK priority (CombatInputDispatcher)

When the player RIGHT-CLICKS while the combat module is active and in combat context, the module intercepts and handles the action. Priority order (first match wins):

```
1. Throwing:       main hand is throwable item -> ThrowableService.throw()
2. Parry:          stance == DEFENSIVE + timing ok -> ParryService.attemptParry()
3. Block:          stance == AGGRESSIVE + melee weapon -> BlockService.startBlock()
4. Sheath toggle:  katana + sheath keybind -> SheathService.toggle()
5. Special stance action (e.g., defensive counter)
6. Otherwise:      let vanilla use-item proceed
```

Combat context is active when:
- Player holds a combat-registered weapon (katana, kunai, shuriken, etc.) OR
- Player has been in combat within last `combatTimeoutTicks` (received or dealt damage)

Outside combat context, vanilla item use (eating food, shield, bow) takes priority.

### 6.2 Stances

Two stances, cycled by a dedicated keybind (default: `V` or `G`).

**Aggressive:**
- +15% attack speed
- +15% damage
- +5% movement speed
- Block available (180° frontal protection)
- Combo window -10% (faster combos)

**Defensive:**
- +10% damage reduction always
- Parry available
- 360° parry angle
- Movement speed -5%
- Combo window +20% (slower but safer)

Stance is stored in the combat CCA component, synced to client.

### 6.3 Block

Trigger:
- Hold RIGHT-CLICK in Aggressive stance with a melee weapon
- Weapon must be in main hand
- Player not exhausted, not in action lock

Behavior:
- Block state flag set
- Each incoming melee/projectile hit is reduced by `block.damageReductionMultiplier` (config)
- Stamina drain: `block.drainPerSecond` while holding block (accumulator pattern)
- Extra stamina drain on each blocked hit: `block.drainPerHit`
- Block stamina accumulator: once per second, check drain
- When stamina reaches 0 -> block breaks (action lock 20 ticks)
- Block only protects frontal 180° cone

### 6.4 Parry

Trigger:
- Press RIGHT-CLICK in Defensive stance within `parry.windowMs` of incoming attack
- OR: hold RIGHT-CLICK in Defensive and let the system detect the parry window on each incoming hit

Behavior:
- Parry window: `parry.baseWindowMs * (1 - perceptionLevel * 0.003)` (clamped)
- On success:
  - Negate incoming damage
  - Apply action lock on attacker (stagger: `parry.successStaggerMs`)
  - Open counter window on defender (counter window: `parry.counterWindowMs`)
  - If incoming was a projectile: reflect it
  - Gain chakra: `parry.successChakraGain`
  - Gain stamina: `parry.successStaminaGain`
- On fail (pressed too early or too late):
  - Take damage
  - Enter parry fail recovery: `parry.failRecoveryMs` (cannot parry again)
  - Log warning

### 6.5 Projectile deflection

Runs on server tick:
1. For each player with active parry state
2. Find all projectile entities within `parry.reflectRadius` (3 blocks)
3. For each projectile moving toward the player
4. Reverse velocity: `velocity = -velocity * reflectSpeedMultiplier`
5. Rotate toward attacker direction if available
6. Publish ProjectileDeflectedEvent
7. Original owner remains same (or switched — config)

### 6.6 Kick

Trigger:
- Dedicated keybind (default: `F`)
- OR: queued as combo finisher (press kick key during combo window)

Behavior:
- Taijutsu-based damage: `kickBaseDamage * (1 + taijutsuLevel * kickTaijutsuPerLevel)`
- Applies knockback
- Combo finisher variant: +25% damage, extra stagger
- Cooldown: `kick.cooldownTicks`
- Stamina cost: `kick.staminaCost`

### 6.7 Combo system (ComboTracker)

Better Combat drives animation and hitboxes. ShinobiCore tracks:

- `lastAttackTimeMs`
- `currentStep` (0..N)
- `weaponClass` (resets combo if weapon changes)
- `comboExpireAtMs`
- `queuedKickFinisher`

Rules:
- Combo resets after `combo.timeoutMs` without attack
- Combo resets on weapon change
- Combo resets on death
- Combo resets on dimension change
- Combo bonuses per step from `combat/combo/*.json` (configurable)
- Step N bonus: damage multiplier, speed multiplier
- Final step can be replaced by kick if queued

Server is authoritative for combo step. Client predicts visually.

### 6.8 Katana sheath

Trigger:
- Dedicated keybind (default: `H` or `I`)
- Only works with katana items

Behavior:
- Toggle sheathed state (stored in combat component)
- When sheathed:
  - Katana not in hand visually (model hidden)
  - Sheath model rendered on back/waist (SheathFeatureRenderer)
  - Cannot attack while sheathed
  - Quick draw possible: attack key while sheathed -> unsheathe + attack in one action (bonus damage)
- When unsheathed:
  - Katana visible in hand
  - Normal attacks work
  - Sheath model hidden
- State saved to NBT and synced

### 6.9 Quick weapon slot

Trigger:
- Dedicated keybind (default: `R`) cycles through: katana -> kunai -> shuriken -> (back to katana)
- OR: mouse wheel while holding modifier

Behavior:
- Cycles through registered combat weapons in inventory
- Equips to main hand
- Updates weapon class for combo tracker

### 6.10 Throwable weapons

Trigger:
- RIGHT-CLICK while holding throwable item (shuriken, kunai)

Behavior:
- Spawn projectile entity with configured stats
- Gravity, speed, damage, spread from config
- Perception stat reduces spread
- Taijutsu/Ninjutsu stat increases damage (via formula)
- Imbued throwables execute a jutsu on impact (see 6.11)

### 6.11 Imbue system

When throwing a weapon:
1. Check if player has a selected jutsu (via JutsuCastGatewayApi)
2. Check if imbue rules allow it (jutsu element, cost, etc.)
3. If allowed, mark projectile as "imbued" with jutsu ID
4. On impact, execute jutsu behavior at hit location
5. Deduct chakra cost

### 6.12 Unarmed combat

Trigger:
- Attack with empty hand

Behavior:
- Better Combat processes empty hand via `weapon_attributes/unarmed_basic.json` if BC supports it
- If BC doesn't support empty hand, `UnarmedCombatService` does a simple server-side cone attack
- Damage formula:
  ```
  extraDamage = 1.0
              * (1 + taijutsuLevel * 0.05)
              * stance.damageMultiplier
              * clanMultiplier
              * chakraModeMultiplier
  ```
- ShinobiCore damage is added ON TOP of vanilla unarmed damage
- Simple 2-step combo (left punch, right punch), no complex chains

---

## 7. DRAIN ACCUMULATOR PATTERN

Reuse the same pattern from Movement for block stamina drain:

```java
public class DrainAccumulator {
    private double accumulator = 0.0;
    private final double perSecond;

    public DrainAccumulator(double perSecond) {
        this.perSecond = perSecond;
    }

    public int tick(double deltaTimeSeconds) {
        accumulator += perSecond * deltaTimeSeconds;
        int toSpend = (int) accumulator;
        accumulator -= toSpend;
        return toSpend;
    }

    public void reset() { accumulator = 0.0; }
}
```

Applied to:
- Block stamina drain (per second while holding block)
- Chakra drain from chakra-mode combat bonuses (optional)

---

## 8. CLIENT-SERVER AUTHORITY

```
CLIENT (authoritative for feel):
- Stance toggle input
- Block press/release timing
- Parry window press timing
- Kick press
- Throw press
- Sheath toggle
- Weapon cycle
- Predictive animations (via PlayerAnimator)
- Predictive damage numbers (visual only)
- Sends packets to server for each action

SERVER (authoritative for truth):
- Validates every action packet:
  - Is stance valid?
  - Has player not exceeded rate limits?
  - Has player enough chakra/stamina?
  - Is weapon in correct state (sheathed/unsheathed)?
  - Is parry timing within server-accepted window?
- Calculates final damage via FormulaApi
- Deducts resources
- Syncs authoritative state back to client periodically
- Soft-corrects client on discrepancy, does NOT crash

CRITICAL: never double-apply damage.
Client predicts visual; server applies the only real damage.
```

### CRITICAL PACKET RULE

```java
ServerPlayNetworking.registerGlobalReceiver(ID, (server, player, handler, buf, sender) -> {
    // STEP 1: Read ALL data from buffer FIRST
    final int stanceOrdinal = buf.readInt();
    final long pressTimestampMs = buf.readLong();
    final float yaw = buf.readFloat();
    final float pitch = buf.readFloat();

    // STEP 2: Execute on server thread
    server.execute(() -> {
        CombatInputDispatcher.handleStanceChange(
            player, stanceOrdinal, pressTimestampMs, yaw, pitch);
    });
});
```

NEVER read `buf` inside `server.execute()`.

---

## 9. FULL CONFIG TEMPLATE

File: `config/shinobicore/modules/combat.json` (auto-created on first run)

```json
{
  "enabled": true,
  "debug": false,

  "stances": {
    "aggressive": {
      "attackSpeedMultiplier": 1.15,
      "damageMultiplier": 1.15,
      "movementSpeedMultiplier": 1.05,
      "comboWindowMultiplier": 0.9,
      "block": {
        "protectionAngle": 180,
        "canBlockProjectiles": false
      }
    },
    "defensive": {
      "damageReductionMultiplier": 0.9,
      "movementSpeedMultiplier": 0.95,
      "comboWindowMultiplier": 1.2,
      "parryAngle": 360
    }
  },

  "block": {
    "enabled": true,
    "drainPerSecond": 5.0,
    "drainPerHit": 8.0,
    "damageReductionMultiplier": 0.4,
    "breakActionLockTicks": 20,
    "minimumStaminaToStart": 10.0
  },

  "parry": {
    "enabled": true,
    "baseWindowMs": 250,
    "perceptionReductionPerLevel": 0.003,
    "minWindowMs": 80,
    "successStaggerMs": 400,
    "counterWindowMs": 600,
    "failRecoveryMs": 800,
    "successChakraGain": 5.0,
    "successStaminaGain": 10.0,
    "reflectRadius": 3.0,
    "reflectSpeedMultiplier": 1.2,
    "projectileReflectEnabled": true
  },

  "kick": {
    "enabled": true,
    "baseDamage": 4.0,
    "taijutsuPerLevel": 0.05,
    "finisherBonusMultiplier": 1.25,
    "cooldownTicks": 40,
    "staminaCost": 8.0,
    "knockbackStrength": 0.6
  },

  "thrown": {
    "enabled": true,
    "perceptionSpreadReductionPerLevel": 0.01,
    "baseDamage": 3.0,
    "taijutsuDamagePerLevel": 0.03,
    "gravity": 0.04,
    "speed": 1.8,
    "lifetimeTicks": 80
  },

  "sheath": {
    "enabled": true,
    "quickDrawDamageBonusMultiplier": 1.3,
    "sheathPosition": "back"
  },

  "quickSlot": {
    "enabled": true,
    "cycleOrder": ["katana", "kunai", "shuriken"]
  },

  "combo": {
    "timeoutMs": 1500,
    "resetOnWeaponChange": true,
    "resetOnDeath": true,
    "resetOnDimensionChange": true
  },

  "unarmed": {
    "enabled": true,
    "baseDamage": 1.0,
    "taijutsuDamagePerLevel": 0.05
  },

  "imbue": {
    "enabled": true,
    "allowedOnThrowables": true,
    "allowedOnMelee": false,
    "maxTier": 3
  },

  "formula": {
    "chakraModeDamageMultiplier": 1.2,
    "chakraModeSpeedMultiplier": 1.15,
    "fatigueDamagePenaltyScale": 0.5
  },

  "client": {
    "hitStopEnabled": true,
    "hitStopAttackerMs": 80,
    "hitStopTargetMs": 150,
    "cameraShakeEnabled": true,
    "screenShakeIntensity": 1.0
  },

  "combatTimeout": {
    "ticks": 100
  },

  "logging": {
    "logHits": false,
    "logParries": false,
    "logComboProgress": false
  }
}
```

### JSON data files

Combat team is responsible for these data directories:

```
data/shinobicore/combat/
├── stances/
│   ├── aggressive.json
│   └── defensive.json
├── weapons/
│   ├── katana.json
│   ├── kunai.json
│   └── unarmed.json
├── thrown/
│   ├── shuriken.json
│   └── kunai.json
├── combo/
│   └── katana_combo.json
├── imbue/
│   └── rules.json
└── balance/
    ├── block.json
    ├── parry.json
    └── kick.json

data/shinobicore/weapon_attributes/   (Better Combat format)
├── katana_basic.json
├── kunai_basic.json
└── unarmed_basic.json
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
/shinobicore combat info           - show stance, combo, block state
/shinobicore combat test           - spawn training dummy + throwable items
/shinobicore combat debug          - toggle debug overlay for this module
/shinobicore combat sheath toggle  - toggle katana sheath (for testing)
/shinobicore combat stance set <aggressive|defensive>
/shinobicore combat reset          - reset all combat state to default
```

---

## 11. FORBIDDEN PATTERNS

Combat team MUST NOT do any of these:

1. **DO NOT** directly import Better Combat classes outside of `BetterCombatAdapter.java` and `BetterCombatBridge.java`.
2. **DO NOT** directly import PlayerAnimator / GeckoLib / Cloth Config classes outside their adapter.
3. **DO NOT** use `System.out.println`. Use `ShinobiLogger.module("combat", ...)`.
4. **DO NOT** hold player state in `static Map<UUID, State>` without cleanup on player disconnect.
5. **DO NOT** apply damage twice (client visual + server real). Server is the ONLY source of real damage.
6. **DO NOT** read `PacketByteBuf` inside `server.execute()`.
7. **DO NOT** cancel vanilla `AttackEntityCallback` entirely. Always return `ActionResult.PASS` from the base event and ADD shinobi bonus damage as magic damage.
8. **DO NOT** hardcode weapon damage — read from JSON balance files.
9. **DO NOT** create god-classes (>300 lines).
10. **DO NOT** make the module crash if another module (e.g., jutsu, clans) is disabled. Always handle missing services gracefully.
11. **DO NOT** implement hot reload for configs.
12. **DO NOT** leak Better Combat API types into `core/api/` or `core/event/` event records. Wrap in ShinobiCore records.

---

## 12. ANIMATIONS

Use PlayerAnimator via the provided adapter for:
- Block pose (stance-dependent)
- Parry flash
- Kick (low sweep)
- Katana draw / sheath animation
- Throw animation
- Combo step animations (delegated to Better Combat)

Use GeckoLib (via adapter) for:
- Katana sheath model on player body

Register all animations in `CombatAnimationIds` constants class.

---

## 13. DEFINITION OF DONE

The combat module is complete when:

1. ✅ Module loads via `shinobicore:module` entrypoint
2. ✅ `/shinobicore systems` shows `combat: ENABLED`
3. ✅ Module auto-disables with clear log if Better Combat is missing
4. ✅ Stances toggle correctly with keybind
5. ✅ Block works in Aggressive stance, reduces damage, drains stamina
6. ✅ Parry works in Defensive stance within configured window
7. ✅ Parry success reflects projectiles
8. ✅ Parry success applies stagger to attacker
9. ✅ Kick works standalone AND as combo finisher
10. ✅ Combo step advances on successive hits, resets on timeout/weapon change/death
11. ✅ Katana sheath toggles, hides/shows katana visually
12. ✅ Quick draw attack works from sheathed state
13. ✅ Quick weapon slot cycles through weapons
14. ✅ Shuriken/kunai throw with correct physics
15. ✅ Imbued throwables execute jutsu on impact (when jutsu module present)
16. ✅ Unarmed combat works (vanilla + shinobi bonus)
17. ✅ No double damage application
18. ✅ No double stamina/chakra drain
19. ✅ Server soft-validates actions, does not crash on anomaly
20. ✅ CombatVisualView registered and readable by visual module
21. ✅ CombatHudDataBridge exposes state for HUD
22. ✅ Commands `/shinobicore combat info|test|debug|sheath|stance|reset` work
23. ✅ Log files `logs/shinobicore/combat-1.log` created and rotated
24. ✅ Module does not crash when other modules (jutsu, clans) are disabled
25. ✅ Config file `combat.json` created on first run with defaults
26. ✅ Broken JSON does not crash the game
27. ✅ All network packets follow "read first, execute second" rule
28. ✅ Better Combat, PlayerAnimator, GeckoLib, Cloth Config detected at runtime via adapters
29. ✅ Build passes: `.\gradlew.bat build`

---

## 14. EXAMPLE CODE SNIPPETS

### 14.1 BetterCombatAdapter (anti-corruption layer)

```java
public final class BetterCombatAdapter {
    private static boolean enabled = false;
    private static String status = "not initialized";

    public static void init() {
        if (FabricLoader.getInstance().isModLoaded("bettercombat")) {
            enabled = true;
            status = "loaded";
            ShinobiLogger.module("combat", "Better Combat detected, delegating melee");
        } else {
            enabled = false;
            status = "not installed";
            ShinobiLogger.error("combat", "Better Combat NOT installed", null);
        }
    }

    public static boolean isEnabled() { return enabled; }
    public static String getStatus() { return status; }

    // Wrap BC-specific types into ShinobiCore enums/records
    public static WeaponClass resolveWeaponClass(ItemStack stack) {
        if (!enabled) return WeaponClass.UNARMED;
        // Read BC weapon category from item tag or datapack
        // ...
        return WeaponClass.KATANA;
    }

    public static Optional<ComboSnapshot> getComboSnapshot(ServerPlayerEntity player) {
        if (!enabled) return Optional.empty();
        // Read BC combo state
        return Optional.of(new ComboSnapshot(/*...*/));
    }
}
```

### 14.2 RIGHT-CLICK dispatcher (client side)

```java
public final class CombatInputDispatcher {

    public static ActionResult onUseItem(ClientPlayerEntity player, Hand hand) {
        if (!CombatClientState.isCombatContextActive()) {
            return ActionResult.PASS; // let vanilla handle
        }

        ItemStack mainHand = player.getMainHandStack();
        CombatConfig config = CombatConfig.get();

        // Priority 1: throwable
        if (config.thrown.enabled && isThrowable(mainHand)) {
            CombatPackets.sendThrow(player.getYaw(), player.getPitch());
            return ActionResult.SUCCESS;
        }

        // Priority 2: parry (defensive stance)
        if (config.parry.enabled
                && CombatClientState.getCurrentStance() == Stance.DEFENSIVE) {
            CombatPackets.sendParryAttempt(System.currentTimeMillis());
            return ActionResult.SUCCESS;
        }

        // Priority 3: block (aggressive stance)
        if (config.block.enabled
                && CombatClientState.getCurrentStance() == Stance.AGGRESSIVE
                && isMeleeWeapon(mainHand)) {
            CombatPackets.sendBlockStart();
            return ActionResult.SUCCESS;
        }

        // Priority 4: sheathed weapon quick draw
        if (config.sheath.enabled && CombatClientState.isSheathed() && isKatana(mainHand)) {
            CombatPackets.sendSheathToggle();
            return ActionResult.SUCCESS;
        }

        return ActionResult.PASS;
    }
}
```

### 14.3 Server-side parry validation

```java
public final class ParryService {

    public static void attemptParry(ServerPlayerEntity defender,
                                    long clientPressTimeMs) {
        Optional<CombatComponent> compOpt = CombatComponentKey.get(defender);
        if (compOpt.isEmpty()) return;
        CombatComponent comp = compOpt.get();

        if (comp.getStance() != Stance.DEFENSIVE) {
            ShinobiLogger.module("combat", "Parry attempt in wrong stance");
            return;
        }

        long now = System.currentTimeMillis();

        // Check fail recovery
        if (now < comp.getParryFailRecoveryUntil()) {
            return; // still in recovery
        }

        // Check if there's an incoming attack within the window
        Optional<IncomingAttack> attackOpt = findIncomingAttack(defender);
        if (attackOpt.isEmpty()) {
            // Parry pressed with no attack nearby -> fail (recovery timer)
            comp.setParryFailRecoveryUntil(now + CombatConfig.get().parry.failRecoveryMs);
            return;
        }

        IncomingAttack attack = attackOpt.get();
        long windowMs = calculateParryWindow(defender);

        // Parry success: negate damage, stagger attacker, reflect projectile
        attack.cancel();
        applyStagger(attack.attacker(), CombatConfig.get().parry.successStaggerMs);
        if (attack.isProjectile()) {
            ProjectileDeflectService.reflect(attack.projectile(), defender);
        }

        CoreServices.get(ChakraApi.class).ifPresent(c ->
            c.add(defender, CombatConfig.get().parry.successChakraGain));

        CoreEvents.publish(new CombatParriedEvent(defender, attack.attacker(),
            attack.isProjectile()));
    }

    private static long calculateParryWindow(ServerPlayerEntity player) {
        CombatConfig cfg = CombatConfig.get();
        int perception = CoreServices.require(StatsApi.class)
            .getStatLevel(player, "perception");
        long window = (long) (cfg.parry.baseWindowMs
            * (1.0 - perception * cfg.parry.perceptionReductionPerLevel));
        return Math.max(cfg.parry.minWindowMs, window);
    }
}
```

### 14.4 Adding shinobi bonus damage (never cancel base)

```java
// In CombatModule.onEnable():
AttackEntityCallback.EVENT.register((player, world, hand, target, hitResult) -> {
    if (!(player instanceof ServerPlayerEntity sp)) return ActionResult.PASS;
    if (!(target instanceof LivingEntity le)) return ActionResult.PASS;

    // Let vanilla damage proceed. Compute bonus and apply separately.
    Optional<CombatComponent> compOpt = CombatComponentKey.get(sp);
    if (compOpt.isEmpty()) return ActionResult.PASS;

    CombatComponent comp = compOpt.get();
    float baseWeaponDamage = player.getMainHandStack().getItem()
        .getAttributeModifiers(EquipmentSlot.MAINHAND).asMap()
        .getOrDefault(EntityAttributes.GENERIC_ATTACK_DAMAGE, List.of())
        .stream().findFirst()
        .map(EntityAttributeModifier::getValue)
        .map(v -> (float) v)
        .orElse(1.0f);

    float bonus = CombatFormula.calculateShinobiBonus(sp, baseWeaponDamage, comp);
    if (bonus > 0.01f) {
        // Schedule bonus damage after vanilla damage is applied
        ((ServerWorld) world).getServer().execute(() -> {
            if (le.isAlive()) {
                le.damage(sp.getDamageSources().magic(), bonus);
            }
        });
    }

    CoreEvents.publish(new CombatHitEvent(sp, le, baseWeaponDamage + bonus));
    return ActionResult.PASS;
});
```

### 14.5 Sheath renderer skeleton

```java
public final class SheathFeatureRenderer {

    public static void register() {
        // Register as a LivingEntityFeatureRenderer on PlayerEntityRenderer
        // Delegates to GeckoLib adapter for the sheath model
    }

    public static void render(MatrixStack matrices, VertexConsumerProvider vcp,
                              int light, PlayerEntity player,
                              float limbAngle, float limbDistance,
                              float tickDelta) {
        Optional<CombatComponent> compOpt = CombatComponentKey.get(player);
        if (compOpt.isEmpty()) return;
        CombatComponent comp = compOpt.get();

        if (!comp.isSheathed()) return; // don't render when unsheathed

        GeckoLibAdapter.renderSheathModel(matrices, vcp, light,
            comp.getSheathPosition(), tickDelta);
    }
}
```

---

## 15. HANDOFF

When the combat team finishes, they must:

1. Run `.\gradlew.bat build` — must pass with 0 errors.
2. Run `.\gradlew.bat runClient` and manually verify all mechanics:
   - stance switching
   - block (with dummy attacker)
   - parry (with timing practice)
   - kick (standalone + combo finisher)
   - katana sheath toggle
   - weapon cycling
   - throwing shuriken/kunai
   - imbued throw (if jutsu module present)
   - unarmed combat
3. Verify that disabling the module via `combat.json` (`enabled: false`) does not break the game.
4. Verify that other modules (when present) still load correctly.
5. Verify that the module degrades gracefully when Better Combat is missing (clear error, auto-disable).
6. Create a brief `modules/combat/README.md` describing non-obvious behaviors.
7. Notify the core team that the module is ready for integration review.

---

## END OF COMBAT TECHNICAL SPECIFICATION
```

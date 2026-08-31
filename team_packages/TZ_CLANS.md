# ТЗ #5: Clans (Кланы)

Сохранить как: `team_packages/TZ_CLANS.md`

---

```markdown
# TECHNICAL SPECIFICATION: Clans Module

**Module ID:** `clans`
**Module Name:** ShinobiCore - Clan System
**Priority:** 2 (second wave, alongside progression, HUD, visual)
**Core dependency:** Sprint 1 (ModuleManager) + Sprint 2 (Chakra, Stats, Clan, Progression, Formula services)

---

## 1. PURPOSE

Implement the complete shinobi clan system with 9 canonical Naruto clans:

- Uchiha (fire affinity, dojutsu: Sharingan)
- Hyuga (wind affinity, dojutsu: Byakugan)
- Uzumaki (water affinity, vitality bonus)
- Senju (earth affinity, HP bonus)
- Nara (earth affinity, shadow control)
- Aburame (wind affinity, insect swarm, poison)
- Inuzuka (earth affinity, speed, beast instinct)
- Akimichi (earth affinity, tank, heavy strikes)
- Hatake (lightning affinity, attack speed)

Each clan provides:
- Native elemental affinity (free attunement)
- Additional free affinities (via extraAffinityCount)
- Stat bonuses
- Elemental damage bonuses (natureBonuses)
- Jutsu cost multipliers
- Fatigue multipliers
- Chakra cap (max chakra)
- Dojutsu hook (auto-unlocks dojutsu)
- Starting jutsu list
- Passive effects
- Reputation tracking with villages/factions
- Clan-specific jutsu access

**NOT in scope** (belong to other modules):
- Chakra management → core ChakraApi
- Stat levels → core StatsApi (clans only apply modifiers)
- Attunement mini-game → Progression module (clans grant free affinities)
- Dojutsu activation/deactivation → future Dojutsu module
- Visual effects → Visual module
- HUD rendering → HUD module (reads our view)
- Jutsu behavior implementation → Jutsu module (clans only gate access)

---

## 2. FILE OWNERSHIP

The clans team may ONLY create and modify files in these locations:

```
src/main/java/com/example/shinobicore/modules/clans/
src/main/resources/data/shinobicore/clans/           (clan JSON definitions)
src/main/resources/assets/shinobicore/clans/         (textures, sounds, UI assets)
config/shinobicore/modules/clans.json                (generated at runtime)
```

The clans team MUST NOT modify:
- Any file under `core/`
- `ShinobiCoreMod.java` or `ShinobiCoreClient.java`
- Any file belonging to another module
- `fabric.mod.json` (entrypoint addition is done by core team)

---

## 3. ARCHITECTURE

### 3.1 Package structure

```
modules/clans/
├── ClansModule.java                          (entry point, implements ClientAwareModule)
├── config/
│   ├── ClansConfig.java
│   └── ClansConfigLoader.java
├── data/
│   ├── ClanDefinition.java                   (record: all JSON-loaded fields)
│   ├── ClanRegistry.java                     (runtime registry)
│   ├── ClanLoader.java                       (loads JSON from data/clans/)
│   └── ClanJsonValidator.java
├── service/
│   ├── ClanService.java                      (main clan operations)
│   ├── ClanModifierService.java              (applies modifiers to formulas)
│   ├── ClanJutsuGateService.java             (gates jutsu access by clan)
│   ├── ReputationService.java                (faction reputation)
│   └── DojutsuHookService.java               (auto-unlocks dojutsu)
├── component/
│   ├── ClanComponentKey.java                 (CCA component key)
│   ├── ClanComponentImpl.java                (CCA implementation)
│   └── ClanComponentInitializer.java
├── client/
│   ├── ClansClientState.java
│   └── ClansKeyBindings.java
├── ui/
│   ├── ClanTab.java                          (tab in K-screen, read-only info)
│   └── ClanSelectionScreen.java              (operator-only clan change UI)
├── network/
│   ├── ClansPackets.java                     (packet registry)
│   ├── ClanChangeRequestPacket.java          (client -> server: operator request)
│   ├── ClanStateSyncPacket.java              (server -> client)
│   └── ReputationSyncPacket.java             (server -> client)
└── view/
    └── ClanVisualViewImpl.java               (implements ClanVisualView)
```

### 3.2 Module entry point

```java
public class ClansModule implements ClientAwareModule {
    public static final String ID = "clans";

    @Override public String id() { return ID; }

    @Override
    public void onRegister(ModuleContext ctx) {
        ClanComponentKey.register();
    }

    @Override
    public void onEnable(ModuleContext ctx) {
        ClansConfig.load(ctx.configs().readModuleConfig(ID));

        // Load clan definitions from JSON
        ClanLoader.load();
        ClanJsonValidator.validateAll();

        // Init services
        ClanService.init();
        ClanModifierService.init();
        ClanJutsuGateService.init();
        ReputationService.init();
        DojutsuHookService.init();

        ClansPackets.registerServer();
    }

    @Override
    public void registerEvents(ModuleContext ctx) {
        // Apply clan modifiers when formulas are calculated
        ctx.events().subscribe(FormulaCalculationEvent.class, e -> {
            ClanModifierService.applyModifiers(e);
        });

        // Sync clan state on join/respawn
        ctx.events().subscribe(PlayerJoinEvent.class, e -> {
            ClanService.syncToClient(e.player());
            ReputationService.syncToClient(e.player());
        });
        ctx.events().subscribe(PlayerRespawnedEvent.class, e -> {
            ClanService.syncToClient(e.player());
        });

        // Auto-unlock dojutsu when clan is set
        ctx.events().subscribe(ClanSelectedEvent.class, e -> {
            DojutsuHookService.applyHook(e.player(), e.clanId());
        });
    }

    @Override
    public void registerViews(ModuleContext ctx) {
        ctx.views().register(ClanVisualView.class, player ->
            Optional.of(new ClanVisualViewImpl(player)));
    }

    @Override
    public void registerCommands(ModuleContext ctx, CommandDispatcher<ServerCommandSource> d) {
        ClanCommands.register(d);
    }

    @Override
    public void onClientInit(ModuleContext ctx) {
        ClansKeyBindings.register();
        ClansPackets.registerClient();
    }

    @Override
    public void onClientTick(ModuleContext ctx) {
        // No client tick needed for clans
    }
}
```

---

## 4. CORE API TO USE

### 4.1 ChakraApi

```java
CoreServices.get(ChakraApi.class).ifPresent(chakra -> {
    float max = chakra.getMax(player);
    // Clan modifies max chakra via ClanModifierService
});
```

### 4.2 StatsApi

```java
CoreServices.get(StatsApi.class).ifPresent(stats -> {
    int control = stats.getStatLevel(player, "control");
    // Clan bonuses are applied via ClanModifierService
});
```

### 4.3 ProgressionApi

```java
CoreServices.get(ProgressionApi.class).ifPresent(prog -> {
    // Clan may grant free element attunements
    int freeAffinities = prog.getUnlockedElementCount(player);
});
```

### 4.4 FormulaApi

```java
CoreServices.get(FormulaApi.class).ifPresent(f -> {
    float jutsuCost = f.calcJutsuCost(player, jutsuId);
    // Clan cost multipliers applied inside formula
});
```

### 4.5 Events to publish

```java
public record ClanSelectedEvent(ServerPlayerEntity player, String clanId) {}
public record ClanChangedEvent(ServerPlayerEntity player, String oldClanId, String newClanId) {}
public record ClanJutsuUnlockedEvent(ServerPlayerEntity player, String jutsuId) {}
public record ClanJutsuLockedEvent(ServerPlayerEntity player, String jutsuId) {}
public record ReputationChangedEvent(ServerPlayerEntity player, String factionId, int old, int current) {}
public record DojutsuHookAppliedEvent(ServerPlayerEntity player, String clanId, String dojutsuId) {}
```

### 4.6 Events to subscribe

```
FormulaCalculationEvent      -> apply clan modifiers to formulas
PlayerJoinEvent              -> sync clan state to client
PlayerRespawnedEvent         -> sync clan state to client
PlayerChangedDimensionEvent  -> sync clan state to client
```

---

## 5. VIEWS TO REGISTER

Register one view:

```java
public interface ClanVisualView {
    String getClanId();              // or null if no clan
    boolean hasClan();
    String getClanName();
    String getClanColor();           // hex color for UI
    String getAffinity();            // native element
    int getExtraAffinityCount();
    boolean hasDojutsuHook();
    String getDojutsuId();           // or null
    List<String> getStartingJutsu();
    int getReputation(String factionId);
    Map<String, Integer> getAllReputations();
}
```

---

## 6. MECHANICS — DETAILED BEHAVIOR

### 6.1 Clan definition (JSON)

```json
{
  "id": "uchiha",
  "name": "Uchiha Clan",
  "color": "#FF4444",
  "affinity": "fire",
  "extraAffinityCount": 0,

  "statBonuses": {
    "ninjutsu": 10,
    "genjutsu": 15,
    "control": 5
  },

  "natureBonuses": {
    "fire": 10
  },

  "costMultiplier": {
    "fire": 0.9
  },

  "fatigueMultiplier": 1.0,
  "reserveBonus": 0,
  "chakraCap": 2000,

  "dojutsuHook": "sharingan",

  "startingJutsu": [
    "shinobicore:fireball_basic",
    "shinobicore:sharingan_activation"
  ],

  "passives": [
    {
      "id": "fire_resistance",
      "description": "+15% fire damage resistance",
      "effect": "resistance",
      "element": "fire",
      "value": 0.15
    }
  ],

  "exclusiveJutsu": [
    "shinobicore:fireball_basic",
    "shinobicore:fire_phoenix",
    "shinobicore:fire_dragon",
    "shinobicore:sharingan_activation",
    "shinobicore:genjutsu_sharingan"
  ]
}
```

Required fields: `id`, `name`, `affinity`.
All other fields have defaults.

### 6.2 All 9 clans

| Clan | Affinity | Extra Affinities | Dojutsu | Specialty |
|------|----------|-----------------|---------|-----------|
| Uchiha | fire | 0 | Sharingan | Fire + Genjutsu |
| Hyuga | wind | 0 | Byakugan | Melee + precision |
| Uzumaki | water | 0 | — | Vitality, seals |
| Senju | earth | 0 | — | Defense, regen |
| Nara | earth | 0 | — | Shadow control |
| Aburame | wind | 0 | — | Insects, poison |
| Inuzuka | earth | 0 | — | Speed, beast instinct |
| Akimichi | earth | 0 | — | Tank, heavy strikes |
| Hatake | lightning | 0 | — | Attack speed |

### 6.3 Clan selection

Clan is assigned via:
1. **Operator command** (`/shinobicore clan set <clanId>`)
2. **Future: clan selection screen** (not in v1)

No automatic random clan assignment in v1 (design decision).

### 6.4 Clan modifiers

Clan modifiers are applied via `ClanModifierService`:

**Stat bonuses:**
```
effectiveStatLevel = baseStatLevel + clanStatBonus[statId]
```

**Nature bonuses (elemental damage):**
```
effectiveElementDamage = baseDamage * (1 + natureBonus[element] / 100)
```

**Cost multipliers:**
```
effectiveJutsuCost = baseCost * costMultiplier[element]
```

**Fatigue multiplier:**
```
effectiveFatigueGain = baseFatigueGain * fatigueMultiplier
```

**Chakra cap:**
```
maxChakra = min(calculatedMaxChakra, clanChakraCap)
```

These modifiers are applied inside `FormulaApi` via `FormulaCalculationEvent`.

### 6.5 Dojutsu hook

When a clan with `dojutsuHook` is selected:
1. `DojutsuHookService.applyHook(player, clanId)` is called
2. If `dojutsuHook` is not null:
   - Publish `DojutsuHookAppliedEvent`
   - Future Dojutsu module will listen and auto-unlock
3. In v1 (no Dojutsu module yet): just log the event

### 6.6 Starting jutsu

When a clan is selected:
1. All jutsu in `startingJutsu` are force-learned
2. Published `ClanJutsuUnlockedEvent` for each

When a clan is changed:
1. All jutsu in old clan's `exclusiveJutsu` are force-forgotten
2. Published `ClanJutsuLockedEvent` for each
3. All jutsu in new clan's `startingJutsu` are force-learned

### 6.7 Exclusive jutsu gating

`ClanJutsuGateService` checks if a jutsu is accessible:

```java
public static boolean isJutsuAccessible(PlayerEntity player, String jutsuId) {
    JutsuDefinition def = JutsuRegistry.get(jutsuId).orElse(null);
    if (def == null) return false;

    // If jutsu has clanRequired, check player's clan
    if (def.requirements().clanRequired() != null) {
        String playerClan = ClanService.getClanId(player);
        if (!def.requirements().clanRequired().equals(playerClan)) {
            return false;
        }
    }

    return true;
}
```

### 6.8 Reputation

**Factions:**
```
village_<id>    - reputation with each village
clan_<id>       - reputation with each clan (if not member)
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

### 6.9 Clan change

**Operator only** (`/shinobicore clan change <newClanId>`):

1. Check player has permission level 2+
2. Get old clan
3. If old clan exists:
   - Force-forget all old clan's `exclusiveJutsu`
   - Publish `ClanJutsuLockedEvent` for each
   - Reset all reputation to 0
   - Publish `ReputationChangedEvent` for each faction
4. Set new clan
5. Force-learn new clan's `startingJutsu`
6. Publish `ClanJutsuUnlockedEvent` for each
7. Apply dojutsu hook if present
8. Publish `ClanChangedEvent`
9. Sync to client

**No self-service clan change** (by design).

---

## 7. CLIENT-SERVER AUTHORITY

```
CLIENT (read-only UI):
- Renders clan info in K-screen tab (read-only)
- No clan change UI (operator-only command)

SERVER (authoritative for truth):
- Validates all clan changes
- Applies modifiers via events
- Syncs clan state to client
- Soft-corrects on desync (log + adjust, never crash)
```

### CRITICAL PACKET RULE

```java
ServerPlayNetworking.registerGlobalReceiver(ID, (server, player, handler, buf, sender) -> {
    // STEP 1: Read ALL data from buffer FIRST
    final String newClanId = buf.readString();

    // STEP 2: Execute on server thread
    server.execute(() -> {
        ClanService.changeClan(player, newClanId);
    });
});
```

NEVER read `buf` inside `server.execute()`.

---

## 8. FULL CONFIG TEMPLATE

File: `config/shinobicore/modules/clans.json` (auto-created on first run)

```json
{
  "enabled": true,
  "debug": false,

  "selection": {
    "allowOperatorChange": true,
    "allowPlayerChange": false,
    "randomAssignOnJoin": false
  },

  "change": {
    "resetReputationOnChange": true,
    "removeClanJutsuOnChange": true,
    "resetDojutsuOnChange": true
  },

  "reputation": {
    "enabled": true,
    "maxReputation": 1000,
    "minReputation": -1000,
    "defaultReputation": 0
  },

  "logging": {
    "logClanChanges": true,
    "logReputationChanges": false,
    "logJutsuLocks": true
  }
}
```

### JSON data files

Clans team is responsible for these data directories:

```
data/shinobicore/clans/
├── uchiha.json
├── hyuga.json
├── uzumaki.json
├── senju.json
├── nara.json
├── aburame.json
├── inuzuka.json
├── akimichi.json
└── hatake.json
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
/shinobicore clan info                     - show current clan, affinity, bonuses
/shinobicore clan list                     - list all registered clans
/shinobicore clan set <clanId>             - set clan (operator only)
/shinobicore clan change <clanId>          - change clan (operator only)
/shinobicore clan reputation info          - show all faction reputations
/shinobicore clan reputation set <faction> <value> - set reputation (operator)
/shinobicore clan reputation add <faction> <amount> - add reputation (operator)
/shinobicore clan validate                 - validate all clan JSON (report errors)
/shinobicore clan sync                     - force sync state to client
/shinobicore clan debug                    - toggle debug overlay
```

---

## 10. FORBIDDEN PATTERNS

Clans team MUST NOT do any of these:

1. **DO NOT** manage chakra directly. Use `ChakraApi`.
2. **DO NOT** manage stat levels directly. Use `StatsApi` (clans only apply modifiers).
3. **DO NOT** use `System.out.println`. Use `ShinobiLogger.module("clans", ...)`.
4. **DO NOT** hold player state in `static Map<UUID, State>` without cleanup on player disconnect.
5. **DO NOT** read `PacketByteBuf` inside `server.execute()`.
6. **DO NOT** crash on malformed clan JSON. Log error, skip clan, continue loading others.
7. **DO NOT** allow non-operators to change clan.
8. **DO NOT** create god-classes (>300 lines). Decompose by responsibility.
9. **DO NOT** import classes from other modules. Use core events/services/views only.
10. **DO NOT** make the module crash if another module is disabled. Handle missing services gracefully.
11. **DO NOT** implement dojutsu activation/deactivation (future module).
12. **DO NOT** hardcode clan data in Java. Read from JSON.

---

## 11. DEFINITION OF DONE

The clans module is complete when:

1. ✅ Module loads via `shinobicore:module` entrypoint
2. ✅ `/shinobicore systems` shows `clans: ENABLED`
3. ✅ All 9 clan JSON definitions load from `data/shinobicore/clans/`
4. ✅ Invalid JSON logs error, does not crash game
5. ✅ Clan selection via operator command works
6. ✅ Clan modifiers apply correctly (stat bonuses, nature bonuses, cost multipliers)
7. ✅ Chakra cap is enforced
8. ✅ Dojutsu hook event is published (even if no listener in v1)
9. ✅ Starting jutsu are force-learned on clan selection
10. ✅ Exclusive jutsu are gated by clan requirement
11. ✅ Clan change removes old clan's exclusive jutsu
12. ✅ Clan change resets reputation
13. ✅ Reputation system works (set, add, query)
14. ✅ Clan state persists across death, respawn, dimension change, game restart
15. ✅ Clan state is ignored if module is disabled (data preserved)
16. ✅ `ClanVisualView` registered and readable by HUD module
17. ✅ K-screen tab shows clan info (read-only)
18. ✅ Commands work (`info`, `list`, `set`, `change`, `reputation`, `validate`, `sync`)
19. ✅ Log files `logs/shinobicore/clans-1.log` created and rotated
20. ✅ Module does not crash when other modules are disabled
21. ✅ Config file `clans.json` created on first run with defaults
22. ✅ Broken JSON does not crash the game
23. ✅ All network packets follow "read first, execute second" rule
24. ✅ Build passes: `.\gradlew.bat build`

---

## 12. EXAMPLE CODE SNIPPETS

### 12.1 ClanDefinition record

```java
public record ClanDefinition(
    String id,
    String name,
    String color,
    String affinity,
    int extraAffinityCount,
    Map<String, Integer> statBonuses,
    Map<String, Integer> natureBonuses,
    Map<String, Float> costMultiplier,
    float fatigueMultiplier,
    int reserveBonus,
    int chakraCap,
    @Nullable String dojutsuHook,
    List<String> startingJutsu,
    List<PassiveEffect> passives,
    List<String> exclusiveJutsu
) {
    public record PassiveEffect(
        String id,
        String description,
        String effect,
        @Nullable String element,
        float value
    ) {}

    public static ClanDefinition DEFAULT = new ClanDefinition(
        "none", "No Clan", "#FFFFFF", "none", 0,
        Map.of(), Map.of(), Map.of(), 1.0f, 0, Integer.MAX_VALUE,
        null, List.of(), List.of(), List.of()
    );
}
```

### 12.2 Clan modifier service

```java
public final class ClanModifierService {

    public static void applyModifiers(FormulaCalculationEvent event) {
        PlayerEntity player = event.player();
        Optional<ClanComponent> compOpt = ClanComponentKey.get(player);
        if (compOpt.isEmpty()) return;
        ClanComponent comp = compOpt.get();

        ClanDefinition clan = ClanRegistry.get(comp.getClanId()).orElse(null);
        if (clan == null) return;

        // Apply stat bonuses
        for (Map.Entry<String, Integer> entry : clan.statBonuses().entrySet()) {
            event.addStatBonus(entry.getKey(), entry.getValue());
        }

        // Apply nature bonuses
        for (Map.Entry<String, Integer> entry : clan.natureBonuses().entrySet()) {
            event.addElementDamageBonus(entry.getKey(), entry.getValue() / 100.0f);
        }

        // Apply cost multipliers
        for (Map.Entry<String, Float> entry : clan.costMultiplier().entrySet()) {
            event.setCostMultiplier(entry.getKey(), entry.getValue());
        }

        // Apply fatigue multiplier
        event.setFatigueMultiplier(clan.fatigueMultiplier());

        // Apply chakra cap
        event.setChakraCap(clan.chakraCap());
    }
}
```

### 12.3 Clan change service

```java
public final class ClanService {

    public static boolean changeClan(ServerPlayerEntity player, String newClanId) {
        // Check operator permission
        if (!player.hasPermissionLevel(2)) {
            ShinobiLogger.module("clans", "Permission denied for clan change");
            return false;
        }

        // Validate new clan exists
        ClanDefinition newClan = ClanRegistry.get(newClanId).orElse(null);
        if (newClan == null) {
            ShinobiLogger.module("clans", "Unknown clan: " + newClanId);
            return false;
        }

        Optional<ClanComponent> compOpt = ClanComponentKey.get(player);
        if (compOpt.isEmpty()) return false;
        ClanComponent comp = compOpt.get();

        String oldClanId = comp.getClanId();

        // Step 1: Remove old clan's exclusive jutsu
        if (oldClanId != null) {
            ClanDefinition oldClan = ClanRegistry.get(oldClanId).orElse(null);
            if (oldClan != null) {
                for (String jutsuId : oldClan.exclusiveJutsu()) {
                    CoreServices.get(ProgressionApi.class).ifPresent(prog -> {
                        // Force-forget jutsu (implementation in progression module)
                    });
                    CoreEvents.publish(new ClanJutsuLockedEvent(player, jutsuId));
                }
            }
        }

        // Step 2: Reset reputation
        ReputationService.resetAll(player);

        // Step 3: Set new clan
        comp.setClanId(newClanId);

        // Step 4: Learn new clan's starting jutsu
        for (String jutsuId : newClan.startingJutsu()) {
            CoreServices.get(ProgressionApi.class).ifPresent(prog -> {
                // Force-learn jutsu (implementation in progression module)
            });
            CoreEvents.publish(new ClanJutsuUnlockedEvent(player, jutsuId));
        }

        // Step 5: Apply dojutsu hook
        if (newClan.dojutsuHook() != null) {
            DojutsuHookService.applyHook(player, newClanId);
        }

        // Step 6: Publish event
        CoreEvents.publish(new ClanChangedEvent(player, oldClanId, newClanId));

        // Step 7: Sync to client
        syncToClient(player);

        ShinobiLogger.module("clans",
            "Clan changed: " + oldClanId + " -> " + newClanId);
        return true;
    }
}
```

### 12.4 Clan JSON loader

```java
public final class ClanLoader {
    private static final Gson GSON = new Gson();

    public static void load() {
        ResourceManager rm = FabricLoader.getInstance()
            .getModContainer("shinobicore").orElseThrow()
            .getResourceManager();

        for (Identifier id : rm.findResources("clans",
                p -> p.getPath().endsWith(".json")).keySet()) {
            try {
                Resource resource = rm.getResource(id).orElseThrow();
                try (InputStream is = resource.getInputStream();
                     Reader reader = new InputStreamReader(is, StandardCharsets.UTF_8)) {
                    ClanDefinition clan = GSON.fromJson(reader, ClanDefinition.class);
                    ClanRegistry.register(clan);
                }
            } catch (Exception e) {
                ShinobiLogger.error("clans", "Failed to load clan: " + id, e);
            }
        }

        ShinobiLogger.module("clans",
            "Loaded " + ClanRegistry.size() + " clans");
    }
}
```

### 12.5 Clan JSON validator

```java
public final class ClanJsonValidator {
    private static int errorCount = 0;

    public static void validateAll() {
        errorCount = 0;
        for (ClanDefinition clan : ClanRegistry.all()) {
            validate(clan);
        }
        if (errorCount > 0) {
            ShinobiLogger.error("clans",
                "Validation completed with " + errorCount + " errors.", null);
        } else {
            ShinobiLogger.module("clans",
                "All " + ClanRegistry.size() + " clans validated successfully.");
        }
    }

    private static void validate(ClanDefinition clan) {
        if (clan.id() == null || clan.id().isEmpty()) {
            error(clan, "empty id");
        }
        if (clan.name() == null || clan.name().isEmpty()) {
            error(clan, "empty name");
        }
        if (clan.affinity() == null || clan.affinity().isEmpty()) {
            error(clan, "empty affinity");
        }
        if (clan.chakraCap() <= 0) {
            error(clan, "chakraCap <= 0");
        }
        if (clan.fatigueMultiplier() <= 0) {
            error(clan, "fatigueMultiplier <= 0");
        }

        // Check starting jutsu exist
        for (String jutsuId : clan.startingJutsu()) {
            if (!JutsuRegistry.get(jutsuId).isPresent()) {
                error(clan, "starting jutsu not found: " + jutsuId);
            }
        }

        // Check exclusive jutsu exist
        for (String jutsuId : clan.exclusiveJutsu()) {
            if (!JutsuRegistry.get(jutsuId).isPresent()) {
                error(clan, "exclusive jutsu not found: " + jutsuId);
            }
        }
    }

    private static void error(ClanDefinition clan, String msg) {
        ShinobiLogger.error("clans",
            "Validation error in " + clan.id() + ": " + msg, null);
        errorCount++;
    }
}
```

---

## 13. HANDOFF

When the clans team finishes, they must:

1. Run `.\gradlew.bat build` — must pass with 0 errors.
2. Run `.\gradlew.bat runClient` and manually verify:
   - `/shinobicore clan set uchiha` sets clan
   - Clan modifiers apply (check chakra cap, cost multipliers)
   - Starting jutsu are learned
   - `/shinobicore clan change hyuga` changes clan, removes Uchiha jutsu
   - Reputation resets on clan change
   - Clan info shows in K-screen tab
3. Verify that disabling the module via `clans.json` (`enabled: false`) does not break the game.
4. Verify that other modules (jutsu, progression, HUD) load correctly and handle missing clan data gracefully.
5. Verify that invalid clan JSON does not crash the game.
6. Create a brief `modules/clans/README.md` describing non-obvious behaviors.
7. Notify the core team that the module is ready for integration review.

---

## END OF CLANS TECHNICAL SPECIFICATION
```

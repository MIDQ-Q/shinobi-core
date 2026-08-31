# ТЗ #6: HUD (Интерфейс)

Сохранить как: `team_packages/TZ_HUD.md`

---

```markdown
# TECHNICAL SPECIFICATION: HUD Module

**Module ID:** `hud`
**Module Name:** ShinobiCore - Heads-Up Display
**Priority:** 2 (second wave, alongside progression, clans, visual)
**Core dependency:** Sprint 1 (ModuleManager) + Sprint 2 (all core services) + all other modules' views

---

## 1. PURPOSE

Implement the complete in-game HUD overlay:

- Chakra bar (always visible)
- Health bar (always visible, replaces vanilla hearts)
- Fatigue bar (contextual, visible when fatigue > 0)
- Jutsu slot bar (contextual, visible when jutsu module active)
- Jutsu cooldown overlays (contextual)
- Cast progress bar (contextual, visible during casting)
- Chakra mode indicator (contextual, visible when chakra mode active)
- Combat stance indicator (contextual, visible when combat module active)
- Combo step indicator (contextual, visible during combat combos)
- Player level + XP bar (always visible, bottom of screen)
- Debug overlay (toggle via command, hidden by default)

**NOT in scope** (belong to other modules):
- Chakra/stat/progression data management → core services
- Jutsu casting logic → Jutsu module (we only read their view)
- Combat logic → Combat module (we only read their view)
- Visual effects / particles → Visual module
- K-screen (progression menu) → Progression module
- Data generation or modification → any other module

**CRITICAL: HUD module is READ-ONLY.** It never modifies any game state. It only reads views and renders.

---

## 2. FILE OWNERSHIP

The HUD team may ONLY create and modify files in these locations:

```
src/main/java/com/example/shinobicore/modules/hud/
src/main/resources/assets/shinobicore/hud/         (textures, icons, fonts)
config/shinobicore/modules/hud.json                (generated at runtime)
```

The HUD team MUST NOT modify:
- Any file under `core/`
- `ShinobiCoreMod.java` or `ShinobiCoreClient.java`
- Any file belonging to another module
- `fabric.mod.json` (entrypoint addition is done by core team)
- Any game state (chakra, stats, progression, etc.)

---

## 3. ARCHITECTURE

### 3.1 Package structure

```
modules/hud/
├── HudModule.java                          (entry point, implements ClientAwareModule)
├── config/
│   ├── HudConfig.java
│   └── HudConfigLoader.java
├── state/
│   ├── HudState.java                       (current HUD state snapshot)
│   ├── HudDirtyTracker.java                (tracks what changed since last render)
│   └── HudElementVisibility.java           (which elements are visible)
├── render/
│   ├── HudRenderer.java                    (main render orchestrator)
│   ├── ChakraBarRenderer.java
│   ├── HealthBarRenderer.java
│   ├── FatigueBarRenderer.java
│   ├── JutsuSlotBarRenderer.java
│   ├── CooldownOverlayRenderer.java
│   ├── CastBarRenderer.java
│   ├── ChakraModeIndicatorRenderer.java
│   ├── StanceIndicatorRenderer.java
│   ├── ComboIndicatorRenderer.java
│   ├── LevelXpBarRenderer.java
│   └── DebugOverlayRenderer.java
├── mixin/
│   ├── HideVanillaHeartsMixin.java         (hides vanilla hearts)
│   └── HideVanillaArmorMixin.java          (optional: hides vanilla armor)
├── util/
│   ├── HudColors.java                      (color constants)
│   ├── HudLayout.java                      (layout constants)
│   └── BarDrawUtil.java                    (draw helpers)
└── view/
    └── HudViewConsumer.java                (reads all views from core)
```

### 3.2 Module entry point

```java
public class HudModule implements ClientAwareModule {
    public static final String ID = "hud";

    @Override public String id() { return ID; }

    @Override
    public void onRegister(ModuleContext ctx) {
        // No CCA component needed (read-only module)
    }

    @Override
    public void onEnable(ModuleContext ctx) {
        HudConfig.load(ctx.configs().readModuleConfig(ID));
        HudState.init();
        HudDirtyTracker.init();
        HudElementVisibility.init();
    }

    @Override
    public void registerEvents(ModuleContext ctx) {
        // Subscribe to events that change HUD state
        ctx.events().subscribe(ChakraChangedEvent.class, e -> HudDirtyTracker.markDirty("chakra"));
        ctx.events().subscribe(ChakraModeEnabledEvent.class, e -> HudDirtyTracker.markDirty("chakraMode"));
        ctx.events().subscribe(ChakraModeDisabledEvent.class, e -> HudDirtyTracker.markDirty("chakraMode"));
        ctx.events().subscribe(FatigueChangedEvent.class, e -> HudDirtyTracker.markDirty("fatigue"));
        ctx.events().subscribe(JutsuCastStartedEvent.class, e -> HudDirtyTracker.markDirty("cast"));
        ctx.events().subscribe(JutsuCastFinishedEvent.class, e -> HudDirtyTracker.markDirty("cast"));
        ctx.events().subscribe(JutsuCooldownChangedEvent.class, e -> HudDirtyTracker.markDirty("cooldowns"));
        ctx.events().subscribe(CombatStanceChangedEvent.class, e -> HudDirtyTracker.markDirty("stance"));
        ctx.events().subscribe(CombatComboChangedEvent.class, e -> HudDirtyTracker.markDirty("combo"));
        ctx.events().subscribe(LevelChangedEvent.class, e -> HudDirtyTracker.markDirty("level"));
        ctx.events().subscribe(XpGainedEvent.class, e -> HudDirtyTracker.markDirty("xp"));
    }

    @Override
    public void registerViews(ModuleContext ctx) {
        // HUD does NOT register views. It only consumes them.
    }

    @Override
    public void registerCommands(ModuleContext ctx, CommandDispatcher<ServerCommandSource> d) {
        HudCommands.register(d);
    }

    @Override
    public void onClientInit(ModuleContext ctx) {
        HudRenderer.init();
        HudViewConsumer.init(ctx);
        HudRenderer.registerHudCallback();
    }

    @Override
    public void onClientTick(ModuleContext ctx) {
        HudViewConsumer.pollViews();
        HudDirtyTracker.tick();
    }
}
```

---

## 4. CORE API TO USE (READ-ONLY)

### 4.1 Views to consume

HUD reads views registered by other modules:

```java
// Chakra (from core)
CoreServices.get(ChakraApi.class).ifPresent(chakra -> {
    float current = chakra.getCurrent(player);
    float max = chakra.getMax(player);
    float fatigue = chakra.getFatigue(player);
    boolean mode = chakra.isChakraModeActive(player);
});

// Progression (from progression module)
CoreViews.get(player, ProgressionVisualView.class).ifPresent(prog -> {
    int level = prog.getPlayerLevel();
    int xp = prog.getCurrentXp();
    int xpToNext = prog.getXpToNextLevel();
    float progress = prog.getProgressToNextLevel();
});

// Jutsu (from jutsu module)
CoreViews.get(player, JutsuVisualView.class).ifPresent(jutsu -> {
    boolean casting = jutsu.isCasting();
    float castProgress = jutsu.getCastProgress();
    String currentJutsu = jutsu.getCurrentJutsuId();
    int slotCount = jutsu.getSlotCount();
    int selectedSlot = jutsu.getSelectedSlot();
    for (int i = 0; i < slotCount; i++) {
        String slotJutsu = jutsu.getSlotJutsuId(i);
        int cooldown = jutsu.getCooldownTicks(slotJutsu);
        int maxCooldown = jutsu.getMaxCooldownTicks(slotJutsu);
    }
});

// Combat (from combat module)
CoreViews.get(player, CombatVisualView.class).ifPresent(combat -> {
    String stance = combat.getCurrentStance();
    boolean blocking = combat.isBlocking();
    int comboStep = combat.getComboStep();
    boolean sheathed = combat.isSheathed();
});

// Movement (from movement module)
CoreViews.get(player, MovementVisualView.class).ifPresent(movement -> {
    boolean waterWalking = movement.isWaterWalking();
    boolean wallRunning = movement.isWallRunning();
    // Optional: show movement state indicator
});

// Clan (from clans module)
CoreViews.get(player, ClanVisualView.class).ifPresent(clan -> {
    String clanName = clan.getClanName();
    String clanColor = clan.getClanColor();
    // Optional: show clan name in corner
});
```

### 4.2 Events to subscribe

```
ChakraChangedEvent           -> mark chakra dirty
ChakraModeEnabledEvent       -> mark chakraMode dirty
ChakraModeDisabledEvent      -> mark chakraMode dirty
FatigueChangedEvent          -> mark fatigue dirty
JutsuCastStartedEvent        -> mark cast dirty
JutsuCastFinishedEvent       -> mark cast dirty
JutsuCooldownChangedEvent    -> mark cooldowns dirty
CombatStanceChangedEvent     -> mark stance dirty
CombatComboChangedEvent      -> mark combo dirty
LevelChangedEvent            -> mark level dirty
XpGainedEvent                -> mark xp dirty
PlayerDiedEvent              -> mark all dirty
PlayerRespawnedEvent         -> mark all dirty
```

---

## 5. HUD ELEMENTS — DETAILED BEHAVIOR

### 5.1 Layout overview

```
+--------------------------------------------------------------+
|                                                              |
|   [Chakra Mode]  [Stance]  [Combo]          (top-left)      |
|                                                              |
|                                                              |
|                                                              |
|                                                              |
|                                                              |
|                                                              |
|                                                              |
|   [Cast Bar]                                  (center)       |
|                                                              |
|                                                              |
|                                                              |
|                                                              |
|                                                              |
|                                                              |
|                                                              |
|   [Chakra Bar]  [Fatigue Bar]               (bottom-left)    |
|   [Health Bar]                               (bottom-center) |
|   [Jutsu Slots + Cooldowns]                  (bottom-right)  |
|   [Level + XP Bar]                           (bottom)        |
+--------------------------------------------------------------+
```

### 5.2 Chakra bar (always visible)

Position: bottom-left, above hotbar.

```
Width:  100 pixels
Height: 8 pixels
Colors:
  Background: 0xFF222222
  Fill:       gradient from CHAKRA_DARK (0xFF1155CC) to CHAKRA_LIGHT (0xFF4499FF)
  Border:     0xFF000000
  Text:       current/max in white
```

Behavior:
- Always visible
- Fill width = `(current / max) * barWidth`
- Text shows `current / max` (integer)
- Flash red when chakra < 10% of max
- Pulse animation when chakra mode is active

### 5.3 Health bar (always visible, replaces vanilla hearts)

Position: bottom-center, where vanilla hearts are.

```
Width:  100 pixels (same as chakra bar)
Height: 8 pixels
Colors:
  Background: 0xFF222222
  Fill:       gradient from 0xFFCC2222 to 0xFFFF4444
  Border:     0xFF000000
  Text:       current/max in white
```

Behavior:
- Always visible
- Vanilla hearts are HIDDEN (via mixin)
- Fill width = `(health / maxHealth) * barWidth`
- Text shows `current / max` (integer)
- Flash red when health < 20% of max
- Pulse animation when health < 10% of max

### 5.4 Fatigue bar (contextual)

Position: bottom-left, below chakra bar.

```
Width:  80 pixels
Height: 6 pixels
Colors:
  Background: 0xFF222222
  Fill:       gradient from FATIGUE_DARK (0xFFBB8811) to FATIGUE_LIGHT (0xFFEEBB33)
  Border:     0xFF000000
```

Behavior:
- Visible only when fatigue > 0
- Fill width = `(fatigue / maxFatigue) * barWidth`
- Flash yellow when fatigue > 80% of max
- Hide when fatigue reaches 0

### 5.5 Jutsu slot bar (contextual)

Position: bottom-right, above hotbar.

```
Slot size:  20x20 pixels
Slot gap:   2 pixels
Colors:
  Background:     0xFF333333
  Selected:       0xFFFFFF00 (yellow border)
  Cooldown fill:  0xFF666666 (gray overlay)
  Icon:           jutsu element color or first letter
```

Behavior:
- Visible when jutsu module is active and player has learned jutsu
- Shows 3 slots (A, B, C) by default
- Selected slot has yellow border
- Each slot shows:
  - Jutsu icon (element color or first letter)
  - Cooldown overlay (gray fill from bottom to top)
  - Cooldown number (seconds remaining)
- Empty slots show gray background

### 5.6 Cast bar (contextual)

Position: center of screen, above crosshair.

```
Width:  120 pixels
Height: 10 pixels
Colors:
  Background: 0xFF222222
  Fill:       jutsu element color
  Border:     0xFF000000
  Text:       jutsu name in white
```

Behavior:
- Visible only during casting (PREPARE, CHARGE, RELEASE phases)
- Fill width = `castProgress * barWidth`
- Text shows jutsu name
- Element color matches jutsu element
- Hide when cast finishes or is cancelled

### 5.7 Chakra mode indicator (contextual)

Position: top-left, below debug overlay.

```
Size:  16x16 pixels
Color: 0xFF4499FF (chakra blue)
```

Behavior:
- Visible only when chakra mode is active
- Shows a small chakra icon (blue circle)
- Pulse animation

### 5.8 Stance indicator (contextual)

Position: top-left, next to chakra mode indicator.

```
Size:  16x16 pixels
Colors:
  Aggressive: 0xFFFF4444 (red)
  Defensive:  0xFF4444FF (blue)
```

Behavior:
- Visible only when combat module is active and player is in combat context
- Shows stance icon (sword for aggressive, shield for defensive)
- Text label below icon: "AGG" or "DEF"

### 5.9 Combo indicator (contextual)

Position: top-left, next to stance indicator.

```
Size:  20x20 pixels
Color: 0xFFFFAA00 (orange)
```

Behavior:
- Visible only during combat combos (comboStep > 0)
- Shows combo step number
- Fades out after combo timeout

### 5.10 Level + XP bar (always visible)

Position: bottom of screen, below hotbar.

```
Width:  200 pixels (centered)
Height: 4 pixels
Colors:
  Background: 0xFF222222
  Fill:       0xFF44FF44 (green)
  Border:     0xFF000000
  Text:       "Lv {level}" in white, above bar
```

Behavior:
- Always visible
- Fill width = `progressToNextLevel * barWidth`
- Text shows `Lv {level}` above the bar
- Flash green on level-up

### 5.11 Debug overlay (toggle via command)

Position: top-left corner.

```
Font: Minecraft default
Color: 0xFFFFFFFF (white)
Background: 0x80000000 (semi-transparent black)
```

Behavior:
- Hidden by default
- Toggle via `/shinobicore hud debug`
- Shows:
  - Module states (from `/shinobicore systems`)
  - Current chakra, fatigue, health
  - Current jutsu cast state
  - Current combat stance, combo
  - Current movement pose
  - FPS, TPS
  - Memory usage

---

## 6. DIRTY TRACKING

HUD uses dirty tracking to avoid re-rendering every frame:

```java
public final class HudDirtyTracker {
    private static final Set<String> dirtyFlags = ConcurrentHashMap.newKeySet();
    private static boolean allDirty = true;

    public static void markDirty(String element) {
        dirtyFlags.add(element);
    }

    public static void markAllDirty() {
        allDirty = true;
    }

    public static boolean isDirty(String element) {
        return allDirty || dirtyFlags.contains(element);
    }

    public static void clear() {
        dirtyFlags.clear();
        allDirty = false;
    }

    public static void tick() {
        // Auto-clear after 1 tick (render happens next frame)
        // This ensures we render at least once after each change
    }
}
```

Render logic:
```java
public static void render(DrawContext ctx, float delta) {
    if (!HudDirtyTracker.isDirty("any")) {
        return; // Skip render if nothing changed
    }

    // Render only dirty elements
    if (HudDirtyTracker.isDirty("chakra")) {
        ChakraBarRenderer.render(ctx);
    }
    if (HudDirtyTracker.isDirty("health")) {
        HealthBarRenderer.render(ctx);
    }
    // ... etc

    HudDirtyTracker.clear();
}
```

---

## 7. VANILLA HEARTS MIXIN

```java
@Mixin(InGameHud.class)
public abstract class HideVanillaHeartsMixin {

    @Inject(method = "renderStatusBars", at = @At("HEAD"), cancellable = true)
    private void shinobicore$hideHearts(DrawContext context, CallbackInfo ci) {
        // Check if HUD module is enabled
        if (!HudConfig.get().enabled) return;

        // Check if we should hide vanilla hearts
        if (HudConfig.get().hideVanillaHearts) {
            ci.cancel(); // Cancel vanilla heart rendering
        }
    }
}
```

**CRITICAL:** This mixin must be registered in `shinobicore.mixins.json` under `"client"` array.

---

## 8. CLIENT-SERVER AUTHORITY

```
CLIENT (authoritative for rendering):
- Reads views from core
- Renders HUD elements
- Tracks dirty state
- No game state modification

SERVER (not involved):
- HUD is purely client-side
- No packets sent from HUD module
- No server-side logic
```

### NO PACKETS

HUD module does NOT send or receive any packets. It only reads views that are already synced by other modules.

---

## 9. FULL CONFIG TEMPLATE

File: `config/shinobicore/modules/hud.json` (auto-created on first run)

```json
{
  "enabled": true,
  "debug": false,

  "elements": {
    "chakraBar": {
      "enabled": true,
      "alwaysVisible": true,
      "width": 100,
      "height": 8,
      "x": 4,
      "y": -20
    },
    "healthBar": {
      "enabled": true,
      "alwaysVisible": true,
      "width": 100,
      "height": 8,
      "x": -50,
      "y": -20
    },
    "fatigueBar": {
      "enabled": true,
      "alwaysVisible": false,
      "width": 80,
      "height": 6,
      "x": 4,
      "y": -10
    },
    "jutsuSlots": {
      "enabled": true,
      "alwaysVisible": false,
      "slotSize": 20,
      "slotGap": 2,
      "x": -70,
      "y": -24
    },
    "castBar": {
      "enabled": true,
      "alwaysVisible": false,
      "width": 120,
      "height": 10,
      "x": 0,
      "y": -60
    },
    "chakraModeIndicator": {
      "enabled": true,
      "alwaysVisible": false,
      "size": 16,
      "x": 4,
      "y": 4
    },
    "stanceIndicator": {
      "enabled": true,
      "alwaysVisible": false,
      "size": 16,
      "x": 24,
      "y": 4
    },
    "comboIndicator": {
      "enabled": true,
      "alwaysVisible": false,
      "size": 20,
      "x": 44,
      "y": 4
    },
    "levelXpBar": {
      "enabled": true,
      "alwaysVisible": true,
      "width": 200,
      "height": 4,
      "x": 0,
      "y": -4
    },
    "debugOverlay": {
      "enabled": false,
      "alwaysVisible": false,
      "x": 4,
      "y": 4
    }
  },

  "colors": {
    "chakraLight": "0xFF4499FF",
    "chakraDark": "0xFF1155CC",
    "fatigueLight": "0xFFEEBB33",
    "fatigueDark": "0xFFBB8811",
    "healthLight": "0xFFFF4444",
    "healthDark": "0xFFCC2222",
    "xpFill": "0xFF44FF44",
    "background": "0xFF222222",
    "border": "0xFF000000",
    "text": "0xFFFFFFFF"
  },

  "hideVanilla": {
    "hearts": true,
    "armor": false,
    "food": false,
    "air": false
  },

  "animations": {
    "flashWhenLow": true,
    "pulseWhenActive": true,
    "fadeSpeed": 0.1
  },

  "logging": {
    "logRenderCalls": false,
    "logDirtyFlags": false
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
/shinobicore hud debug           - toggle debug overlay
/shinobicore hud test            - show all HUD elements with fake data
/shinobicore hud reset           - reset HUD state
/shinobicore hud info            - show current HUD state (dirty flags, visibility)
```

---

## 11. FORBIDDEN PATTERNS

HUD team MUST NOT do any of these:

1. **DO NOT** modify any game state (chakra, stats, progression, etc.). HUD is READ-ONLY.
2. **DO NOT** send or receive any network packets.
3. **DO NOT** use `System.out.println`. Use `ShinobiLogger.module("hud", ...)`.
4. **DO NOT** render every frame without dirty tracking. Must skip render if nothing changed.
5. **DO NOT** create god-classes (>300 lines). Decompose by responsibility.
6. **DO NOT** import classes from other modules. Use core views only.
7. **DO NOT** make the module crash if another module is disabled. Handle missing views gracefully.
8. **DO NOT** hardcode colors in Java. Read from config.
9. **DO NOT** render debug overlay by default. Must be toggled via command.
10. **DO NOT** modify vanilla HUD elements other than hearts (and optionally armor).
11. **DO NOT** drop below 60 FPS on medium PC with all HUD elements visible.

---

## 12. DEFINITION OF DONE

The HUD module is complete when:

1. ✅ Module loads via `shinobicore:module` entrypoint
2. ✅ `/shinobicore systems` shows `hud: ENABLED`
3. ✅ Chakra bar renders correctly (always visible)
4. ✅ Health bar renders correctly (always visible, replaces vanilla hearts)
5. ✅ Vanilla hearts are hidden (mixin works)
6. ✅ Fatigue bar renders when fatigue > 0 (contextual)
7. ✅ Jutsu slots render when jutsu module active (contextual)
8. ✅ Cooldown overlays render on jutsu slots
9. ✅ Cast bar renders during casting (contextual)
10. ✅ Chakra mode indicator renders when chakra mode active (contextual)
11. ✅ Stance indicator renders when combat module active (contextual)
12. ✅ Combo indicator renders during combat combos (contextual)
13. ✅ Level + XP bar renders correctly (always visible)
14. ✅ Debug overlay toggles via command
15. ✅ Dirty tracking works (no unnecessary re-renders)
16. ✅ HUD does not modify any game state
17. ✅ HUD does not send or receive any packets
18. ✅ HUD handles missing views gracefully (other modules disabled)
19. ✅ Commands work (`debug`, `test`, `reset`, `info`)
20. ✅ Log files `logs/shinobicore/hud-1.log` created and rotated
21. ✅ Module does not crash when other modules are disabled
22. ✅ Config file `hud.json` created on first run with defaults
23. ✅ Broken JSON does not crash the game
24. ✅ 60+ FPS on medium PC with all HUD elements visible
25. ✅ Build passes: `.\gradlew.bat build`

---

## 13. EXAMPLE CODE SNIPPETS

### 13.1 Chakra bar renderer

```java
public final class ChakraBarRenderer {
    private static final int WIDTH = 100;
    private static final int HEIGHT = 8;

    public static void render(DrawContext ctx) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;

        // Read chakra from core
        Optional<ChakraApi> chakraOpt = CoreServices.get(ChakraApi.class);
        if (chakraOpt.isEmpty()) return;
        ChakraApi chakra = chakraOpt.get();

        float current = chakra.getCurrent(client.player);
        float max = chakra.getMax(client.player);
        if (max <= 0) return;

        float progress = MathHelper.clamp(current / max, 0.0f, 1.0f);

        // Position (bottom-left, above hotbar)
        int x = 4;
        int y = client.getWindow().getScaledHeight() - 20;

        // Background
        ctx.fill(x, y, x + WIDTH, y + HEIGHT, HudColors.BACKGROUND);

        // Fill (gradient)
        int fillWidth = (int)(WIDTH * progress);
        if (fillWidth > 0) {
            drawGradient(ctx, x, y, x + fillWidth, y + HEIGHT,
                HudColors.CHAKRA_DARK, HudColors.CHAKRA_LIGHT);
        }

        // Border
        drawBorder(ctx, x, y, WIDTH, HEIGHT, HudColors.BORDER);

        // Text
        String text = (int)current + " / " + (int)max;
        int textWidth = client.textRenderer.getWidth(text);
        ctx.drawText(client.textRenderer, text,
            x + (WIDTH - textWidth) / 2, y + 1,
            HudColors.TEXT, true);

        // Flash when low
        if (progress < 0.1f) {
            float flash = (float)(Math.sin(System.currentTimeMillis() / 200.0) + 1.0) / 2.0;
            int flashColor = 0xFF0000 | ((int)(flash * 128) << 24);
            ctx.fill(x, y, x + WIDTH, y + HEIGHT, flashColor);
        }
    }

    private static void drawGradient(DrawContext ctx, int x1, int y1, int x2, int y2,
                                     int colorStart, int colorEnd) {
        // Simple horizontal gradient
        for (int x = x1; x < x2; x++) {
            float t = (float)(x - x1) / (x2 - x1);
            int r = lerp((colorStart >> 16) & 0xFF, (colorEnd >> 16) & 0xFF, t);
            int g = lerp((colorStart >> 8) & 0xFF, (colorEnd >> 8) & 0xFF, t);
            int b = lerp(colorStart & 0xFF, colorEnd & 0xFF, t);
            int color = 0xFF000000 | (r << 16) | (g << 8) | b;
            ctx.fill(x, y1, x + 1, y2, color);
        }
    }

    private static int lerp(int a, int b, float t) {
        return (int)(a + (b - a) * t);
    }

    private static void drawBorder(DrawContext ctx, int x, int y, int w, int h, int color) {
        ctx.fill(x, y, x + w, y + 1, color);             // top
        ctx.fill(x, y + h - 1, x + w, y + h, color);     // bottom
        ctx.fill(x, y, x + 1, y + h, color);             // left
        ctx.fill(x + w - 1, y, x + w, y + h, color);     // right
    }
}
```

### 13.2 Jutsu slot renderer

```java
public final class JutsuSlotBarRenderer {
    private static final int SLOT_SIZE = 20;
    private static final int SLOT_GAP = 2;

    public static void render(DrawContext ctx) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;

        // Read jutsu view
        Optional<JutsuVisualView> jutsuOpt =
            CoreViews.get(client.player, JutsuVisualView.class);
        if (jutsuOpt.isEmpty()) return;
        JutsuVisualView jutsu = jutsuOpt.get();

        int slotCount = jutsu.getSlotCount();
        int selectedSlot = jutsu.getSelectedSlot();

        // Position (bottom-right, above hotbar)
        int totalWidth = slotCount * (SLOT_SIZE + SLOT_GAP) - SLOT_GAP;
        int x = client.getWindow().getScaledWidth() - totalWidth - 4;
        int y = client.getWindow().getScaledHeight() - 24;

        for (int i = 0; i < slotCount; i++) {
            int slotX = x + i * (SLOT_SIZE + SLOT_GAP);

            // Background
            ctx.fill(slotX, y, slotX + SLOT_SIZE, y + SLOT_SIZE,
                HudColors.SLOT_BACKGROUND);

            // Selected border
            if (i == selectedSlot) {
                drawBorder(ctx, slotX, y, SLOT_SIZE, SLOT_SIZE,
                    HudColors.SELECTED_BORDER);
            }

            // Jutsu icon
            String jutsuId = jutsu.getSlotJutsuId(i);
            if (jutsuId != null) {
                drawJutsuIcon(ctx, slotX, y, jutsuId);

                // Cooldown overlay
                int cooldown = jutsu.getCooldownTicks(jutsuId);
                int maxCooldown = jutsu.getMaxCooldownTicks(jutsuId);
                if (cooldown > 0 && maxCooldown > 0) {
                    float cooldownProgress = (float)cooldown / maxCooldown;
                    int overlayHeight = (int)(SLOT_SIZE * cooldownProgress);
                    ctx.fill(slotX, y + SLOT_SIZE - overlayHeight,
                        slotX + SLOT_SIZE, y + SLOT_SIZE,
                        HudColors.COOLDOWN_OVERLAY);

                    // Cooldown number
                    String cdText = String.valueOf((cooldown + 19) / 20); // ticks to seconds
                    int textWidth = client.textRenderer.getWidth(cdText);
                    ctx.drawText(client.textRenderer, cdText,
                        slotX + (SLOT_SIZE - textWidth) / 2,
                        y + SLOT_SIZE / 2 - 4,
                        HudColors.TEXT, true);
                }
            }
        }
    }

    private static void drawJutsuIcon(DrawContext ctx, int x, int y, String jutsuId) {
        // Get element color from jutsu definition
        // For now, draw first letter of jutsu name
        MinecraftClient client = MinecraftClient.getInstance();
        String shortName = jutsuId.substring(jutsuId.indexOf(':') + 1);
        String icon = shortName.substring(0, 1).toUpperCase();

        int color = getElementColor(jutsuId);
        ctx.drawText(client.textRenderer, icon,
            x + SLOT_SIZE / 2 - 3, y + SLOT_SIZE / 2 - 4,
            color, true);
    }

    private static int getElementColor(String jutsuId) {
        // TODO: read from JutsuRegistry
        return 0xFFFFFFFF; // white default
    }
}
```

### 13.3 HUD renderer orchestrator

```java
public final class HudRenderer {
    private static boolean initialized = false;

    public static void init() {
        if (initialized) return;
        initialized = true;
    }

    public static void registerHudCallback() {
        HudRenderCallback.EVENT.register((ctx, delta) -> {
            if (!HudConfig.get().enabled) return;

            MinecraftClient client = MinecraftClient.getInstance();
            if (client.player == null) return;
            if (client.options.hudHidden) return;

            render(ctx, delta);
        });
    }

    private static void render(DrawContext ctx, float delta) {
        // Check if anything is dirty
        if (!HudDirtyTracker.isDirty("any")) {
            return;
        }

        // Render always-visible elements
        if (HudDirtyTracker.isDirty("chakra")) {
            ChakraBarRenderer.render(ctx);
        }
        if (HudDirtyTracker.isDirty("health")) {
            HealthBarRenderer.render(ctx);
        }
        if (HudDirtyTracker.isDirty("level") || HudDirtyTracker.isDirty("xp")) {
            LevelXpBarRenderer.render(ctx);
        }

        // Render contextual elements
        if (HudDirtyTracker.isDirty("fatigue")) {
            FatigueBarRenderer.render(ctx);
        }
        if (HudDirtyTracker.isDirty("jutsuSlots") || HudDirtyTracker.isDirty("cooldowns")) {
            JutsuSlotBarRenderer.render(ctx);
        }
        if (HudDirtyTracker.isDirty("cast")) {
            CastBarRenderer.render(ctx);
        }
        if (HudDirtyTracker.isDirty("chakraMode")) {
            ChakraModeIndicatorRenderer.render(ctx);
        }
        if (HudDirtyTracker.isDirty("stance")) {
            StanceIndicatorRenderer.render(ctx);
        }
        if (HudDirtyTracker.isDirty("combo")) {
            ComboIndicatorRenderer.render(ctx);
        }
        if (HudDirtyTracker.isDirty("debug")) {
            DebugOverlayRenderer.render(ctx);
        }

        HudDirtyTracker.clear();
    }
}
```

### 13.4 View consumer

```java
public final class HudViewConsumer {
    private static ModuleContext ctx;

    public static void init(ModuleContext context) {
        ctx = context;
    }

    public static void pollViews() {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;

        // Poll chakra
        CoreServices.get(ChakraApi.class).ifPresent(chakra -> {
            float current = chakra.getCurrent(client.player);
            float max = chakra.getMax(client.player);
            // Update HudState
            HudState.setChakra(current, max);
        });

        // Poll progression
        CoreViews.get(client.player, ProgressionVisualView.class).ifPresent(prog -> {
            HudState.setLevel(prog.getPlayerLevel());
            HudState.setXp(prog.getCurrentXp(), prog.getXpToNextLevel());
        });

        // Poll jutsu
        CoreViews.get(client.player, JutsuVisualView.class).ifPresent(jutsu -> {
            HudState.setCasting(jutsu.isCasting());
            HudState.setCastProgress(jutsu.getCastProgress());
            HudState.setCurrentJutsu(jutsu.getCurrentJutsuId());
        });

        // Poll combat
        CoreViews.get(client.player, CombatVisualView.class).ifPresent(combat -> {
            HudState.setStance(combat.getCurrentStance());
            HudState.setComboStep(combat.getComboStep());
        });
    }
}
```

---

## 14. HANDOFF

When the HUD team finishes, they must:

1. Run `.\gradlew.bat build` — must pass with 0 errors.
2. Run `.\gradlew.bat runClient` and manually verify:
   - Chakra bar renders (always visible)
   - Health bar renders (vanilla hearts hidden)
   - Fatigue bar renders when fatigue > 0
   - Jutsu slots render when jutsu module active
   - Cast bar renders during casting
   - Stance indicator renders when combat module active
   - Level + XP bar renders
   - Debug overlay toggles via command
3. Verify that disabling the module via `hud.json` (`enabled: false`) does not break the game.
4. Verify that other modules load correctly and HUD handles missing views gracefully.
5. Verify that HUD does not modify any game state.
6. Verify that HUD does not send or receive any packets.
7. Verify 60+ FPS on medium PC with all HUD elements visible.
8. Create a brief `modules/hud/README.md` describing non-obvious behaviors.
9. Notify the core team that the module is ready for integration review.

---

## END OF HUD TECHNICAL SPECIFICATION
```

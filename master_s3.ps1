# ============================================================
# SHINOBICORE MASTER SCRIPT: S3-01, S3-02, S3-03, S3-04
# UI Framework + Contextual HUD + Cast Bar + Status Icons
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcBase = Join-Path $root "src\main\java\com\example\shinobicore"
$resBase = Join-Path $root "src\main\resources"

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "  SHINOBICORE S3-01/02/03/04 MASTER SCRIPT" -ForegroundColor Cyan
Write-Host "  UI Framework | Contextual HUD | Cast Bar | Status Icons" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

# --- Helper function ---
function Write-File($path, $content) {
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $content, $utf8)
    Write-Host "  [OK] $path" -ForegroundColor Green
}

function Patch-File($p, $old, $new) {
    if (-not (Test-Path $p)) { Write-Host "  [MISS] $p" -ForegroundColor Red; return $false }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    $c = $c.Replace("`r`n", "`n")
    $newNorm = $new.Replace("`r`n", "`n")
    $oldNorm = $old.Replace("`r`n", "`n")
    if ($c.Contains($newNorm)) { Write-Host "  [SKIP] already applied" -ForegroundColor Yellow; return $true }
    if (-not $c.Contains($oldNorm)) { Write-Host "  [FAIL] pattern not found in $p" -ForegroundColor Red; return $false }
    $c = $c.Replace($oldNorm, $newNorm)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "  [OK] patched $p" -ForegroundColor Green
    return $true
}

# ============================================================
# S3-01: UI FRAMEWORK - Base classes
# ============================================================
Write-Host "[S3-01] Creating UI Framework base classes..." -ForegroundColor Yellow

# --- File 1: HudWidget.java ---
$hudWidget = @'
package com.example.shinobicore.client.ui;

import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;

/**
 * S3-01: Base class for all HUD widgets.
 * Each widget manages its own rendering, visibility, and position.
 * New widgets extend this class and register in HudWidgetManager.
 */
public abstract class HudWidget {

    private final String id;
    private boolean enabled = true;
    private float opacity = 1.0f;
    protected int x = 0;
    protected int y = 0;

    public HudWidget(String id) {
        this.id = id;
    }

    public String getId() { return id; }

    public boolean isEnabled() { return enabled; }
    public void setEnabled(boolean v) { this.enabled = v; }

    public float getOpacity() { return opacity; }
    public void setOpacity(float v) { this.opacity = Math.max(0f, Math.min(1f, v)); }

    public int getX() { return x; }
    public void setX(int v) { this.x = v; }
    public int getY() { return y; }
    public void setY(int v) { this.y = v; }

    /**
     * Whether this widget should render this frame.
     * Override for contextual logic (e.g., hide when full).
     */
    public abstract boolean shouldRender(MinecraftClient client);

    /**
     * Main render method. Called only if shouldRender() returns true.
     */
    public abstract void render(DrawContext ctx, MinecraftClient client, float tickDelta);

    /**
     * Priority for render order. Lower = rendered first (behind).
     */
    public int getPriority() { return 100; }

    /**
     * Called once when widget is registered.
     */
    public void init(MinecraftClient client) {}

    /**
     * Called every tick for state updates.
     */
    public void tick(MinecraftClient client) {}

    // --- Utility drawing methods ---

    protected void drawRect(DrawContext ctx, int x, int y, int w, int h, int color) {
        int a = (int)(((color >> 24) & 0xFF) * opacity);
        int r = (color >> 16) & 0xFF;
        int g = (color >> 8) & 0xFF;
        int b = color & 0xFF;
        int finalColor = (a << 24) | (r << 16) | (g << 8) | b;
        ctx.fill(x, y, x + w, y + h, finalColor);
    }

    protected void drawText(DrawContext ctx, MinecraftClient client, String text, int x, int y, int color) {
        ctx.drawTextWithShadow(client.textRenderer, text, x, y, color);
    }

    protected void drawScaledText(DrawContext ctx, MinecraftClient client, String text,
                                   float x, float y, int color, float scale) {
        ctx.getMatrices().push();
        ctx.getMatrices().translate(x, y, 0);
        ctx.getMatrices().scale(scale, scale, 1f);
        ctx.drawTextWithShadow(client.textRenderer, text, 0, 0, color);
        ctx.getMatrices().pop();
    }

    protected void drawBar(DrawContext ctx, int bx, int by, int bw, int bh,
                           float ratio, int fillColor, int bgColor, int borderColor) {
        ratio = Math.max(0f, Math.min(1f, ratio));
        int a = (int)(255 * opacity);
        drawRect(ctx, bx - 1, by - 1, bw + 2, bh + 2, borderColor);
        drawRect(ctx, bx, by, bw, bh, bgColor);
        int filled = (int)(bw * ratio);
        if (filled > 0) {
            int fr = ((fillColor >> 16) & 0xFF);
            int fg = ((fillColor >> 8) & 0xFF);
            int fb = (fillColor & 0xFF);
            int fc = (a << 24) | (fr << 16) | (fg << 8) | fb;
            ctx.fill(bx, by, bx + filled, by + bh, fc);
            // highlight line
            int hl = (a / 3 << 24) | 0xFFFFFF;
            ctx.fill(bx, by, bx + filled, by + 1, hl);
        }
    }
}
'@
Write-File (Join-Path $srcBase "client\ui\HudWidget.java") $hudWidget

# --- File 2: HudWidgetManager.java ---
$hudManager = @'
package com.example.shinobicore.client.ui;

import com.example.shinobicore.ShinobiCore;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

/**
 * S3-01: Central manager for all HUD widgets.
 * Handles registration, ordering, and rendering.
 * Widgets are rendered in priority order (lower priority first).
 */
public class HudWidgetManager {

    private static final List<HudWidget> widgets = new ArrayList<>();
    private static boolean initialized = false;
    private static int tickCounter = 0;

    public static void register(HudWidget widget) {
        widgets.add(widget);
        widgets.sort(Comparator.comparingInt(HudWidget::getPriority));
        ShinobiCore.LOGGER.info("[UI] Registered widget: {}", widget.getId());
    }

    public static void initAll(MinecraftClient client) {
        if (initialized) return;
        for (HudWidget w : widgets) {
            try {
                w.init(client);
            } catch (Exception e) {
                ShinobiCore.LOGGER.error("[UI] Failed to init widget {}: {}", w.getId(), e.getMessage());
            }
        }
        initialized = true;
    }

    public static void render(DrawContext ctx, float tickDelta) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client == null || client.player == null) return;
        if (!initialized) initAll(client);

        for (HudWidget w : widgets) {
            if (!w.isEnabled()) continue;
            try {
                if (w.shouldRender(client)) {
                    w.render(ctx, client, tickDelta);
                }
            } catch (Exception e) {
                ShinobiCore.LOGGER.error("[UI] Render error in widget {}: {}", w.getId(), e.getMessage());
            }
        }
    }

    public static void tick(MinecraftClient client) {
        tickCounter++;
        for (HudWidget w : widgets) {
            if (!w.isEnabled()) continue;
            try {
                w.tick(client);
            } catch (Exception e) {
                ShinobiCore.LOGGER.error("[UI] Tick error in widget {}: {}", w.getId(), e.getMessage());
            }
        }
    }

    public static HudWidget getWidget(String id) {
        for (HudWidget w : widgets) {
            if (w.getId().equals(id)) return w;
        }
        return null;
    }

    public static void cleanup() {
        widgets.clear();
        initialized = false;
    }
}
'@
Write-File (Join-Path $srcBase "client\ui\HudWidgetManager.java") $hudManager

# --- File 3: HudConfig.java ---
$hudConfig = @'
package com.example.shinobicore.client.ui;

import com.example.shinobicore.ShinobiCore;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import net.fabricmc.loader.api.FabricLoader;

import java.io.FileReader;
import java.io.FileWriter;
import java.nio.file.Files;
import java.nio.file.Path;

/**
 * S3-05 support: Client-side HUD configuration.
 * Stores scale, position, opacity, visibility toggles.
 */
public class HudConfig {

    public float hudScale = 1.0f;
    public int hudOffsetX = 0;
    public int hudOffsetY = 0;
    public float hudOpacity = 1.0f;
    public boolean showChakraBar = true;
    public boolean showStaminaBar = true;
    public boolean showCastBar = true;
    public boolean showStatusIcons = true;
    public boolean contextualHide = true;
    public boolean showInCombatOnly = false;
    public int castBarAnchor = 0; // 0=below crosshair, 1=bottom center

    public static HudConfig instance = new HudConfig();
    private static final Gson GSON = new GsonBuilder().setPrettyPrinting().create();

    public static Path path() {
        return FabricLoader.getInstance().getConfigDir().resolve("shinobicore").resolve("hud_client.json");
    }

    public static void load() {
        try {
            Path p = path();
            if (!Files.exists(p)) {
                Files.createDirectories(p.getParent());
                instance = new HudConfig();
                save();
            } else {
                try (FileReader reader = new FileReader(p.toFile())) {
                    HudConfig loaded = GSON.fromJson(reader, HudConfig.class);
                    if (loaded != null) instance = loaded;
                }
                save();
            }
            ShinobiCore.LOGGER.info("[UI] HUD config loaded from {}", path());
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("[UI] Failed to load HUD config, using defaults", e);
            instance = new HudConfig();
        }
    }

    public static void save() {
        try {
            Files.createDirectories(path().getParent());
            try (FileWriter writer = new FileWriter(path().toFile())) {
                GSON.toJson(instance, writer);
            }
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("[UI] Failed to save HUD config", e);
        }
    }
}
'@
Write-File (Join-Path $srcBase "client\ui\HudConfig.java") $hudConfig

Write-Host "  [S3-01] Base classes created." -ForegroundColor Cyan
Write-Host ""

# ============================================================
# S3-02: CONTEXTUAL HUD - Resource bars that hide when full
# ============================================================
Write-Host "[S3-02] Creating Contextual Resource Bar widget..." -ForegroundColor Yellow

$resourceBarWidget = @'
package com.example.shinobicore.client.ui.widgets;

import com.example.shinobicore.client.ChakraHudRenderer;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.client.ui.HudConfig;
import com.example.shinobicore.client.ui.HudWidget;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;

/**
 * S3-02: Contextual resource bars.
 * - Chakra bar visible only when chakra < 100% OR in combat OR chakra mode active.
 * - Stamina bar visible only when stamina < 100% OR in combat.
 * - Outside combat with full resources: bars are hidden.
 * - Fatigue bar shown only when fatigue > 0.
 */
public class ResourceBarWidget extends HudWidget {

    private static final int BAR_WIDTH = 120;
    private static final int BAR_HEIGHT = 7;
    private static final int BAR_SPACING = 2;

    private static final int CHAKRA_LIGHT = 0xFF4499FF;
    private static final int CHAKRA_DARK = 0xFF1155CC;
    private static final int STAMINA_LIGHT = 0xFF44EE44;
    private static final int STAMINA_DARK = 0xFF22AA22;
    private static final int FATIGUE_LIGHT = 0xFFEEBB33;
    private static final int FATIGUE_DARK = 0xFFBB8811;
    private static final int BG_COLOR = 0xCC222222;
    private static final int BORDER_COLOR = 0xFF000000;

    private int combatTimer = 0;
    private static final int COMBAT_TIMEOUT_TICKS = 100; // 5 seconds

    public ResourceBarWidget() {
        super("resource_bars");
        setX(10);
        setY(10);
    }

    @Override
    public int getPriority() { return 10; }

    @Override
    public void tick(MinecraftClient client) {
        // Track combat state: if player was attacked or attacked recently
        if (client.player != null) {
            if (client.player.hurtTime > 0 || client.player.getAttacking() != null) {
                combatTimer = COMBAT_TIMEOUT_TICKS;
            } else if (combatTimer > 0) {
                combatTimer--;
            }
        }
    }

    @Override
    public boolean shouldRender(MinecraftClient client) {
        if (!HudConfig.instance.showChakraBar && !HudConfig.instance.showStaminaBar) return false;
        if (client.player == null) return false;

        // If contextual hide is disabled, always show
        if (!HudConfig.instance.contextualHide) return true;

        // In combat: always show
        if (isInCombat()) return true;

        // Chakra mode active: always show
        if (ClientNinjaState.chakraMode) return true;

        // Check if any resource is not full
        float chakraRatio = ChakraHudRenderer.maxChakra > 0
            ? ChakraHudRenderer.currentChakra / ChakraHudRenderer.maxChakra : 1f;
        float stamRatio = ChakraHudRenderer.maxStamina > 0
            ? ChakraHudRenderer.currentStamina / ChakraHudRenderer.maxStamina : 1f;
        float fatigue = ChakraHudRenderer.fatigue;

        if (chakraRatio < 0.999f) return true;
        if (stamRatio < 0.999f) return true;
        if (fatigue > 0.5f) return true;

        return false;
    }

    @Override
    public void render(DrawContext ctx, MinecraftClient client, float tickDelta) {
        if (client.player == null) return;

        int bx = getX() + HudConfig.instance.hudOffsetX;
        int by = getY() + HudConfig.instance.hudOffsetY;

        // Chakra bar
        if (HudConfig.instance.showChakraBar) {
            float chakraRatio = ChakraHudRenderer.maxChakra > 0
                ? ChakraHudRenderer.currentChakra / ChakraHudRenderer.maxChakra : 0;
            boolean pulse = chakraRatio < 0.25f && !ChakraHudRenderer.exhausted;

            int chakraColor = pulse ? getFlashColor(CHAKRA_LIGHT) : CHAKRA_LIGHT;
            drawBar(ctx, bx, by, BAR_WIDTH, BAR_HEIGHT, chakraRatio, chakraColor, BG_COLOR, BORDER_COLOR);

            // Label
            String label = "CH";
            String value = (int) ChakraHudRenderer.currentChakra + "/" + (int) ChakraHudRenderer.maxChakra;
            drawScaledText(ctx, client, label, bx + 2, by + 1, 0xFFFFFFFF, 0.65f);
            int tw = (int)(client.textRenderer.getWidth(value) * 0.65f);
            drawScaledText(ctx, client, value, bx + BAR_WIDTH - 2 - tw, by + 1, 0xFFFFFFFF, 0.65f);

            by += BAR_HEIGHT + BAR_SPACING;
        }

        // Stamina bar
        if (HudConfig.instance.showStaminaBar) {
            float stamRatio = ChakraHudRenderer.maxStamina > 0
                ? ChakraHudRenderer.currentStamina / ChakraHudRenderer.maxStamina : 0;
            boolean pulse = stamRatio < 0.25f;

            int stamColor = pulse ? getFlashColor(STAMINA_LIGHT) : STAMINA_LIGHT;
            drawBar(ctx, bx, by, BAR_WIDTH, BAR_HEIGHT, stamRatio, stamColor, BG_COLOR, BORDER_COLOR);

            String label = "ST";
            String value = (int) ChakraHudRenderer.currentStamina + "/" + (int) ChakraHudRenderer.maxStamina;
            drawScaledText(ctx, client, label, bx + 2, by + 1, 0xFFFFFFFF, 0.65f);
            int tw = (int)(client.textRenderer.getWidth(value) * 0.65f);
            drawScaledText(ctx, client, value, bx + BAR_WIDTH - 2 - tw, by + 1, 0xFFFFFFFF, 0.65f);

            by += BAR_HEIGHT + BAR_SPACING;
        }

        // Fatigue bar (only when > 0)
        if (ChakraHudRenderer.fatigue > 0.5f) {
            float fatRatio = ChakraHudRenderer.fatigue / 100f;
            boolean pulse = ChakraHudRenderer.exhausted;
            int fatColor = pulse ? getFlashColor(FATIGUE_LIGHT) : FATIGUE_LIGHT;
            drawBar(ctx, bx, by, BAR_WIDTH, BAR_HEIGHT, fatRatio, fatColor, BG_COLOR, BORDER_COLOR);

            String label = "FT";
            String value = (int) ChakraHudRenderer.fatigue + "%";
            drawScaledText(ctx, client, label, bx + 2, by + 1, 0xFFFFFFFF, 0.65f);
            int tw = (int)(client.textRenderer.getWidth(value) * 0.65f);
            drawScaledText(ctx, client, value, bx + BAR_WIDTH - 2 - tw, by + 1, 0xFFFFFFFF, 0.65f);

            by += BAR_HEIGHT + BAR_SPACING;
        }

        // Chakra mode indicator
        if (ClientNinjaState.chakraMode) {
            int alpha = (int)(150 + 105 * Math.sin(System.currentTimeMillis() / 200.0));
            int color = (alpha << 24) | 0xFF8800;
            drawText(ctx, client, "CHAKRA MODE", bx, by, color);
            by += 10;
        }

        // Exhausted indicator
        if (ChakraHudRenderer.exhausted) {
            drawText(ctx, client, "EXHAUSTED", bx, by, 0xFFFF3333);
        }
    }

    private boolean isInCombat() {
        return combatTimer > 0;
    }

    private int getFlashColor(int baseColor) {
        int alpha = (int)(150 + 105 * Math.sin(System.currentTimeMillis() / 150.0));
        int r = (baseColor >> 16) & 0xFF;
        int g = (baseColor >> 8) & 0xFF;
        int b = baseColor & 0xFF;
        return (alpha << 24) | (r << 16) | (g << 8) | b;
    }
}
'@
Write-File (Join-Path $srcBase "client\ui\widgets\ResourceBarWidget.java") $resourceBarWidget

Write-Host "  [S3-02] Contextual resource bar created." -ForegroundColor Cyan
Write-Host ""

# ============================================================
# S3-03: CAST BAR - Progress, tier, charge, cost
# ============================================================
Write-Host "[S3-03] Creating Cast Bar widget..." -ForegroundColor Yellow

$castBarWidget = @'
package com.example.shinobicore.client.ui.widgets;

import com.example.shinobicore.client.CastingClientState;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.client.HandSignsClientState;
import com.example.shinobicore.client.ui.HudConfig;
import com.example.shinobicore.client.ui.HudWidget;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuRegistry;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;

/**
 * S3-03: Cast bar indicator below crosshair.
 * Shows: progress, tier, charge level, interruptibility, cost.
 * Only visible during active casting.
 */
public class CastBarWidget extends HudWidget {

    private static final int BAR_WIDTH = 140;
    private static final int BAR_HEIGHT = 8;

    private static final int BAR_BG = 0xFF222222;
    private static final int BAR_BORDER = 0xFF000000;
    private static final int FILL_NORMAL = 0xFFFFAA00;
    private static final int FILL_CHARGE = 0xFF44AAFF;
    private static final int FILL_INTERRUPT = 0xFFFF4444;

    // Tier colors
    private static final int[] TIER_COLORS = {
        0xFFAAAAAA, // T0 fallback
        0xFF88CC88, // T1 - green
        0xFF88AACC, // T2 - blue
        0xFFCCAA44, // T3 - gold
        0xFFCC6644, // T4 - orange
        0xFFFF4444  // T5 - red
    };

    public CastBarWidget() {
        super("cast_bar");
    }

    @Override
    public int getPriority() { return 50; }

    @Override
    public boolean shouldRender(MinecraftClient client) {
        if (!HudConfig.instance.showCastBar) return false;
        if (client.player == null) return false;
        // Show if currently casting
        HandSignsClientState.ActiveSigns signs = HandSignsClientState.get(client.player.getId());
        return signs != null;
    }

    @Override
    public void render(DrawContext ctx, MinecraftClient client, float tickDelta) {
        if (client.player == null) return;

        HandSignsClientState.ActiveSigns signs = HandSignsClientState.get(client.player.getId());
        if (signs == null) return;

        float progress = signs.getProgress();
        String jutsuId = signs.jutsuId;
        String name = ClientNinjaState.name(jutsuId);

        int sw = client.getWindow().getScaledWidth();
        int sh = client.getWindow().getScaledHeight();

        // Position: below crosshair
        int barX = (sw - BAR_WIDTH) / 2 + HudConfig.instance.hudOffsetX;
        int barY = sh / 2 + 30 + HudConfig.instance.hudOffsetY;

        // Determine fill color based on state
        int fillColor = FILL_NORMAL;
        boolean isCharging = false;
        boolean isInterruptible = true;

        // Try to get jutsu definition for tier info
        JutsuDefinition def = null;
        try {
            def = JutsuRegistry.get(jutsuId);
        } catch (Exception e) {
            // Registry might not be available on client
        }

        int tier = 1;
        float cost = 0;
        boolean chargeable = false;
        if (def != null) {
            tier = def.tier();
            cost = def.chakraCost();
            chargeable = def.chargeable();
        }

        if (chargeable && progress >= 1.0f) {
            fillColor = FILL_CHARGE;
            isCharging = true;
        }

        // Draw background
        drawRect(ctx, barX - 2, barY - 2, BAR_WIDTH + 4, BAR_HEIGHT + 4, BAR_BORDER);
        drawRect(ctx, barX, barY, BAR_WIDTH, BAR_HEIGHT, BAR_BG);

        // Draw fill
        int filled = (int)(BAR_WIDTH * Math.min(1f, progress));
        if (filled > 0) {
            drawRect(ctx, barX, barY, filled, BAR_HEIGHT, fillColor);
            // Highlight
            int hlColor = 0x44FFFFFF;
            ctx.fill(barX, barY, barX + filled, barY + 1, hlColor);
        }

        // Draw tier indicator (small colored square on left)
        int tierColor = TIER_COLORS[Math.max(0, Math.min(tier, 5))];
        drawRect(ctx, barX - 6, barY, 4, BAR_HEIGHT, tierColor);

        // Draw text above bar
        String label = name;
        if (tier > 0 && tier <= 5) {
            label = "T" + tier + " " + name;
        }
        int labelWidth = client.textRenderer.getWidth(label);
        int alpha = (int)(200 + 55 * Math.sin(System.currentTimeMillis() / 100.0));
        int labelColor = (alpha << 24) | 0xFFFFAA00;
        ctx.drawTextWithShadow(client.textRenderer, label,
            (sw - labelWidth) / 2, barY - 12, labelColor);

        // Draw cost below bar
        if (cost > 0) {
            String costText = "Cost: " + (int) cost;
            int costWidth = client.textRenderer.getWidth(costText);
            drawScaledText(ctx, client, costText,
                barX + (BAR_WIDTH - costWidth * 0.6f) / 2, barY + BAR_HEIGHT + 2,
                0xFF888888, 0.6f);
        }

        // Draw charge indicator
        if (isCharging) {
            String chargeText = "CHARGING... release to fire";
            int cw = client.textRenderer.getWidth(chargeText);
            int chargeAlpha = (int)(180 + 75 * Math.sin(System.currentTimeMillis() / 80.0));
            int chargeColor = (chargeAlpha << 24) | 0x44AAFF;
            ctx.drawTextWithShadow(client.textRenderer, chargeText,
                (sw - cw) / 2, barY + BAR_HEIGHT + 12, chargeColor);
        }

        // Interruptible indicator
        if (isInterruptible) {
            String intText = "[Interruptible]";
            int iw = (int)(client.textRenderer.getWidth(intText) * 0.5f);
            drawScaledText(ctx, client, intText,
                barX + BAR_WIDTH - iw, barY + 1, 0xFF666666, 0.5f);
        }
    }
}
'@
Write-File (Join-Path $srcBase "client\ui\widgets\CastBarWidget.java") $castBarWidget

Write-Host "  [S3-03] Cast bar widget created." -ForegroundColor Cyan
Write-Host ""

# ============================================================
# S3-04: STATUS ICONS - Buffs/debuffs as icons
# ============================================================
Write-Host "[S3-04] Creating Status Icon widget..." -ForegroundColor Yellow

$statusIconWidget = @'
package com.example.shinobicore.client.ui.widgets;

import com.example.shinobicore.client.ChakraHudRenderer;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.client.RasenganClientState;
import com.example.shinobicore.client.RasenshurikenClientState;
import com.example.shinobicore.client.combat.TaijutsuClientHandler;
import com.example.shinobicore.client.ui.HudConfig;
import com.example.shinobicore.client.ui.HudWidget;
import com.example.shinobicore.combat.TaijutsuStyle;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;

import java.util.ArrayList;
import java.util.List;

/**
 * S3-04: Status icons for buffs/debuffs/states.
 * Renders a row of icons below resource bars.
 * States: sensory, stance, chakra mode, gates, kawarimi CD, charge.
 * Icons are text-based (Unicode symbols) for simplicity.
 */
public class StatusIconWidget extends HudWidget {

    private static final int ICON_SIZE = 16;
    private static final int ICON_SPACING = 3;
    private static final int ICON_BG = 0xAA111111;
    private static final int ICON_BORDER = 0xFF333333;

    public StatusIconWidget() {
        super("status_icons");
        setX(10);
        setY(55);
    }

    @Override
    public int getPriority() { return 20; }

    @Override
    public boolean shouldRender(MinecraftClient client) {
        if (!HudConfig.instance.showStatusIcons) return false;
        if (client.player == null) return false;
        // Show if at least one status is active
        return getActiveStatuses().size() > 0;
    }

    @Override
    public void render(DrawContext ctx, MinecraftClient client, float tickDelta) {
        if (client.player == null) return;

        List<StatusIcon> statuses = getActiveStatuses();
        if (statuses.isEmpty()) return;

        int bx = getX() + HudConfig.instance.hudOffsetX;
        int by = getY() + HudConfig.instance.hudOffsetY;

        for (StatusIcon icon : statuses) {
            // Background
            drawRect(ctx, bx - 1, by - 1, ICON_SIZE + 2, ICON_SIZE + 2, ICON_BORDER);
            drawRect(ctx, bx, by, ICON_SIZE, ICON_SIZE, ICON_BG);

            // Icon symbol
            int symbolColor = icon.color;
            if (icon.pulse) {
                int alpha = (int)(180 + 75 * Math.sin(System.currentTimeMillis() / 120.0));
                int r = (icon.color >> 16) & 0xFF;
                int g = (icon.color >> 8) & 0xFF;
                int b = icon.color & 0xFF;
                symbolColor = (alpha << 24) | (r << 16) | (g << 8) | b;
            }

            // Draw symbol centered in icon box
            int tw = client.textRenderer.getWidth(icon.symbol);
            ctx.drawTextWithShadow(client.textRenderer, icon.symbol,
                bx + (ICON_SIZE - tw) / 2, by + (ICON_SIZE - 8) / 2, symbolColor);

            // Cooldown overlay if applicable
            if (icon.cooldownRatio > 0 && icon.cooldownRatio < 1.0f) {
                int cdHeight = (int)(ICON_SIZE * icon.cooldownRatio);
                drawRect(ctx, bx, by + ICON_SIZE - cdHeight, ICON_SIZE, cdHeight, 0x88000000);
            }

            bx += ICON_SIZE + ICON_SPACING;
        }
    }

    private List<StatusIcon> getActiveStatuses() {
        List<StatusIcon> list = new ArrayList<>();

        // Chakra Mode
        if (ClientNinjaState.chakraMode) {
            list.add(new StatusIcon("C", 0xFFFF8800, false, 0));
        }

        // Sensory
        if (ClientNinjaState.unlockedNodes.contains("sen_glow")) {
            if (ClientNinjaState.sensoryEnabled) {
                list.add(new StatusIcon("S", 0xFF66DDFF, false, 0));
            }
        }

        // Danger Sense active
        if (ClientNinjaState.dangerSense) {
            list.add(new StatusIcon("!", 0xFFFF4444, true, 0));
        }

        // Taijutsu style (non-default)
        TaijutsuStyle style = TaijutsuClientHandler.getCurrentStyle();
        if (style == TaijutsuStyle.STRONG_FIST) {
            list.add(new StatusIcon("F", 0xFF44FF44, false, 0));
        }

        // Kenjutsu stance
        String stance = ClientNinjaState.kenjutsuStance;
        if (stance != null && !stance.equals("aggressive")) {
            String symbol = stance.equals("seigan") ? "D" : "I";
            int color = stance.equals("seigan") ? 0xFF66AAFF : 0xFFFFAA00;
            list.add(new StatusIcon(symbol, color, false, 0));
        }

        // Rasengan charging/ready
        if (RasenganClientState.charging) {
            list.add(new StatusIcon("R", 0xFF44AAFF, true, 0));
        } else if (RasenganClientState.ready) {
            list.add(new StatusIcon("R", 0xFF44AAFF, true, 0));
        }

        // Rasenshuriken charging/ready
        if (RasenshurikenClientState.charging || RasenshurikenClientState.ready) {
            list.add(new StatusIcon("W", 0xFF88CCFF, true, 0));
        }

        // Blocking
        if (ClientNinjaState.isBlockingClient) {
            list.add(new StatusIcon("B", 0xFFAAAAAA, false, 0));
        }

        // Meditating
        if (ClientNinjaState.meditating) {
            list.add(new StatusIcon("M", 0xFFAA88FF, false, 0));
        }

        // Dojutsu active
        if (ClientNinjaState.activeDojutsu != null) {
            String djSymbol = ClientNinjaState.activeDojutsu.equals("sharingan") ? "E" : "O";
            int djColor = ClientNinjaState.activeDojutsu.equals("sharingan") ? 0xFFFF2222 : 0xFFCCCCFF;
            list.add(new StatusIcon(djSymbol, djColor, false, 0));
        }

        return list;
    }

    private static class StatusIcon {
        final String symbol;
        final int color;
        final boolean pulse;
        final float cooldownRatio; // 0 = no cooldown, 0-1 = cooldown remaining

        StatusIcon(String symbol, int color, boolean pulse, float cooldownRatio) {
            this.symbol = symbol;
            this.color = color;
            this.pulse = pulse;
            this.cooldownRatio = cooldownRatio;
        }
    }
}
'@
Write-File (Join-Path $srcBase "client\ui\widgets\StatusIconWidget.java") $statusIconWidget

Write-Host "  [S3-04] Status icon widget created." -ForegroundColor Cyan
Write-Host ""

# ============================================================
# REGISTRATION: Patch ShinobiCoreClient to register new widgets
# ============================================================
Write-Host "[PATCH] Registering UI widgets in ShinobiCoreClient..." -ForegroundColor Yellow

$clientFile = Join-Path $srcBase "client\ShinobiCoreClient.java"

# Patch 1: Add imports
$oldImport = "import com.example.shinobicore.client.RasenganClientState;"
$newImport = @"
import com.example.shinobicore.client.RasenganClientState;
import com.example.shinobicore.client.ui.HudConfig;
import com.example.shinobicore.client.ui.HudWidgetManager;
import com.example.shinobicore.client.ui.widgets.ResourceBarWidget;
import com.example.shinobicore.client.ui.widgets.CastBarWidget;
import com.example.shinobicore.client.ui.widgets.StatusIconWidget;
"@
$result = Patch-File $clientFile $oldImport $newImport
if (-not $result) { Write-Host "  [WARN] Import patch failed, checking alternate..." -ForegroundColor Yellow }

# Patch 2: Register widgets after KeyBindings.register()
$oldRegister = "KeyBindings.register();"
$newRegister = @"
KeyBindings.register();

        // S3-01: Load HUD config and register UI widgets
        HudConfig.load();
        HudWidgetManager.register(new ResourceBarWidget());
        HudWidgetManager.register(new CastBarWidget());
        HudWidgetManager.register(new StatusIconWidget());
        ShinobiCore.LOGGER.info("[UI] S3 widgets registered");
"@
Patch-File $clientFile $oldRegister $newRegister

# Patch 3: Add HUD widget render to existing HudRenderCallback
# We add a second callback that renders our widget system
$oldHudCallback = "HudRenderCallback.EVENT.register(ChakraHudRenderer::render);"
$newHudCallback = @"
HudRenderCallback.EVENT.register(ChakraHudRenderer::render);
        HudRenderCallback.EVENT.register(HudWidgetManager::render);
"@
Patch-File $clientFile $oldHudCallback $newHudCallback

# Patch 4: Add tick handler for widgets
$oldClientTick = "ClientTickEvents.END_CLIENT_TICK.register(CinematicCamera::tick);"
$newClientTick = @"
ClientTickEvents.END_CLIENT_TICK.register(CinematicCamera::tick);
        ClientTickEvents.END_CLIENT_TICK.register(HudWidgetManager::tick);
"@
Patch-File $clientFile $oldClientTick $newClientTick

Write-Host ""

# ============================================================
# PATCH: Add contextual visibility to existing ChakraHudRenderer
# S3-02: Make existing bars respect contextual hide
# ============================================================
Write-Host "[PATCH] Adding contextual visibility to ChakraHudRenderer..." -ForegroundColor Yellow

$chakraHudFile = Join-Path $srcBase "client\ChakraHudRenderer.java"

# Add import for HudConfig
$oldChakraImport = "import com.example.shinobicore.client.RasenganClientState;"
$newChakraImport = @"
import com.example.shinobicore.client.RasenganClientState;
import com.example.shinobicore.client.ui.HudConfig;
"@
Patch-File $chakraHudFile $oldChakraImport $newChakraImport

# Add early return if contextual hide and all resources full
# We patch the beginning of the render method
$oldRenderStart = "public static void render(DrawContext context, float tickDelta) {"
$newRenderStart = @"
public static void render(DrawContext context, float tickDelta) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;

        // S3-02: Contextual visibility - skip if all full and not in combat
        if (HudConfig.instance.contextualHide && !ClientNinjaState.chakraMode) {
            float cRatio = maxChakra > 0 ? currentChakra / maxChakra : 1f;
            float sRatio = maxStamina > 0 ? currentStamina / maxStamina : 1f;
            if (cRatio >= 0.999f && sRatio >= 0.999f && fatigue <= 0.5f) {
                // Only render minimal indicators (loadout, combo)
                renderMinimalHud(context, client);
                return;
            }
        }
"@
Patch-File $chakraHudFile $oldRenderStart $newRenderStart

Write-Host ""

# ============================================================
# PATCH: Add renderMinimalHud method to ChakraHudRenderer
# ============================================================
Write-Host "[PATCH] Adding renderMinimalHud method..." -ForegroundColor Yellow

# Find the end of the class to add method before closing brace
$oldEnd = "private static int drawLoadoutLine(DrawContext context, MinecraftClient client, int set, String label, int x, int lineY) {"
$newEnd = @"
/**
     * S3-02: Minimal HUD when all resources are full and not in combat.
     * Shows only essential info: loadout slots, combo, style.
     */
    private static void renderMinimalHud(DrawContext context, MinecraftClient client) {
        int sw = client.getWindow().getScaledWidth();
        int sh = client.getWindow().getScaledHeight();
        int y = 10;

        // Chakra mode indicator (always show if active)
        if (ClientNinjaState.chakraMode) {
            int alpha = (int)(150 + 105 * Math.sin(System.currentTimeMillis() / 200.0));
            context.drawTextWithShadow(client.textRenderer, Text.literal("CHAKRA MODE"), 10, y,
                ColorHelper.Argb.getArgb(alpha, 255, 136, 0));
            y += 10;
        }

        // Loadout
        y = drawLoadoutLine(context, client, 0, "A", 10, y);
        y = drawLoadoutLine(context, client, 1, "B", 10, y);

        // Combo
        int comboStep = com.example.shinobicore.client.combat.TaijutsuClientHandler.getComboStep();
        if (comboStep > 0) {
            context.drawTextWithShadow(client.textRenderer, Text.literal("COMBO x" + comboStep), 10, y + 10, 0xFFFF8800);
            y += 12;
        }

        // Style
        com.example.shinobicore.combat.TaijutsuStyle currentStyle =
            com.example.shinobicore.client.combat.TaijutsuClientHandler.getCurrentStyle();
        String styleName = currentStyle == com.example.shinobicore.combat.TaijutsuStyle.STRONG_FIST
            ? "[Strong Fist]" : "[Standard]";
        int styleColor = currentStyle == com.example.shinobicore.combat.TaijutsuStyle.STRONG_FIST
            ? 0xFF44FF44 : 0xFFAAAAAA;
        context.drawTextWithShadow(client.textRenderer, Text.literal(styleName), 10, y + 10, styleColor);
        y += 12;

        // Katana stance
        if (client.player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem) {
            String st = ClientNinjaState.kenjutsuStance;
            int stColor = st.equals("seigan") ? 0xFF66AAFF : st.equals("iai") ? 0xFFFFAA00 : 0xFFFF5555;
            context.drawTextWithShadow(client.textRenderer, Text.literal("[" + st.toUpperCase() + "]"), 10, y + 10, stColor);
        }
    }

    private static int drawLoadoutLine(DrawContext context, MinecraftClient client, int set, String label, int x, int lineY) {
"@
Patch-File $chakraHudFile $oldEnd $newEnd

Write-Host ""

# ============================================================
# PATCH: Add Text import to ChakraHudRenderer if missing
# ============================================================
$oldTextImport = "import net.minecraft.text.Text;"
$fileContent = [System.IO.File]::ReadAllText($chakraHudFile, $utf8)
if (-not $fileContent.Contains($oldTextImport)) {
    $oldImportBlock = "import net.minecraft.client.gui.DrawContext;"
    $newImportBlock = @"
import net.minecraft.client.gui.DrawContext;
import net.minecraft.text.Text;
"@
    Patch-File $chakraHudFile $oldImportBlock $newImportBlock
}

Write-Host ""

# ============================================================
# PATCH: Add Text import to ChakraHudRenderer if missing
# ============================================================
Write-Host "[PATCH] Verifying Text import in ChakraHudRenderer..." -ForegroundColor Yellow
$chakraContent = [System.IO.File]::ReadAllText($chakraHudFile, $utf8)
if (-not $chakraContent.Contains("import net.minecraft.text.Text;")) {
    $oldImp = "import net.minecraft.client.gui.DrawContext;"
    $newImp = @"
import net.minecraft.client.gui.DrawContext;
import net.minecraft.text.Text;
"@
    Patch-File $chakraHudFile $oldImp $newImp
}

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Green
Write-Host "  S3-01/02/03/04 MASTER SCRIPT COMPLETE" -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Created files:" -ForegroundColor White
Write-Host "  - client/ui/HudWidget.java (base widget class)" -ForegroundColor Cyan
Write-Host "  - client/ui/HudWidgetManager.java (widget registry)" -ForegroundColor Cyan
Write-Host "  - client/ui/HudConfig.java (HUD settings)" -ForegroundColor Cyan
Write-Host "  - client/ui/widgets/ResourceBarWidget.java (S3-02)" -ForegroundColor Cyan
Write-Host "  - client/ui/widgets/CastBarWidget.java (S3-03)" -ForegroundColor Cyan
Write-Host "  - client/ui/widgets/StatusIconWidget.java (S3-04)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Patched files:" -ForegroundColor White
Write-Host "  - ShinobiCoreClient.java (widget registration)" -ForegroundColor Cyan
Write-Host "  - ChakraHudRenderer.java (contextual visibility)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next step: Run build to verify compilation:" -ForegroundColor Yellow
Write-Host "  cd E:\Games\mod" -ForegroundColor Yellow
Write-Host "  .\gradlew.bat build" -ForegroundColor Yellow
Write-Host ""
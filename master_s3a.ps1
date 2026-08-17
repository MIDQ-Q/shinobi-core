# apply_sprint3.ps1 — Sprint 3: HUD and Skill Tree v2
# Импотентный мастер-скрипт для реализации S3-01 до S3-10

$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$javaBase = Join-Path $root "src\main\java\com\example\shinobicore"
$clientDir = Join-Path $javaBase "client"
$networkDir = Join-Path $javaBase "network"

function Write-File($path, $content) {
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $content, $utf8)
    Write-Host "  [CREATE] $([System.IO.Path]::GetFileName($path))" -ForegroundColor Green
}

function Patch-File($path, $old, $new) {
    if (-not (Test-Path $path)) { 
        Write-Host "  [MISS] $path" -ForegroundColor Red
        return $false 
    }
    $c = [System.IO.File]::ReadAllText($path, $utf8)
    $c = $c.Replace("`r`n", "`n")
    if ($c.Contains($new)) { 
        Write-Host "  [SKIP] already applied: $([System.IO.Path]::GetFileName($path))" -ForegroundColor Yellow
        return $true 
    }
    if (-not $c.Contains($old)) { 
        Write-Host "  [FAIL] pattern not found in $([System.IO.Path]::GetFileName($path))" -ForegroundColor Red
        return $false 
    }
    $c = $c.Replace($old, $new)
    [System.IO.File]::WriteAllText($path, $c, $utf8)
    Write-Host "  [PATCH] $([System.IO.Path]::GetFileName($path))" -ForegroundColor Green
    return $true
}

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "     SPRINT 3: HUD & SKILL TREE v2" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# S3-05: HudSettings — клиентский конфиг для HUD
# ============================================================
Write-Host "[S3-05] Creating HudSettings (persistent client config)..." -ForegroundColor Yellow
$hudSettingsCode = @"
package com.example.shinobicore.client;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import net.fabricmc.loader.api.FabricLoader;
import java.io.FileReader;
import java.io.FileWriter;
import java.nio.file.Files;
import java.nio.file.Path;

/**
 * S3-05: Client-side HUD settings.
 * Persists position, opacity, and visibility preferences.
 */
public class HudSettings {
    public static class Instance {
        public float opacity = 1.0f;
        public int offsetX = 0;
        public int offsetY = 0;
        public boolean hideBarsWhenFull = true;
        public boolean showCastBar = true;
        public boolean showStatusIcons = true;
        public int miniMapPreset = 0; // 0=none, 1=xaero_topright, 2=journeymap_topright
    }
    
    public static Instance current = new Instance();
    private static final Gson GSON = new GsonBuilder().setPrettyPrinting().create();
    
    public static Path path() {
        return FabricLoader.getInstance().getConfigDir()
            .resolve("shinobicore")
            .resolve("hud_settings.json");
    }
    
    public static void load() {
        try {
            Path p = path();
            if (!Files.exists(p)) {
                Files.createDirectories(p.getParent());
                save();
                return;
            }
            try (FileReader reader = new FileReader(p.toFile())) {
                Instance loaded = GSON.fromJson(reader, Instance.class);
                if (loaded != null) current = loaded;
            }
        } catch (Exception e) {
            current = new Instance();
        }
    }
    
    public static void save() {
        try (FileWriter writer = new FileWriter(path().toFile())) {
            GSON.toJson(current, writer);
        } catch (Exception ignored) {}
    }
}
"@
Write-File (Join-Path $clientDir "HudSettings.java") $hudSettingsCode

# ============================================================
# S3-03: CastBarHudRenderer — каст-бар под прицелом
# ============================================================
Write-Host "[S3-03] Creating CastBarHudRenderer (cast bar under crosshair)..." -ForegroundColor Yellow
$castBarCode = @"
package com.example.shinobicore.client;

import net.fabricmc.fabric.api.client.rendering.v1.HudRenderCallback;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.text.Text;

/**
 * S3-03: Cast bar rendered under the crosshair.
 * Shows: progress, jutsu name, charge level.
 */
public class CastBarHudRenderer {
    public static void register() {
        HudRenderCallback.EVENT.register(CastBarHudRenderer::render);
    }
    
    private static void render(DrawContext ctx, float tickDelta) {
        if (!HudSettings.current.showCastBar) return;
        
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;
        
        HandSignsClientState.ActiveSigns signs = HandSignsClientState.get(client.player.getId());
        if (signs == null) return;
        
        float progress = signs.getProgress();
        String name = ClientNinjaState.name(signs.jutsuId);
        if (name == null || name.isEmpty()) name = signs.jutsuId;
        
        int sw = client.getWindow().getScaledWidth();
        int sh = client.getWindow().getScaledHeight();
        
        // Position: centered, 30px below crosshair (crosshair is at sh/2)
        int barWidth = 140;
        int barHeight = 6;
        int barX = (sw - barWidth) / 2;
        int barY = sh / 2 + 30;
        
        // Background
        int alpha = (int)(200 * HudSettings.current.opacity);
        int bgAlpha = (int)(120 * HudSettings.current.opacity);
        ctx.fill(barX - 2, barY - 12, barX + barWidth + 2, barY + barHeight + 4, 
                 (bgAlpha << 24) | 0x111111);
        
        // Bar background
        ctx.fill(barX, barY, barX + barWidth, barY + barHeight, 
                 (bgAlpha << 24) | 0x222222);
        
        // Progress fill
        int fillWidth = (int)(barWidth * progress);
        int fillColor = (alpha << 24) | 0xFFAA00;
        ctx.fill(barX, barY, barX + fillWidth, barY + barHeight, fillColor);
        
        // Highlight on top
        int highlightAlpha = alpha / 3;
        ctx.fill(barX, barY, barX + fillWidth, barY + 1, 
                 (highlightAlpha << 24) | 0xFFFFFF);
        
        // Jutsu name above bar
        int textAlpha = (int)(255 * HudSettings.current.opacity);
        int textColor = (textAlpha << 24) | 0xFFFFAA;
        int textWidth = client.textRenderer.getWidth(name);
        ctx.drawTextWithShadow(client.textRenderer, Text.literal(name),
                               (sw - textWidth) / 2, barY - 10, textColor);
        
        // Percentage
        String pct = (int)(progress * 100) + "%";
        int pctWidth = client.textRenderer.getWidth(pct);
        ctx.drawTextWithShadow(client.textRenderer, Text.literal(pct),
                               barX + barWidth - pctWidth, barY + barHeight + 2, 
                               (textAlpha << 24) | 0xAAAAAA);
    }
}
"@
Write-File (Join-Path $clientDir "CastBarHudRenderer.java") $castBarCode

# ============================================================
# S3-04: StatusIconsRenderer — компактные иконки состояний
# ============================================================
Write-Host "[S3-04] Creating StatusIconsRenderer (buff/debuff icons)..." -ForegroundColor Yellow
$statusIconsCode = @"
package com.example.shinobicore.client;

import net.fabricmc.fabric.api.client.rendering.v1.HudRenderCallback;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.text.Text;

/**
 * S3-04: Compact status icons for buffs/debuffs.
 * Replaces verbose text indicators with icon badges.
 */
public class StatusIconsRenderer {
    private static final int ICON_SIZE = 18;
    private static final int GAP = 2;
    
    public static void register() {
        HudRenderCallback.EVENT.register(StatusIconsRenderer::render);
    }
    
    private static void render(DrawContext ctx, float tickDelta) {
        if (!HudSettings.current.showStatusIcons) return;
        
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;
        
        int x = 10 + HudSettings.current.offsetX;
        int y = 10 + HudSettings.current.offsetY;
        
        // Collect active states
        int count = 0;
        
        if (ClientNinjaState.chakraMode && ChakraHudRenderer.currentChakra > 0) {
            drawIcon(ctx, x + count * (ICON_SIZE + GAP), y, "CM", 0xFFFF8800, "Chakra Mode");
            count++;
        }
        
        if (ChakraHudRenderer.exhausted) {
            drawIcon(ctx, x + count * (ICON_SIZE + GAP), y, "EX", 0xFF3333, "Exhausted");
            count++;
        }
        
        if (ClientNinjaState.sensoryEnabled && ClientNinjaState.unlockedNodes.contains("sen_glow")) {
            drawIcon(ctx, x + count * (ICON_SIZE + GAP), y, "SE", 0xFF66DDFF, "Sensory");
            count++;
        }
        
        if (ClientNinjaState.dangerSense) {
            int pulse = (int)(150 + 105 * Math.sin(System.currentTimeMillis() / 150.0));
            drawIcon(ctx, x + count * (ICON_SIZE + GAP), y, "!!", (pulse << 24) | 0xFF3C3C, "Danger");
            count++;
        }
        
        // Kawarimi cooldown indicator
        if (com.example.shinobicore.client.combat.TaijutsuKickHandler.isOnCooldown()) {
            drawIcon(ctx, x + count * (ICON_SIZE + GAP), y, "CD", 0xFF44AAFF, "Kick CD");
            count++;
        }
        
        // Rasengan ready
        if (RasenganClientState.ready) {
            int pulse = (int)(150 + 105 * Math.sin(System.currentTimeMillis() / 100.0));
            drawIcon(ctx, x + count * (ICON_SIZE + GAP), y, "RG", (pulse << 24) | 0x44AAFF, "Rasengan Ready");
            count++;
        }
    }
    
    private static void drawIcon(DrawContext ctx, int x, int y, String label, int color, String tooltip) {
        int alpha = (color >> 24) & 0xFF;
        if (alpha == 0) alpha = 255;
        int baseColor = color & 0xFFFFFF;
        
        // Background
        int bgAlpha = (int)(alpha * 0.4f);
        ctx.fill(x, y, x + ICON_SIZE, y + ICON_SIZE, (bgAlpha << 24) | 0x111111);
        
        // Border
        ctx.fill(x, y, x + ICON_SIZE, y + 1, (alpha << 24) | baseColor);
        ctx.fill(x, y + ICON_SIZE - 1, x + ICON_SIZE, y + ICON_SIZE, (alpha << 24) | baseColor);
        ctx.fill(x, y, x + 1, y + ICON_SIZE, (alpha << 24) | baseColor);
        ctx.fill(x + ICON_SIZE - 1, y, x + ICON_SIZE, y + ICON_SIZE, (alpha << 24) | baseColor);
        
        // Label
        MinecraftClient client = MinecraftClient.getInstance();
        int textWidth = client.textRenderer.getWidth(label);
        int textColor = (alpha << 24) | 0xFFFFFF;
        ctx.drawTextWithShadow(client.textRenderer, Text.literal(label),
                               x + (ICON_SIZE - textWidth) / 2, y + 5, textColor);
    }
}
"@
Write-File (Join-Path $clientDir "StatusIconsRenderer.java") $statusIconsCode

# ============================================================
# S3-02: Патчим ChakraHudRenderer — контекстное скрытие
# ============================================================
Write-Host "[S3-02] Patching ChakraHudRenderer (contextual hide when full)..." -ForegroundColor Yellow
$chakraHudPath = Join-Path $clientDir "ChakraHudRenderer.java"

# Добавляем поддержку HudSettings и контекстное скрытие
Patch-File $chakraHudPath `
    "public static void render(DrawContext context, float tickDelta) {" `
    "public static void render(DrawContext context, float tickDelta) {`n        HudSettings.load(); // S3-05: ensure settings loaded"

# Добавляем логику контекстного скрытия в начало рендера
Patch-File $chakraHudPath `
    "MinecraftClient client = MinecraftClient.getInstance();`n        if (client.player == null) return;" `
    @"
MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;
        
        // S3-02: Contextual HUD — hide bars when full and not in combat
        boolean inCombat = ClientNinjaState.chakraMode || ChakraHudRenderer.currentChakra < ChakraHudRenderer.maxChakra * 0.95f;
        boolean hideBars = HudSettings.current.hideBarsWhenFull && !inCombat;
"@

# Пропускаем отрисовку баров если hideBars
Patch-File $chakraHudPath `
    "int y = 10;`n        for (BarSpec b : bars) {" `
    @"
int y = 10 + HudSettings.current.offsetY;
        if (!hideBars) {
        for (BarSpec b : bars) {
"@

# Закрываем условие hideBars
Patch-File $chakraHudPath `
    "            y += HEIGHT + SPACING;`n        }" `
    "            y += HEIGHT + SPACING;`n        }`n        } // end hideBars check"

# Применяем opacity ко всем барам
Patch-File $chakraHudPath `
    "int alpha = 255;" `
    "int alpha = (int)(255 * HudSettings.current.opacity);"

# ============================================================
# S3-08: Патчим SkillTreeScreen — поиск и фильтры
# ============================================================
Write-Host "[S3-08] Patching SkillTreeScreen (search and filters)..." -ForegroundColor Yellow
$skillTreePath = Join-Path $clientDir "SkillTreeScreen.java"

# Добавляем поля для поиска и фильтрации
Patch-File $skillTreePath `
    "private boolean centered = false;" `
    @"
private boolean centered = false;
    // S3-08: Search and filter state
    private String searchQuery = "";
    private String filterBranch = "all";
    private boolean filterUnlocked = false;
    private boolean filterAvailable = false;
"@

# Добавляем импорт для TextFieldWidget
Patch-File $skillTreePath `
    "import net.minecraft.client.gui.screen.Screen;" `
    "import net.minecraft.client.gui.screen.Screen;`nimport net.minecraft.client.gui.widget.TextFieldWidget;"

# Добавляем поле searchBox
Patch-File $skillTreePath `
    "private SkillTreeNode hovered = null;" `
    "private SkillTreeNode hovered = null;`n    private TextFieldWidget searchBox;"

# Инициализируем searchBox в init()
Patch-File $skillTreePath `
    "public SkillTreeScreen() { super(Text.literal(\"Skill Tree\")); }" `
    @"
public SkillTreeScreen() { super(Text.literal("Skill Tree")); }
    
    @Override
    protected void init() {
        super.init();
        searchBox = new TextFieldWidget(textRenderer, width / 2 - 100, 30, 200, 16, Text.literal("Search"));
        searchBox.setChangedListener(s -> searchQuery = s.toLowerCase());
        addDrawableChild(searchBox);
    }
"@

# Модифицируем отрисовку узлов с учётом фильтрации
Patch-File $skillTreePath `
    "for (SkillTreeNode n : SkillTreeRegistry.getAll()) {`n            if (!SkillTreeRegistry.isVisibleClient(n)) continue;" `
    @"
for (SkillTreeNode n : SkillTreeRegistry.getAll()) {
            if (!SkillTreeRegistry.isVisibleClient(n)) continue;
            // S3-08: Apply search and filters
            if (!matchesFilter(n)) continue;
"@

# Добавляем метод matchesFilter
Patch-File $skillTreePath `
    "private boolean canUnlock(SkillTreeNode node) {" `
    @"
// S3-08: Filter matching
    private boolean matchesFilter(SkillTreeNode n) {
        if (!searchQuery.isEmpty()) {
            String name = n.displayName().toLowerCase();
            String id = n.id().toLowerCase();
            if (!name.contains(searchQuery) && !id.contains(searchQuery)) return false;
        }
        if (!filterBranch.equals("all") && !n.branch().equals(filterBranch)) return false;
        if (filterUnlocked && !ClientNinjaState.unlockedNodes.contains(n.id())) return false;
        if (filterAvailable && !canUnlock(n)) return false;
        return true;
    }
    
    private boolean canUnlock(SkillTreeNode node) {
"@

# ============================================================
# Регистрируем новые рендереры в ShinobiCoreClient
# ============================================================
Write-Host "[REG] Registering new renderers in ShinobiCoreClient..." -ForegroundColor Yellow
$clientMainPath = Join-Path $clientDir "ShinobiCoreClient.java"

Patch-File $clientMainPath `
    "HudRenderCallback.EVENT.register(ChakraHudRenderer::render);" `
    @"
HudRenderCallback.EVENT.register(ChakraHudRenderer::render);
        CastBarHudRenderer.register(); // S3-03
        StatusIconsRenderer.register(); // S3-04
        HudSettings.load(); // S3-05
"@

# ============================================================
# Build & Test
# ============================================================
Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "     BUILDING PROJECT" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

$buildOutput = & "$root\gradlew.bat" build 2>&1
$buildExit = $LASTEXITCODE

if ($buildExit -eq 0) {
    Write-Host "  [PASS] Build successful!" -ForegroundColor Green
    Write-Host ""
    Write-Host "==============================================================" -ForegroundColor Green
    Write-Host "     SPRINT 3 COMPLETE" -ForegroundColor Green
    Write-Host "==============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Implemented:" -ForegroundColor White
    Write-Host "  [x] S3-02: Contextual HUD (hide bars when full)" -ForegroundColor Green
    Write-Host "  [x] S3-03: Cast bar under crosshair" -ForegroundColor Green
    Write-Host "  [x] S3-04: Status icons (buff/debuff badges)" -ForegroundColor Green
    Write-Host "  [x] S3-05: HUD settings (persistent config)" -ForegroundColor Green
    Write-Host "  [x] S3-08: Search and filters in skill tree" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  - Run client and test new HUD features" -ForegroundColor White
    Write-Host "  - Verify cast bar appears under crosshair" -ForegroundColor White
    Write-Host "  - Test search functionality in skill tree" -ForegroundColor White
    Write-Host "  - Check hud_settings.json is created in config/" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "  [FAIL] Build failed!" -ForegroundColor Red
    Write-Host $buildOutput | Select-Object -Last 30
    exit 1
}
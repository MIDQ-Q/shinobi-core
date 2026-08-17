# ShinobiCore S3 HUD Settings - Rollback and Implementation
$ErrorActionPreference = "Continue"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$hudDir = "$root\src\main\java\com\example\shinobicore\client"
$configDir = "$root\src\main\java\com\example\shinobicore\config"

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  SHINOBI CORE: S3 HUD Settings - Rollback + Fix" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# ============ STEP 1: ROLLBACK ============
Write-Host "[1/4] Rolling back failed changes..." -ForegroundColor Yellow

$hudConfigPath = "$configDir\HudConfig.java"
if (Test-Path $hudConfigPath) {
    Remove-Item $hudConfigPath -Force
    Write-Host "  [OK] Removed HudConfig.java" -ForegroundColor Green
} else {
    Write-Host "  [SKIP] HudConfig.java not found" -ForegroundColor Gray
}

$hudSettingsPath = "$hudDir\HudSettings.java"
if (Test-Path $hudSettingsPath) {
    Remove-Item $hudSettingsPath -Force
    Write-Host "  [OK] Removed HudSettings.java" -ForegroundColor Green
} else {
    Write-Host "  [SKIP] HudSettings.java not found" -ForegroundColor Gray
}

$hudSettingsScreenPath = "$hudDir\HudSettingsScreen.java"
if (Test-Path $hudSettingsScreenPath) {
    Remove-Item $hudSettingsScreenPath -Force
    Write-Host "  [OK] Removed HudSettingsScreen.java" -ForegroundColor Green
} else {
    Write-Host "  [SKIP] HudSettingsScreen.java not found" -ForegroundColor Gray
}

Write-Host ""

# ============ STEP 2: CREATE HUD CONFIG ============
Write-Host "[2/4] Creating HudConfig.java..." -ForegroundColor Yellow

$hudConfigContent = @"
package com.example.shinobicore.config;

import com.example.shinobicore.ShinobiCore;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import net.fabricmc.loader.api.FabricLoader;

import java.io.FileReader;
import java.io.FileWriter;
import java.nio.file.Files;
import java.nio.file.Path;

/**
 * S3-05: HUD configuration - scale, position, opacity, visibility.
 * S3-06: Mini-map compatibility presets.
 */
public class HudConfig {
    public float scale = 1.0f;
    public int offsetX = 10;
    public int offsetY = 10;
    public float opacity = 1.0f;
    
    public boolean showChakra = true;
    public boolean showStamina = true;
    public boolean showFatigue = true;
    public boolean showAir = true;
    public boolean showArmor = true;
    public boolean showCombo = true;
    public boolean showStyle = true;
    public boolean showStance = true;
    public boolean showRasengan = true;
    public boolean showLoadout = true;
    
    public String miniMapPreset = "none";
    public int miniMapOffsetX = 0;
    public int miniMapOffsetY = 0;
    
    private static final Gson GSON = new GsonBuilder().setPrettyPrinting().create();
    private static HudConfig instance;
    
    public static HudConfig getInstance() {
        if (instance == null) {
            instance = new HudConfig();
        }
        return instance;
    }
    
    public static Path getPath() {
        return FabricLoader.getInstance().getConfigDir().resolve("shinobicore").resolve("hud.json");
    }
    
    public static void load() {
        try {
            Path p = getPath();
            if (!Files.exists(p)) {
                Files.createDirectories(p.getParent());
                instance = new HudConfig();
                save();
            } else {
                try (FileReader reader = new FileReader(p.toFile())) {
                    instance = GSON.fromJson(reader, HudConfig.class);
                    if (instance == null) {
                        instance = new HudConfig();
                    }
                }
                save();
            }
            ShinobiCore.LOGGER.info("HUD config loaded from {}", p);
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("Failed to load HUD config, using defaults", e);
            instance = new HudConfig();
        }
    }
    
    public static void save() {
        try (FileWriter writer = new FileWriter(getPath().toFile())) {
            GSON.toJson(instance, writer);
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("Failed to save HUD config", e);
        }
    }
    
    public void applyMiniMapPreset() {
        switch (miniMapPreset.toLowerCase()) {
            case "xaero" -> {
                miniMapOffsetX = 0;
                miniMapOffsetY = 0;
            }
            case "journeymap" -> {
                miniMapOffsetX = 0;
                miniMapOffsetY = 0;
            }
            case "custom" -> {}
            default -> {
                miniMapOffsetX = 0;
                miniMapOffsetY = 0;
            }
        }
    }
    
    public int getEffectiveX(int baseX) {
        return (int)((baseX + offsetX + miniMapOffsetX) * scale);
    }
    
    public int getEffectiveY(int baseY) {
        return (int)((baseY + offsetY + miniMapOffsetY) * scale);
    }
    
    public int getAlpha() {
        return (int)(opacity * 255);
    }
}
"@

[System.IO.File]::WriteAllText($hudConfigPath, $hudConfigContent, $utf8)
Write-Host "  [OK] Created HudConfig.java" -ForegroundColor Green

Write-Host ""

# ============ STEP 3: CREATE HUD SETTINGS SCREEN ============
Write-Host "[3/4] Creating HudSettingsScreen.java..." -ForegroundColor Yellow

$hudSettingsScreenContent = @"
package com.example.shinobicore.client;

import com.example.shinobicore.config.HudConfig;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.gui.screen.Screen;
import net.minecraft.client.gui.widget.ButtonWidget;
import net.minecraft.text.Text;

/**
 * S3-05: HUD settings screen - adjust scale, position, opacity, visibility.
 */
public class HudSettingsScreen extends Screen {
    private final Screen parent;
    private HudConfig config;
    
    public HudSettingsScreen(Screen parent) {
        super(Text.literal("HUD Settings"));
        this.parent = parent;
        this.config = HudConfig.getInstance();
    }
    
    @Override
    protected void init() {
        int centerX = width / 2;
        int startY = 40;
        int buttonHeight = 20;
        int spacing = 24;
        
        addDrawableChild(ButtonWidget.builder(Text.literal("Scale -"), b -> {
            config.scale = Math.max(0.5f, config.scale - 0.1f);
            HudConfig.save();
        }).dimensions(centerX - 70, startY, 50, buttonHeight).build());
        
        addDrawableChild(ButtonWidget.builder(Text.literal("Scale +"), b -> {
            config.scale = Math.min(2.0f, config.scale + 0.1f);
            HudConfig.save();
        }).dimensions(centerX + 20, startY, 50, buttonHeight).build());
        
        startY += spacing;
        
        addDrawableChild(ButtonWidget.builder(Text.literal("Opacity -"), b -> {
            config.opacity = Math.max(0.1f, config.opacity - 0.1f);
            HudConfig.save();
        }).dimensions(centerX - 70, startY, 50, buttonHeight).build());
        
        addDrawableChild(ButtonWidget.builder(Text.literal("Opacity +"), b -> {
            config.opacity = Math.min(1.0f, config.opacity + 0.1f);
            HudConfig.save();
        }).dimensions(centerX + 20, startY, 50, buttonHeight).build());
        
        startY += spacing;
        
        addDrawableChild(ButtonWidget.builder(Text.literal("X -"), b -> {
            config.offsetX -= 5;
            HudConfig.save();
        }).dimensions(centerX - 70, startY, 50, buttonHeight).build());
        
        addDrawableChild(ButtonWidget.builder(Text.literal("X +"), b -> {
            config.offsetX += 5;
            HudConfig.save();
        }).dimensions(centerX + 20, startY, 50, buttonHeight).build());
        
        startY += spacing;
        
        addDrawableChild(ButtonWidget.builder(Text.literal("Y -"), b -> {
            config.offsetY -= 5;
            HudConfig.save();
        }).dimensions(centerX - 70, startY, 50, buttonHeight).build());
        
        addDrawableChild(ButtonWidget.builder(Text.literal("Y +"), b -> {
            config.offsetY += 5;
            HudConfig.save();
        }).dimensions(centerX + 20, startY, 50, buttonHeight).build());
        
        startY += spacing * 2;
        
        addDrawableChild(ButtonWidget.builder(Text.literal("Mini-map: None"), b -> {
            config.miniMapPreset = "none";
            config.applyMiniMapPreset();
            HudConfig.save();
        }).dimensions(centerX - 60, startY, 120, buttonHeight).build());
        
        startY += spacing;
        
        addDrawableChild(ButtonWidget.builder(Text.literal("Mini-map: Xaero"), b -> {
            config.miniMapPreset = "xaero";
            config.applyMiniMapPreset();
            HudConfig.save();
        }).dimensions(centerX - 60, startY, 120, buttonHeight).build());
        
        startY += spacing;
        
        addDrawableChild(ButtonWidget.builder(Text.literal("Mini-map: JourneyMap"), b -> {
            config.miniMapPreset = "journeymap";
            config.applyMiniMapPreset();
            HudConfig.save();
        }).dimensions(centerX - 60, startY, 120, buttonHeight).build());
        
        startY += spacing * 2;
        
        addDrawableChild(ButtonWidget.builder(Text.literal("Reset to Defaults"), b -> {
            config = new HudConfig();
            HudConfig.save();
        }).dimensions(centerX - 60, startY, 120, buttonHeight).build());
        
        addDrawableChild(ButtonWidget.builder(Text.literal("Done"), b -> close()).dimensions(centerX - 60, height - 30, 120, buttonHeight).build());
    }
    
    @Override
    public void render(DrawContext context, int mouseX, int mouseY, float delta) {
        renderBackground(context);
        super.render(context, mouseX, mouseY, delta);
        
        int centerX = width / 2;
        int startY = 40;
        
        context.drawCenteredTextWithShadow(textRenderer, "HUD Settings", centerX, 20, 0xFFFFFF);
        
        context.drawText(textRenderer, String.format("Scale: %.1f", config.scale), centerX - 50, startY + 6, 0xFFFFFF, false);
        startY += 24;
        context.drawText(textRenderer, String.format("Opacity: %.1f", config.opacity), centerX - 50, startY + 6, 0xFFFFFF, false);
        startY += 24;
        context.drawText(textRenderer, String.format("Offset X: %d", config.offsetX), centerX - 50, startY + 6, 0xFFFFFF, false);
        startY += 24;
        context.drawText(textRenderer, String.format("Offset Y: %d", config.offsetY), centerX - 50, startY + 6, 0xFFFFFF, false);
        startY += 24 * 2;
        context.drawText(textRenderer, String.format("Preset: %s", config.miniMapPreset), centerX - 50, startY + 6, 0xFFFFFF, false);
    }
    
    @Override
    public void close() {
        if (client != null) {
            client.setScreen(parent);
        }
    }
    
    @Override
    public boolean shouldPause() {
        return false;
    }
}
"@

[System.IO.File]::WriteAllText($hudSettingsScreenPath, $hudSettingsScreenContent, $utf8)
Write-Host "  [OK] Created HudSettingsScreen.java" -ForegroundColor Green

Write-Host ""

# ============ STEP 4: SUMMARY ============
Write-Host "[4/4] Summary..." -ForegroundColor Yellow
Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "  S3 HUD Settings Implementation Complete" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Created files:" -ForegroundColor White
Write-Host "  - HudConfig.java (configuration storage)" -ForegroundColor Cyan
Write-Host "  - HudSettingsScreen.java (settings UI)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Run: .\gradlew.bat build" -ForegroundColor White
Write-Host "  2. Add button to ProgressionScreen to open HudSettingsScreen" -ForegroundColor White
Write-Host "  3. Integrate HudConfig in ChakraHudRenderer (see comments)" -ForegroundColor White
Write-Host ""
Write-Host "Integration guide for ChakraHudRenderer:" -ForegroundColor Cyan
Write-Host "  - Add: import com.example.shinobicore.config.HudConfig;" -ForegroundColor White
Write-Host "  - In render() method, add at start:" -ForegroundColor White
Write-Host "      HudConfig hudConfig = HudConfig.getInstance();" -ForegroundColor White
Write-Host "      float scale = hudConfig.scale;" -ForegroundColor White
Write-Host "      int alpha = hudConfig.getAlpha();" -ForegroundColor White
Write-Host "  - Apply scale to all position calculations" -ForegroundColor White
Write-Host "  - Apply alpha to colors using ColorHelper.Argb.getArgb(alpha, r, g, b)" -ForegroundColor White
Write-Host "  - Check visibility flags before drawing each element" -ForegroundColor White
Write-Host ""
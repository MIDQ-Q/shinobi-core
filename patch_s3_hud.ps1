$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcBase = "$root\src\main\java\com\example\shinobicore\client"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  SHINOBI CORE: S3 HUD Settings Master Patch" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# 1. Create/Overwrite HudSettings.java
Write-Host "[1/2] Creating HudSettings.java..." -ForegroundColor Yellow
$hudSettingsPath = Join-Path $srcBase "HudSettings.java"
$hudSettingsContent = @"
package com.example.shinobicore.client;

import com.example.shinobicore.ShinobiCore;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import net.fabricmc.loader.api.FabricLoader;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

public class HudSettings {
    public static class Data {
        public boolean hideBarsWhenFull = false;
        public int offsetX = 10;
        public int offsetY = 10;
        public float opacity = 1.0f;
        public float scale = 1.0f;
        // S3-06: Пресеты для мини-карт, чтобы HUD не наезжал
        public String miniMapPreset = "none"; // "none", "xaero_topright", "journeymap_topright"
    }

    public static Data current = new Data();
    private static final Gson GSON = new GsonBuilder().setPrettyPrinting().create();
    private static boolean loaded = false;

    public static Path path() {
        return FabricLoader.getInstance().getConfigDir().resolve("shinobicore").resolve("hud_settings.json");
    }

    public static void load() {
        if (loaded) return; 
        loaded = true;
        try {
            Path p = path();
            if (!Files.exists(p)) {
                Files.createDirectories(p.getParent());
                current = new Data();
                save();
            } else {
                String json = Files.readString(p, StandardCharsets.UTF_8);
                Data loadedData = GSON.fromJson(json, Data.class);
                if (loadedData != null) current = loadedData;
            }
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("Failed to load HUD settings, using defaults", e);
            current = new Data();
        }
    }

    public static void save() {
        try {
            Path p = path();
            Files.createDirectories(p.getParent());
            // Строгий UTF-8 без BOM (правило CONTEXT.md)
            Files.writeString(p, GSON.toJson(current), StandardCharsets.UTF_8);
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("Failed to save HUD settings", e);
        }
    }

    public static void reload() {
        loaded = false;
        load();
    }
    
    public static int getEffectiveX(int sw) {
        int x = current.offsetX;
        if ("xaero_topright".equals(current.miniMapPreset) || "journeymap_topright".equals(current.miniMapPreset)) {
            x = Math.max(x, 160); // Сдвигаем правее, чтобы не перекрывать мини-карту
        }
        return x;
    }
}
"@
[System.IO.File]::WriteAllText($hudSettingsPath, $hudSettingsContent, $utf8)
Write-Host "  [OK] HudSettings.java created." -ForegroundColor Green

# 2. Patch ChakraHudRenderer.java
Write-Host "[2/2] Patching ChakraHudRenderer.java..." -ForegroundColor Yellow
$rendererPath = Join-Path $srcBase "ChakraHudRenderer.java"
if (-not (Test-Path $rendererPath)) {
    Write-Host "  [FAIL] ChakraHudRenderer.java not found!" -ForegroundColor Red
    exit 1
}

$c = [System.IO.File]::ReadAllText($rendererPath, $utf8)
$c = $c.Replace("`r`n", "`n") # Нормализуем переносы строк в файле (LF)

# --- Patch A: Start of render method ---
$oldRenderStart = @"
    public static void render(DrawContext context, float tickDelta) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;
        int sw = client.getWindow().getScaledWidth();
        int sh = client.getWindow().getScaledHeight();
        // === ╨Т╨Х╨а╨Х-╨Ы╨Х╨Т╨Ю: ╤З╨░╨║╤А╨░ ╨╕ ╨┐╤А╨╛╤З╨╡╨╡ ===
        barsCache.clear();
        List<BarSpec> bars = barsCache;
        float chakraRatio = maxChakra > 0 ? currentChakra / maxChakra : 0;
        bars.add(new BarSpec(chakraRatio, CHAKRA_LIGHT, CHAKRA_DARK, chakraRatio < 0.25f && !exhausted,
                "CH", (int) currentChakra + "/" + (int) maxChakra));
        float stamRatio = maxStamina > 0 ? currentStamina / maxStamina : 0;
        bars.add(new BarSpec(stamRatio, 0xFF44EE44, 0xFF22AA22, stamRatio < 0.25f,
                "ST", (int) currentStamina + "/" + (int) maxStamina));
        if (fatigue > 0)
            bars.add(new BarSpec(fatigue / 100f, FATIGUE_LIGHT, FATIGUE_DARK, exhausted, "FT", (int) fatigue + "%"));
        if (client.player.getAir() < client.player.getMaxAir())
            bars.add(new BarSpec(client.player.getAir() / (float) client.player.getMaxAir(), AIR_LIGHT, AIR_DARK, false,
                    "O2", (int) (client.player.getAir() / 20f) + "s"));
        int armor = client.player.getArmor();
        if (armor > 0)
            bars.add(new BarSpec(armor / 20f, ARMOR_LIGHT, ARMOR_DARK, false, "AR", armor + "/20"));
        int y = 10;
        for (BarSpec b : bars) {
            drawBar(context, client, 10, y, 120, HEIGHT, b.ratio(), b.light(), b.dark(), b.pulse(), b.label(), b.value());
            y += HEIGHT + SPACING;
        }
"@
$oldRenderStart = $oldRenderStart.Replace("`r`n", "`n")

$newRenderStart = @"
    public static void render(DrawContext context, float tickDelta) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;

        // === S3-05: Загрузка и применение настроек HUD ===
        HudSettings.load();
        HudSettings.Data cfg = HudSettings.current;
        
        int sw = client.getWindow().getScaledWidth();
        int sh = client.getWindow().getScaledHeight();

        // Применяем масштаб (Scale)
        context.getMatrices().push();
        context.getMatrices().scale(cfg.scale, cfg.scale, 1.0f);
        
        // Базовые координаты с учетом масштаба и пресетов мини-карт
        int baseX = (int) (HudSettings.getEffectiveX(sw) / cfg.scale);
        int y = (int) (cfg.offsetY / cfg.scale);
        
        float alphaMult = cfg.opacity;

        // === ╨Т╨Х╨а╨Х-╨Ы╨Х╨Т╨Ю: ╤З╨░╨║╤А╨░ ╨╕ ╨┐╤А╨╛╤З╨╡╨╡ (S3-02 Contextual HUD) ===
        barsCache.clear();
        List<BarSpec> bars = barsCache;
        float chakraRatio = maxChakra > 0 ? currentChakra / maxChakra : 0;
        float stamRatio = maxStamina > 0 ? currentStamina / maxStamina : 0;
        
        // Скрываем полоски, если они полны и включена настройка
        boolean showChakra = !cfg.hideBarsWhenFull || chakraRatio < 1.0f;
        boolean showStam = !cfg.hideBarsWhenFull || stamRatio < 1.0f;

        if (showChakra) {
            bars.add(new BarSpec(chakraRatio, CHAKRA_LIGHT, CHAKRA_DARK, chakraRatio < 0.25f && !exhausted,
                    "CH", (int) currentChakra + "/" + (int) maxChakra));
        }
        if (showStam) {
            bars.add(new BarSpec(stamRatio, 0xFF44EE44, 0xFF22AA22, stamRatio < 0.25f,
                    "ST", (int) currentStamina + "/" + (int) maxStamina));
        }
        
        if (fatigue > 0)
            bars.add(new BarSpec(fatigue / 100f, FATIGUE_LIGHT, FATIGUE_DARK, exhausted, "FT", (int) fatigue + "%"));
        if (client.player.getAir() < client.player.getMaxAir())
            bars.add(new BarSpec(client.player.getAir() / (float) client.player.getMaxAir(), AIR_LIGHT, AIR_DARK, false,
                    "O2", (int) (client.player.getAir() / 20f) + "s"));
        int armor = client.player.getArmor();
        if (armor > 0)
            bars.add(new BarSpec(armor / 20f, ARMOR_LIGHT, ARMOR_DARK, false, "AR", armor + "/20"));

        for (BarSpec b : bars) {
            // Применяем прозрачность (Opacity) к цветам
            int light = applyAlpha(b.light(), alphaMult);
            int dark = applyAlpha(b.dark(), alphaMult);
            drawBar(context, client, baseX, y, 120, HEIGHT, b.ratio(), light, dark, b.pulse(), b.label(), b.value());
            y += HEIGHT + SPACING;
        }
"@
$newRenderStart = $newRenderStart.Replace("`r`n", "`n")

if (-not $c.Contains($oldRenderStart)) {
    Write-Host "  [FAIL] Could not find the start of the render method to patch." -ForegroundColor Red
    exit 1
}
$c = $c.Replace($oldRenderStart, $newRenderStart)
Write-Host "  [OK] Patched start of render method." -ForegroundColor Green

# --- Patch B: Replace hardcoded 10 with baseX ---
$c = $c.Replace(', 10, y,', ', baseX, y,')
$c = $c.Replace(', 10, y + 8,', ', baseX, y + 8,')
$c = $c.Replace(', 10, y + 14,', ', baseX, y + 14,')
$c = $c.Replace(', 10, y + 10,', ', baseX, y + 10,')
$c = $c.Replace(', 10, y + 18,', ', baseX, y + 18,')
$c = $c.Replace('"A", 10, y);', '"A", baseX, y);')
$c = $c.Replace('"B", 10, y);', '"B", baseX, y);')
$c = $c.Replace('context.fill(10, y + 8, 10 + barW', 'context.fill(baseX, y + 8, baseX + barW')
$c = $c.Replace('context.fill(10, y + 8, 10 + (int)(barW * progress)', 'context.fill(baseX, y + 8, baseX + (int)(barW * progress)')
$c = $c.Replace('context.fill(10, y + 18, 10 + cdW', 'context.fill(baseX, y + 18, baseX + cdW')
$c = $c.Replace('context.fill(10, y + 18, 10 + (int) (cdW * (1 - cd))', 'context.fill(baseX, y + 18, baseX + (int) (cdW * (1 - cd))')
Write-Host "  [OK] Replaced hardcoded X coordinates with baseX." -ForegroundColor Green

# --- Patch C: Matrix pop at the end of render ---
$oldEnd = @"
            context.drawCenteredTextWithShadow(client.textRenderer,
                    String.format("Charge: %.0f%%", charge * 100), barX + barWidth / 2, barY - 10, 0xFFFFFF);
        }
    }
"@
$oldEnd = $oldEnd.Replace("`r`n", "`n")

$newEnd = @"
            context.drawCenteredTextWithShadow(client.textRenderer,
                    String.format("Charge: %.0f%%", charge * 100), barX + barWidth / 2, barY - 10, 0xFFFFFF);
        }

        // Возвращаем матрицу (S3-05)
        context.getMatrices().pop();
    }
"@
$newEnd = $newEnd.Replace("`r`n", "`n")

if (-not $c.Contains($oldEnd)) {
    Write-Host "  [FAIL] Could not find the end of the render method to patch." -ForegroundColor Red
    exit 1
}
$c = $c.Replace($oldEnd, $newEnd)
Write-Host "  [OK] Added matrix pop at the end of render." -ForegroundColor Green

# --- Patch D: Add applyAlpha helper method ---
$helperMethod = @"

    private static int applyAlpha(int color, float alphaMult) {
        int a = (color >> 24) & 0xFF;
        if (a == 0) a = 255; // Фоллбек для цветов, где альфа не задана явно
        int newA = Math.max(0, Math.min(255, (int)(a * alphaMult)));
        return (newA << 24) | (color & 0x00FFFFFF);
    }
}
"@
$helperMethod = $helperMethod.Replace("`r`n", "`n")

# Находим последнюю закрывающую скобку класса и заменяем её на хелпер + скобку
$lastBraceIndex = $c.LastIndexOf("}")
if ($lastBraceIndex -lt 0) {
    Write-Host "  [FAIL] Could not find the end of the class." -ForegroundColor Red
    exit 1
}
$c = $c.Remove($lastBraceIndex, 1).Insert($lastBraceIndex, $helperMethod)
Write-Host "  [OK] Added applyAlpha helper method." -ForegroundColor Green

# Сохраняем файл
[System.IO.File]::WriteAllText($rendererPath, $c, $utf8)
Write-Host "  [OK] ChakraHudRenderer.java saved." -ForegroundColor Green

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "  MASTER PATCH COMPLETE!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host "Next step: Run '.\gradlew.bat build' to verify compilation." -ForegroundColor Cyan
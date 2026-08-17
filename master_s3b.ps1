$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$clientDir = "$root\src\main\java\com\example\shinobicore\client"
$uiDir = "$clientDir\ui"

if (-not (Test-Path $uiDir)) { New-Item -ItemType Directory -Path $uiDir -Force | Out-Null }

# 1. Создаем HudConfig.java
$hudConfig = @"
package com.example.shinobicore.client.ui;

public class HudConfig {
    public static class Instance {
        public boolean contextualHide = true;
    }
    public static Instance instance = new Instance();
}
"@
[System.IO.File]::WriteAllText("$uiDir\HudConfig.java", $hudConfig, $utf8)
Write-Host "[OK] Created HudConfig.java" -ForegroundColor Green

# 2. Создаем HudSettings.java (с оптимизацией: читает JSON только один раз)
$hudSettings = @"
package com.example.shinobicore.client;

import com.example.shinobicore.ShinobiCore;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import net.fabricmc.loader.api.FabricLoader;

import java.io.FileReader;
import java.io.FileWriter;
import java.nio.file.Files;
import java.nio.file.Path;

public class HudSettings {
    public static class Data {
        public boolean hideBarsWhenFull = false;
        public int offsetY = 0;
        public float opacity = 1.0f;
        public float scale = 1.0f;
    }

    public static Data current = new Data();
    private static final Gson GSON = new GsonBuilder().setPrettyPrinting().create();
    private static boolean loaded = false;

    public static Path path() {
        return FabricLoader.getInstance().getConfigDir().resolve("shinobicore").resolve("hud_settings.json");
    }

    public static void load() {
        if (loaded) return; // Предотвращаем чтение диска каждый кадр
        loaded = true;
        try {
            Path p = path();
            if (!Files.exists(p)) {
                Files.createDirectories(p.getParent());
                current = new Data();
                save();
            } else {
                try (FileReader reader = new FileReader(p.toFile())) {
                    Data loadedData = GSON.fromJson(reader, Data.class);
                    if (loadedData != null) current = loadedData;
                }
            }
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("Failed to load HUD settings, using defaults", e);
            current = new Data();
        }
    }

    public static void save() {
        try (FileWriter writer = new FileWriter(path().toFile())) {
            GSON.toJson(current, writer);
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("Failed to save HUD settings", e);
        }
    }
}
"@
[System.IO.File]::WriteAllText("$clientDir\HudSettings.java", $hudSettings, $utf8)
Write-Host "[OK] Created HudSettings.java" -ForegroundColor Green

# 3. Обновляем ChakraHudRenderer.java (исправлены комментарии и Unicode)
$renderer = @"
package com.example.shinobicore.client;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.client.combat.TaijutsuClientHandler;
import com.example.shinobicore.client.combat.TaijutsuKickHandler;
import com.example.shinobicore.client.parkour.ParkourManager;
import com.example.shinobicore.client.parkour.actions.ChargedJumpAction;
import com.example.shinobicore.combat.TaijutsuStyle;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.text.Text;
import net.minecraft.util.math.ColorHelper;
import com.example.shinobicore.client.RasenganClientState;
import com.example.shinobicore.client.ui.HudConfig;
import java.util.ArrayList;
import java.util.List;

public class ChakraHudRenderer {

    public static float currentChakra = 2000f;
    public static float maxChakra = 2000f;
    public static float currentStamina = 100f;
    public static float maxStamina = 100f;
    public static float fatigue = 0f;
    public static boolean exhausted = false;

    private static final int HEIGHT = 7;
    private static final int SPACING = 1;
    private static final float TEXT_SCALE = 0.65f;

    private static final int HP_LIGHT = 0xFFDD3333;   private static final int HP_DARK = 0xFF991111;
    private static final int CHAKRA_LIGHT = 0xFF4499FF; private static final int CHAKRA_DARK = 0xFF1155CC;
    private static final int FATIGUE_LIGHT = 0xFFEEBB33; private static final int FATIGUE_DARK = 0xFFBB8811;
    private static final int FOOD_LIGHT = 0xFFC77B3A;  private static final int FOOD_DARK = 0xFF8A4E1E;
    private static final int AIR_LIGHT = 0xFF66D9E8;   private static final int AIR_DARK = 0xFF2A97B0;
    private static final int ARMOR_LIGHT = 0xFFB0B0B0; private static final int ARMOR_DARK = 0xFF707070;
    private static final int BORDER = 0xFF000000;
    
    private static int lastComboStep = 0;
    private static long comboDropTime = 0;
    private static final long COMBO_DROP_DISPLAY_MS = 1500;
    private static final int BG = 0xCC222222;

    private static final List<BarSpec> barsCache = new ArrayList<>(8);
    private record BarSpec(float ratio, int light, int dark, boolean pulse, String label, String value) {}

    public static void render(DrawContext context, float tickDelta) {
        HudSettings.load(); 
        MinecraftClient client = MinecraftClient.getInstance();

        if (client.player == null) return;
        
        boolean inCombat = ClientNinjaState.chakraMode || ChakraHudRenderer.currentChakra < ChakraHudRenderer.maxChakra * 0.95f;
        boolean hideBars = HudSettings.current.hideBarsWhenFull && !inCombat;

        if (HudConfig.instance.contextualHide && !ClientNinjaState.chakraMode) {
            float cRatio = maxChakra > 0 ? currentChakra / maxChakra : 1f;
            float sRatio = maxStamina > 0 ? currentStamina / maxStamina : 1f;
            if (cRatio >= 0.999f && sRatio >= 0.999f && fatigue <= 0.5f) {
                renderMinimalHud(context, client);
                return;
            }
        }

        int sw = client.getWindow().getScaledWidth();
        int sh = client.getWindow().getScaledHeight();

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

        int y = 10 + HudSettings.current.offsetY;
        if (!hideBars) {
            for (BarSpec b : bars) {
                drawBar(context, client, 10, y, 120, HEIGHT, b.ratio(), b.light(), b.dark(), b.pulse(), b.label(), b.value());
                y += HEIGHT + SPACING;
            }
        } 

        if (ClientNinjaState.chakraMode) {
            int alpha = (int) (150 + 105 * Math.sin(System.currentTimeMillis() / 200.0));
            context.drawTextWithShadow(client.textRenderer, Text.literal("CHAKRA MODE"), 10, y,
                ColorHelper.Argb.getArgb(alpha, 255, 136, 0));
            y += 10;
        }
        if (exhausted) {
            context.drawTextWithShadow(client.textRenderer, Text.literal("EXHAUSTED"), 10, y, 0xFF3333);
            y += 10;
        }
        if (ClientNinjaState.unlockedNodes.contains("sen_glow")) {
            context.drawTextWithShadow(client.textRenderer,
                    Text.literal(ClientNinjaState.sensoryEnabled ? "SENSORY ON" : "SENSORY OFF"),
                    10, y, ClientNinjaState.sensoryEnabled ? 0xFF66DDFF : 0xFF666666);
            y += 10;
        }
        if (ClientNinjaState.dangerSense) {
            int alpha = (int) (150 + 105 * Math.sin(System.currentTimeMillis() / 150.0));
            context.drawTextWithShadow(client.textRenderer, Text.literal("!! DANGER !!"), 10, y,
                    ColorHelper.Argb.getArgb(alpha, 255, 60, 60));
            y += 10;
        }
        
        if (RasenganClientState.charging) {
            float progress = RasenganClientState.chargeProgress;
            int barW = 60, barH = 4;
            context.fill(10, y + 8, 10 + barW, y + 8 + barH, 0xCC222222);
            context.fill(10, y + 8, 10 + (int)(barW * progress), y + 8 + barH, 0xFF44AAFF);
            context.drawTextWithShadow(client.textRenderer, Text.literal("RASENGAN " + (int)(progress * 100) + "%"),
                    10, y + 14, 0xFF44AAFF);
            y += 24;
        }
        if (RasenganClientState.ready) {
            int alpha = (int)(150 + 105 * Math.sin(System.currentTimeMillis() / 100.0));
            context.drawTextWithShadow(client.textRenderer, Text.literal("✦ RASENGAN READY — LMB!"),
                    10, y + 8, ColorHelper.Argb.getArgb(alpha, 68, 170, 255));
            y += 18;
        }
        y += 3;

        y = drawLoadoutLine(context, client, 0, "A", 10, y);
        y = drawLoadoutLine(context, client, 1, "B", 10, y);

        int comboStep = TaijutsuClientHandler.getComboStep();
        if (lastComboStep > 0 && comboStep == 0) {
            comboDropTime = System.currentTimeMillis();
        }
        lastComboStep = comboStep;
        
        if (comboStep > 0) {
            String comboText = "COMBO x" + comboStep;
            context.drawTextWithShadow(client.textRenderer, Text.literal(comboText), 10, y + 10, 0xFFFF8800);
            y += 12;
        }

        TaijutsuStyle currentStyle = TaijutsuClientHandler.getCurrentStyle();
        String styleName = currentStyle == TaijutsuStyle.STRONG_FIST ? "[Strong Fist]" : "[Standard]";
        int styleColor = currentStyle == TaijutsuStyle.STRONG_FIST ? 0xFF44FF44 : 0xFFAAAAAA;
        context.drawTextWithShadow(client.textRenderer, Text.literal(styleName), 10, y + 10, styleColor);
        y += 12;
        
        if (client.player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem) {
            String st = ClientNinjaState.kenjutsuStance;
            int stColor = st.equals("seigan") ? 0xFF66AAFF : st.equals("iai") ? 0xFFFFAA00 : 0xFFFF5555;
            context.drawTextWithShadow(client.textRenderer, Text.literal("[" + st.toUpperCase() + "]"), 10, y + 10, stColor);
            y += 12;
        }

        boolean kickOnCooldown = TaijutsuKickHandler.isOnCooldown();
        if (kickOnCooldown) {
            float cd = TaijutsuKickHandler.getCooldownRatio();
            int cdW = 60, cdH = 4;
            context.drawTextWithShadow(client.textRenderer, Text.literal("KICK [V]"), 10, y + 8, 0xFF44AAFF);
            context.fill(10, y + 18, 10 + cdW, y + 18 + cdH, 0xCC222222);
            context.fill(10, y + 18, 10 + (int) (cdW * (1 - cd)), y + 18 + cdH, 0xFF44AAFF);
            y += 26;
        }

        int hbLeft = sw / 2 - 91;
        int hbRight = sw / 2 + 91;
        int barW = 91;
        int yHot = sh - 39;

        float hp = client.player.getHealth();
        float maxHp = client.player.getMaxHealth();
        drawBar(context, client, hbLeft, yHot, barW, HEIGHT, hp / maxHp, HP_LIGHT, HP_DARK, false,
            "HP", (int) hp + "/" + (int) maxHp);

        float food = client.player.getHungerManager().getFoodLevel();
        drawBar(context, client, hbRight - barW, yHot, barW, HEIGHT, food / 20f, FOOD_LIGHT, FOOD_DARK, food <= 6,
            "FD", (int) food + "/20");

        ChargedJumpAction chargedJump = ParkourManager.getChargedJumpAction();
        if (chargedJump != null && chargedJump.isCharging()) {
            float charge = chargedJump.getChargeRatio();
            int barWidth = 100, barHeight = 6;
            int barX = (sw - barWidth) / 2;
            int barY = sh - 80;

            context.fill(barX - 1, barY - 1, barX + barWidth + 1, barY + barHeight + 1, 0xCC000000);
            int color = charge >= 0.8f ? 0xFF5555 : 0xFFFF00;
            context.fill(barX, barY, barX + (int) (barWidth * charge), barY + barHeight, color);
            context.drawCenteredTextWithShadow(client.textRenderer,
                String.format("Charge: %.0f%%", charge * 100), barX + barWidth / 2, barY - 10, 0xFFFFFF);
        }
    }

    private static void drawBar(DrawContext context, MinecraftClient client, int x, int y, int width, int height,
                                float ratio, int lightColor, int darkColor, boolean pulse, String label, String value) {
        ratio = Math.max(0, Math.min(1, ratio));
        int filled = (int) (width * ratio);

        int alpha = (int)(255 * HudSettings.current.opacity);
        if (pulse) alpha = (int) (150 + 105 * Math.sin(System.currentTimeMillis() / 150.0));

        context.fill(x - 1, y - 1, x + width + 1, y + height + 1, BORDER);
        context.fill(x, y, x + width, y + height, BG);

        int lr = (lightColor >> 16) & 0xFF, lg = (lightColor >> 8) & 0xFF, lb = lightColor & 0xFF;
        int dr = (darkColor >> 16) & 0xFF, dg = (darkColor >> 8) & 0xFF, db = darkColor & 0xFF;
        context.fillGradient(x, y, x + filled, y + height,
            ColorHelper.Argb.getArgb(alpha, lr, lg, lb),
            ColorHelper.Argb.getArgb(alpha, dr, dg, db));
        context.fill(x, y, x + filled, y + 1, ColorHelper.Argb.getArgb(alpha / 3, 255, 255, 255));

        drawScaledText(context, client, label, x + 2, y + 1, 0xFFFFFFFF, TEXT_SCALE);
        int tw = (int) (client.textRenderer.getWidth(value) * TEXT_SCALE);
        drawScaledText(context, client, value, x + width - 2 - tw, y + 1, 0xFFFFFFFF, TEXT_SCALE);
    }

    private static void drawScaledText(DrawContext context, MinecraftClient client, String text,
                                       float x, float y, int color, float scale) {
        context.getMatrices().push();
        context.getMatrices().translate(x, y, 0);
        context.getMatrices().scale(scale, scale, 1f);
        context.drawTextWithShadow(client.textRenderer, text, 0, 0, color);
        context.getMatrices().pop();
    }

    private static void renderMinimalHud(DrawContext context, MinecraftClient client) {
        int y = 10;

        if (ClientNinjaState.chakraMode) {
            int alpha = (int)(150 + 105 * Math.sin(System.currentTimeMillis() / 200.0));
            context.drawTextWithShadow(client.textRenderer, Text.literal("CHAKRA MODE"), 10, y,
                ColorHelper.Argb.getArgb(alpha, 255, 136, 0));
            y += 10;
        }

        y = drawLoadoutLine(context, client, 0, "A", 10, y);
        y = drawLoadoutLine(context, client, 1, "B", 10, y);

        int comboStep = TaijutsuClientHandler.getComboStep();
        if (comboStep > 0) {
            context.drawTextWithShadow(client.textRenderer, Text.literal("COMBO x" + comboStep), 10, y + 10, 0xFFFF8800);
            y += 12;
        }

        TaijutsuStyle currentStyle = TaijutsuClientHandler.getCurrentStyle();
        String styleName = currentStyle == TaijutsuStyle.STRONG_FIST ? "[Strong Fist]" : "[Standard]";
        int styleColor = currentStyle == TaijutsuStyle.STRONG_FIST ? 0xFF44FF44 : 0xFFAAAAAA;
        context.drawTextWithShadow(client.textRenderer, Text.literal(styleName), 10, y + 10, styleColor);
        y += 12;

        if (client.player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem) {
            String st = ClientNinjaState.kenjutsuStance;
            int stColor = st.equals("seigan") ? 0xFF66AAFF : st.equals("iai") ? 0xFFFFAA00 : 0xFFFF5555;
            context.drawTextWithShadow(client.textRenderer, Text.literal("[" + st.toUpperCase() + "]"), 10, y + 10, stColor);
        }
    }

    private static int drawLoadoutLine(DrawContext context, MinecraftClient client, int set, String label, int x, int lineY) {
        String current = ClientNinjaState.activeJutsuId(set);
        String name = current == null ? "empty" : ClientNinjaState.name(current);

        context.drawTextWithShadow(client.textRenderer, Text.literal("[" + label + "]"), x, lineY, 0xFF8800);
        context.drawTextWithShadow(client.textRenderer, Text.literal(" " + name), x + 14, lineY, 0xFFFFFF);
        lineY += 10;

        for (int i = 0; i < 5; i++) {
            int color = (i == ClientNinjaState.active(set)) ? 0xFF8800
                : (ClientNinjaState.loadout(set)[i] != null ? 0x55AAFF : 0x555555);
            context.drawTextWithShadow(client.textRenderer, Text.literal("[" + (i + 1) + "]"),
                x + i * 18, lineY, color);
        }
        return lineY + 12;
    }
}
"@
[System.IO.File]::WriteAllText("$clientDir\ChakraHudRenderer.java", $renderer, $utf8)
Write-Host "[OK] Updated ChakraHudRenderer.java" -ForegroundColor Green

Write-Host "`n[INFO] Запустите .\gradlew.bat build для проверки компиляции." -ForegroundColor Cyan
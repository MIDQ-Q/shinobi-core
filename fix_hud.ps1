$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main\java\com\example\shinobicore\client"
function Write-File($p, $c) { [System.IO.File]::WriteAllText($p, $c, $utf8); Write-Host "[OK] $p" }

# ============ ChakraHudRenderer (Dark Souls / Elden Ring style) ============
Write-File "$base\ChakraHudRenderer.java" @'
package com.example.shinobicore.client;

import net.fabricmc.fabric.api.client.rendering.v1.HudRenderCallback;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.font.TextRenderer;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.util.hit.EntityHitResult;
import net.minecraft.util.hit.HitResult;

public class ChakraHudRenderer {
    public static float currentChakra = 0;
    public static float maxChakra = 100;
    public static float currentFatigue = 0;
    public static float maxFatigue = 100;
    public static float fatigue = 0;
    public static boolean exhausted = false;
    public static String stanceId = "aggressive";
    public static boolean chakraModeOn = false;
    public static boolean sensoryOn = false;
    public static boolean dangerOn = false;
    public static boolean markOn = false;
    private static boolean registered = false;

    public static void register() {
        if (registered) return;
        registered = true;
        HudRenderCallback.EVENT.register((ctx, tick) -> render(ctx));
    }

    private static void render(DrawContext ctx) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client == null || client.player == null || client.world == null) return;
        if (client.options.hudHidden) return;
        int sw = client.getWindow().getScaledWidth();
        int sh = client.getWindow().getScaledHeight();
        long now = System.currentTimeMillis();
        currentFatigue = fatigue;

        // ===== 1. ENEMY HP BAR (top center, thin, no name) =====
        if (client.crosshairTarget != null && client.crosshairTarget.getType() == HitResult.Type.ENTITY) {
            var ent = ((EntityHitResult) client.crosshairTarget).getEntity();
            if (ent instanceof LivingEntity liv) {
                int bw = 200, bh = 3;
                int bx = sw / 2 - bw / 2, by = 8;
                float hr = Math.max(0, Math.min(1, liv.getHealth() / liv.getMaxHealth()));
                ctx.fill(bx - 1, by - 1, bx + bw + 1, by + bh + 1, 0xFF000000);
                ctx.fill(bx, by, bx + bw, by + bh, 0xFF330000);
                ctx.fill(bx, by, bx + (int)(bw * hr), by + bh, 0xFFCC2222);
                ctx.fill(bx, by, bx + (int)(bw * hr), by + 1, 0xFFFF5555);
            }
        }

        // ===== 2. CHAKRA + FATIGUE (bottom-left, Dark Souls stamina style) =====
        int barW = 140, barH = 5;
        int bx = 12, by = sh - 60;

        // Chakra bar
        ctx.fill(bx - 1, by - 1, bx + barW + 1, by + barH + 1, 0xFF000000);
        ctx.fill(bx, by, bx + barW, by + barH, 0xFF112244);
        float ratio = maxChakra > 0 ? Math.max(0, Math.min(1, currentChakra / maxChakra)) : 0;
        int fw = (int)(barW * ratio);
        if (fw > 0) {
            int baseColor = chakraModeOn ? 0xFF4499FF : 0xFF2266DD;
            int topColor = chakraModeOn ? 0xFF88CCFF : 0xFF4488EE;
            ctx.fill(bx, by, bx + fw, by + barH, baseColor);
            ctx.fill(bx, by, bx + fw, by + 1, topColor);
        }

        // Fatigue bar (thin red, below chakra)
        int fy = by + barH + 3;
        ctx.fill(bx, fy, bx + barW, fy + 2, 0xFF330000);
        float fr = maxFatigue > 0 ? Math.max(0, Math.min(1, fatigue / maxFatigue)) : 0;
        int ffw = (int)(barW * fr);
        if (ffw > 0) {
            ctx.fill(bx, fy, bx + ffw, fy + 2, 0xFFCC3322);
        }

        // Mode indicators (dots below bars)
        int dy = fy + 6;
        if (chakraModeOn) drawDot(ctx, bx, dy, 0xFF4499FF, "C");
        if (sensoryOn)    drawDot(ctx, bx + 10, dy, 0xFF44CC66, "S");
        if (markOn)       drawDot(ctx, bx + 20, dy, 0xFFCC8833, "M");

        // Exhausted overlay on chakra bar
        if (exhausted) {
            int blink = (now / 300) % 2 == 0 ? 0xCCFF2222 : 0xCC880000;
            ctx.fill(bx, by, bx + barW, by + barH, blink);
        }

        // ===== 3. ACTIVE EFFECTS (top-right, minimal squares) =====
        int ex = sw - 16;
        for (StatusEffectInstance eff : client.player.getStatusEffects()) {
            int col = eff.getEffectType().getColor() | 0xFF000000;
            int dur = eff.getDuration() / 20;
            ctx.fill(ex - 12, 10, ex, 22, 0xFF000000);
            ctx.fill(ex - 11, 11, ex - 1, 21, col);
            ctx.fill(ex - 11, 11, ex - 1, 13, 0x44FFFFFF);
            if (dur < 10) {
                TextRenderer tr = client.textRenderer;
                ctx.drawText(tr, String.valueOf(dur), ex - 9, 13, 0xFFFFFF, true);
            }
            ex -= 15;
        }

        // ===== 4. DANGER VIGNETTE (red edges when targeted) =====
        if (dangerOn) {
            int a = (int)(40 + 30 * Math.sin(now / 200.0));
            int col = (a << 24) | 0xCC1111;
            // top/bottom gradient feel (simple bars)
            ctx.fill(0, 0, sw, 2, col);
            ctx.fill(0, sh - 2, sw, sh, col);
            ctx.fill(0, 0, 2, sh, col);
            ctx.fill(sw - 2, 0, sw, sh, col);
        }
    }

    private static void drawDot(DrawContext ctx, int x, int y, int color, String label) {
        ctx.fill(x, y, x + 6, y + 6, 0xFF000000);
        ctx.fill(x + 1, y + 1, x + 5, y + 5, color);
    }
}
'@

# ============ JutsuSlotHud: панель слотов техник ============
Write-File "$base\JutsuSlotHud.java" @'
package com.example.shinobicore.client;

import net.fabricmc.fabric.api.client.rendering.v1.HudRenderCallback;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.font.TextRenderer;
import net.minecraft.item.ItemStack;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuRegistry;

public class JutsuSlotHud {
    private static boolean registered = false;
    public static final int SLOT_COUNT = 4;

    public static void register() {
        if (registered) return;
        registered = true;
        HudRenderCallback.EVENT.register((ctx, tick) -> render(ctx));
    }

    private static void render(DrawContext ctx) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client == null || client.player == null) return;
        if (client.options.hudHidden) return;
        TextRenderer tr = client.textRenderer;
        int sw = client.getWindow().getScaledWidth();
        int sh = client.getWindow().getScaledHeight();

        int slotSize = 22;
        int gap = 2;
        int totalW = SLOT_COUNT * slotSize + (SLOT_COUNT - 1) * gap;
        int startX = sw / 2 - totalW / 2;
        int y = sh - 36;

        // Get active jutsu id from ClientNinjaState
        for (int i = 0; i < SLOT_COUNT; i++) {
            int sx = startX + i * (slotSize + gap);
            String jutsuId = getActiveJutsu(i);
            boolean hasJutsu = jutsuId != null && !jutsuId.isEmpty();

            // Slot background
            ctx.fill(sx - 1, y - 1, sx + slotSize + 1, y + slotSize + 1, 0xFF000000);
            ctx.fill(sx, y, sx + slotSize, y + slotSize, hasJutsu ? 0xCC223344 : 0xCC111111);
            ctx.fill(sx, y, sx + slotSize, y + 1, 0xFF556677);

            if (hasJutsu) {
                // Try to show jutsu icon/color based on nature
                JutsuDefinition def = JutsuRegistry.get(jutsuId);
                int col = getNatureColor(def);
                ctx.fill(sx + 2, y + 2, sx + slotSize - 2, y + slotSize - 2, col);

                // Jutsu initial letter
                String name = def != null ? def.name() : jutsuId.substring(jutsuId.lastIndexOf(':') + 1);
                String letter = name.substring(0, 1).toUpperCase();
                int tw = tr.getWidth(letter);
                ctx.drawText(tr, letter, sx + slotSize / 2 - tw / 2, y + slotSize / 2 - 4, 0xFFFFFF, true);
            }

            // Slot number (1-4) at top-left
            ctx.drawText(tr, String.valueOf(i + 1), sx + 2, y + 2, 0xFFAAAAAA, true);
        }
    }

    private static String getActiveJutsu(int slot) {
        try {
            return ClientNinjaState.activeJutsuId(slot);
        } catch (Exception e) {
            return null;
        }
    }

    private static int getNatureColor(JutsuDefinition def) {
        if (def == null) return 0xCC555555;
        String nature = def.nature();
        if (nature == null) return 0xCC888888;
        return switch (nature) {
            case "fire" -> 0xCCFF5522;
            case "water" -> 0xCC2288FF;
            case "wind" -> 0xCC88DD88;
            case "lightning" -> 0xCCFFDD44;
            case "earth" -> 0xCC996633;
            case "genjutsu" -> 0xCC9944CC;
            default -> 0xCC666688;
        };
    }
}
'@

# ============ Register both in ShinobiCoreClient ============
$scc = [System.IO.File]::ReadAllText("$base\ShinobiCoreClient.java", $utf8)
if (-not $scc.Contains("JutsuSlotHud.register")) {
    $scc = $scc.Replace(
        "ChakraHudRenderer.register(); // PHASE_H_HUD",
        "ChakraHudRenderer.register(); // PHASE_H_HUD`n        JutsuSlotHud.register(); // PHASE_H_JUTSU_SLOTS"
    )
    [System.IO.File]::WriteAllText("$base\ShinobiCoreClient.java", $scc, $utf8)
    Write-Host "[OK] ShinobiCoreClient: JutsuSlotHud registered"
} else {
    Write-Host "[SKIP] JutsuSlotHud already registered"
}

Write-Host "=== HUD FIX DONE ==="
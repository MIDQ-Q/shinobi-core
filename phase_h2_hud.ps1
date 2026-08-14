$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main"
$hudPath = "$base\java\com\example\shinobicore\client\ChakraHudRenderer.java"
function Write-File($p, $c) { [System.IO.File]::WriteAllText($p, $c, $utf8); Write-Host "[OK] $p" }

Write-File $hudPath @'
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
    public static String stanceId = "aggressive";
    public static boolean chakraModeOn = false;
    public static boolean sensoryOn = false;
    public static boolean dangerOn = false;
    public static boolean markOn = false;
    private static boolean registered = false;

    public static void register() {
        if (registered) return;
        registered = true;
        HudRenderCallback.EVENT.register((ctx, tickDelta) -> render(ctx));
    }

    private static void render(DrawContext ctx) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client == null || client.player == null || client.world == null) return;
        if (client.options.hudHidden) return;
        TextRenderer tr = client.textRenderer;
        int sw = client.getWindow().getScaledWidth();
        int sh = client.getWindow().getScaledHeight();
        long now = System.currentTimeMillis();

        // ===== CHAKRA PANEL (top-left, sci-fi frame) =====
        int px = 8, py = 8, pw = 168, ph = 46;
        panel(ctx, px, py, pw, ph);
        // chakra bar with gradient
        float ratio = maxChakra > 0 ? Math.max(0, Math.min(1, currentChakra / maxChakra)) : 0;
        int bw = pw - 12;
        ctx.fill(px + 6, py + 8, px + 6 + bw, py + 18, 0x66001133);
        int fw = (int)(bw * ratio);
        if (fw > 0) {
            ctx.fill(px + 6, py + 8, px + 6 + fw, py + 18, 0xFF1E6FFF);
            ctx.fill(px + 6, py + 8, px + 6 + fw, py + 11, 0xFF6FB4FF);
        }
        ctx.drawText(tr, (int)currentChakra + "/" + (int)maxChakra, px + 8, py + 9, 0xFFFFFF, true);
        // fatigue bar (thin red)
        float fr = maxFatigue > 0 ? Math.max(0, Math.min(1, currentFatigue / maxFatigue)) : 0;
        ctx.fill(px + 6, py + 21, px + 6 + bw, py + 24, 0x66330000);
        ctx.fill(px + 6, py + 21, px + 6 + (int)(bw * fr), py + 24, 0xFFE04040);
        // stance + mode chips
        String stance = stanceId.substring(0, 1).toUpperCase();
        ctx.fill(px + 6, py + 28, px + 20, py + 40, 0xAA222222);
        ctx.drawText(tr, stance, px + 10, py + 31, 0xFFDDDD, true);
        if (chakraModeOn) {
            int pulse = (int)(120 + 80 * Math.sin(now / 200.0));
            ctx.fill(px + 24, py + 28, px + 38, py + 40, (0xFF000000) | (pulse << 8) | 0xFF);
            ctx.drawText(tr, "C", px + 28, py + 31, 0xFFFFFF, true);
        }
        if (sensoryOn) {
            ctx.fill(px + 42, py + 28, px + 56, py + 40, 0xAA22AA66);
            ctx.drawText(tr, "S", px + 46, py + 31, 0xFFFFFF, true);
        }
        if (markOn) {
            ctx.fill(px + 60, py + 28, px + 74, py + 40, 0xAAAA6622);
            ctx.drawText(tr, "M", px + 64, py + 31, 0xFFFFFF, true);
        }

        // ===== ACTIVE EFFECT ICONS (top-right) =====
        int ix = sw - 20;
        for (StatusEffectInstance eff : client.player.getStatusEffects()) {
            int col = eff.getEffectType().getColor() | 0xFF000000;
            ctx.fill(ix, 10, ix + 14, 24, 0xAA111111);
            ctx.fill(ix + 2, 12, ix + 12, 22, col);
            int secs = eff.getDuration() / 20;
            ctx.drawText(tr, String.valueOf(secs), ix + 2, 26, 0xFFFFFF, true);
            ix -= 18;
        }

        // ===== TARGET FRAME (top-center) =====
        if (client.crosshairTarget != null && client.crosshairTarget.getType() == HitResult.Type.ENTITY) {
            var ent = ((EntityHitResult) client.crosshairTarget).getEntity();
            if (ent instanceof LivingEntity liv) {
                String name = liv.getName().getString();
                int tw = Math.max(120, tr.getWidth(name) + 20);
                int tx = sw / 2 - tw / 2, ty = 12;
                panel(ctx, tx, ty, tw, 26);
                ctx.drawText(tr, name, tx + 8, ty + 4, 0xFFFFFF, true);
                float hr = Math.max(0, Math.min(1, liv.getHealth() / liv.getMaxHealth()));
                ctx.fill(tx + 6, ty + 16, tx + tw - 6, ty + 21, 0x66330000);
                ctx.fill(tx + 6, ty + 16, tx + 6 + (int)((tw - 12) * hr), ty + 21, 0xFF33CC33);
            }
        }

        // ===== DANGER FRAME (pulsing red edges) =====
        if (dangerOn) {
            int a = (int)(90 + 70 * Math.sin(now / 150.0));
            int col = (a << 24) | 0xCC2222;
            ctx.fill(0, 0, sw, 3, col);
            ctx.fill(0, sh - 3, sw, sh, col);
            ctx.fill(0, 0, 3, sh, col);
            ctx.fill(sw - 3, 0, sw, sh, col);
        }
    }

    private static void panel(DrawContext ctx, int x, int y, int w, int h) {
        ctx.fill(x, y, x + w, y + h, 0x88101418);
        ctx.fill(x, y, x + w, y + 1, 0xFF3FA7FF);
        ctx.fill(x, y + h - 1, x + w, y + h, 0xFF3FA7FF);
        ctx.fill(x, y, x + 1, y + h, 0xFF3FA7FF);
        ctx.fill(x + w - 1, y, x + w, y + h, 0xFF3FA7FF);
        ctx.fill(x, y, x + 3, y + 3, 0xFFBFE7FF);
        ctx.fill(x + w - 3, y, x + w, y + 3, 0xFFBFE7FF);
        ctx.fill(x, y + h - 3, x + 3, y + h, 0xFFBFE7FF);
        ctx.fill(x + w - 3, y + h - 3, x + w, y + h, 0xFFBFE7FF);
    }
}
'@

# Ensure register() is called once from ShinobiCoreClient
$scc = [System.IO.File]::ReadAllText("$base\java\com\example\shinobicore\client\ShinobiCoreClient.java", $utf8)
if (-not $scc.Contains("ChakraHudRenderer.register")) {
    $scc = $scc.Replace("ChakraAuraVisual.register();",
        "ChakraAuraVisual.register();`n        com.example.shinobicore.client.ChakraHudRenderer.register(); // PHASE_H_HUD")
    [System.IO.File]::WriteAllText("$base\java\com\example\shinobicore\client\ShinobiCoreClient.java", $scc, $utf8)
    Write-Host "[OK] ShinobiCoreClient: HUD register added"
}

Write-Host "=== PHASE H2 (MODERN HUD) DONE ==="
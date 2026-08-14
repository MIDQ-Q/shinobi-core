$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$hudPath = "E:\Games\mod\src\main\java\com\example\shinobicore\client\ChakraHudRenderer.java"
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
        TextRenderer tr = client.textRenderer;
        int sw = client.getWindow().getScaledWidth();
        long now = System.currentTimeMillis();
        currentFatigue = fatigue;

        // ===== TOP-LEFT INFO PANEL =====
        int px = 8, py = 8, pw = 150, ph = 76;
        ctx.fill(px, py, px + pw, py + ph, 0x88000000);
        ctx.fill(px, py, px + pw, py + 1, 0xFFAAAAAA);
        ctx.fill(px, py + ph - 1, px + pw, py + ph, 0xFFAAAAAA);
        ctx.fill(px, py, px + 1, py + ph, 0xFFAAAAAA);
        ctx.fill(px + pw - 1, py, px + pw, py + ph, 0xFFAAAAAA);

        // Chakra label + bar
        int barX = px + 4, barY = py + 4, barW = pw - 8, barH = 8;
        String chakraText = "CHAKRA: " + (int)currentChakra + "/" + (int)maxChakra;
        ctx.drawText(tr, chakraText, barX, barY - 1, 0xFFFFFF, true);
        barY += 9;
        ctx.fill(barX, barY, barX + barW, barY + barH, 0x66333333);
        float ratio = maxChakra > 0 ? Math.max(0, Math.min(1, currentChakra / maxChakra)) : 0;
        int fw = (int)(barW * ratio);
        if (fw > 0) {
            ctx.fill(barX, barY, barX + fw, barY + barH, exhausted ? 0xFF882222 : 0xFF2266CC);
            if (chakraModeOn) ctx.fill(barX, barY, barX + fw, barY + 2, 0xFF88CCFF);
        }

        // Fatigue bar
        barY += barH + 4;
        ctx.drawText(tr, "FATIGUE: " + (int)fatigue + "/" + (int)maxFatigue, barX, barY - 1, 0xFFCCCCCC, true);
        barY += 9;
        ctx.fill(barX, barY, barX + barW, barY + 5, 0x66333333);
        float fr = maxFatigue > 0 ? Math.max(0, Math.min(1, fatigue / maxFatigue)) : 0;
        int ffw = (int)(barW * fr);
        if (ffw > 0) ctx.fill(barX, barY, barX + ffw, barY + 5, 0xFFCC4422);

        // Stance line
        barY += 8;
        String stanceLabel = "STANCE: " + (stanceId != null ? stanceId : "none");
        ctx.drawText(tr, stanceLabel, barX, barY, 0xFFFFDD88, true);

        // Modes line
        barY += 10;
        StringBuilder modes = new StringBuilder("MODE:");
        if (chakraModeOn) modes.append(" [CHAKRA]");
        if (sensoryOn) modes.append(" [SENSE]");
        if (markOn) modes.append(" [MARK]");
        ctx.drawText(tr, modes.toString(), barX, barY, 0xFFAADDFF, true);

        // ===== TARGET FRAME (top-center) =====
        if (client.crosshairTarget != null && client.crosshairTarget.getType() == HitResult.Type.ENTITY) {
            var ent = ((EntityHitResult) client.crosshairTarget).getEntity();
            if (ent instanceof LivingEntity liv) {
                String name = liv.getName().getString();
                int tw = Math.max(100, tr.getWidth(name) + 16);
                int tx = sw / 2 - tw / 2, ty = 10;
                ctx.fill(tx, ty, tx + tw, ty + 22, 0x88000000);
                ctx.fill(tx, ty, tx + tw, ty + 1, 0xFFAAAAAA);
                ctx.fill(tx, ty + 21, tx + tw, ty + 22, 0xFFAAAAAA);
                ctx.fill(tx, ty, tx + 1, ty + 22, 0xFFAAAAAA);
                ctx.fill(tx + tw - 1, ty, tx + tw, ty + 22, 0xFFAAAAAA);
                int ttw = tr.getWidth(name);
                ctx.drawText(tr, name, tx + (tw - ttw) / 2, ty + 2, 0xFFFFFF, true);
                int hbx = tx + 4, hby = ty + 13;
                float hr = Math.max(0, Math.min(1, liv.getHealth() / liv.getMaxHealth()));
                ctx.fill(hbx, hby, hbx + tw - 8, hby + 5, 0x66333333);
                ctx.fill(hbx, hby, hbx + (int)((tw - 8) * hr), hby + 5, 0xFF33CC33);
            }
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

        // ===== DANGER MESSAGE (top-center below target) =====
        if (dangerOn) {
            int blink = (now / 250) % 2 == 0 ? 0xFFFF2222 : 0xFFCC0000;
            String dmsg = "!! DANGER !!";
            int dw = tr.getWidth(dmsg);
            ctx.drawText(tr, dmsg, sw / 2 - dw / 2, 40, blink, true);
        }
    }

    // Simple StringBuilder replacement (avoiding import)
    private static class StringBuilder {
        private final StringBuilderInner inner = new StringBuilderInner();
        public StringBuilder(String s) { inner.sb.append(s); }
        public StringBuilder append(String s) { inner.sb.append(s); return this; }
        public String toString() { return inner.sb.toString(); }
        private static class StringBuilderInner { final java.lang.StringBuilder sb = new java.lang.StringBuilder(); }
    }
}
'@

Write-Host "=== OLD HUD RESTORED ==="
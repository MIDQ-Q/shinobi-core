$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main"
$hudPath = "$base\java\com\example\shinobicore\client\ChakraHudRenderer.java"
$sccPath = "$base\java\com\example\shinobicore\client\ShinobiCoreClient.java"
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
    // ===== Старые поля для совместимости =====
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

    // ===== Японская палитра (Konoha) =====
    private static final int COL_BG = 0xCC1A0F0A;         // тёмно-коричневый фон свитка
    private static final int COL_BORDER = 0xFFB8860B;      // золото (暗金色)
    private static final int COL_ACCENT = 0xFF8B0000;      // тёмно-красный (朱色)
    private static final int COL_CHAKRA = 0xFF2E5CFF;      // синий чакра
    private static final int COL_CHAKRA_GLOW = 0xFF6B9EFF;
    private static final int COL_FATIGUE = 0xFFB22222;     // тёмно-красный (усталость)
    private static final int COL_HP = 0xFF33AA33;          // зелёный
    private static final int COL_TEXT = 0xFFF5E6C8;        // кремовый (бумага свитка)
    private static final int COL_KANJI = 0xFFFFD700;       // золотой иероглиф
    // Кандзи стихий
    private static final String KANJI_FIRE = "\u706B";     // 火
    private static final String KANJI_WATER = "\u6C34";    // 水
    private static final String KANJI_WIND = "\u98A8";     // 風
    private static final String KANJI_LIGHTNING = "\u96F7"; // 雷
    private static final String KANJI_EARTH = "\u571F";    // 土
    private static final String KANJI_CHAKRA = "\u67E5";   // 査 (сокращение от 查克拉)
    private static final String KANJI_SEAL = "\u5370";     // 印 (печать)

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
        int sh = client.getWindow().getScaledHeight();
        long now = System.currentTimeMillis();

        // Синхронизация: currentFatigue == fatigue
        currentFatigue = fatigue;

        // ===== ПАНЕЛЬ ЧАКРЫ (верхний-левый, стиль свитка) =====
        int px = 8, py = 8, pw = 180, ph = 56;
        scrollPanel(ctx, px, py, pw, ph);

        // Кандзи 査 слева от бара
        ctx.drawText(tr, KANJI_CHAKRA, px + 6, py + 8, COL_KANJI, true);

        // Чакра-бар (градиент синий с подсветкой)
        float ratio = maxChakra > 0 ? Math.max(0, Math.min(1, currentChakra / maxChakra)) : 0;
        int bw = pw - 30;
        int bx = px + 20, by = py + 8;
        ctx.fill(bx, by, bx + bw, by + 10, 0x66000011);
        int fw = (int)(bw * ratio);
        if (fw > 0) {
            ctx.fill(bx, by, bx + fw, by + 10, COL_CHAKRA);
            ctx.fill(bx, by, bx + fw, by + 3, COL_CHAKRA_GLOW);
            // Пульсация при chakra mode
            if (chakraModeOn) {
                int pulse = (int)(100 + 80 * Math.sin(now / 180.0));
                ctx.fill(bx, by, bx + fw, by + 1, (pulse << 24) | 0xAADDFF);
            }
        }
        ctx.drawText(tr, (int)currentChakra + "/" + (int)maxChakra, bx + 4, by + 1, COL_TEXT, true);

        // Усталость-бар (тонкая тёмно-красная)
        float fr = maxFatigue > 0 ? Math.max(0, Math.min(1, fatigue / maxFatigue)) : 0;
        ctx.fill(bx, by + 14, bx + bw, by + 18, 0x66220000);
        int ffw = (int)(bw * fr);
        if (ffw > 0) ctx.fill(bx, by + 14, bx + ffw, by + 18, COL_FATIGUE);
        ctx.drawText(tr, "\u75B2", bx + 2, by + 14, 0xFFAA6666, true); // 疲 (усталость)

        // Exhausted overlay
        if (exhausted) {
            int blink = (now / 250) % 2 == 0 ? 0xFFCC0000 : 0xFF880000;
            ctx.fill(px + 4, py + 28, px + pw - 4, py + 46, blink);
            ctx.drawText(tr, "EXHAUSTED", px + pw / 2 - 30, py + 33, 0xFFFFFF, true);
        }

        // ===== ЧИПЫ СТИЛЕЙ И РЕЖИМОВ (ниже панели) =====
        int chipX = px, chipY = py + ph + 4;
        chipX = drawChip(ctx, tr, chipX, chipY, stanceChar(stanceId), COL_BORDER, "stance");
        chipX = drawChip(ctx, tr, chipX + 2, chipY, chakraModeOn ? "C" : "", 0xFF2E5CFF, "chakra");
        chipX = drawChip(ctx, tr, chipX + 2, chipY, sensoryOn ? "S" : "", 0xFF33AA66, "sensory");
        chipX = drawChip(ctx, tr, chipX + 2, chipY, markOn ? "M" : "", 0xFFCC8822, "mark");

        // ===== АКТИВНЫЕ ЭФФЕКТЫ (верхний-правый, как печати) =====
        int ex = sw - 22;
        for (StatusEffectInstance eff : client.player.getStatusEffects()) {
            int col = eff.getEffectType().getColor() | 0xFF000000;
            sealBox(ctx, ex, 8, 22, 26, col);
            int secs = eff.getDuration() / 20;
            String amp = eff.getAmplifier() > 0 ? (eff.getAmplifier() + 1) + "" : "";
            ctx.drawText(tr, amp, ex + 4, 12, 0xFFFFFF, true);
            ctx.drawText(tr, String.valueOf(secs), ex + 4, 24, COL_TEXT, true);
            ex -= 26;
        }

        // ===== TARGET FRAME (верх-центр, стиль печати-круг) =====
        if (client.crosshairTarget != null && client.crosshairTarget.getType() == HitResult.Type.ENTITY) {
            var ent = ((EntityHitResult) client.crosshairTarget).getEntity();
            if (ent instanceof LivingEntity liv) {
                String name = liv.getName().getString();
                int tw = Math.max(140, tr.getWidth(name) + 28);
                int tx = sw / 2 - tw / 2, ty = 14;
                scrollPanel(ctx, tx, ty, tw, 30);
                ctx.drawText(tr, "\u6575", tx + 6, ty + 4, COL_KANJI, true); // 敵 (враг)
                ctx.drawText(tr, name, tx + 20, ty + 4, COL_TEXT, true);
                float hr = Math.max(0, Math.min(1, liv.getHealth() / liv.getMaxHealth()));
                int hbx = tx + 6, hby = ty + 18;
                ctx.fill(hbx, hby, hbx + tw - 12, hby + 5, 0x66220000);
                ctx.fill(hbx, hby, hbx + (int)((tw - 12) * hr), hby + 5, COL_HP);
                ctx.fill(hbx, hby, hbx + (int)((tw - 12) * hr), hby + 2, 0xFF66DD66);
            }
        }

        // ===== DANGER FRAME (красные края + кандзи 危) =====
        if (dangerOn) {
            int a = (int)(90 + 70 * Math.sin(now / 150.0));
            int col = (a << 24) | 0xCC2222;
            ctx.fill(0, 0, sw, 3, col);
            ctx.fill(0, sh - 3, sw, sh, col);
            ctx.fill(0, 0, 3, sh, col);
            ctx.fill(sw - 3, 0, sw, sh, col);
            // кандзи 危 (опасность) по углам
            int blinkCol = ((now / 300) % 2 == 0) ? 0xFFCC0000 : 0xFF660000;
            ctx.drawText(tr, "\u5371", 6, 6, blinkCol, true);
            ctx.drawText(tr, "\u5371", sw - 14, 6, blinkCol, true);
            ctx.drawText(tr, "\u5371", 6, sh - 14, blinkCol, true);
            ctx.drawText(tr, "\u5371", sw - 14, sh - 14, blinkCol, true);
        }
    }

    private static String stanceChar(String s) {
        if (s == null) return "?";
        return switch (s) {
            case "aggressive" -> "\u653B"; // 攻
            case "seigan"     -> "\u5B88"; // 守
            case "iai"        -> "\u5C45"; // 居
            default -> "?";
        };
    }

    private static int drawChip(DrawContext ctx, TextRenderer tr, int x, int y, String label, int color, String key) {
        if (label == null || label.isEmpty()) return x;
        ctx.fill(x, y, x + 18, y + 18, 0xBB1A0F0A);
        ctx.fill(x, y, x + 18, y + 1, color);
        ctx.fill(x, y + 17, x + 18, y + 18, color);
        ctx.fill(x, y, x + 1, y + 18, color);
        ctx.fill(x + 17, y, x + 18, y + 18, color);
        ctx.drawText(tr, label, x + 5, y + 4, COL_TEXT, true);
        return x + 18;
    }

    private static void scrollPanel(DrawContext ctx, int x, int y, int w, int h) {
        ctx.fill(x, y, x + w, y + h, COL_BG);
        // Золотая рамка
        ctx.fill(x, y, x + w, y + 1, COL_BORDER);
        ctx.fill(x, y + h - 1, x + w, y + h, COL_BORDER);
        ctx.fill(x, y, x + 1, y + h, COL_BORDER);
        ctx.fill(x + w - 1, y, x + w, y + h, COL_BORDER);
        // Уголки-закрутки свитка (тёмно-золотые)
        int c1 = 0xFFDAA520; // более светлый золотой
        ctx.fill(x, y, x + 4, y + 1, c1);
        ctx.fill(x, y, x + 1, y + 4, c1);
        ctx.fill(x + w - 4, y, x + w, y + 1, c1);
        ctx.fill(x + w - 1, y, x + w, y + 4, c1);
        ctx.fill(x, y + h - 1, x + 4, y + h, c1);
        ctx.fill(x, y + h - 4, x + 1, y + h, c1);
        ctx.fill(x + w - 4, y + h - 1, x + w, y + h, c1);
        ctx.fill(x + w - 1, y + h - 4, x + w, y + h, c1);
    }

    private static void sealBox(DrawContext ctx, int x, int y, int w, int h, int innerCol) {
        ctx.fill(x, y, x + w, y + h, COL_BG);
        ctx.fill(x, y, x + w, y + 1, COL_ACCENT);
        ctx.fill(x, y + h - 1, x + w, y + h, COL_ACCENT);
        ctx.fill(x, y, x + 1, y + h, COL_ACCENT);
        ctx.fill(x + w - 1, y, x + w, y + h, COL_ACCENT);
        ctx.fill(x + 3, y + 3, x + w - 3, y + h - 3, innerCol);
    }
}
'@

# Удалить старую регистрацию в ShinobiCoreClient (строка 211)
$scc = [System.IO.File]::ReadAllText($sccPath, $utf8)
$scc = $scc.Replace("HudRenderCallback.EVENT.register(ChakraHudRenderer::render);",
    "// HUD registration now inside ChakraHudRenderer.register() (self-guarded)")
[System.IO.File]::WriteAllText($sccPath, $scc, $utf8)
Write-Host "[OK] ShinobiCoreClient: removed duplicate HUD registration"
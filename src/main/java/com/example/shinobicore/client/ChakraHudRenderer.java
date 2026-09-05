package com.example.shinobicore.client;

import com.example.shinobicore.config.ModConfig;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.text.Text;

public class ChakraHudRenderer {
    public static float currentChakra = 100f;
    public static float maxChakra = 100f;
    public static float fatigue = 0f;
    public static boolean exhausted = false;

    private static final String[] HEART = {".X.X.", "XXXXX", "XXXXX", ".XXX.", "..X.."};
    private static final String[] MEAT  = {".XXX.", "XXXX.", "XXXX.", ".XX..", "..X.."};
    private static final String[] ORB   = {".XXX.", "X...X", "X.X.X", "X...X", ".XXX."};
    private static final String[] BOLT  = {"..XX.", ".XX..", "XXXX.", "..XX.", ".XX.."};
    private static final String[] DROP  = {"..X..", ".XXX.", "XXXXX", "XXXXX", ".XXX."};

    public static void render(DrawContext context, float tickDelta) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;
        ModConfig.Hud cfg = ModConfig.instance.hud;
        if (!cfg.showHud) return;

        float sc = cfg.hudScale;
        int x = cfg.x;
        int y = cfg.y;
        int barW = Math.max(40, (int) (cfg.barWidth * sc));
        int barH = Math.max(2, (int) (cfg.barHeight * sc));
        int gap = Math.max(3, (int) (cfg.barSpacing * sc));
        int slot = Math.max(10, (int) (cfg.slotSize * sc));
        int slotGap = Math.max(1, (int) (cfg.slotSpacing * sc));

        float hp = client.player.getHealth();
        float maxHp = client.player.getMaxHealth();
        float food = client.player.getHungerManager().getFoodLevel() / 20f;
        float chakra = maxChakra > 0 ? currentChakra / maxChakra : 0;
        float stamina = Math.max(0, 100 - fatigue) / 100f;
        float fat = fatigue / 100f;

        y = drawBar(context, client, x, y, barW, barH, gap, HEART, 0xFFFF5555, 0xFF992222, hp / maxHp,
                hp < maxHp ? (int) hp + "/" + (int) maxHp : "", hp / maxHp < 0.3f);
        y = drawBar(context, client, x, y, barW, barH, gap, MEAT, 0xFFDD9955, 0xFF774422, food,
                food < 1f ? String.valueOf((int) (food * 20)) : "", food < 0.3f);
        y = drawBar(context, client, x, y, barW, barH, gap, ORB, 0xFF66BBFF, 0xFF1166CC, chakra,
                chakra < 1f ? String.valueOf((int) currentChakra) : "", chakra < 0.25f);
        y = drawBar(context, client, x, y, barW, barH, gap, BOLT, 0xFF77DD77, 0xFF22AA44, stamina, "", false);
        y = drawBar(context, client, x, y, barW, barH, gap, DROP, 0xFFFFAA44, 0xFFCC7711, fat, "", false);

        y += 2;
        y = drawSlotRow(context, client, x, y, slot, slotGap, 0, true);
        y = drawSlotRow(context, client, x, y, slot, slotGap, 1, false);

        if (ClientNinjaStateHolder.get().isChakraMode()) {
            int alpha = (int) (150 + 105 * Math.sin(System.currentTimeMillis() / 200.0));
            context.drawTextWithShadow(client.textRenderer, Text.literal("CHAKRA MODE"),
                    x, y, (alpha << 24) | 0xFF8800);
            y += 9;
        }
        if (exhausted) {
            context.drawTextWithShadow(client.textRenderer, Text.literal("EXHAUSTED"), x, y, 0xFFFF3333);
            y += 9;
        }
        if (RasenganClientState.charging) {
            context.fill(x, y + 5, x + barW, y + 8, 0xCC222222);
            context.fill(x, y + 5, x + (int) (barW * RasenganClientState.chargeProgress), y + 8, 0xFF44AAFF);
        }
    }

    private static int drawBar(DrawContext ctx, MinecraftClient client, int x, int y,
                               int barW, int barH, int gap, String[] icon, int light, int dark,
                               float ratio, String value, boolean pulse) {
        ratio = Math.max(0f, Math.min(1f, ratio));
        boolean flash = pulse && (System.currentTimeMillis() / 250 % 2 == 0);
        drawIcon(ctx, x, y - 1, icon, flash ? 0xFFFFFFFF : light);

        int bx = x + 8;
        // glow
        ctx.fill(bx - 1, y - 1, bx + barW + 1, y + barH + 1, (light & 0x00FFFFFF) | 0x26000000);
        // frame + bg
        ctx.fill(bx - 1, y - 1, bx + barW + 1, y + barH + 1, 0xFF000000);
        ctx.fill(bx, y, bx + barW, y + barH, 0xFF141414);
        int fw = (int) (barW * ratio);
        if (fw > 0) {
            ctx.fillGradient(bx, y, bx + fw, y + barH, light, dark);
            ctx.fill(bx, y, bx + fw, y + 1, 0x55FFFFFF);
        }
        // value only when not full
        if (!value.isEmpty()) {
            drawSmallText(ctx, client, value, bx + barW + 3, y, 0xFFFFFFFF);
        }
        return y + barH + gap;
    }

    private static void drawIcon(DrawContext ctx, int x, int y, String[] pattern, int color) {
        for (int ry = 0; ry < pattern.length; ry++) {
            for (int rx = 0; rx < pattern[ry].length(); rx++) {
                if (pattern[ry].charAt(rx) == 'X') {
                    ctx.fill(x + rx, y + ry, x + rx + 1, y + ry + 1, color);
                }
            }
        }
    }

    private static void drawSmallText(DrawContext ctx, MinecraftClient client, String text, int x, int y, int color) {
        ctx.getMatrices().push();
        ctx.getMatrices().scale(0.5f, 0.5f, 1f);
        ctx.drawTextWithShadow(client.textRenderer, Text.literal(text), x * 2, y * 2, color);
        ctx.getMatrices().pop();
    }

    private static int drawSlotRow(DrawContext ctx, MinecraftClient client, int x, int y,
                                   int s, int gap, int set, boolean warm) {
        ctx.drawTextWithShadow(client.textRenderer, Text.literal(set == 0 ? "A" : "B"),
                x, y + s / 2 - 4, warm ? 0xFFCC9966 : 0xFF888888);
        int bx = x + 9;
        String[] loadout = ClientNinjaStateHolder.get().getLoadout(set);
        int active = ClientNinjaStateHolder.get().getActive(set);
        for (int i = 0; i < 5; i++) {
            int sx = bx + i * (s + gap);
            String id = loadout[i];
            if (i == active) ctx.fill(sx - 1, y - 1, sx + s + 1, y + s + 1, warm ? 0x33FF8800 : 0x33AAAAAA);
            ctx.fill(sx, y, sx + s, y + s, 0xCC1A1A1A);
            int border;
            if (i == active) {
                int pulse = (int) (200 + 55 * Math.sin(System.currentTimeMillis() / 200.0));
                border = warm ? (0xFF << 24) | (pulse << 16) | 0xCC88 : 0xFFDDDDDD;
            } else {
                border = warm ? 0xFFAA7744 : 0xFF555555;
            }
            ctx.fill(sx, y, sx + s, y + 1, border);
            ctx.fill(sx, y + s - 1, sx + s, y + s, border);
            ctx.fill(sx, y, sx + 1, y + s, border);
            ctx.fill(sx + s - 1, y, sx + s, y + s, border);
            if (id != null) {
                String name = ClientNinjaStateHolder.get().getName(id);
                String ch = name.isEmpty() ? "?" : name.substring(0, 1);
                int rem = CooldownHudState.getRemaining(id);
                if (rem > 0) {
                    float prog = CooldownHudState.getProgress(id);
                    int cover = (int) ((s - 2) * Math.max(0f, Math.min(1f, prog)));
                    ctx.fill(sx + 1, y + 1 + (s - 2) - cover, sx + s - 1, y + s - 1, 0xAA000000);
                    String sec = String.format("%.1f", rem / 20f);
                    int tw2 = client.textRenderer.getWidth(sec);
                    drawSmallText(ctx, client, sec, sx + s / 2 - (int) (tw2 * 0.25f), y + s / 2 - 2, 0xFFFF5555);
                    ctx.fill(sx - 1, y - 1, sx + s + 1, y, 0xFFCC3333);
                    ctx.fill(sx - 1, y + s, sx + s + 1, y + s + 1, 0xFFCC3333);
                    ctx.fill(sx - 1, y, sx, y + s, 0xFFCC3333);
                    ctx.fill(sx + s, y, sx + s + 1, y + s, 0xFFCC3333);
                } else {
                    int tw = client.textRenderer.getWidth(ch);
                    ctx.drawTextWithShadow(client.textRenderer, Text.literal(ch),
                            sx + s / 2 - tw / 2, y + s / 2 - 4, 0xFFFFFFFF);
                }
            }
        }
        return y + s + 2;
    }
}
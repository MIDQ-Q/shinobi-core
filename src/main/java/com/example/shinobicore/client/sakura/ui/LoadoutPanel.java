package com.example.shinobicore.client.sakura.ui;

import com.example.shinobicore.client.ClientNinjaStateHolder;
import com.example.shinobicore.client.JutsuAssignmentScreen;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.text.Text;

/** JUTSU tab: loadout sets A/B, click a slot to assign a jutsu. */
public final class LoadoutPanel {
    private static int set = 0;

    private LoadoutPanel() {}

    private static int[] setBtnRect(int idx, int x0, int y0) {
        return new int[]{ x0 + 20 + idx * 46, y0 + 34, 40, 14 };
    }
    private static int[] slotRect(int idx, int x0, int y0) {
        return new int[]{ x0 + 20, y0 + 58 + idx * 22, 240, 20 };
    }

    public static void render(DrawContext ctx, int x0, int y0, int w, int h, int mx, int my) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client == null) return;
        ctx.drawTextWithShadow(client.textRenderer, Text.literal("JUTSU LOADOUT"),
            x0 + 20, y0 + 16, 0xFFFF9EC4);

        for (int i = 0; i < 2; i++) {
            int[] r = setBtnRect(i, x0, y0);
            boolean active = set == i;
            boolean hov = mx >= r[0] && mx <= r[0] + r[2] && my >= r[1] && my <= r[1] + r[3];
            ctx.fill(r[0], r[1], r[0] + r[2], r[1] + r[3], active ? 0xFF8A4A66 : 0xFF2A1F2E);
            ctx.fill(r[0], r[1], r[0] + r[2], r[1] + 1, active ? 0xFFFF9EC4 : 0xFF4A3A50);
            if (hov && !active) ctx.fill(r[0], r[1], r[0] + r[2], r[1] + r[3], 0x22FF9EC4);
            ctx.drawTextWithShadow(client.textRenderer, Text.literal(i == 0 ? "A" : "B"),
                r[0] + r[2] / 2 - 3, r[1] + 3, active ? 0xFFF2EAF0 : 0xFF9A8FA6);
        }

        String[] loadout = ClientNinjaStateHolder.get().getLoadout(set);
        int active = ClientNinjaStateHolder.get().getActive(set);
        for (int i = 0; i < 5; i++) {
            int[] r = slotRect(i, x0, y0);
            boolean hov = mx >= r[0] && mx <= r[0] + r[2] && my >= r[1] && my <= r[1] + r[3];
            ctx.fill(r[0], r[1], r[0] + r[2], r[1] + r[3], hov ? 0xFF3A2A3E : 0xFF241B2A);
            ctx.fill(r[0], r[1], r[0] + 1, r[1] + r[3], i == active ? 0xFFFF9EC4 : 0xFF4A3A50);
            if (hov) ctx.fill(r[0], r[1], r[0] + r[2], r[1] + 1, 0x55FF9EC4);

            ctx.drawTextWithShadow(client.textRenderer, Text.literal((i + 1) + "."),
                r[0] + 6, r[1] + 6, 0xFF9A8FA6);
            String id = loadout[i];
            String name = id == null ? "- empty -" : ClientNinjaStateHolder.get().getName(id);
            ctx.drawTextWithShadow(client.textRenderer, Text.literal(name),
                r[0] + 22, r[1] + 6, id == null ? 0xFF6E6478 : 0xFFF2EAF0);
            if (i == active) {
                ctx.drawTextWithShadow(client.textRenderer, Text.literal("ACT"),
                    r[0] + r[2] - 26, r[1] + 6, 0xFFFF9EC4);
            }
        }
        ctx.drawTextWithShadow(client.textRenderer,
            Text.literal("Click a slot to assign a jutsu"),
            x0 + 20, y0 + 58 + 5 * 22 + 8, 0xFF9A8FA6);
    }

    public static boolean handleClick(double mx, double my, int x0, int y0, int w, int h) {
        for (int i = 0; i < 2; i++) {
            int[] r = setBtnRect(i, x0, y0);
            if (mx >= r[0] && mx <= r[0] + r[2] && my >= r[1] && my <= r[1] + r[3]) {
                set = i;
                UiSounds.tab();
                return true;
            }
        }
        for (int i = 0; i < 5; i++) {
            int[] r = slotRect(i, x0, y0);
            if (mx >= r[0] && mx <= r[0] + r[2] && my >= r[1] && my <= r[1] + r[3]) {
                MinecraftClient client = MinecraftClient.getInstance();
                if (client != null) {
                    UiSounds.click();
                    client.setScreen(new JutsuAssignmentScreen(client.currentScreen, set, i));
                }
                return true;
            }
        }
        return false;
    }
}
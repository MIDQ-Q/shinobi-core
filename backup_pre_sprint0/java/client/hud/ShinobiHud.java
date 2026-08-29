package com.example.shinobicore.client.hud;

import com.example.shinobicore.client.LoadoutHudState;
import com.example.shinobicore.stat.component.IChakraComponent;
import com.example.shinobicore.stat.component.IDojutsuComponent;
import com.example.shinobicore.stat.component.IJutsuComponent;
import com.example.shinobicore.stat.component.NinjaComponents;
import net.fabricmc.fabric.api.client.rendering.v1.HudRenderCallback;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.font.TextRenderer;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.network.ClientPlayerEntity;

/** Compact HUD in top-left: chakra, fatigue, loadouts, dojutsu. */
public final class ShinobiHud {

    private ShinobiHud() {}

    public static void init() {
        HudRenderCallback.EVENT.register((context, delta) -> {
            MinecraftClient client = MinecraftClient.getInstance();
            if (client == null || client.player == null) return;
            if (client.currentScreen != null) return;
            draw(client, context);
        });
    }

    private static void draw(MinecraftClient client, DrawContext context) {
        ClientPlayerEntity player = client.player;
        TextRenderer tr = client.textRenderer;
        int x = 4;
        int y = 4;

        IChakraComponent chakra = NinjaComponents.getChakra(player);
        IJutsuComponent jutsu = NinjaComponents.getJutsu(player);
        IDojutsuComponent doj = NinjaComponents.getDojutsu(player);
        if (chakra == null) return;

        // Chakra bar
        float cRatio = chakra.getMaxChakra() > 0 ? chakra.getCurrentChakra() / chakra.getMaxChakra() : 0f;
        context.fill(x, y, x + 92, y + 7, 0xAA000000);
        context.fill(x + 1, y + 1, x + 1 + (int) (90 * cRatio), y + 6, 0xFF33AAFF);
        context.drawText(tr, "Chakra", x + 96, y, 0xFFBFE6FF, true);
        y += 9;

        // Fatigue bar
        float fRatio = chakra.getFatigue() / 100.0f;
        context.fill(x, y, x + 92, y + 7, 0xAA000000);
        context.fill(x + 1, y + 1, x + 1 + (int) (90 * fRatio), y + 6, 0xFFE6D333);
        context.drawText(tr, "Fatigue", x + 96, y, 0xFFF5E6A3, true);
        y += 11;

        // Loadouts
        if (jutsu != null) {
            drawLoadout(context, tr, x, y, "A", jutsu.getLoadout(0), LoadoutHudState.selA);
            y += 16;
            drawLoadout(context, tr, x, y, "B", jutsu.getLoadout(1), LoadoutHudState.selB);
            y += 16;
        }

        // Dojutsu
        if (doj != null && doj.getActiveDojutsu() != null) {
            context.drawText(tr, doj.getActiveDojutsu() + " (stage " + doj.getActiveStage() + ")",
                x, y, 0xFFFF9EC7, true);
        }
    }

    private static void drawLoadout(DrawContext context, TextRenderer tr, int x, int y,
                                    String label, String[] slots, int selected) {
        context.drawText(tr, label, x, y + 3, 0xFFFFFFFF, true);
        int sx = x + 10;
        for (int i = 0; i < 5; i++) {
            String id = slots != null && i < slots.length ? slots[i] : null;
            int border = (i == selected) ? 0xFFFFFFFF : 0xAA888888;
            context.fill(sx, y, sx + 12, y + 12, 0xAA222222);
            context.fill(sx, y, sx + 12, y + 1, border);
            context.fill(sx, y + 11, sx + 12, y + 12, border);
            context.fill(sx, y, sx + 1, y + 12, border);
            context.fill(sx + 11, y, sx + 12, y + 12, border);
            if (id != null) {
                String letter = shortName(id);
                context.drawText(tr, letter, sx + 3, y + 2, 0xFFFFD7E6, true);
            }
            sx += 14;
        }
    }

    private static String shortName(String jutsuId) {
        String s = jutsuId;
        int idx = s.indexOf(':');
        if (idx >= 0 && idx + 1 < s.length()) {
            s = s.substring(idx + 1);
        }
        return s.isEmpty() ? "?" : s.substring(0, 1).toUpperCase();
    }
}
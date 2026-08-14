$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$f = "E:\Games\mod\src\main\java\com\example\shinobicore\client\JutsuSlotHud.java"

$code = @'
package com.example.shinobicore.client;

import net.fabricmc.fabric.api.client.rendering.v1.HudRenderCallback;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.font.TextRenderer;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuRegistry;
import com.example.shinobicore.stat.ElementType;

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

        for (int i = 0; i < SLOT_COUNT; i++) {
            int sx = startX + i * (slotSize + gap);
            String jutsuId = getActiveJutsu(i);
            boolean hasJutsu = jutsuId != null && !jutsuId.isEmpty();

            ctx.fill(sx - 1, y - 1, sx + slotSize + 1, y + slotSize + 1, 0xFF000000);
            ctx.fill(sx, y, sx + slotSize, y + slotSize, hasJutsu ? 0xCC223344 : 0xCC111111);
            ctx.fill(sx, y, sx + slotSize, y + 1, 0xFF556677);

            if (hasJutsu) {
                JutsuDefinition def = JutsuRegistry.get(jutsuId);
                int col = getNatureColor(def);
                ctx.fill(sx + 2, y + 2, sx + slotSize - 2, y + slotSize - 2, col);

                String name = def != null ? def.name() : jutsuId.substring(jutsuId.lastIndexOf(':') + 1);
                String letter = name.substring(0, 1).toUpperCase();
                int tw = tr.getWidth(letter);
                ctx.drawText(tr, letter, sx + slotSize / 2 - tw / 2, y + slotSize / 2 - 4, 0xFFFFFF, true);
            }

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
        ElementType nature = def.nature();
        if (nature == null) return 0xCC888888;
        return switch (nature) {
            case FIRE -> 0xCCFF5522;
            case WATER -> 0xCC2288FF;
            case WIND -> 0xCC88DD88;
            case LIGHTNING -> 0xCCFFDD44;
            case EARTH -> 0xCC996633;
            default -> 0xCC666688;
        };
    }
}
'@

[System.IO.File]::WriteAllText($f, $code, $utf8)
Write-Host "[OK] JutsuSlotHud.java fixed (ElementType enum)"
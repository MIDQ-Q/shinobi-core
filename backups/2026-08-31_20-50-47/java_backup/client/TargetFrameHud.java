package com.example.shinobicore.client;

import net.fabricmc.fabric.api.client.rendering.v1.HudRenderCallback;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.font.TextRenderer;
import net.minecraft.entity.LivingEntity;
import net.minecraft.util.hit.EntityHitResult;
import net.minecraft.util.hit.HitResult;

public class TargetFrameHud {
    private static boolean registered = false;
    public static void register() {
        if (registered) return;
        registered = true;
        HudRenderCallback.EVENT.register((ctx, tick) -> render(ctx));
    }
    private static void render(DrawContext ctx) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client == null || client.player == null || client.options.hudHidden) return;
        if (client.crosshairTarget == null || client.crosshairTarget.getType() != HitResult.Type.ENTITY) return;
        var ent = ((EntityHitResult) client.crosshairTarget).getEntity();
        if (!(ent instanceof LivingEntity liv)) return;
        TextRenderer tr = client.textRenderer;
        int sw = client.getWindow().getScaledWidth();
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
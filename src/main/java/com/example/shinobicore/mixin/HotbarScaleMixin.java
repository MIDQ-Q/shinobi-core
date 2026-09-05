package com.example.shinobicore.mixin;

import com.example.shinobicore.config.ModConfig;
import com.llamalad7.mixinextras.injector.wrapoperation.Operation;
import com.llamalad7.mixinextras.injector.wrapoperation.WrapOperation;
import com.mojang.blaze3d.systems.RenderSystem;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.gui.hud.InGameHud;
import net.minecraft.client.util.math.MatrixStack;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;

@Mixin(InGameHud.class)
public abstract class HotbarScaleMixin {

    @WrapOperation(
            method = "render",
            at = @At(value = "INVOKE",
                    target = "Lnet/minecraft/client/gui/hud/InGameHud;renderHotbar(FLnet/minecraft/client/gui/DrawContext;)V")
    )
    private void shinobicore$scaleHotbar(InGameHud instance, float tickDelta, DrawContext context, Operation<Void> original) {
        applyScale(context, true);
        original.call(instance, tickDelta, context);
        applyScale(context, false);
    }

    // require=0: safe no-op if the method signature differs in this mapping
    @WrapOperation(
            method = "render",
            require = 0,
            at = @At(value = "INVOKE",
                    target = "Lnet/minecraft/client/gui/hud/InGameHud;renderExperienceBar(Lnet/minecraft/client/gui/DrawContext;I)V")
    )
    private void shinobicore$scaleXpBar(InGameHud instance, DrawContext context, int yOffset, Operation<Void> original) {
        applyScale(context, true);
        original.call(instance, context, yOffset);
        applyScale(context, false);
    }

    private void applyScale(DrawContext context, boolean on) {
        ModConfig.Hud cfg = ModConfig.instance.hud;
        if (!cfg.hotbarModify) return;
        MinecraftClient client = MinecraftClient.getInstance();
        int sw = client.getWindow().getScaledWidth();
        int sh = client.getWindow().getScaledHeight();
        MatrixStack m = context.getMatrices();
        if (on) {
            m.push();
            float s = cfg.hotbarScale;
            m.translate(sw / 2f, sh - 22, 0);
            m.scale(s, s, 1f);
            m.translate(-sw / 2f, -(sh - 22), 0);
            RenderSystem.enableBlend();
            RenderSystem.setShaderColor(1f, 1f, 1f, cfg.hotbarAlpha);
        } else {
            RenderSystem.setShaderColor(1f, 1f, 1f, 1f);
            m.pop();
        }
    }
}
package com.example.shinobicore.mixin;

import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.gui.hud.InGameHud;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(InGameHud.class)
public abstract class HideVanillaStatusMixin {

    // Полностью скрываем ванильную панель статусов (сердца, голод, броня, воздух)
    @Inject(method = "renderStatusBars", at = @At("HEAD"), cancellable = true)
    private void shinobicore_hideStatusBars(DrawContext context, CallbackInfo ci) {
        ci.cancel();
    }
}
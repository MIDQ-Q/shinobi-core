package com.example.shinobicore.mixin;

import com.example.shinobicore.client.CinematicCamera;
import net.minecraft.client.render.GameRenderer;
import net.minecraft.client.util.math.MatrixStack;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(GameRenderer.class)
public abstract class GameRendererMixin {
    // === УБРАЛИ getFov mixin (больше не трогаем FOV) ===
    // === УБРАЛИ renderWorld mixin (тряска теперь в CameraMixin) ===
    
    // Оставляем класс пустым для будущих расширений
    // или можно полностью удалить файл
}
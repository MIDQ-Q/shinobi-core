package com.example.shinobicore.mixin;

import com.example.shinobicore.client.CinematicCamera;
import com.example.shinobicore.client.movement.MovementFeel;
import com.example.shinobicore.config.ModConfig;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.client.render.Camera;
import net.minecraft.entity.Entity;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.BlockView;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Shadow;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

/**
 * Combat/Movement Pack (1.1.4): оживляет CinematicCamera и MovementFeel.
 *
 * До этого камера-система мода считала значения (тряска, смещения), но их
 * никто не применял — не было хука. Миксин в Camera.update (TAIL) применяет:
 *   1. тряску (удары, приземления, парирование) — дрожание yaw/pitch + позиции;
 *   2. покачивание при беге по воде и просадку при приземлении (bob + dip);
 *   3. наклон (roll) к стене при wall-run/подъёме — через Quaternionf.rotateZ;
 *   4. камеру «за правым плечом» в третьем лице (config: cameraFx.shoulderEnabled).
 *
 * Все величины приходят из конфигов (cameraFx.*) и MovementFeel; эффекты
 * можно полностью отключить, не трогая код.
 */
@Mixin(Camera.class)
public abstract class CameraFxMixin {

    @Shadow protected abstract void setPos(double x, double y, double z);
    @Shadow protected abstract void setRotation(float yaw, float pitch);

    /** Знак наклона: при -1 наклон идёт «к стене» для wallSide=+1 (стена справа). */
    private static final float ROLL_SIGN = -1.0f;

    @Inject(method = "update", at = @At("RETURN"))
    private void shinobicore$applyCameraFx(BlockView area, Entity focusedEntity, boolean thirdPerson,
                                           boolean inverseView, float tickDelta, CallbackInfo ci) {
        if (!(focusedEntity instanceof ClientPlayerEntity)) return;
        Camera self = (Camera) (Object) this;
        ModConfig.CameraFx cfg = ModConfig.instance.cameraFx;
        if (cfg == null) return;

        double dx = 0.0, dy = 0.0, dz = 0.0;
        float rollDeg = 0f;
        boolean rotationDirty = false;
        float newYaw = self.getYaw();
        float newPitch = self.getPitch();

        if (cfg.effectsEnabled) {
            // --- тряска: микро-дрожание углов и позиции ---
            float shake = CinematicCamera.getShakeIntensity();
            if (shake > 0.001f) {
                float s = shake * Math.max(0f, cfg.shakeScale);
                if (s > 0.001f) {
                    newYaw += (float) (Math.random() - 0.5) * s * 2.6f;
                    newPitch += (float) (Math.random() - 0.5) * s * 2.2f;
                    rotationDirty = true;
                    dx += (Math.random() - 0.5) * s * 0.06;
                    dy += (Math.random() - 0.5) * s * 0.06;
                    dz += (Math.random() - 0.5) * s * 0.06;
                }
            }
            // --- покачивание на воде + просадка при приземлении ---
            dy += MovementFeel.getCameraDip();
            if (cfg.bobEnabled) {
                dy += MovementFeel.getCameraBob();
            }
            // --- наклон к стене ---
            if (cfg.rollEnabled) {
                rollDeg = MovementFeel.getCameraRollDeg();
            }
        }

        // --- камера за правым плечом (только третье лицо) ---
        if (cfg.shoulderEnabled && thirdPerson && CinematicCamera.isEnabled()) {
            double yawRad = Math.toRadians(self.getYaw());
            double fx = -Math.sin(yawRad), fz = Math.cos(yawRad);   // вперёд
            double rx = Math.cos(yawRad), rz = Math.sin(yawRad);    // вправо
            double side = inverseView ? -1.0 : 1.0;                 // в F5-инверсии зеркалим
            float right = (float) (CinematicCamera.getRightOffset() * side);
            float up = CinematicCamera.getUpOffset();
            float fwd = CinematicCamera.getForwardOffset();
            dx += rx * right + fx * fwd;
            dy += up;
            dz += rz * right + fz * fwd;
        }

        if (rotationDirty) {
            setRotation(newYaw, newPitch);
        }
        if (dx != 0.0 || dy != 0.0 || dz != 0.0) {
            Vec3d pos = self.getPos();
            setPos(pos.x + dx, pos.y + dy, pos.z + dz);
        }
        if (rollDeg != 0f) {
            // roll в 1.20.1 делается поворотом кватерниона камеры вокруг оси Z
            self.getRotation().rotateZ((float) Math.toRadians(rollDeg * ROLL_SIGN));
        }
    }
}
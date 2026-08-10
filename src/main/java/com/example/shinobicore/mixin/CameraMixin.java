package com.example.shinobicore.mixin;

import com.example.shinobicore.client.CinematicCamera;
import net.minecraft.client.render.Camera;
import net.minecraft.entity.Entity;
import net.minecraft.util.math.MathHelper;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.BlockView;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Shadow;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(Camera.class)
public abstract class CameraMixin {

    @Shadow private float yaw;
    @Shadow private float pitch;

    @Shadow public abstract void setPos(double x, double y, double z);
    @Shadow public abstract Vec3d getPos();

    @Inject(method = "update", at = @At("TAIL"))
    private void shinobicore_applyOverShoulderCamera(BlockView area, Entity focusedEntity,
                                                      boolean thirdPerson, boolean inverseView,
                                                      float tickDelta, CallbackInfo ci) {
        if (!CinematicCamera.isEnabled() || !thirdPerson || inverseView) return;
        if (focusedEntity == null) return;

        Vec3d currentPos = this.getPos();

        float rightOffset = CinematicCamera.getRightOffset();
        float upOffset = CinematicCamera.getUpOffset();
        float forwardOffset = CinematicCamera.getForwardOffset();
        float distanceReduction = CinematicCamera.getDistanceReduction();

        // === Вычисляем векторы на основе yaw/pitch камеры ===
        float yawRad = this.yaw * 0.017453292F;
        float pitchRad = this.pitch * 0.017453292F;

        // Forward vector (куда смотрит камера)
        double forwardX = -MathHelper.sin(yawRad) * MathHelper.cos(pitchRad);
        double forwardY = -MathHelper.sin(pitchRad);
        double forwardZ = MathHelper.cos(yawRad) * MathHelper.cos(pitchRad);

        // Right vector (перпендикуляр вправо в горизонтальной плоскости)
        double rightX = Math.cos(yawRad + Math.PI / 2.0);
        double rightZ = Math.sin(yawRad + Math.PI / 2.0);

        // Применяем смещения
        double newX = currentPos.x;
        double newY = currentPos.y;
        double newZ = currentPos.z;

        // 1. Смещение вправо (за правое плечо)
        newX += rightX * rightOffset;
        newZ += rightZ * rightOffset;

        // 2. Смещение вверх (чуть выше плеча)
        newY += upOffset;

        // 3. Смещение ВПЕРЁД (приближение камеры)
        // Forward вектор указывает ОТ камеры К игроку, поэтому вычитаем
        // (камера "отодвинута" от игрока в направлении противоположном взгляду)
        newX -= forwardX * forwardOffset;
        newY -= forwardY * forwardOffset;
        newZ -= forwardZ * forwardOffset;

        // 4. Сокращение дистанции (если ванила поставила слишком далеко)
        // Вектор от текущей позиции к игроку
        Vec3d toPlayer = new Vec3d(
                focusedEntity.getX() - newX,
                focusedEntity.getEyeY() - newY,
                focusedEntity.getZ() - newZ
        );
        double distToPlayer = toPlayer.length();
        if (distToPlayer > distanceReduction + 0.5) {
            Vec3d norm = toPlayer.normalize();
            newX += norm.x * distanceReduction * 0.5;
            newY += norm.y * distanceReduction * 0.5;
            newZ += norm.z * distanceReduction * 0.5;
        }

        // === Лёгкая тряска ===
        Vec3d shake = CinematicCamera.getShakeOffset();
        newX += shake.x;
        newY += shake.y;
        newZ += shake.z;

        setPos(newX, newY, newZ);
    }
}
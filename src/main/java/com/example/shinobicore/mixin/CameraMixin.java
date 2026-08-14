package com.example.shinobicore.mixin;

import com.example.shinobicore.client.RpgCamera;
import net.minecraft.client.render.Camera;
import net.minecraft.entity.Entity;
import net.minecraft.util.math.MathHelper;
import net.minecraft.util.math.Vec3d;
import net.minecraft.util.hit.HitResult;
import net.minecraft.world.BlockView;
import net.minecraft.world.RaycastContext;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(Camera.class)
public abstract class CameraMixin {
    @Inject(method = "update", at = @At("TAIL"))
    private void shinobicore$rpgCamera(BlockView area, Entity focusedEntity, boolean thirdPerson,
                                       boolean inverseView, float tickDelta, CallbackInfo ci) {
        if (!RpgCamera.enabled || !thirdPerson || focusedEntity == null) return;
        Camera self = (Camera) (Object) this;

        // Interpolated eye (smooth movement)
        double ex = MathHelper.lerp(tickDelta, focusedEntity.lastRenderX, focusedEntity.getX());
        double ey = MathHelper.lerp(tickDelta, focusedEntity.lastRenderY, focusedEntity.getY());
        double ez = MathHelper.lerp(tickDelta, focusedEntity.lastRenderZ, focusedEntity.getZ());
        Vec3d eye = new Vec3d(ex, ey + focusedEntity.getStandingEyeHeight(), ez);

        float yaw = self.getYaw();
        float pitch = self.getPitch();
        float yr = yaw * ((float) Math.PI / 180f);
        float pr = pitch * ((float) Math.PI / 180f);
        Vec3d forward = new Vec3d(
            -MathHelper.sin(yr) * MathHelper.cos(pr),
            -MathHelper.sin(pr),
            MathHelper.cos(yr) * MathHelper.cos(pr));
        float rightYaw = (yaw + 90f) * ((float) Math.PI / 180f);
        Vec3d right = new Vec3d(-MathHelper.sin(rightYaw), 0, MathHelper.cos(rightYaw));
        float shoulderOff = RpgCamera.shoulder * RpgCamera.shoulderSide;
        float dist = RpgCamera.distance;
        Vec3d desired = eye.subtract(forward.multiply(dist)).add(right.multiply(shoulderOff));
        HitResult hit = area.raycast(new RaycastContext(eye, desired,
            RaycastContext.ShapeType.VISUAL, RaycastContext.FluidHandling.NONE, focusedEntity));
        if (hit.getType() == HitResult.Type.BLOCK) {
            double d = eye.distanceTo(hit.getPos()) - 0.25;
            if (d < dist) {
                dist = (float) Math.max(0.5, d);
                desired = eye.subtract(forward.multiply(dist))
                    .add(right.multiply(shoulderOff * (dist / RpgCamera.distance)));
            }
        }
        Vec3d smooth = RpgCamera.smooth(desired);
        ((CameraAccessor) self).shinobicore$setPos(smooth.x, smooth.y, smooth.z);
    }
}
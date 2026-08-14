$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$clientDir = "E:\Games\mod\src\main\java\com\example\shinobicore\client"
$mixinDir = "E:\Games\mod\src\main\java\com\example\shinobicore\mixin"
function Write-File($p, $c) { [System.IO.File]::WriteAllText($p, $c, $utf8); Write-Host "[OK] $p" }

# ============ RpgCamera: enabled=true, shoulderSide flip ============
Write-File "$clientDir\RpgCamera.java" @'
package com.example.shinobicore.client;

import net.minecraft.util.math.Vec3d;

public class RpgCamera {
    public static boolean enabled = true;        // по умолчанию ВКЛ
    public static float distance = 3.0f;
    public static float shoulder = 0.7f;
    public static float smoothing = 0.60f;       // больше = плавнее
    public static int shoulderSide = 1;          // +1 = правое плечо, -1 = левое
    private static Vec3d lastPos = null;

    public static void toggle() {
        enabled = !enabled;
        lastPos = null;
    }

    public static void flipShoulder() {
        shoulderSide = -shoulderSide;
        lastPos = null;
    }

    public static Vec3d smooth(Vec3d target) {
        if (lastPos == null || lastPos.squaredDistanceTo(target) > 25) {
            lastPos = target;
        } else {
            lastPos = lastPos.lerp(target, smoothing);
        }
        return lastPos;
    }
}
'@

# ============ RpgCameraKeybind: F5 = shoulder flip ============
Write-File "$clientDir\RpgCameraKeybind.java" @'
package com.example.shinobicore.client;

import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.keybinding.v1.KeyBindingHelper;
import net.minecraft.client.option.KeyBinding;

public class RpgCameraKeybind {
    public static final KeyBinding FLIP = new KeyBinding(
        "key.shinobicore.camera_flip", 63, "key.category.shinobicore"); // F5

    public static void register() {
        KeyBindingHelper.registerKeyBinding(FLIP);
        ClientTickEvents.END_CLIENT_TICK.register(client -> {
            while (FLIP.wasPressed()) RpgCamera.flipShoulder();
        });
    }
}
'@

# ============ CameraMixin: use shoulderSide ============
Write-File "$mixinDir\CameraMixin.java" @'
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
        Vec3d eye = focusedEntity.getEyePos();
        float yaw = self.getYaw();
        float pitch = self.getPitch();
        float yr = yaw * ((float) Math.PI / 180f);
        float pr = pitch * ((float) Math.PI / 180f);
        Vec3d forward = new Vec3d(
            -MathHelper.sin(yr) * MathHelper.cos(pr),
            -MathHelper.sin(pr),
            MathHelper.cos(yr) * MathHelper.cos(pr));
        float ry = (yaw + 90f) * ((float) Math.PI / 180f);
        Vec3d right = new Vec3d(-MathHelper.sin(ry), 0, MathHelper.cos(ry));
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
'@

Write-Host "=== CAMERA FIX DONE ==="
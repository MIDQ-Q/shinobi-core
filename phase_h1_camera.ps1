$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main"
$clientDir = "$base\java\com\example\shinobicore\client"
$mixinDir = "$base\java\com\example\shinobicore\mixin"
$mixinsJson = "$base\resources\shinobicore.mixins.json"
function Write-File($p, $c) { [System.IO.File]::WriteAllText($p, $c, $utf8); Write-Host "[OK] $p" }

# ============ RpgCamera state ============
Write-File "$clientDir\RpgCamera.java" @'
package com.example.shinobicore.client;

import net.minecraft.util.math.Vec3d;

public class RpgCamera {
    public static boolean enabled = false;
    public static float distance = 3.0f;
    public static float shoulder = 0.7f;
    public static float smoothing = 0.35f;
    private static Vec3d lastPos = null;

    public static void toggle() {
        enabled = !enabled;
        lastPos = null;
    }

    public static Vec3d smooth(Vec3d target) {
        if (lastPos == null || lastPos.squaredDistanceTo(target) > 16) {
            lastPos = target;
        } else {
            lastPos = lastPos.lerp(target, smoothing);
        }
        return lastPos;
    }
}
'@

# ============ RpgCameraKeybind (G key) ============
Write-File "$clientDir\RpgCameraKeybind.java" @'
package com.example.shinobicore.client;

import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.keybinding.v1.KeyBindingHelper;
import net.minecraft.client.option.KeyBinding;

public class RpgCameraKeybind {
    public static final KeyBinding KEY = new KeyBinding(
        "key.shinobicore.rpg_camera", 71, "key.category.shinobicore");

    public static void register() {
        KeyBindingHelper.registerKeyBinding(KEY);
        ClientTickEvents.END_CLIENT_TICK.register(client -> {
            while (KEY.wasPressed()) RpgCamera.toggle();
        });
    }
}
'@

# ============ CameraMixin ============
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
        float shoulder = inverseView ? -RpgCamera.shoulder : RpgCamera.shoulder;
        float dist = RpgCamera.distance;
        Vec3d desired = eye.subtract(forward.multiply(dist)).add(right.multiply(shoulder));
        HitResult hit = area.raycast(new RaycastContext(eye, desired,
            RaycastContext.ShapeType.VISUAL, RaycastContext.FluidHandling.NONE, focusedEntity));
        if (hit.getType() == HitResult.Type.BLOCK) {
            double d = eye.distanceTo(hit.getPos()) - 0.25;
            if (d < dist) {
                dist = (float) Math.max(0.5, d);
                desired = eye.subtract(forward.multiply(dist))
                    .add(right.multiply(shoulder * (dist / RpgCamera.distance)));
            }
        }
        Vec3d smooth = RpgCamera.smooth(desired);
        self.setPos(smooth.x, smooth.y, smooth.z);
    }
}
'@

# ============ Register keybind in ShinobiCoreClient ============
$scc = [System.IO.File]::ReadAllText("$clientDir\ShinobiCoreClient.java", $utf8)
if (-not $scc.Contains("RpgCameraKeybind.register")) {
    $scc = $scc.Replace("ChakraAuraVisual.register();",
        "ChakraAuraVisual.register();`n        com.example.shinobicore.client.RpgCameraKeybind.register(); // PHASE_H_CAMERA")
    [System.IO.File]::WriteAllText("$clientDir\ShinobiCoreClient.java", $scc, $utf8)
    Write-Host "[OK] ShinobiCoreClient: RpgCameraKeybind registered"
}

# ============ Add CameraMixin to mixins.json (client section) ============
$mj = [System.IO.File]::ReadAllText($mixinsJson, $utf8)
if (-not $mj.Contains("CameraMixin")) {
    $mj = $mj.Replace('"client": [', '"client": [
    "CameraMixin",')
    [System.IO.File]::WriteAllText($mixinsJson, $mj, $utf8)
    Write-Host "[OK] mixins.json: CameraMixin added"
}

Write-Host "=== PHASE H1 (RPG CAMERA) DONE ==="
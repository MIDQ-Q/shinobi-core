$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main"
function Write-File($p, $c) {
    $dir = [System.IO.Path]::GetDirectoryName($p)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($p, $c, $utf8); Write-Host "[OK] $p"
}

# ============ 1. CameraMixin - rewritten with proper variable names ============
Write-File "$base\java\com\example\shinobicore\mixin\CameraMixin.java" @'
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
'@

# ============ 2. ActionLogger (util folder) ============
Write-File "$base\java\com\example\shinobicore\util\ActionLogger.java" @'
package com.example.shinobicore.util;

import net.fabricmc.loader.api.FabricLoader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.LocalTime;

public class ActionLogger {
    private static final Path FILE = FabricLoader.getInstance().getGameDir().resolve("shinobicore_actions.log");
    public static synchronized void log(String msg) {
        try {
            String line = "[" + LocalTime.now() + "] " + msg + "\n";
            Files.write(FILE, line.getBytes(), StandardOpenOption.CREATE, StandardOpenOption.APPEND);
        } catch (Exception e) { }
    }
}
'@

# ============ 3. DebugCommands (with logging) ============
Write-File "$base\java\com\example\shinobicore\DebugCommands.java" @'
package com.example.shinobicore;

import com.mojang.brigadier.CommandDispatcher;
import net.fabricmc.api.ModInitializer;
import net.fabricmc.fabric.api.command.v2.CommandRegistrationCallback;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import java.lang.reflect.Method;
import java.util.Collection;

import static net.minecraft.server.command.CommandManager.literal;

public class DebugCommands implements ModInitializer {
    @Override
    public void onInitialize() {
        CommandRegistrationCallback.EVENT.register((d, r, e) ->
            d.register(literal("unlockall").executes(ctx -> unlock(ctx.getSource()))));
    }

    private int unlock(ServerCommandSource src) {
        try {
            ServerPlayerEntity p = src.getPlayer();
            Object data = p.getClass().getMethod("shinobicore_getData").invoke(p);
            if (data == null) return 0;
            for (Object et : Class.forName("com.example.shinobicore.stat.ElementType").getEnumConstants()) {
                call(data, new Class[]{Class.forName("com.example.shinobicore.stat.ElementType")},
                     new String[]{"unlockNature","setNatureUnlocked","addNature"}, et);
            }
            for (Object st : Class.forName("com.example.shinobicore.stat.StatType").getEnumConstants()) {
                call(data, new Class[]{Class.forName("com.example.shinobicore.stat.StatType"), int.class},
                     new String[]{"setStatLevel","setStat","addStat"}, st, 100);
            }
            Class reg = Class.forName("com.example.shinobicore.jutsu.JutsuRegistry");
            Collection<?> all = (Collection<?>) reg.getMethod("getAll").invoke(null);
            for (Object jd : all) {
                String id = (String) jd.getClass().getMethod("id").invoke(jd);
                call(data, new Class[]{String.class}, new String[]{"learnJutsu","unlockJutsu","addJutsu"}, id);
            }
            call(data, new Class[]{int.class}, new String[]{"addSkillPoints","giveSkillPoints","setSkillPoints"}, 300);
            com.example.shinobicore.util.ActionLogger.log("unlockall by " + p.getName().getString());
            p.sendMessage(Text.literal("\u00a7aAll natures/stats/jutsu unlocked! +300 SP"), false);
        } catch (Exception ex) {
            com.example.shinobicore.util.ActionLogger.log("unlockall error: " + ex);
        }
        return 1;
    }

    private void call(Object target, Class[] sig, String[] names, Object... args) {
        for (String n : names) {
            try {
                Method m = target.getClass().getMethod(n, sig);
                m.invoke(target, args);
                return;
            } catch (Exception ignored) { }
        }
    }
}
'@

Write-Host "=== BATCH MISC V2 DONE ==="
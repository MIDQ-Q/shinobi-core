$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main"
function Write-File($p, $c) { [System.IO.File]::WriteAllText($p, $c, $utf8); Write-Host "[OK] $p" }

# ============ 1. Camera jitter fix (interpolated eye) ============
$cm = "$base\java\com\example\shinobicore\mixin\CameraMixin.java"
$c = [System.IO.File]::ReadAllText($cm, $utf8)
$c = $c.Replace(
    "Vec3d eye = focusedEntity.getEyePos();",
    "double rx = MathHelper.lerp(tickDelta, focusedEntity.lastRenderX, focusedEntity.getX());`n        double ry = MathHelper.lerp(tickDelta, focusedEntity.lastRenderY, focusedEntity.getY());`n        double rz = MathHelper.lerp(tickDelta, focusedEntity.lastRenderZ, focusedEntity.getZ());`n        Vec3d eye = new Vec3d(rx, ry + focusedEntity.getStandingEyeHeight(), rz);"
)
[System.IO.File]::WriteAllText($cm, $c, $utf8)
Write-Host "[OK] CameraMixin: interpolated eye (fix jitter)"

# ============ 2. RpgCamera smoothing up ============
$rc = "$base\java\com\example\shinobicore\client\RpgCamera.java"
$c = [System.IO.File]::ReadAllText($rc, $utf8)
$c = $c.Replace("public static float smoothing = 0.60f;", "public static float smoothing = 0.85f;")
[System.IO.File]::WriteAllText($rc, $c, $utf8)
Write-Host "[OK] RpgCamera: smoothing 0.85"

# ============ 3. TargetFrameHud (target frame only) ============
Write-File "$base\java\com\example\shinobicore\client\TargetFrameHud.java" @'
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
'@

# ============ 4. ActionLogger ============
Write-File "$base\java\com\example\shinobicore\util\ActionLogger.java" @'
package com.example.shinobicore.util;

import net.fabricmc.loader.api.FabricLoader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.LocalTime;

public class ActionLogger {
    private static final Path FILE = FabricLoader.getGameDir().resolve("shinobicore_actions.log");
    public static synchronized void log(String msg) {
        try {
            String line = "[" + LocalTime.now() + "] " + msg + "\n";
            Files.write(FILE, line.getBytes(), StandardOpenOption.CREATE, StandardOpenOption.APPEND);
        } catch (Exception e) { }
    }
}
'@

# ============ 5. DebugCommands (/unlockall) ============
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

# ============ 6. Register DebugCommands entrypoint ============
$fm = "E:\Games\mod\src\main\resources\fabric.mod.json"
$c = [System.IO.File]::ReadAllText($fm, $utf8)
if (-not $c.Contains("DebugCommands")) {
    $c = $c.Replace('"com.example.shinobicore.ShinobiCore"',
        '"com.example.shinobicore.ShinobiCore",
    "com.example.shinobicore.DebugCommands"')
    [System.IO.File]::WriteAllText($fm, $c, $utf8)
    Write-Host "[OK] fabric.mod.json: DebugCommands entrypoint"
}

# ============ 7. Register TargetFrameHud ============
$scc = "$base\java\com\example\shinobicore\client\ShinobiCoreClient.java"
$c = [System.IO.File]::ReadAllText($scc, $utf8)
if (-not $c.Contains("TargetFrameHud.register")) {
    $c = $c.Replace("HudRenderCallback.EVENT.register(ChakraHudRenderer::render);",
        "HudRenderCallback.EVENT.register(ChakraHudRenderer::render);`n        TargetFrameHud.register();")
    [System.IO.File]::WriteAllText($scc, $c, $utf8)
    Write-Host "[OK] ShinobiCoreClient: TargetFrameHud registered"
}

# ============ 8. Buff weak jutsu (Wind Slash + Blade Dance) ============
Write-File "$base\resources\data\shinobicore\jutsu\kenjutsu_wind_slash.json" @'
{"id":"shinobicore:kenjutsu_wind_slash","name":"Kenjutsu: Wind Slash","category":"taijutsu","nature":"wind","type":"projectile","params":{"speed":2.6,"radius":2.5,"particle":"wind","lifetime":60,"knockback":1.2,"pierce":1},"baseCost":24,"baseDamage":16,"strain":7,"requiredUsesForFullProficiency":40,"requirements":{"taijutsu":28,"nature_wind":15}}
'@
Write-File "$base\resources\data\shinobicore\jutsu\kenjutsu_blade_dance.json" @'
{"id":"shinobicore:kenjutsu_blade_dance","name":"Kenjutsu: Blade Dance","category":"taijutsu","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.ChainMeleeBehavior","params":{"range":4.0,"hits":8,"coneAngle":180},"baseCost":30,"baseDamage":22,"strain":9,"requiredUsesForFullProficiency":50,"requirements":{"taijutsu":30,"control":20}}
'@
Write-Host "[OK] Buffed Wind Slash + Blade Dance"

Write-Host "=== BATCH MISC DONE ==="
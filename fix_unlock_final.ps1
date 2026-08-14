$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main"
function Write-File($p, $c) {
    $dir = [System.IO.Path]::GetDirectoryName($p)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($p, $c, $utf8); Write-Host "[OK] $p"
}

# ============ 1. fabric.mod.json: add DebugCommands entrypoint ============
$fm = "$base\resources\fabric.mod.json"
$c = [System.IO.File]::ReadAllText($fm, $utf8)
if (-not $c.Contains("DebugCommands")) {
    $c = $c.Replace('"com.example.shinobicore.ShinobiCore"',
        '"com.example.shinobicore.ShinobiCore",`n      "com.example.shinobicore.DebugCommands"')
    [System.IO.File]::WriteAllText($fm, $c, $utf8)
    Write-Host "[OK] fabric.mod.json: DebugCommands entrypoint added"
} else { Write-Host "[SKIP] entrypoint exists" }

# ============ 2. ShinobiCoreClient: register TargetFrameHud ============
$scc = "$base\java\com\example\shinobicore\client\ShinobiCoreClient.java"
$c = [System.IO.File]::ReadAllText($scc, $utf8)
if (-not $c.Contains("TargetFrameHud.register")) {
    $c = $c.Replace("HudRenderCallback.EVENT.register(ChakraHudRenderer::render);",
        "HudRenderCallback.EVENT.register(ChakraHudRenderer::render);`n        com.example.shinobicore.client.TargetFrameHud.register();")
    [System.IO.File]::WriteAllText($scc, $c, $utf8)
    Write-Host "[OK] TargetFrameHud registered"
} else { Write-Host "[SKIP] TargetFrameHud registered" }

# ============ 3. Buff weak jutsu JSONs ============
Write-File "$base\resources\data\shinobicore\jutsu\kenjutsu_wind_slash.json" @'
{"id":"shinobicore:kenjutsu_wind_slash","name":"Kenjutsu: Wind Slash","category":"taijutsu","nature":"wind","type":"projectile","params":{"speed":2.6,"radius":2.5,"particle":"wind","lifetime":60,"knockback":1.2,"pierce":1},"baseCost":24,"baseDamage":16,"strain":7,"requiredUsesForFullProficiency":40,"requirements":{"taijutsu":28,"nature_wind":15}}
'@
Write-File "$base\resources\data\shinobicore\jutsu\kenjutsu_blade_dance.json" @'
{"id":"shinobicore:kenjutsu_blade_dance","name":"Kenjutsu: Blade Dance","category":"taijutsu","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.ChainMeleeBehavior","params":{"range":4.0,"hits":8,"coneAngle":180},"baseCost":30,"baseDamage":22,"strain":9,"requiredUsesForFullProficiency":50,"requirements":{"taijutsu":30,"control":20}}
'@
Write-Host "[OK] Buffed Wind Slash + Blade Dance"

# ============ 4. DebugCommands with EXACT method names ============
Write-File "$base\java\com\example\shinobicore\DebugCommands.java" @'
package com.example.shinobicore;

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
        CommandRegistrationCallback.EVENT.register((d, r, e) -> {
            d.register(literal("unlockall").executes(ctx -> unlock(ctx.getSource())));
        });
    }

    private int unlock(ServerCommandSource src) {
        try {
            ServerPlayerEntity p = src.getPlayer();
            Object data = p.getClass().getMethod("shinobicore_getData").invoke(p);
            if (data == null) { src.sendError(Text.literal("no data")); return 0; }
            int natures = 0, stats = 0, jutsus = 0;

            for (Object et : Class.forName("com.example.shinobicore.stat.ElementType").getEnumConstants()) {
                if (call(data, "setNatureUnlocked", new Class[]{Class.forName("com.example.shinobicore.stat.ElementType"), boolean.class}, et, true)) natures++;
                call(data, "setNatureLevel", new Class[]{Class.forName("com.example.shinobicore.stat.ElementType"), int.class}, et, 100);
            }
            for (Object st : Class.forName("com.example.shinobicore.stat.StatType").getEnumConstants()) {
                if (call(data, "setStatLevel", new Class[]{Class.forName("com.example.shinobicore.stat.StatType"), int.class}, st, 100)) stats++;
            }
            Class<?> reg = Class.forName("com.example.shinobicore.jutsu.JutsuRegistry");
            Collection<?> all = (Collection<?>) reg.getMethod("getAll").invoke(null);
            for (Object jd : all) {
                String id = (String) jd.getClass().getMethod("id").invoke(jd);
                if (call(data, "learnJutsu", new Class[]{String.class}, id)) jutsus++;
                else call(data, "learnJutsu", new Class[]{Class.forName("com.example.shinobicore.jutsu.JutsuDefinition")}, jd);
            }
            call(data, "addSkillPoints", new Class[]{int.class}, 300);
            com.example.shinobicore.util.ActionLogger.log("unlockall: natures=" + natures + " stats=" + stats + " jutsus=" + jutsus);
            p.sendMessage(Text.literal("\u00a7aUnlocked: " + natures + " natures, " + stats + " stats, " + jutsus + " jutsu. +300 SP"), false);
        } catch (Exception ex) {
            com.example.shinobicore.util.ActionLogger.log("unlockall ERROR: " + ex);
            src.sendError(Text.literal("error: " + ex.getMessage()));
        }
        return 1;
    }

    private boolean call(Object target, String name, Class[] sig, Object... args) {
        try {
            Method m = target.getClass().getMethod(name, sig);
            m.setAccessible(true);
            m.invoke(target, args);
            return true;
        } catch (Exception e) { return false; }
    }
}
'@
Write-Host "[OK] DebugCommands rewritten with exact methods"

# ============ 5. DIAGNOSTICS for new jutsu menu ============
Write-Host ""
Write-Host "========== DIAG: ClientNinjaState =========="
$cns = "$base\java\com\example\shinobicore\client\ClientNinjaState.java"
if (Test-Path $cns) { [System.IO.File]::ReadAllText($cns, $utf8) | Write-Host }

Write-Host ""
Write-Host "========== DIAG: ModPackets packet IDs =========="
$mp = "$base\java\com\example\shinobicore\network\ModPackets.java"
if (Test-Path $mp) {
    $lines = [System.IO.File]::ReadAllLines($mp, $utf8)
    foreach ($ln in $lines) {
        if ($ln -match "Identifier|static final|LOADOUT|loadout|SLOT|slot") { Write-Host $ln }
    }
}

Write-Host ""
Write-Host "========== DIAG: ProgressionScreen jutsu section =========="
$ps = "$base\java\com\example\shinobicore\client\ProgressionScreen.java"
if (Test-Path $ps) {
    $lines = [System.IO.File]::ReadAllLines($ps, $utf8)
    $print = $false
    $count = 0
    foreach ($ln in $lines) {
        if ($ln -match "class ProgressionScreen|jutsu|Jutsu|slot|Slot|dropdown|List|learned|Learned") {
            Write-Host $ln
            $count++
            if ($count -gt 80) { break }
        }
    }
}

Write-Host "=== FIX DONE + DIAG PRINTED ==="
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$java = "$root\src\main\java\com\example\shinobicore"
$res  = "$root\src\main\resources"

function Write-File($p, $c) {
    $dir = [System.IO.Path]::GetDirectoryName($p)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] $($p.Replace($root, ''))"
}
function Read-File($p) { return [System.IO.File]::ReadAllText($p, $utf8) }

# Удалитель дублей import-строк (безопасен: трогает только точные совпадения)
function Remove-DuplicateImports($content) {
    $lines = $content -split "`n"
    $seen = @{}
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($ln in $lines) {
        $t = $ln.TrimEnd("`r").Trim()
        if ($t.StartsWith("import ")) {
            if ($seen.ContainsKey($t)) { continue }
            $seen[$t] = $true
        }
        $out.Add($ln)
    }
    return ($out -join "`n")
}

Write-Host "=============================================="
Write-Host "  PHASE G2.5 (Part A): JAVA TECH DEBT"
Write-Host "=============================================="

# ============ 1. КРИТИЧНЫЙ ФИКС: SubstitutionBehavior ============
# Было: static long LAST_USE_MS — ОДИН кулдаун на весь сервер.
# Стало: кулдаун на каждого игрока отдельно (Map по UUID).
Write-File "$java\jutsu\custom\SubstitutionBehavior.java" @'
package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.jutsu.WallRemovalTask;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.block.Blocks;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;
import net.minecraft.text.Text;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Substitution Jutsu (Kawarimi).
 *
 * FIX (Phase G2.5): cooldown used to be a single static long shared by ALL players.
 * In multiplayer, one player's cast put the jutsu on cooldown for everyone.
 * Cooldown is now stored per-player UUID.
 */
public class SubstitutionBehavior implements JutsuBehavior {

    private static final Map<UUID, Long> LAST_USE_MS = new HashMap<>();
    private static final long COOLDOWN_MS = 10000;

    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;

        long now = System.currentTimeMillis();

        // Cheap cleanup of stale entries
        LAST_USE_MS.entrySet().removeIf(e -> now - e.getValue() > COOLDOWN_MS * 6);

        long last = LAST_USE_MS.getOrDefault(player.getUuid(), 0L);
        long since = now - last;
        if (since < COOLDOWN_MS) {
            player.sendMessage(Text.literal("\u00a7cSubstitution on cooldown: " + ((COOLDOWN_MS - since) / 1000) + "s"), false);
            return;
        }
        LAST_USE_MS.put(player.getUuid(), now);

        float teleportDistance = params.has("distance") ? params.get("distance").getAsFloat() : 8f;
        int invisDuration = params.has("invisDuration") ? params.get("invisDuration").getAsInt() : 40;

        Vec3d oldPos = player.getPos();
        Vec3d dir = player.getRotationVector().multiply(-1).normalize();
        Vec3d newPos = oldPos.add(dir.multiply(teleportDistance));

        // Particles at old position
        for (int i = 0; i < 30; i++) {
            world.spawnParticles(ParticleTypes.SMOKE,
                    oldPos.x + (Math.random() - 0.5) * 1.5, oldPos.y + Math.random() * 1.8, oldPos.z + (Math.random() - 0.5) * 1.5,
                    1, 0.1, 0.1, 0.1, 0.05);
            world.spawnParticles(ParticleTypes.LARGE_SMOKE,
                    oldPos.x + (Math.random() - 0.5) * 1.0, oldPos.y + Math.random() * 1.5, oldPos.z + (Math.random() - 0.5) * 1.0,
                    1, 0.05, 0.05, 0.05, 0.02);
        }

        // Place log at old position
        BlockPos logPos = BlockPos.ofFloored(oldPos);
        if (world.getBlockState(logPos).isAir()) {
            world.setBlockState(logPos, Blocks.OAK_LOG.getDefaultState(), 3);
            WallRemovalTask.schedule(world, List.of(logPos), 60);
        }

        world.playSound(null, BlockPos.ofFloored(oldPos), SoundEvents.ENTITY_ENDERMAN_TELEPORT, SoundCategory.PLAYERS, 1.0f, 1.0f);

        player.teleport(newPos.x, newPos.y, newPos.z);
        player.addStatusEffect(new StatusEffectInstance(StatusEffects.INVISIBILITY, invisDuration, 0, false, false));
        player.addStatusEffect(new StatusEffectInstance(StatusEffects.SPEED, invisDuration, 2, false, false));
        player.sendMessage(Text.literal("\u00a77*Substitution!*"), true);

        JutsuLogger.logBehavior("substitution", "player=" + player.getName().getString() + " dist=" + teleportDistance);
    }
}
'@

# ============ 2. Чистка дублей import во ВСЕХ Java-файлах ============
# (ShinobiCoreClient: TaijutsuSounds x3, Registries x2...; ModPackets; NinjaProjectileEntity...)
$changed = 0
Get-ChildItem -Path $java -Recurse -Filter *.java | ForEach-Object {
    $c = Read-File $_.FullName
    $n = Remove-DuplicateImports $c
    if ($n -ne $c) {
        Write-File $_.FullName $n
        $changed++
    }
}
Write-Host "[OK] Import dedupe: cleaned $changed files"

# ============ 3. ShinobiCoreClient: дубль ChakraAuraRenderer.register() ============
$f = "$java\client\ShinobiCoreClient.java"
$c = Read-File $f
$c2 = [regex]::Replace($c, '(ChakraAuraRenderer\.register\(\);[^\r\n]*)\r?\n\s*ChakraAuraRenderer\.register\(\);', '$1')
if ($c2 -ne $c) { Write-File $f $c2 } else { Write-Host "[SKIP] ChakraAura duplicate not found" }

# ============ 4. ShinobiCore: дубль регистрации genjutsu ============
$f = "$java\ShinobiCore.java"
$c = Read-File $f
$c2 = [regex]::Replace($c, '(BehaviorRegistry\.register\("genjutsu",\s*new GenjutsuBehavior\(\)\);)[^\r\n]*\r?\n\s*BehaviorRegistry\.register\("genjutsu",\s*new GenjutsuBehavior\(\)\);[^\r\n]*', '$1')
if ($c2 -ne $c) { Write-File $f $c2 } else { Write-Host "[SKIP] genjutsu duplicate not found" }

# ============ 5. KatanaDeflectMixin: строка-проверка продублирована 3 раза ============
$f = "$java\mixin\KatanaDeflectMixin.java"
$c = Read-File $f
$line = 'if (!isSeiganShield && now - data.getLastDeflectReflectMs() < 200) return;'
$pat = [regex]::Escape($line)
$c2 = [regex]::Replace($c, "(?:\s*$pat){2,}", "`n        $line")
if ($c2 -ne $c) { Write-File $f $c2 } else { Write-Host "[SKIP] KatanaDeflect duplicate not found" }

# ============ 6. Пустой файл TaijutsuAnimations (client/combat/animations) ============
$empty = "$java\client\combat\animations\TaijutsuAnimations.java"
if (Test-Path $empty) {
    if ((Get-Item $empty).Length -lt 5) {
        Remove-Item $empty -Force
        Write-Host "[OK] Removed empty TaijutsuAnimations.java"
    }
}
$dir = "$java\client\combat\animations"
if ((Test-Path $dir) -and (@(Get-ChildItem $dir -Force).Count -eq 0)) {
    Remove-Item $dir -Force
    Write-Host "[OK] Removed empty dir: animations"
}

# ============ 7. fabric.mod.json: Java >= 17 (было >=21 при байткоде 17) ============
$f = "$res\fabric.mod.json"
$c = Read-File $f
$c = $c.Replace('"java": ">=21"', '"java": ">=17"')
Write-File $f $c

# ============ 8. mixins.json: JAVA_17 + регистрация MobEntityAccessor ============
# ВАЖНО: MobEntityAccessor НЕ был зарегистрирован (прошлый скрипт вставлял его
# в несуществующую секцию "client") -> призывы могли крашиться.
$f = "$res\shinobicore.mixins.json"
$c = Read-File $f
$c = $c.Replace('"compatibilityLevel": "JAVA_21"', '"compatibilityLevel": "JAVA_17"')
if (-not $c.Contains('"MobEntityAccessor"')) {
    if ($c.Contains('"CameraAccessor",')) {
        $c = $c.Replace('"CameraAccessor",', """CameraAccessor"",`n        ""MobEntityAccessor"",""")
    } else {
        $c = $c.Replace('"mixins": [', """mixins"": [`n        ""MobEntityAccessor"",""")
    }
    Write-Host "[OK] MobEntityAccessor registered in mixins.json"
}
Write-File $f $c

Write-Host ""
Write-Host "=============================================="
Write-Host "  PART A DONE"
Write-Host "=============================================="
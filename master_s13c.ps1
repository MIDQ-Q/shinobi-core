$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcBase = Join-Path $root "src\main\java\com\example\shinobicore"
$behaviorDir = Join-Path $srcBase "jutsu\custom"
$effectsDir = Join-Path $srcBase "jutsu\effects"

Write-Host "=== SPRINT 13B-2: Unique Clan Particles ===" -ForegroundColor Cyan

function Write-File($path, $content) {
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $content, $utf8)
    Write-Host ("  [OK] " + (Split-Path $path -Leaf)) -ForegroundColor Green
}

# ============================================================
# SECTION 1: ClanParticleEffects helper
# ============================================================
Write-Host "`n[1/19] Creating ClanParticleEffects helper..." -ForegroundColor Yellow

$effectsHelper = @'
package com.example.shinobicore.jutsu.effects;

import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.particle.DustParticleEffect;
import net.minecraft.particle.ParticleEffect;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import org.joml.Vector3f;

/**
 * S13-02: Clan-specific particle and effect helpers.
 * Each clan has unique visual identity.
 */
public class ClanParticleEffects {

    // === UCHIHA: red fire ===
    public static void fireBurst(ServerWorld w, Vec3d pos, int count) {
        w.spawnParticles(ParticleTypes.FLAME, pos.x, pos.y + 1, pos.z, count, 0.6, 0.6, 0.6, 0.05);
        w.spawnParticles(ParticleTypes.LAVA, pos.x, pos.y + 1, pos.z, count/3, 0.4, 0.4, 0.4, 0.02);
    }
    public static void susanooAura(ServerWorld w, Vec3d pos) {
        w.spawnParticles(ParticleTypes.SOUL_FIRE_FLAME, pos.x, pos.y + 1, pos.z, 15, 0.5, 1.0, 0.5, 0.02);
        w.spawnParticles(dustColor(0.9f, 0.2f, 0.1f), pos.x, pos.y + 1.2, pos.z, 8, 0.3, 0.3, 0.3, 0.01);
    }

    // === HYUGA: white/blue chakra ===
    public static void byakuganPulse(ServerWorld w, Vec3d pos) {
        w.spawnParticles(dustColor(0.8f, 0.9f, 1.0f), pos.x, pos.y + 1, pos.z, 20, 0.8, 0.8, 0.8, 0.01);
        w.spawnParticles(ParticleTypes.ENCHANT, pos.x, pos.y + 1, pos.z, 10, 0.5, 0.5, 0.5, 0.1);
    }

    // === UZUMAKI: red/orange chains ===
    public static void chakraChain(ServerWorld w, Vec3d from, Vec3d to) {
        Vec3d dir = to.subtract(from).normalize();
        for (int i = 0; i < 10; i++) {
            Vec3d p = from.add(dir.multiply(i * 0.3));
            w.spawnParticles(dustColor(1.0f, 0.4f, 0.1f), p.x, p.y, p.z, 2, 0.05, 0.05, 0.05, 0.0);
        }
    }
    public static void barrierSeal(ServerWorld w, Vec3d pos) {
        w.spawnParticles(ParticleTypes.ENCHANT, pos.x, pos.y + 1, pos.z, 25, 0.8, 0.8, 0.8, 0.1);
        w.spawnParticles(dustColor(1.0f, 0.5f, 0.1f), pos.x, pos.y + 1, pos.z, 10, 0.5, 0.5, 0.5, 0.02);
    }

    // === SENJU: green wood ===
    public static void woodGrowth(ServerWorld w, Vec3d pos, float radius) {
        w.spawnParticles(ParticleTypes.HAPPY_VILLAGER, pos.x, pos.y + 1, pos.z, 20, radius, 0.5, radius, 0.05);
        w.spawnParticles(ParticleTypes.SPORE_BLOSSOM_AIR, pos.x, pos.y + 1, pos.z, 15, radius, 1.0, radius, 0.02);
    }
    public static void regeneration(ServerWorld w, Vec3d pos) {
        w.spawnParticles(ParticleTypes.HEART, pos.x, pos.y + 1.5, pos.z, 6, 0.3, 0.3, 0.3, 0.02);
        w.spawnParticles(ParticleTypes.HAPPY_VILLAGER, pos.x, pos.y + 1, pos.z, 10, 0.4, 0.4, 0.4, 0.02);
    }

    // === NARA: dark shadows ===
    public static void shadowGrab(ServerWorld w, Vec3d from, Vec3d to) {
        Vec3d dir = to.subtract(from).normalize();
        for (int i = 0; i < 12; i++) {
            Vec3d p = from.add(dir.multiply(i * 0.25));
            w.spawnParticles(ParticleTypes.LARGE_SMOKE, p.x, p.y + 0.1, p.z, 2, 0.05, 0.02, 0.05, 0.0);
        }
    }
    public static void shadowTrap(ServerWorld w, Vec3d pos) {
        w.spawnParticles(ParticleTypes.SMOKE, pos.x, pos.y + 0.1, pos.z, 15, 0.6, 0.1, 0.6, 0.02);
        w.spawnParticles(ParticleTypes.LARGE_SMOKE, pos.x, pos.y + 0.2, pos.z, 8, 0.4, 0.1, 0.4, 0.01);
    }

    // === ABURAME: insects/dark ===
    public static void insectSwarm(ServerWorld w, Vec3d pos, float radius) {
        w.spawnParticles(ParticleTypes.ITEM_SLIME, pos.x, pos.y + 1, pos.z, 25, radius, 0.6, radius, 0.08);
        w.spawnParticles(dustColor(0.2f, 0.15f, 0.1f), pos.x, pos.y + 1, pos.z, 12, radius * 0.7, 0.5, radius * 0.7, 0.01);
    }
    public static void bugShield(ServerWorld w, Vec3d pos) {
        w.spawnParticles(ParticleTypes.ITEM_SLIME, pos.x, pos.y + 1, pos.z, 15, 0.5, 0.8, 0.5, 0.05);
        w.spawnParticles(ParticleTypes.CLOUD, pos.x, pos.y + 1, pos.z, 8, 0.3, 0.3, 0.3, 0.02);
    }

    // === INUZUKA: dust/impact ===
    public static void fangStrike(ServerWorld w, Vec3d pos) {
        w.spawnParticles(ParticleTypes.CRIT, pos.x, pos.y + 1, pos.z, 12, 0.4, 0.4, 0.4, 0.15);
        w.spawnParticles(ParticleTypes.POOF, pos.x, pos.y + 0.5, pos.z, 8, 0.3, 0.2, 0.3, 0.03);
    }
    public static void spinAttack(ServerWorld w, Vec3d pos, float radius) {
        w.spawnParticles(ParticleTypes.CRIT, pos.x, pos.y + 0.8, pos.z, 20, radius, 0.4, radius, 0.2);
        w.spawnParticles(ParticleTypes.CLOUD, pos.x, pos.y + 0.5, pos.z, 12, radius, 0.3, radius, 0.05);
    }

    // === AKIMICHI: expansion/dust ===
    public static void expansion(ServerWorld w, Vec3d pos) {
        w.spawnParticles(ParticleTypes.POOF, pos.x, pos.y + 1, pos.z, 20, 0.8, 0.8, 0.8, 0.08);
        w.spawnParticles(ParticleTypes.CLOUD, pos.x, pos.y + 1, pos.z, 10, 0.6, 0.6, 0.6, 0.03);
    }
    public static void stoneFist(ServerWorld w, Vec3d pos) {
        w.spawnParticles(ParticleTypes.CRIT, pos.x, pos.y + 1, pos.z, 15, 0.5, 0.5, 0.5, 0.2);
        w.spawnParticles(ParticleTypes.BLOCK, pos.x, pos.y + 1, pos.z, 10, 0.4, 0.4, 0.4, 0.1);
    }

    // === HATAKE: lightning ===
    public static void lightningBlade(ServerWorld w, Vec3d pos) {
        w.spawnParticles(ParticleTypes.ELECTRIC_SPARK, pos.x, pos.y + 1, pos.z, 25, 0.5, 0.5, 0.5, 0.15);
        w.spawnParticles(ParticleTypes.FLASH, pos.x, pos.y + 1.2, pos.z, 1, 0, 0, 0, 0);
    }
    public static void raikiri(ServerWorld w, Vec3d pos) {
        w.spawnParticles(ParticleTypes.ELECTRIC_SPARK, pos.x, pos.y + 1, pos.z, 40, 0.7, 0.7, 0.7, 0.2);
        w.spawnParticles(ParticleTypes.FLASH, pos.x, pos.y + 1.2, pos.z, 2, 0, 0, 0, 0);
        w.spawnParticles(dustColor(0.6f, 0.8f, 1.0f), pos.x, pos.y + 1, pos.z, 15, 0.5, 0.5, 0.5, 0.02);
    }

    // === COMMON ===
    public static void applySlowness(LivingEntity e, int ticks, int amp) {
        e.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, ticks, amp, false, true));
    }
    public static void applyResistance(LivingEntity e, int ticks, int amp) {
        e.addStatusEffect(new StatusEffectInstance(StatusEffects.RESISTANCE, ticks, amp, false, true));
    }
    public static void applyStrength(LivingEntity e, int ticks, int amp) {
        e.addStatusEffect(new StatusEffectInstance(StatusEffects.STRENGTH, ticks, amp, false, true));
    }
    public static void applyPoison(LivingEntity e, int ticks, int amp) {
        e.addStatusEffect(new StatusEffectInstance(StatusEffects.POISON, ticks, amp, false, true));
    }

    public static void meleeDamage(ServerWorld w, LivingEntity attacker, Vec3d pos, float radius, float damage) {
        Box aoe = new Box(pos.subtract(radius, radius, radius), pos.add(radius, radius, radius));
        for (var e : w.getOtherEntities(attacker, aoe)) {
            if (e instanceof LivingEntity liv) {
                liv.damage(attacker.getDamageSources().playerAttack((net.minecraft.server.network.ServerPlayerEntity) attacker), damage);
            }
        }
    }

    public static void aoeDamage(ServerWorld w, LivingEntity attacker, Vec3d pos, float radius, float damage) {
        Box aoe = new Box(pos.subtract(radius, radius, radius), pos.add(radius, radius, radius));
        for (var e : w.getOtherEntities(attacker, aoe)) {
            if (e instanceof LivingEntity liv) {
                liv.damage(attacker.getDamageSources().playerAttack((net.minecraft.server.network.ServerPlayerEntity) attacker), damage);
            }
        }
    }

    private static DustParticleEffect dustColor(float r, float g, float b) {
        return new DustParticleEffect(new Vector3f(r, g, b), 1.0f);
    }
}
'@
Write-File (Join-Path $effectsDir "ClanParticleEffects.java") $effectsHelper

# ============================================================
# SECTION 2: Rewrite all 18 Behavior classes
# ============================================================
Write-Host "`n[2/19] Rewriting Behavior classes with clan-specific effects..." -ForegroundColor Yellow

# Template helper function
function New-ClanBehavior($className, $body) {
    return @"
package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.jutsu.effects.ClanParticleEffects;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;
import net.minecraft.util.math.Vec3d;

public class $className implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        Vec3d pos = player.getPos();
$body
        JutsuLogger.logBehavior(def.id(), "cast at " + pos);
    }
}
"@
}

# === UCHIHA ===
Write-File (Join-Path $behaviorDir "SusanooBehavior.java") (New-ClanBehavior "SusanooBehavior" @'

        ClanParticleEffects.susanooAura(world, pos);
        ClanParticleEffects.applyResistance(player, 100, 1);
        world.playSound(null, player.getBlockPos(), SoundEvents.ENTITY_BLAZE_SHOOT, SoundCategory.PLAYERS, 1.0f, 0.8f);
        player.sendMessage(net.minecraft.text.Text.literal("\u00a7c\u26a1 Susanoo activated!"), true);
'@)

Write-File (Join-Path $behaviorDir "FireSphereBehavior.java") (New-ClanBehavior "FireSphereBehavior" @'

        Vec3d look = player.getRotationVector();
        com.example.shinobicore.entity.NinjaProjectileEntity proj =
            new com.example.shinobicore.entity.NinjaProjectileEntity(
                world, player, look.multiply(1.5), damage, 2f, def.nature().getId(), def.id(), 60);
        proj.setPosition(player.getX(), player.getEyeY() - 0.2, player.getZ());
        world.spawnEntity(proj);
        ClanParticleEffects.fireBurst(world, pos, 8);
        world.playSound(null, player.getBlockPos(), SoundEvents.ITEM_FIRECHARGE_USE, SoundCategory.PLAYERS, 1.0f, 1.0f);
'@)

# === HYUGA ===
Write-File (Join-Path $behaviorDir "SkyVortexBehavior.java") (New-ClanBehavior "SkyVortexBehavior" @'

        ClanParticleEffects.byakuganPulse(world, pos);
        ClanParticleEffects.meleeDamage(world, player, pos, 4f, damage);
        world.playSound(null, player.getBlockPos(), SoundEvents.ENTITY_PLAYER_ATTACK_SWEEP, SoundCategory.PLAYERS, 1.0f, 1.5f);
'@)

Write-File (Join-Path $behaviorDir "HakkeShieldBehavior.java") (New-ClanBehavior "HakkeShieldBehavior" @'

        ClanParticleEffects.byakuganPulse(world, pos);
        ClanParticleEffects.applyResistance(player, 80, 2);
        world.playSound(null, player.getBlockPos(), SoundEvents.BLOCK_AMETHYST_BLOCK_HIT, SoundCategory.PLAYERS, 1.0f, 1.2f);
'@)

# === UZUMAKI ===
Write-File (Join-Path $behaviorDir "ChakraChainsBehavior.java") (New-ClanBehavior "ChakraChainsBehavior" @'

        java.util.List<LivingEntity> targets = new java.util.ArrayList<>();
        for (var e : world.getOtherEntities(player, new net.minecraft.util.math.Box(pos.subtract(6, 6, 6), pos.add(6, 6, 6)))) {
            if (e instanceof LivingEntity liv) {
                targets.add(liv);
                ClanParticleEffects.applySlowness(liv, 80, 2);
                ClanParticleEffects.chakraChain(world, pos, liv.getPos());
            }
        }
        world.playSound(null, player.getBlockPos(), SoundEvents.BLOCK_CHAIN_PLACE, SoundCategory.PLAYERS, 1.0f, 0.8f);
'@)

Write-File (Join-Path $behaviorDir "BarrierSealBehavior.java") (New-ClanBehavior "BarrierSealBehavior" @'

        ClanParticleEffects.barrierSeal(world, pos);
        ClanParticleEffects.applyResistance(player, 120, 2);
        world.playSound(null, player.getBlockPos(), SoundEvents.BLOCK_ENCHANTMENT_TABLE_USE, SoundCategory.PLAYERS, 1.0f, 1.0f);
'@)

# === SENJU ===
Write-File (Join-Path $behaviorDir "WoodDragonBehavior.java") (New-ClanBehavior "WoodDragonBehavior" @'

        float radius = 6f;
        ClanParticleEffects.woodGrowth(world, pos, radius);
        ClanParticleEffects.aoeDamage(world, player, pos, radius, damage);
        world.playSound(null, player.getBlockPos(), SoundEvents.BLOCK_BAMBOO_BREAK, SoundCategory.PLAYERS, 1.5f, 0.6f);
'@)

Write-File (Join-Path $behaviorDir "RegenerationBehavior.java") (New-ClanBehavior "RegenerationBehavior" @'

        player.heal(damage * 2f);
        ClanParticleEffects.regeneration(world, pos);
        player.addStatusEffect(new net.minecraft.entity.effect.StatusEffectInstance(
            net.minecraft.entity.effect.StatusEffects.REGENERATION, 100, 1, false, true));
        world.playSound(null, player.getBlockPos(), SoundEvents.BLOCK_CHERRY_LEAVES_HIT, SoundCategory.PLAYERS, 1.0f, 1.2f);
'@)

# === NARA ===
Write-File (Join-Path $behaviorDir "ShadowGrabBehavior.java") (New-ClanBehavior "ShadowGrabBehavior" @'

        LivingEntity target = null;
        double minDist = 8;
        for (var e : world.getOtherEntities(player, new net.minecraft.util.math.Box(pos.subtract(8, 4, 8), pos.add(8, 4, 8)))) {
            if (e instanceof LivingEntity liv) {
                double d = liv.distanceTo(player);
                if (d < minDist) { minDist = d; target = liv; }
            }
        }
        if (target != null) {
            ClanParticleEffects.shadowGrab(world, pos, target.getPos());
            ClanParticleEffects.applySlowness(target, 60, 3);
        }
        ClanParticleEffects.shadowTrap(world, pos);
        world.playSound(null, player.getBlockPos(), SoundEvents.BLOCK_SOUL_SAND_HIT, SoundCategory.PLAYERS, 1.0f, 0.7f);
'@)

Write-File (Join-Path $behaviorDir "ShadowLoopBehavior.java") (New-ClanBehavior "ShadowLoopBehavior" @'

        java.util.List<LivingEntity> targets = new java.util.ArrayList<>();
        for (var e : world.getOtherEntities(player, new net.minecraft.util.math.Box(pos.subtract(5, 3, 5), pos.add(5, 3, 5)))) {
            if (e instanceof LivingEntity liv) {
                targets.add(liv);
                ClanParticleEffects.applySlowness(liv, 80, 3);
            }
        }
        ClanParticleEffects.shadowTrap(world, pos);
        world.playSound(null, player.getBlockPos(), SoundEvents.BLOCK_SOUL_SAND_PLACE, SoundCategory.PLAYERS, 1.0f, 0.6f);
'@)

# === ABURAME ===
Write-File (Join-Path $behaviorDir "InsectSwarmBehavior.java") (New-ClanBehavior "InsectSwarmBehavior" @'

        float radius = 4f;
        ClanParticleEffects.insectSwarm(world, pos, radius);
        for (var e : world.getOtherEntities(player, new net.minecraft.util.math.Box(pos.subtract(radius, radius, radius), pos.add(radius, radius, radius)))) {
            if (e instanceof LivingEntity liv) {
                ClanParticleEffects.applyPoison(liv, 80, 1);
                liv.damage(player.getDamageSources().playerAttack(player), damage * 0.5f);
            }
        }
        world.playSound(null, player.getBlockPos(), SoundEvents.ENTITY_BEE_HURT, SoundCategory.PLAYERS, 0.8f, 0.7f);
'@)

Write-File (Join-Path $behaviorDir "BugShieldBehavior.java") (New-ClanBehavior "BugShieldBehavior" @'

        ClanParticleEffects.bugShield(world, pos);
        ClanParticleEffects.applyResistance(player, 100, 1);
        world.playSound(null, player.getBlockPos(), SoundEvents.ENTITY_BEE_LOOP, SoundCategory.PLAYERS, 0.6f, 0.8f);
'@)

# === INUZUKA ===
Write-File (Join-Path $behaviorDir "WolfFangBehavior.java") (New-ClanBehavior "WolfFangBehavior" @'

        ClanParticleEffects.fangStrike(world, pos);
        ClanParticleEffects.meleeDamage(world, player, pos, 2.5f, damage);
        world.playSound(null, player.getBlockPos(), SoundEvents.ENTITY_WOLF_GROWL, SoundCategory.PLAYERS, 1.0f, 1.2f);
'@)

Write-File (Join-Path $behaviorDir "SpinFangBehavior.java") (New-ClanBehavior "SpinFangBehavior" @'

        ClanParticleEffects.spinAttack(world, pos, 3f);
        ClanParticleEffects.meleeDamage(world, player, pos, 3f, damage);
        world.playSound(null, player.getBlockPos(), SoundEvents.ENTITY_PLAYER_ATTACK_SWEEP, SoundCategory.PLAYERS, 1.0f, 1.5f);
'@)

# === AKIMICHI ===
Write-File (Join-Path $behaviorDir "ExpansionBehavior.java") (New-ClanBehavior "ExpansionBehavior" @'

        ClanParticleEffects.expansion(world, pos);
        ClanParticleEffects.applyStrength(player, 120, 1);
        player.addStatusEffect(new net.minecraft.entity.effect.StatusEffectInstance(
            net.minecraft.entity.effect.StatusEffects.RESISTANCE, 120, 0, false, true));
        world.playSound(null, player.getBlockPos(), SoundEvents.ENTITY_GENERIC_EXPLODE, SoundCategory.PLAYERS, 0.5f, 0.8f);
'@)

Write-File (Join-Path $behaviorDir "StoneFistBehavior.java") (New-ClanBehavior "StoneFistBehavior" @'

        ClanParticleEffects.stoneFist(world, pos);
        ClanParticleEffects.meleeDamage(world, player, pos, 3f, damage * 1.5f);
        world.playSound(null, player.getBlockPos(), SoundEvents.ENTITY_IRON_GOLEM_ATTACK, SoundCategory.PLAYERS, 1.0f, 0.8f);
'@)

# === HATAKE ===
Write-File (Join-Path $behaviorDir "LightningBladeBehavior.java") (New-ClanBehavior "LightningBladeBehavior" @'

        ClanParticleEffects.lightningBlade(world, pos);
        ClanParticleEffects.meleeDamage(world, player, pos, 2.5f, damage * 1.3f);
        world.playSound(null, player.getBlockPos(), SoundEvents.ITEM_TRIDENT_THUNDER, SoundCategory.PLAYERS, 0.8f, 1.5f);
'@)

Write-File (Join-Path $behaviorDir "RaikiriBehavior.java") (New-ClanBehavior "RaikiriBehavior" @'

        ClanParticleEffects.raikiri(world, pos);
        ClanParticleEffects.meleeDamage(world, player, pos, 3f, damage * 2.0f);
        world.playSound(null, player.getBlockPos(), SoundEvents.ITEM_TRIDENT_THUNDER, SoundCategory.PLAYERS, 1.2f, 1.3f);
'@)

# ============================================================
# BUILD
# ============================================================
Write-Host "`n[19/19] Building..." -ForegroundColor Yellow
Push-Location $root
try {
    $out = & ".\gradlew.bat" build 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [PASS] Build successful!" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Build failed" -ForegroundColor Red
        $out | Select-Object -Last 20 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    }
} finally { Pop-Location }

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Green
Write-Host "  SPRINT 13B-2: UNIQUE CLAN PARTICLES COMPLETE" -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Clan visual identities:" -ForegroundColor White
Write-Host "  Uchiha: Susanoo aura (soul fire + red dust), Fire Sphere (flame + lava)" -ForegroundColor Red
Write-Host "  Hyuga: Byakugan pulse (white dust + enchant), Hakke shield" -ForegroundColor Cyan
Write-Host "  Uzumaki: Chakra chains (orange dust trail), Barrier seal (enchant)" -ForegroundColor Yellow
Write-Host "  Senju: Wood growth (green villagers), Regeneration (hearts)" -ForegroundColor Green
Write-Host "  Nara: Shadow grab (smoke trail), Shadow trap (large smoke)" -ForegroundColor Gray
Write-Host "  Aburame: Insect swarm (slime + dark dust), Bug shield" -ForegroundColor DarkYellow
Write-Host "  Inuzuka: Fang strike (crit + poof), Spin attack (circular crit)" -ForegroundColor DarkRed
Write-Host "  Akimichi: Expansion (poof + cloud), Stone fist (block break)" -ForegroundColor Yellow
Write-Host "  Hatake: Lightning blade (electric sparks + flash), Raikiri" -ForegroundColor Magenta
Write-Host ""
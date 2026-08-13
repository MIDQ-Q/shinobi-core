$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)

# === 1. Create GenjutsuAuraEffect.java (server-side particle aura) ===
$auraPath = "E:\Games\mod\src\main\java\com\example\shinobicore\jutsu\GenjutsuAuraEffect.java"
if (Test-Path $auraPath) {
    Write-Host "[SKIP] GenjutsuAuraEffect.java already exists"
} else {
    $auraCode = @'
package com.example.shinobicore.jutsu;

import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffect;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;

/**
 * Server-side visual: purple aura around entities suffering from genjutsu.
 * Detects the unique debuff combos applied by GenjutsuBehavior and spawns
 * purple particles around the afflicted entity every 5 ticks.
 */
public class GenjutsuAuraEffect {
    private static int tickCounter = 0;

    public static void tick(ServerWorld world) {
        tickCounter++;
        if (tickCounter % 5 != 0) return;

        for (LivingEntity entity : world.getEntitiesByType(
                net.minecraft.entity.EntityType.ZOMBIE, e -> true)) {
            // no-op, we iterate manually below for all living
        }

        // Iterate all living entities in the world
        for (LivingEntity entity : world.iterateEntities()) {
            if (!(entity instanceof LivingEntity living)) continue;
            if (!living.isAlive()) continue;
            if (!isUnderGenjutsu(living)) continue;

            spawnGenjutsuAura(world, living);
        }
    }

    /**
     * Detects our unique genjutsu debuff combinations:
     * - fear:      SLOWNESS + NAUSEA (+ MINING_FATIGUE)
     * - blindness: BLINDNESS + WEAKNESS
     * - nightmare: BLINDNESS + NAUSEA + SLOWNESS + WEAKNESS
     * - paralysis: SLOWNESS(255) + MINING_FATIGUE(255)
     *
     * Core marker: SLOWNESS + NAUSEA together, OR BLINDNESS + WEAKNESS together.
     * These combos are unique to our genjutsu (vanilla doesn't apply them together).
     */
    private static boolean isUnderGenjutsu(LivingEntity entity) {
        boolean hasSlowness = entity.hasStatusEffect(StatusEffects.SLOWNESS);
        boolean hasNausea = entity.hasStatusEffect(StatusEffects.NAUSEA);
        boolean hasBlindness = entity.hasStatusEffect(StatusEffects.BLINDNESS);
        boolean hasWeakness = entity.hasStatusEffect(StatusEffects.WEAKNESS);
        boolean hasMiningFatigue = entity.hasStatusEffect(StatusEffects.MINING_FATIGUE);

        // Fear / Nightmare / Paralysis marker
        if (hasSlowness && (hasNausea || hasMiningFatigue)) return true;

        // Blindness / Nightmare marker
        if (hasBlindness && hasWeakness) return true;

        return false;
    }

    private static void spawnGenjutsuAura(ServerWorld world, LivingEntity entity) {
        Vec3d pos = entity.getPos().add(0, entity.getHeight() * 0.5, 0);
        double bodyRadius = 0.6;
        double height = entity.getHeight();

        // Swirling purple portal particles in a helix around the body
        float phase = tickCounter * 0.15f;
        for (int i = 0; i < 4; i++) {
            float angle = phase + (i / 4.0f) * (float)(Math.PI * 2);
            double y = pos.y + (height * 0.5) * ((Math.sin(phase + i) + 1.0) * 0.5);
            double x = pos.x + Math.cos(angle) * bodyRadius;
            double z = pos.z + Math.sin(angle) * bodyRadius;

            world.spawnParticles(ParticleTypes.PORTAL,
                x, y, z,
                1, 0, 0.02, 0, 0.02);
        }

        // Occasional rising soul particles
        if (tickCounter % 10 == 0) {
            world.spawnParticles(ParticleTypes.SCULK_SOUL,
                pos.x + (Math.random() - 0.5) * 0.8,
                pos.y + height * 0.3,
                pos.z + (Math.random() - 0.5) * 0.8,
                1, 0, 0.08, 0, 0.01);
        }

        // Witch particles near the head (mental effect indicator)
        if (tickCounter % 15 == 0) {
            world.spawnParticles(ParticleTypes.WITCH,
                pos.x,
                pos.y + height * 0.85,
                pos.z,
                2, 0.3, 0.2, 0.3, 0.02);
        }
    }
}
'@
    [System.IO.File]::WriteAllText($auraPath, $auraCode, $utf8)
    Write-Host "[FIX] Created GenjutsuAuraEffect.java"
}

# === 2. Register tick in NinjaTickHandler.java ===
$nthPath = "E:\Games\mod\src\main\java\com\example\shinobicore\event\NinjaTickHandler.java"
$nthContent = [System.IO.File]::ReadAllText($nthPath, $utf8)
$sentinel = "PHASE_E_GEN_AURA_REGISTERED"

if ($nthContent.Contains($sentinel)) {
    Write-Host "[SKIP] GenjutsuAuraEffect already registered in NinjaTickHandler"
} else {
    # Add import
    $importAnchor = "import com.example.shinobicore.jutsu.WallRemovalTask;"
    if ($nthContent.Contains($importAnchor)) {
        $nthContent = $nthContent.Replace(
            $importAnchor,
            $importAnchor + "`nimport com.example.shinobicore.jutsu.GenjutsuAuraEffect;"
        )
        Write-Host "[FIX] Added GenjutsuAuraEffect import"
    } else {
        Write-Host "[ERROR] Import anchor not found in NinjaTickHandler"
        exit 1
    }

    # Add tick call inside the world loop, right after WallRemovalTask.tick(world)
    $wallCall = "WallRemovalTask.tick(world);"
    if ($nthContent.Contains($wallCall)) {
        $nthContent = $nthContent.Replace(
            $wallCall,
            $wallCall + "`n            if (world instanceof ServerWorld sw) GenjutsuAuraEffect.tick(sw); // " + $sentinel
        )
        Write-Host "[FIX] Registered GenjutsuAuraEffect.tick() in world loop"
    } else {
        Write-Host "[ERROR] WallRemovalTask anchor not found"
        exit 1
    }

    # Need to import ServerWorld
    if (-not $nthContent.Contains("import net.minecraft.server.world.ServerWorld;")) {
        $nthContent = $nthContent.Replace(
            "import net.minecraft.server.network.ServerPlayerEntity;",
            "import net.minecraft.server.network.ServerPlayerEntity;`nimport net.minecraft.server.world.ServerWorld;"
        )
        Write-Host "[FIX] Added ServerWorld import"
    }

    [System.IO.File]::WriteAllText($nthPath, $nthContent, $utf8)
    Write-Host "[OK] NinjaTickHandler.java updated"
}

Write-Host ""
Write-Host "=== PHASE E STEP 2 APPLIED ==="
Write-Host "Run: .\gradlew.bat build"
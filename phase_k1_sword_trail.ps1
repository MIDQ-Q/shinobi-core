$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod\src\main\java\com\example\shinobicore"

# ============================================================
# 1. NEW: SwordTrailRenderer.java - client-side sword trail
# ============================================================
$trailPath = "$root\client\combat\SwordTrailRenderer.java"
if (Test-Path $trailPath) {
    Write-Host "[SKIP] SwordTrailRenderer already exists"
} else {
    $trailCode = @'
package com.example.shinobicore.client.combat;

import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.util.math.Vec3d;

/**
 * Sword Trail: arc of particles following katana slashes.
 * Each combo step has a different trail pattern:
 * - Step 0: horizontal left-to-right arc
 * - Step 1: horizontal right-to-left arc
 * - Step 2: vertical top-to-bottom arc
 * - Step 3 (finisher): full 360 ring + orange flash
 */
public class SwordTrailRenderer {
    private static int tickCounter = 0;

    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(SwordTrailRenderer::tick);
    }

    private static void tick(MinecraftClient client) {
        if (client.world == null) return;
        tickCounter++;
    }

    /**
     * Called from KenjutsuClientHandler.tryAttack() after each slash.
     * Spawns trail particles in an arc pattern.
     */
    public static void playSlashTrail(AbstractClientPlayerEntity player, int comboStep) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.world == null) return;

        Vec3d pos = player.getPos().add(0, 1.2, 0);
        Vec3d look = player.getRotationVector();
        Vec3d right = new Vec3d(-look.z, 0, look.x).normalize();
        Vec3d up = new Vec3d(0, 1, 0);

        switch (comboStep) {
            case 0 -> spawnHorizontalArc(client, pos, right, up, true);   // left to right
            case 1 -> spawnHorizontalArc(client, pos, right, up, false);  // right to left
            case 2 -> spawnVerticalArc(client, pos, look, right);         // top to bottom
            case 3 -> spawnFinisherRing(client, pos);                     // 360 ring
        }
    }

    private static void spawnHorizontalArc(MinecraftClient client, Vec3d center,
                                            Vec3d right, Vec3d up, boolean leftToRight) {
        int count = 14;
        for (int i = 0; i < count; i++) {
            float t = (float) i / count;
            float angle = leftToRight ? (t * 1.8f - 0.9f) : (0.9f - t * 1.8f);
            Vec3d offset = right.multiply(Math.cos(angle) * 1.6)
                    .add(up.multiply(Math.sin(angle) * 0.6 + 0.2));
            Vec3d p = center.add(offset);

            // White sweep particles (main trail)
            client.world.addParticle(ParticleTypes.SWEEP_ATTACK,
                    p.x, p.y, p.z,
                    offset.x * 0.05, offset.y * 0.05, offset.z * 0.05);

            // Small white sparkle at trail edge
            if (i % 3 == 0) {
                client.world.addParticle(ParticleTypes.CRIT,
                        p.x, p.y, p.z, 0, 0.02, 0);
            }
        }
    }

    private static void spawnVerticalArc(MinecraftClient client, Vec3d center,
                                          Vec3d look, Vec3d right) {
        int count = 14;
        for (int i = 0; i < count; i++) {
            float t = (float) i / count;
            float angle = t * 1.6f - 0.8f; // -0.8 to +0.8 radians
            Vec3d offset = look.multiply(0.8)
                    .add(new Vec3d(0, 1, 0).multiply(Math.cos(angle) * 1.2))
                    .add(right.multiply(Math.sin(angle) * 0.4));
            Vec3d p = center.add(offset);

            client.world.addParticle(ParticleTypes.SWEEP_ATTACK,
                    p.x, p.y, p.z,
                    0, -0.06, 0);

            if (i % 4 == 0) {
                client.world.addParticle(ParticleTypes.CRIT,
                        p.x, p.y, p.z, 0, -0.03, 0);
            }
        }
    }

    private static void spawnFinisherRing(MinecraftClient client, Vec3d center) {
        // 360 degree ring of particles
        int count = 28;
        for (int i = 0; i < count; i++) {
            float angle = (float) (i / (double) count) * (float)(Math.PI * 2);
            double r = 1.8;
            double x = center.x + Math.cos(angle) * r;
            double z = center.z + Math.sin(angle) * r;
            double y = center.y + Math.sin(angle * 2) * 0.3;

            // Orange enchant particles for finisher
            client.world.addParticle(ParticleTypes.ENCHANT,
                    x, y, z,
                    Math.cos(angle) * 0.1, 0.05, Math.sin(angle) * 0.1);

            // White crit sparks
            if (i % 3 == 0) {
                client.world.addParticle(ParticleTypes.CRIT,
                        x, y, z, 0, 0.08, 0);
            }
        }

        // Central flash (small explosion particle)
        client.world.addParticle(ParticleTypes.EXPLOSION,
                center.x, center.y, center.z, 0, 0, 0);

        // Rising sparks
        for (int i = 0; i < 8; i++) {
            client.world.addParticle(ParticleTypes.END_ROD,
                    center.x + (Math.random() - 0.5) * 1.5,
                    center.y + Math.random() * 0.5,
                    center.z + (Math.random() - 0.5) * 1.5,
                    0, 0.12, 0);
        }
    }

    /**
     * Called when a projectile is deflected.
     * Spawns bright sparks at the deflection point.
     */
    public static void playDeflectSparks(AbstractClientPlayerEntity player) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.world == null) return;

        Vec3d pos = player.getPos().add(0, 1.3, 0);
        Vec3d look = player.getRotationVector();
        Vec3d sparkPos = pos.add(look.multiply(0.8));

        // Bright white sparks burst
        for (int i = 0; i < 16; i++) {
            double angle = Math.random() * Math.PI * 2;
            double speed = 0.1 + Math.random() * 0.15;
            client.world.addParticle(ParticleTypes.CRIT,
                    sparkPos.x, sparkPos.y, sparkPos.z,
                    Math.cos(angle) * speed,
                    Math.random() * 0.15,
                    Math.sin(angle) * speed);
        }

        // Electric spark for metallic feel
        for (int i = 0; i < 6; i++) {
            client.world.addParticle(ParticleTypes.ELECTRIC_SPARK,
                    sparkPos.x + (Math.random() - 0.5) * 0.4,
                    sparkPos.y + (Math.random() - 0.5) * 0.4,
                    sparkPos.z + (Math.random() - 0.5) * 0.4,
                    0, 0.05, 0);
        }

        // Small flash
        client.world.addParticle(ParticleTypes.FLASH,
                sparkPos.x, sparkPos.y, sparkPos.z, 0, 0, 0);
    }
}
'@
    [System.IO.File]::WriteAllText($trailPath, $trailCode, $utf8)
    Write-Host "[FIX] Created SwordTrailRenderer.java"
}

# ============================================================
# 2. Register SwordTrailRenderer in ShinobiCoreClient
# ============================================================
$sccPath = "$root\client\ShinobiCoreClient.java"
$sccContent = [System.IO.File]::ReadAllText($sccPath, $utf8)
$sentinel1 = "PHASE_K1_TRAIL_REGISTERED"

if ($sccContent.Contains($sentinel1)) {
    Write-Host "[SKIP] SwordTrailRenderer already registered"
} else {
    $sccContent = $sccContent.Replace(
        "CastingClientVisual.register();",
        "CastingClientVisual.register();`n        com.example.shinobicore.client.combat.SwordTrailRenderer.register(); // " + $sentinel1
    )
    [System.IO.File]::WriteAllText($sccPath, $sccContent, $utf8)
    Write-Host "[FIX] Registered SwordTrailRenderer"
}

# ============================================================
# 3. Hook trail into KenjutsuClientHandler.tryAttack()
# ============================================================
$kchPath = "$root\client\combat\KenjutsuClientHandler.java"
$kchContent = [System.IO.File]::ReadAllText($kchPath, $utf8)
$sentinel2 = "PHASE_K1_TRAIL_HOOKED"

if ($kchContent.Contains($sentinel2)) {
    Write-Host "[SKIP] Trail already hooked in KenjutsuClientHandler"
} else {
    # Add trail call after playSlashParticles
    $kchContent = $kchContent.Replace(
        "playSlashParticles(player, comboStep);",
        "playSlashParticles(player, comboStep);`n        SwordTrailRenderer.playSlashTrail(player, comboStep); // " + $sentinel2
    )
    # Add deflect sparks in setDeflectHeld (when held = true)
    $kchContent = $kchContent.Replace(
        "if (held) {`n            KenjutsuAnimations.playDeflect(player);",
        "if (held) {`n            KenjutsuAnimations.playDeflect(player);`n            SwordTrailRenderer.playDeflectSparks(player);"
    )
    [System.IO.File]::WriteAllText($kchPath, $kchContent, $utf8)
    Write-Host "[FIX] Hooked trail into KenjutsuClientHandler"
}

# ============================================================
# 4. Improve KenjutsuAnimations - smoother curves + body lean
# ============================================================
$kaPath = "$root\client\combat\KenjutsuAnimations.java"
$kaContent = [System.IO.File]::ReadAllText($kaPath, $utf8)
$sentinel3 = "PHASE_K1_ANIM_IMPROVED"

if ($kaContent.Contains($sentinel3)) {
    Write-Host "[SKIP] KenjutsuAnimations already improved"
} else {
    # Replace the curve function with a smoother ease-in-out + overshoot
    $oldCurve = @"
private static float curve(float p) {
if (p < 0.3f) return (float) Math.sin(p / 0.3f * Math.PI / 2);
if (p < 0.5f) return 1.0f + 0.15f * (float) Math.sin((p - 0.3f) / 0.2f * Math.PI);
return 1.0f - (float) Math.sin((p - 0.5f) / 0.5f * Math.PI / 2);
}
"@
    $newCurve = @"
// PHASE_K1_ANIM_IMPROVED
private static float curve(float p) {
    // Improved ease-in-out with stronger overshoot for impact feel
    if (p < 0.25f) {
        // Fast windup (ease-in cubic)
        float t = p / 0.25f;
        return t * t * t;
    } else if (p < 0.45f) {
        // Impact overshoot (spring)
        float t = (p - 0.25f) / 0.2f;
        return 1.0f + 0.25f * (float) Math.sin(t * Math.PI);
    } else if (p < 0.55f) {
        // Hold at peak (impact frame)
        return 1.0f;
    } else {
        // Smooth return (ease-out)
        float t = (p - 0.55f) / 0.45f;
        return 1.0f - t * t * (3.0f - 2.0f * t); // smoothstep
    }
}
"@
    if ($kaContent.Contains("private static float curve(float p)")) {
        $kaContent = $kaContent.Replace($oldCurve, $newCurve)
        Write-Host "[FIX] Improved curve function"
    } else {
        Write-Host "[WARN] Could not find curve function"
    }

    # Add body lean to applySlash (forward lean during impact)
    $kaContent = $kaContent.Replace(
        "case 0 -> { rArm.yaw = -1.9f + c * 3.2f; rArm.pitch = -0.85f; rArm.roll = 0.2f; body.yaw += c * 0.6f - 0.3f; lArm.yaw = 0.4f; lArm.pitch = -0.6f; }",
        "case 0 -> { rArm.yaw = -1.9f + c * 3.2f; rArm.pitch = -0.85f; rArm.roll = 0.2f; body.yaw += c * 0.6f - 0.3f; body.pitch += c * 0.12f; lArm.yaw = 0.4f; lArm.pitch = -0.6f; }"
    )
    $kaContent = $kaContent.Replace(
        "case 1 -> { rArm.yaw = 1.9f - c * 3.2f; rArm.pitch = -0.85f; rArm.roll = -0.2f; body.yaw -= c * 0.6f - 0.3f; lArm.yaw = -0.4f; lArm.pitch = -0.6f; }",
        "case 1 -> { rArm.yaw = 1.9f - c * 3.2f; rArm.pitch = -0.85f; rArm.roll = -0.2f; body.yaw -= c * 0.6f - 0.3f; body.pitch += c * 0.12f; lArm.yaw = -0.4f; lArm.pitch = -0.6f; }"
    )
    $kaContent = $kaContent.Replace(
        "case 2 -> { rArm.pitch = 2.3f - c * 4.0f; rArm.yaw = -0.2f; body.pitch += c * 0.35f; lArm.pitch = -0.9f; lArm.yaw = 0.5f; }",
        "case 2 -> { rArm.pitch = 2.3f - c * 4.0f; rArm.yaw = -0.2f; body.pitch += c * 0.35f; body.roll += c * 0.05f; lArm.pitch = -0.9f; lArm.yaw = 0.5f; }"
    )

    [System.IO.File]::WriteAllText($kaPath, $kaContent, $utf8)
    Write-Host "[FIX] Improved KenjutsuAnimations"
}

Write-Host ""
Write-Host "=== PHASE K1 APPLIED ==="
Write-Host "Run: .\gradlew.bat build"
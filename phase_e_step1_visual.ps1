# phase_e_step1_visual.ps1
# Phase E Step 1: Chakra Aura + Genjutsu Hand Signs Visual
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod\src\main\java\com\example\shinobicore\client"

# ============================================================
# 1. NEW: ChakraAuraRenderer.java
# ============================================================
$auraPath = "$root\ChakraAuraRenderer.java"
if (Test-Path $auraPath) {
    Write-Host "[SKIP] ChakraAuraRenderer already exists"
} else {
    $auraCode = @'
package com.example.shinobicore.client;

import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.particle.DustParticleEffect;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.util.math.Vec3d;
import org.joml.Vector3f;

public class ChakraAuraRenderer {
    private static int tickCounter = 0;

    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(ChakraAuraRenderer::tick);
    }

    private static void tick(MinecraftClient client) {
        if (client.world == null) return;
        tickCounter++;
        if (tickCounter % 3 != 0) return; // Every 3 ticks for performance

        for (AbstractClientPlayerEntity p : client.world.getPlayers()) {
            boolean isLocal = (p == client.player);
            boolean hasChakra = false;
            String affinityId = null;

            if (isLocal) {
                hasChakra = ClientNinjaState.chakraMode && ChakraHudRenderer.currentChakra > 0;
                affinityId = ClientNinjaState.affinityId;
            } else {
                // For other players: check casting state as proxy for chakra visibility
                hasChakra = CastingClientState.isCasting(p);
            }

            if (!hasChakra) continue;
            spawnAuraParticles(client, p, affinityId, isLocal);
        }
    }

    private static void spawnAuraParticles(MinecraftClient client, AbstractClientPlayerEntity p,
                                            String affinityId, boolean isLocal) {
        Vec3d pos = p.getPos();
        double bodyY = pos.y + 0.5;
        float bodyRadius = 0.45f;
        Vector3f color = getColorForAffinity(affinityId);

        int count = isLocal ? 8 : 4;
        float rotation = tickCounter * 0.12f;

        for (int i = 0; i < count; i++) {
            float angle = rotation + (i / (float) count) * (float)(Math.PI * 2);
            double x = pos.x + Math.cos(angle) * bodyRadius;
            double z = pos.z + Math.sin(angle) * bodyRadius;

            for (int h = 0; h < 3; h++) {
                double y = bodyY + h * 0.55 + (Math.random() - 0.5) * 0.15;
                DustParticleEffect effect = new DustParticleEffect(color, 0.7f);
                client.world.addParticle(effect, x, y, z, 0, 0.008, 0);
            }
        }

        // Shoulder flames for local player only
        if (isLocal && tickCounter % 6 == 0) {
            Vec3d look = p.getRotationVector();
            Vec3d right = new Vec3d(-look.z, 0, look.x).normalize();
            Vec3d leftShoulder = pos.add(0, 1.3, 0).add(right.multiply(-0.3));
            Vec3d rightShoulder = pos.add(0, 1.3, 0).add(right.multiply(0.3));

            client.world.addParticle(ParticleTypes.SOUL_FIRE_FLAME,
                leftShoulder.x, leftShoulder.y, leftShoulder.z, 0, 0.025, 0);
            client.world.addParticle(ParticleTypes.SOUL_FIRE_FLAME,
                rightShoulder.x, rightShoulder.y, rightShoulder.z, 0, 0.025, 0);
        }
    }

    private static Vector3f getColorForAffinity(String affinityId) {
        if (affinityId == null) return new Vector3f(0.3f, 0.5f, 1.0f);
        return switch (affinityId) {
            case "fire"      -> new Vector3f(1.0f, 0.4f, 0.1f);
            case "water"     -> new Vector3f(0.2f, 0.5f, 1.0f);
            case "wind"      -> new Vector3f(0.5f, 1.0f, 0.7f);
            case "lightning" -> new Vector3f(1.0f, 1.0f, 0.3f);
            case "earth"     -> new Vector3f(0.7f, 0.5f, 0.2f);
            default          -> new Vector3f(0.3f, 0.5f, 1.0f);
        };
    }
}
'@
    [System.IO.File]::WriteAllText($auraPath, $auraCode, $utf8)
    Write-Host "[FIX] Created ChakraAuraRenderer.java"
}

# ============================================================
# 2. Register ChakraAuraRenderer in ShinobiCoreClient.java
# ============================================================
$sccPath = "$root\ShinobiCoreClient.java"
$sccContent = [System.IO.File]::ReadAllText($sccPath, $utf8)
$sentinel = "PHASE_E_AURA_REGISTERED"

if ($sccContent.Contains($sentinel)) {
    Write-Host "[SKIP] ChakraAuraRenderer already registered"
} else {
    $sccContent = $sccContent.Replace(
        "CastingClientVisual.register();",
        "CastingClientVisual.register();`n        ChakraAuraRenderer.register(); // " + $sentinel
    )
    [System.IO.File]::WriteAllText($sccPath, $sccContent, $utf8)
    Write-Host "[FIX] Registered ChakraAuraRenderer in ShinobiCoreClient"
}

# ============================================================
# 3. Add genjutsu hand sign pose to PlayerRenderAnimationMixin
# ============================================================
$mixinPath = "E:\Games\mod\src\main\java\com\example\shinobicore\mixin\PlayerRenderAnimationMixin.java"
$mixinContent = [System.IO.File]::ReadAllText($mixinPath, $utf8)
$mixinSentinel = "PHASE_E_GENJUTSU_POSE"

if ($mixinContent.Contains($mixinSentinel)) {
    Write-Host "[SKIP] Genjutsu pose already added to mixin"
} else {
    # Add import for JutsuRegistry
    $mixinContent = $mixinContent.Replace(
        "import com.example.shinobicore.client.parkour.ParkourManager;",
        "import com.example.shinobicore.client.parkour.ParkourManager;`nimport com.example.shinobicore.jutsu.JutsuRegistry;`nimport com.example.shinobicore.jutsu.JutsuDefinition;"
    )

    # Replace the existing casting pose block with enhanced version
    $oldPose = @"
     // === РџР•Р§РђРўР   РџР Р   РљРђРЎРўР• ===
     if (com.example.shinobicore.client.CastingClientState.isCasting(player)) {
         rightArm.pitch = -1.25f; rightArm.yaw = -0.45f;
         leftArm.pitch = -1.25f; leftArm.yaw = 0.45f;
         head.pitch += 0.1f;
     }
"@

    $newPose = @"
     // === PHASE_E_GENJUTSU_POSE ===
     if (com.example.shinobicore.client.CastingClientState.isCasting(player)) {
         // Check if casting genjutsu for special hand sign pose
         boolean isGenjutsu = false;
         String activeJutsu = ClientNinjaState.activeJutsuId(0);
         if (activeJutsu == null) activeJutsu = ClientNinjaState.activeJutsuId(1);
         if (activeJutsu != null) {
             JutsuDefinition def = JutsuRegistry.get(activeJutsu);
             if (def != null && "genjutsu".equals(def.type())) isGenjutsu = true;
         }

         if (isGenjutsu) {
             // Genjutsu hand signs: hands together at chest, fingers interlocked
             rightArm.pitch = -0.8f; rightArm.yaw = -0.15f; rightArm.roll = 0.3f;
             leftArm.pitch = -0.8f; leftArm.yaw = 0.15f; leftArm.roll = -0.3f;
             head.pitch += 0.2f;
             body.pitch += 0.05f;
         } else {
             // Normal casting pose
             rightArm.pitch = -1.25f; rightArm.yaw = -0.45f;
             leftArm.pitch = -1.25f; leftArm.yaw = 0.45f;
             head.pitch += 0.1f;
         }
     }
"@

    if ($mixinContent.Contains("// === РџР•Р§РђРўР")) {
        # Try to find and replace the block using line-by-line approach
        $lines = $mixinContent -split "`n"
        $newLines = [System.Collections.Generic.List[string]]::new()
        $skipUntil = -1

        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($i -le $skipUntil) { continue }

            if ($lines[$i].Contains("// === РџР•Р§РђРўР") -or $lines[$i].Contains("PECHATI PRI KASTE")) {
                # Found start of casting pose block, insert new version
                $newLines.Add($newPose)
                # Skip old block lines until we find the closing brace
                $braceCount = 0
                $foundOpen = $false
                for ($j = $i; $j -lt $lines.Count; $j++) {
                    if ($lines[$j].Contains("{")) { $braceCount++; $foundOpen = $true }
                    if ($lines[$j].Contains("}")) { $braceCount-- }
                    if ($foundOpen -and $braceCount -eq 0) {
                        $skipUntil = $j
                        break
                    }
                }
            } else {
                $newLines.Add($lines[$i])
            }
        }
        $mixinContent = $newLines -join "`n"
        Write-Host "[FIX] Replaced casting pose with genjutsu-aware version"
    } else {
        # Fallback: just add genjutsu check before existing casting block
        $mixinContent = $mixinContent.Replace(
            "if (com.example.shinobicore.client.CastingClientState.isCasting(player)) {",
            "// " + $mixinSentinel + "`n     if (com.example.shinobicore.client.CastingClientState.isCasting(player)) {"
        )
        Write-Host "[WARN] Could not find casting pose block, added sentinel only"
    }

    [System.IO.File]::WriteAllText($mixinPath, $mixinContent, $utf8)
    Write-Host "[OK] PlayerRenderAnimationMixin updated"
}

Write-Host ""
Write-Host "=== PHASE E STEP 1 APPLIED ==="
Write-Host "Run: .\gradlew.bat build"
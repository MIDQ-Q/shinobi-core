$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod\src\main\java\com\example\shinobicore"
function Write-File($p, $c) { [System.IO.File]::WriteAllText($p, $c, $utf8); Write-Host "[OK] $p" }

# ============================================================
# 1. NEW: ChakraAuraVisual.java
# ============================================================
$f = "$root\client\ChakraAuraVisual.java"
if (Test-Path $f) { Write-Host "[SKIP] ChakraAuraVisual exists" } else {
Write-File $f @'
package com.example.shinobicore.client;

import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.util.math.Vec3d;

public class ChakraAuraVisual {
    private static int tickCounter = 0;

    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(ChakraAuraVisual::tick);
    }

    private static void tick(MinecraftClient client) {
        if (client.world == null || client.player == null) return;
        tickCounter++;

        boolean chakraOn = ClientNinjaState.chakraMode && ChakraHudRenderer.currentChakra > 0;
        if (!chakraOn) return;

        float chakraRatio = ChakraHudRenderer.maxChakra > 0
            ? ChakraHudRenderer.currentChakra / ChakraHudRenderer.maxChakra : 0;

        boolean flicker = chakraRatio < 0.25f;
        if (flicker && (tickCounter % 8 > 4)) return;

        Vec3d pos = client.player.getPos();
        float pulse = 0.7f + 0.3f * (float) Math.sin(tickCounter * 0.15);

        int flameCount = Math.max(1, (int) (2 * pulse));
        for (int i = 0; i < flameCount; i++) {
            double angle = tickCounter * 0.1 + i * Math.PI * 2 / flameCount;
            double r = 0.35;
            client.world.addParticle(ParticleTypes.SOUL_FIRE_FLAME,
                pos.x + Math.cos(angle) * r,
                pos.y + 0.1,
                pos.z + Math.sin(angle) * r,
                (Math.random() - 0.5) * 0.01,
                0.03,
                (Math.random() - 0.5) * 0.01);
        }

        if (tickCounter % 3 == 0) {
            double angle = Math.random() * Math.PI * 2;
            double r = 0.3 + Math.random() * 0.3;
            client.world.addParticle(ParticleTypes.SOUL_FIRE_FLAME,
                pos.x + Math.cos(angle) * r,
                pos.y + 0.5 + Math.random() * 1.0,
                pos.z + Math.sin(angle) * r,
                0, 0.05, 0);
        }

        if (tickCounter % 5 == 0 && Math.random() < 0.5 * pulse) {
            client.world.addParticle(ParticleTypes.ENCHANT,
                pos.x + (Math.random() - 0.5) * 0.8,
                pos.y + 0.5 + Math.random() * 1.2,
                pos.z + (Math.random() - 0.5) * 0.8,
                0, 0.01, 0);
        }
    }
}
'@
}

# ============================================================
# 2. NEW: HandSealPoses.java
# ============================================================
$f = "$root\client\combat\HandSealPoses.java"
if (Test-Path $f) { Write-Host "[SKIP] HandSealPoses exists" } else {
Write-File $f @'
package com.example.shinobicore.client.combat;

import net.minecraft.client.model.ModelPart;

public class HandSealPoses {
    public static void apply(String nature, ModelPart rArm, ModelPart lArm, ModelPart body, ModelPart head) {
        float t = (float) (Math.sin(System.currentTimeMillis() / 150.0) * 0.05f);

        switch (nature) {
            case "fire" -> {
                rArm.pitch = -0.8f + t; rArm.yaw = -0.6f; rArm.roll = 0.3f;
                lArm.pitch = -0.8f + t; lArm.yaw = 0.6f; lArm.roll = -0.3f;
                body.pitch += 0.1f;
                head.pitch += 0.15f;
            }
            case "water" -> {
                rArm.pitch = -1.0f + t; rArm.yaw = -0.1f;
                lArm.pitch = -1.0f + t; lArm.yaw = 0.1f;
                body.pitch += 0.08f;
                head.pitch += 0.12f;
            }
            case "wind" -> {
                rArm.pitch = -0.5f + t; rArm.yaw = -1.2f; rArm.roll = 0.4f;
                lArm.pitch = -0.5f + t; lArm.yaw = 1.2f; lArm.roll = -0.4f;
                body.pitch += 0.05f;
                head.pitch += 0.08f;
            }
            case "earth" -> {
                rArm.pitch = -0.4f + t; rArm.yaw = -0.15f;
                lArm.pitch = -0.4f + t; lArm.yaw = 0.15f;
                body.pitch += 0.15f;
                head.pitch += 0.2f;
            }
            case "lightning" -> {
                rArm.pitch = -1.8f + t; rArm.yaw = -0.3f;
                lArm.pitch = -0.6f + t; lArm.yaw = 0.3f;
                body.pitch += 0.05f;
                head.pitch -= 0.1f;
            }
            default -> {
                rArm.pitch = -1.1f + t; rArm.yaw = -0.2f;
                lArm.pitch = -1.1f + t; lArm.yaw = 0.2f;
                body.pitch += 0.1f;
                head.pitch += 0.1f;
            }
        }
    }
}
'@
}

# ============================================================
# 3. Modify PlayerRenderAnimationMixin
# ============================================================
$mx = "$root\mixin\PlayerRenderAnimationMixin.java"
$c = [System.IO.File]::ReadAllText($mx, $utf8)
$c = $c.Replace("`r`n", "`n")

# 3a. Insert water/wall/slide before naruto run
$narutoIf = "if (chakraMode && sprinting && !sliding && !rolling) {"
if ($c.Contains($narutoIf) -and !$c.Contains("BATCH3_WATER")) {
    $insert = "        // === WATER RUNNING === // BATCH3_WATER`n" +
        "        if (chakraMode && com.example.shinobicore.client.ChakraPhysicsClient.standingOnWater && sprinting) {`n" +
        "            applyWaterRun(limbAngle, limbDistance);`n" +
        "            return;`n" +
        "        }`n" +
        "        // === WALL RUNNING === // BATCH3_WALL`n" +
        "        if (com.example.shinobicore.client.parkour.ParkourManager.isWallRunning()) {`n" +
        "            applyWallRun(limbAngle, limbDistance);`n" +
        "            return;`n" +
        "        }`n" +
        "        // === SLIDING === // BATCH3_SLIDE`n" +
        "        if (sliding) {`n" +
        "            applySlidePose();`n" +
        "            return;`n" +
        "        }`n" +
        "        " + $narutoIf
    $c = $c.Replace($narutoIf, $insert)
}

# 3b. Replace casting pose with hand seals
$oldCast = "if (com.example.shinobicore.client.CastingClientState.isCasting(player)) {"
if ($c.Contains($oldCast) -and !$c.Contains("BATCH3_HANDSEAL")) {
    $c = $c.Replace($oldCast,
        "var castState = com.example.shinobicore.client.CastingClientState.get(player); // BATCH3_HANDSEAL`n" +
        "        if (castState != null) {")
    $c = $c.Replace(
        "rightArm.pitch = -1.25f; rightArm.yaw = -0.45f;",
        "com.example.shinobicore.client.combat.HandSealPoses.apply(castState.nature, rightArm, leftArm, body, head);")
    $c = $c.Replace("leftArm.pitch = -1.25f; leftArm.yaw = 0.45f;", "// BATCH3: nature-specific")
    $c = $c.Replace("head.pitch += 0.1f;", "// BATCH3: hand seals")
}

# 3c. Append new pose methods before closing brace
if (!$c.Contains("applyWaterRun")) {
    $c = $c.TrimEnd()
    if ($c.EndsWith("}")) { $c = $c.Substring(0, $c.Length - 1) }
    $methods = @"

    // === BATCH 3: Water Run / Wall Run / Slide Poses ===
    private void applyWaterRun(float limbAngle, float limbDistance) {
        float bob = MathHelper.sin(limbAngle * 2.0f) * 0.1f * limbDistance;
        rightArm.pitch = -0.3f + bob;
        rightArm.yaw = -0.9f;
        rightArm.roll = 0.3f;
        leftArm.pitch = -0.3f + bob;
        leftArm.yaw = 0.9f;
        leftArm.roll = -0.3f;
        body.pitch = 0.25f;
        head.pitch -= 0.15f;
        float legSwing = MathHelper.cos(limbAngle) * limbDistance * 1.3f;
        rightLeg.pitch = legSwing;
        rightLeg.yaw = -0.15f;
        leftLeg.pitch = -legSwing;
        leftLeg.yaw = 0.15f;
    }

    private void applyWallRun(float limbAngle, float limbDistance) {
        body.roll = 0.3f;
        body.pitch = 0.2f;
        rightArm.pitch = -1.5f;
        rightArm.yaw = -0.8f;
        rightArm.roll = 0.5f;
        leftArm.pitch = 0.5f;
        leftArm.yaw = 0.5f;
        head.yaw += 0.2f;
        head.pitch -= 0.1f;
        float legSwing = MathHelper.cos(limbAngle) * limbDistance * 1.2f;
        rightLeg.pitch = legSwing;
        leftLeg.pitch = -legSwing;
    }

    private void applySlidePose() {
        rightLeg.pitch = -1.0f;
        rightLeg.yaw = 0.1f;
        leftLeg.pitch = -0.7f;
        leftLeg.yaw = -0.1f;
        body.pitch = -0.4f;
        body.roll = 0.05f;
        rightArm.pitch = 0.6f;
        rightArm.yaw = -0.3f;
        leftArm.pitch = 0.6f;
        leftArm.yaw = 0.3f;
        head.pitch -= 0.2f;
    }
}
"@
    $c += $methods
}

Write-File $mx $c

# ============================================================
# 4. Register ChakraAuraVisual in ShinobiCoreClient
# ============================================================
$sc = "$root\client\ShinobiCoreClient.java"
$c = [System.IO.File]::ReadAllText($sc, $utf8)
if (!$c.Contains("ChakraAuraVisual.register")) {
    $c = $c.Replace(
        "RasenganClientVisual.register();",
        "RasenganClientVisual.register();`n        com.example.shinobicore.client.ChakraAuraVisual.register(); // BATCH3_AURA")
    Write-File $sc $c
} else {
    Write-Host "[SKIP] ChakraAuraVisual already registered"
}

Write-Host "=== BATCH 3 DONE ==="
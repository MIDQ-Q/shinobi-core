$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod\src\main\java\com\example\shinobicore"
function Write-File($p, $c) { [System.IO.File]::WriteAllText($p, $c, $utf8); Write-Host "[OK] $p" }

# ============ 1. NEW: ThrowAnimations.java ============
$f = "$root\client\combat\ThrowAnimations.java"
if (Test-Path $f) { Write-Host "[SKIP] ThrowAnimations exists" } else {
Write-File $f @'
package com.example.shinobicore.client.combat;

import net.minecraft.client.model.ModelPart;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.util.math.MathHelper;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

public class ThrowAnimations {
    private static final Map<UUID, Long> THROWS = new HashMap<>();

    public static void playThrow(AbstractClientPlayerEntity p) {
        THROWS.put(p.getUuid(), System.currentTimeMillis());
    }

    public static void apply(AbstractClientPlayerEntity p, ModelPart rArm, ModelPart lArm, ModelPart body) {
        Long t = THROWS.get(p.getUuid());
        if (t == null) return;
        long e = System.currentTimeMillis() - t;
        if (e > 300) { THROWS.remove(p.getUuid()); return; }
        float pr = e / 300f;
        float c;
        if (pr < 0.35f) {
            c = 0.8f * (pr / 0.35f);
        } else {
            float q = (pr - 0.35f) / 0.65f;
            c = 0.8f - 2.2f * q;
        }
        rArm.pitch = c;
        rArm.yaw = -0.25f;
        lArm.pitch = -0.5f;
        lArm.yaw = 0.3f;
        body.yaw += MathHelper.sin(pr * (float) Math.PI) * -0.3f;
    }
}
'@
}

# ============ 2. NEW: LandingAnimations.java ============
$f = "$root\client\LandingAnimations.java"
if (Test-Path $f) { Write-Host "[SKIP] LandingAnimations exists" } else {
Write-File $f @'
package com.example.shinobicore.client;

import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.model.ModelPart;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.MathHelper;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

public class LandingAnimations {
    private static final Map<UUID, Long> LANDINGS = new HashMap<>();
    private static final Map<UUID, Boolean> PREV_GROUND = new HashMap<>();
    private static final Map<UUID, Float> LAST_FALL_VEL = new HashMap<>();

    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(client -> {
            ClientPlayerEntity p = client.player;
            if (p == null) return;
            UUID id = p.getUuid();
            if (!p.isOnGround()) {
                LAST_FALL_VEL.put(id, (float) p.getVelocity().y);
            }
            boolean prev = PREV_GROUND.getOrDefault(id, true);
            if (!prev && p.isOnGround()) {
                float v = LAST_FALL_VEL.getOrDefault(id, 0f);
                if (v < -0.6f) LANDINGS.put(id, System.currentTimeMillis());
            }
            PREV_GROUND.put(id, p.isOnGround());
        });
    }

    public static void apply(AbstractClientPlayerEntity p, ModelPart body, ModelPart rLeg, ModelPart lLeg,
                             ModelPart rArm, ModelPart lArm, ModelPart head) {
        Long t = LANDINGS.get(p.getUuid());
        if (t == null) return;
        long e = System.currentTimeMillis() - t;
        if (e > 400) { LANDINGS.remove(p.getUuid()); return; }
        float s = MathHelper.sin((e / 400f) * (float) Math.PI);
        body.pitch = 0.45f * s;
        rLeg.pitch = -0.7f * s;
        lLeg.pitch = -0.4f * s;
        rLeg.yaw = 0.2f * s;
        lLeg.yaw = -0.2f * s;
        rArm.pitch = 0.7f * s;
        lArm.pitch = 0.7f * s;
        rArm.yaw = -0.4f * s;
        lArm.yaw = 0.4f * s;
        head.pitch -= 0.25f * s;
    }
}
'@
}

# ============ 3. NEW: ChakraBurstAnimations.java ============
$f = "$root\client\combat\ChakraBurstAnimations.java"
if (Test-Path $f) { Write-Host "[SKIP] ChakraBurstAnimations exists" } else {
Write-File $f @'
package com.example.shinobicore.client.combat;

import net.minecraft.client.model.ModelPart;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.util.math.MathHelper;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

public class ChakraBurstAnimations {
    private static final Map<UUID, Long> BURSTS = new HashMap<>();

    public static void playBurst(AbstractClientPlayerEntity p) {
        BURSTS.put(p.getUuid(), System.currentTimeMillis());
    }

    public static void apply(AbstractClientPlayerEntity p, ModelPart rArm, ModelPart lArm, ModelPart body, ModelPart head) {
        Long t = BURSTS.get(p.getUuid());
        if (t == null) return;
        long e = System.currentTimeMillis() - t;
        if (e > 500) { BURSTS.remove(p.getUuid()); return; }
        float s = MathHelper.sin((e / 500f) * (float) Math.PI);
        rArm.pitch = 0.3f * s;
        lArm.pitch = 0.3f * s;
        rArm.roll = -0.5f * s;
        lArm.roll = 0.5f * s;
        rArm.yaw = -0.3f * s;
        lArm.yaw = 0.3f * s;
        body.pitch = -0.1f * s;
        head.pitch += 0.15f * s;
    }
}
'@
}

# ============ 4. KenjutsuAnimations: iai slash (step 4) ============
$f = "$root\client\combat\KenjutsuAnimations.java"
$c = [System.IO.File]::ReadAllText($f, $utf8)
if ($c.Contains("PHASE_A_IAI")) { Write-Host "[SKIP] KenjutsuAnimations iai" } else {
    $c = $c.Replace("case 0, 1 -> 260f; case 2 -> 340f; default -> 520f;",
        "case 0, 1 -> 260f; case 2 -> 340f; case 4 -> 350f; default -> 520f;")
    $c = $c.Replace("case 2 -> { rArm.pitch = 2.3f - c * 4.0f; rArm.yaw = -0.2f; body.pitch += c * 0.35f; lArm.pitch = -0.9f; lArm.yaw = 0.5f; }",
        "case 2 -> { rArm.pitch = 2.3f - c * 4.0f; rArm.yaw = -0.2f; body.pitch += c * 0.35f; lArm.pitch = -0.9f; lArm.yaw = 0.5f; }`n        case 4 -> { rArm.pitch = 0.2f - c * 1.6f; rArm.yaw = -0.6f + c * 1.4f; rArm.roll = 0.3f - c * 0.3f; lArm.pitch = -0.3f; lArm.yaw = 0.5f; body.yaw += -0.4f + c * 0.9f; head.pitch -= 0.1f * c; } // PHASE_A_IAI")
    $c = $c.Replace("public static void playSlash(AbstractClientPlayerEntity p, int step) { SLASHES.put(p.getUuid(), new SlashState(step)); }",
        "public static void playSlash(AbstractClientPlayerEntity p, int step) { SLASHES.put(p.getUuid(), new SlashState(step)); }`n    public static void playIaiSlash(AbstractClientPlayerEntity p) { SLASHES.put(p.getUuid(), new SlashState(4)); }")
    Write-File $f $c
}

# ============ 5. KenjutsuClientHandler: use iai slash in iai stance ============
$f = "$root\client\combat\KenjutsuClientHandler.java"
$c = [System.IO.File]::ReadAllText($f, $utf8)
if ($c.Contains("PHASE_A_IAI_HOOK")) { Write-Host "[SKIP] KenjutsuClientHandler iai hook" } else {
    $c = $c.Replace("KenjutsuAnimations.playSlash(player, comboStep);",
        "if (stance.equals(`"iai`")) KenjutsuAnimations.playIaiSlash(player); else KenjutsuAnimations.playSlash(player, comboStep); // PHASE_A_IAI_HOOK")
    Write-File $f $c
}

# ============ 6. ThrowingWeaponItem: client throw anim trigger ============
$f = "$root\item\ThrowingWeaponItem.java"
$c = [System.IO.File]::ReadAllText($f, $utf8)
if ($c.Contains("PHASE_A_THROW_HOOK")) { Write-Host "[SKIP] ThrowingWeaponItem hook" } else {
    $c = $c.Replace("return TypedActionResult.success(stack, world.isClient());",
        "if (world.isClient && user instanceof net.minecraft.client.network.ClientPlayerEntity cp) { com.example.shinobicore.client.combat.ThrowAnimations.playThrow(cp); } // PHASE_A_THROW_HOOK`n        return TypedActionResult.success(stack, world.isClient());")
    Write-File $f $c
}

# ============ 7. ClientInputHandler: chakra burst trigger ============
$f = "$root\client\ClientInputHandler.java"
$c = [System.IO.File]::ReadAllText($f, $utf8)
if ($c.Contains("PHASE_A_BURST_HOOK")) { Write-Host "[SKIP] ClientInputHandler burst hook" } else {
    $c = $c.Replace("ClientNinjaState.chakraMode = !ClientNinjaState.chakraMode;",
        "ClientNinjaState.chakraMode = !ClientNinjaState.chakraMode;`n            if (ClientNinjaState.chakraMode) com.example.shinobicore.client.combat.ChakraBurstAnimations.playBurst(client.player); // PHASE_A_BURST_HOOK")
    Write-File $f $c
}

# ============ 8. PlayerRenderAnimationMixin: apply new anims ============
$f = "$root\mixin\PlayerRenderAnimationMixin.java"
$c = [System.IO.File]::ReadAllText($f, $utf8)
if ($c.Contains("PHASE_A_APPLY")) { Write-Host "[SKIP] Mixin apply block" } else {
    $c = $c.Replace("if (TaijutsuAnimations.isKicking(player)) {",
        "// === PHASE_A_APPLY: throw / landing / chakra burst ===`n        com.example.shinobicore.client.combat.ThrowAnimations.apply(player, rightArm, leftArm, body);`n        com.example.shinobicore.client.LandingAnimations.apply(player, body, rightLeg, leftLeg, rightArm, leftArm, head);`n        com.example.shinobicore.client.combat.ChakraBurstAnimations.apply(player, rightArm, leftArm, body, head);`n        if (TaijutsuAnimations.isKicking(player)) {")
    Write-File $f $c
}

# ============ 9. ShinobiCoreClient: register landing detector ============
$f = "$root\client\ShinobiCoreClient.java"
$c = [System.IO.File]::ReadAllText($f, $utf8)
if ($c.Contains("PHASE_A_REG")) { Write-Host "[SKIP] LandingAnimations register" } else {
    $c = $c.Replace("RasenganClientVisual.register();",
        "RasenganClientVisual.register();`n        com.example.shinobicore.client.LandingAnimations.register(); // PHASE_A_REG")
    Write-File $f $c
}

Write-Host "=== PHASE A DONE ==="
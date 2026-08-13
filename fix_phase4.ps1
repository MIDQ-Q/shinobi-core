# fix_phase4.ps1
# Phase 4: Hit-Stop (combat feel) + Chakra Aura (visual)
# All ASCII markers, UTF-8 no BOM

$ErrorActionPreference = "Stop"
$root = "E:\Games\mod\src\main\java\com\example\shinobicore"
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Write-File($path, $content) {
    [System.IO.File]::WriteAllText($path, $content, $utf8)
    Write-Host "[OK] $path"
}

# ============================================================
# 1. HitStopManager.java (NEW) - client-side freeze manager
# ============================================================
$hsPath = "$root\client\combat\HitStopManager.java"
if (Test-Path $hsPath) {
    Write-Host "[SKIP] HitStopManager already exists"
} else {
    $hsContent = @"
package com.example.shinobicore.client.combat;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Hit-Stop: freeze-frame on hit for combat feel.
 * Attacker freezes ~100ms, target freezes ~200ms.
 * This is NOT stun - just animation pause for impact weight.
 */
public class HitStopManager {
    private static final Map<Integer, Long> FROZEN = new ConcurrentHashMap<>();

    public static void freeze(int entityId, long ms) {
        long until = System.currentTimeMillis() + ms;
        Long existing = FROZEN.get(entityId);
        if (existing == null || until > existing) {
            FROZEN.put(entityId, until);
        }
    }

    public static boolean isFrozen(int entityId) {
        Long until = FROZEN.get(entityId);
        if (until == null) return false;
        if (System.currentTimeMillis() >= until) {
            FROZEN.remove(entityId);
            return false;
        }
        return true;
    }

    public static void clear() {
        FROZEN.clear();
    }
}
"@
    Write-File $hsPath $hsContent
}

# ============================================================
# 2. ChakraAuraRenderer.java (NEW) - particles around body
# ============================================================
$caPath = "$root\client\ChakraAuraRenderer.java"
if (Test-Path $caPath) {
    Write-Host "[SKIP] ChakraAuraRenderer already exists"
} else {
    $caContent = @"
package com.example.shinobicore.client;

import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.particle.DustParticleEffect;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.util.math.Vec3d;
import org.joml.Vector3f;

/**
 * Chakra Aura: particles around body in chakra mode.
 * Color depends on affinity (fire=red, water=blue, etc.)
 * Default: blue chakra glow.
 */
public class ChakraAuraRenderer {
    private static int tickCounter = 0;

    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(ChakraAuraRenderer::tick);
    }

    private static void tick(MinecraftClient client) {
        if (client.world == null) return;
        tickCounter++;
        // Spawn particles every 2 ticks for performance
        if (tickCounter % 2 != 0) return;

        for (AbstractClientPlayerEntity p : client.world.getPlayers()) {
            boolean isLocal = (p == client.player);
            boolean hasChakra;
            String affinityId = null;

            if (isLocal) {
                hasChakra = ClientNinjaState.chakraMode && ChakraHudRenderer.currentChakra > 0;
                affinityId = ClientNinjaState.affinityId;
            } else {
                // For other players, check their casting state as proxy
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
        float bodyRadius = 0.4f;

        // Color from affinity
        Vector3f color = getColorForAffinity(affinityId);

        // === AURA: ring of particles around body ===
        int count = isLocal ? 6 : 3; // fewer for other players (performance)
        float rotation = tickCounter * 0.15f;

        for (int i = 0; i < count; i++) {
            float angle = rotation + (i / (float) count) * (float)(Math.PI * 2);
            double x = pos.x + Math.cos(angle) * bodyRadius;
            double z = pos.z + Math.sin(angle) * bodyRadius;
            // Rising particles along body height
            for (int h = 0; h < 3; h++) {
                double y = bodyY + h * 0.5 + (Math.random() - 0.5) * 0.2;
                DustParticleEffect effect = new DustParticleEffect(color, 0.8f);
                client.world.addParticle(effect, x, y, z,
                    0, 0.01, 0);
            }
        }

        // === FLAME-LIKE: rising wisps from shoulders ===
        if (isLocal && tickCounter % 4 == 0) {
            Vec3d look = p.getRotationVector();
            Vec3d right = new Vec3d(-look.z, 0, look.x).normalize();
            // Left shoulder
            Vec3d leftShoulder = pos.add(0, 1.3, 0).add(right.multiply(-0.3));
            // Right shoulder
            Vec3d rightShoulder = pos.add(0, 1.3, 0).add(right.multiply(0.3));

            client.world.addParticle(ParticleTypes.SOUL_FIRE_FLAME,
                leftShoulder.x, leftShoulder.y, leftShoulder.z,
                0, 0.03, 0);
            client.world.addParticle(ParticleTypes.SOUL_FIRE_FLAME,
                rightShoulder.x, rightShoulder.y, rightShoulder.z,
                0, 0.03, 0);
        }
    }

    private static Vector3f getColorForAffinity(String affinityId) {
        if (affinityId == null) return new Vector3f(0.3f, 0.5f, 1.0f); // default blue
        return switch (affinityId) {
            case "fire" -> new Vector3f(1.0f, 0.4f, 0.1f);
            case "water" -> new Vector3f(0.2f, 0.5f, 1.0f);
            case "wind" -> new Vector3f(0.5f, 1.0f, 0.7f);
            case "lightning" -> new Vector3f(1.0f, 1.0f, 0.3f);
            case "earth" -> new Vector3f(0.7f, 0.5f, 0.2f);
            default -> new Vector3f(0.3f, 0.5f, 1.0f);
        };
    }
}
"@
    Write-File $caPath $caContent
}

# ============================================================
# 3. Modify ModPackets.java - add HIT_STOP_ID
# ============================================================
$mpPath = "$root\network\ModPackets.java"
$mp = [System.IO.File]::ReadAllText($mpPath, $utf8)

$sentinel = "HIT_STOP_ID"
if ($mp.Contains($sentinel)) {
    Write-Host "[SKIP] ModPackets already has HIT_STOP_ID"
} else {
    # Add identifier after SENSORY_TOGGLE_ID
    $mp = $mp.Replace(
        'public static final Identifier SENSORY_TOGGLE_ID = new Identifier("shinobicore", "sensory_toggle");',
        "public static final Identifier SENSORY_TOGGLE_ID = new Identifier(`"shinobicore`", `"sensory_toggle`");`n    public static final Identifier HIT_STOP_ID = new Identifier(`"shinobicore`", `"hit_stop`");"
    )

    # Add receiver registration before the last closing brace of register()
    # Find the last registerGlobalReceiver in register() method
    $hitStopReceiver = @"

        // === HIT-STOP (server -> client): freeze-frame on hit ===
        // This is S2C only, no server receiver needed.
        // Server sends it via ShinobiCore.broadcastHitStop()
"@
    # Insert before the last "}" of the register method
    $lastBrace = $mp.LastIndexOf("    }`n}")
    if ($lastBrace -lt 0) {
        $lastBrace = $mp.LastIndexOf("}`n}")
    }
    if ($lastBrace -gt 0) {
        $mp = $mp.Substring(0, $lastBrace) + $hitStopReceiver + "`n" + $mp.Substring($lastBrace)
    }

    Write-File $mpPath $mp
    Write-Host "[FIX] ModPackets: added HIT_STOP_ID"
}

# ============================================================
# 4. Modify ShinobiCore.java - add broadcastHitStop()
# ============================================================
$scPath = "$root\ShinobiCore.java"
$sc = [System.IO.File]::ReadAllText($scPath, $utf8)

$sentinel2 = "broadcastHitStop"
if ($sc.Contains($sentinel2)) {
    Write-Host "[SKIP] ShinobiCore already has broadcastHitStop"
} else {
    $hitStopMethod = @"

    public static void broadcastHitStop(ServerPlayerEntity attacker, net.minecraft.entity.LivingEntity target,
                                         int attackerMs, int targetMs) {
        // Send to attacker
        PacketByteBuf atkBuf = new PacketByteBuf(Unpooled.buffer());
        atkBuf.writeInt(attacker.getId());
        atkBuf.writeInt(attackerMs);
        ServerPlayNetworking.send(attacker, ModPackets.HIT_STOP_ID, atkBuf);
        // Send target freeze to attacker (so attacker sees target freeze)
        if (target != null) {
            PacketByteBuf tgtBuf = new PacketByteBuf(Unpooled.buffer());
            tgtBuf.writeInt(target.getId());
            tgtBuf.writeInt(targetMs);
            ServerPlayNetworking.send(attacker, ModPackets.HIT_STOP_ID, tgtBuf);
        }
        // Send to target (if player)
        if (target instanceof ServerPlayerEntity targetPlayer) {
            PacketByteBuf selfBuf = new PacketByteBuf(Unpooled.buffer());
            selfBuf.writeInt(targetPlayer.getId());
            selfBuf.writeInt(targetMs);
            ServerPlayNetworking.send(targetPlayer, ModPackets.HIT_STOP_ID, selfBuf);
        }
    }
"@
    # Insert before the last closing brace
    $lastBrace = $sc.LastIndexOf("}")
    $sc = $sc.Substring(0, $lastBrace) + $hitStopMethod + "`n}"
    Write-File $scPath $sc
    Write-Host "[FIX] ShinobiCore: added broadcastHitStop()"
}

# ============================================================
# 5. Modify ShinobiCoreClient.java - register HitStop + Aura
# ============================================================
$sccPath = "$root\client\ShinobiCoreClient.java"
$scc = [System.IO.File]::ReadAllText($sccPath, $utf8)

$sentinel3 = "HitStopManager"
if ($scc.Contains($sentinel3)) {
    Write-Host "[SKIP] ShinobiCoreClient already has HitStop registration"
} else {
    # Add import
    $scc = $scc.Replace(
        "import com.example.shinobicore.client.combat.TaijutsuAnimations;",
        "import com.example.shinobicore.client.combat.TaijutsuAnimations;`nimport com.example.shinobicore.client.combat.HitStopManager;"
    )

    # Add HIT_STOP receiver before HudRenderCallback
    $hitStopClientReceiver = @"
        ClientPlayNetworking.registerGlobalReceiver(ModPackets.HIT_STOP_ID, (client, handler, buf, responseSender) -> {
            int entityId = buf.readInt();
            int durationMs = buf.readInt();
            client.execute(() -> HitStopManager.freeze(entityId, durationMs));
        });
"@
    $scc = $scc.Replace(
        "CastingClientVisual.register();",
        "CastingClientVisual.register();`n        ChakraAuraRenderer.register();`n        $hitStopClientReceiver"
    )

    # Add disconnect cleanup
    $scc = $scc.Replace(
        "CastingClientState.clear();",
        "CastingClientState.clear();`n            HitStopManager.clear();"
    )

    Write-File $sccPath $scc
    Write-Host "[FIX] ShinobiCoreClient: registered HitStop + Aura"
}

# ============================================================
# 6. Modify PlayerRenderAnimationMixin - add freeze check
# ============================================================
$praPath = "$root\mixin\PlayerRenderAnimationMixin.java"
$pra = [System.IO.File]::ReadAllText($praPath, $utf8)

$sentinel4 = "HitStopManager"
if ($pra.Contains($sentinel4)) {
    Write-Host "[SKIP] PlayerRenderAnimationMixin already has freeze check"
} else {
    # Add import
    $pra = $pra.Replace(
        "import com.example.shinobicore.client.parkour.ParkourManager;",
        "import com.example.shinobicore.client.parkour.ParkourManager;`nimport com.example.shinobicore.client.combat.HitStopManager;"
    )

    # Add freeze check at the beginning of setAngles injection
    $freezeCheck = @"
        // === HIT-STOP: freeze animation on hit ===
        if (HitStopManager.isFrozen(entity.getId())) {
            return;
        }
"@
    $pra = $pra.Replace(
        "if (!(entity instanceof AbstractClientPlayerEntity player)) return;",
        "if (!(entity instanceof AbstractClientPlayerEntity player)) return;`n$freezeCheck"
    )

    Write-File $praPath $pra
    Write-Host "[FIX] PlayerRenderAnimationMixin: added freeze check"
}

# ============================================================
# 7. Modify ModPackets TAIJUTSU_ATTACK handler - add hit-stop
# ============================================================
$mp2 = [System.IO.File]::ReadAllText($mpPath, $utf8)

$sentinel5 = "HITSTOP_TAIJUTSU"
if ($mp2.Contains($sentinel5)) {
    Write-Host "[SKIP] TAIJUTSU_ATTACK hit-stop already added"
} else {
    # Find the applyDamage call and add hit-stop after it
    $mp2 = $mp2.Replace(
        'MeleeHitDetection.applyDamage((ServerWorld) player.getWorld(), player, targets, damage, knockback);',
        "MeleeHitDetection.applyDamage((ServerWorld) player.getWorld(), player, targets, damage, knockback);`n                // === HITSTOP_TAIJUTSU ===`n                for (LivingEntity t : targets) {`n                    ShinobiCore.broadcastHitStop(player, t, 80, 160);`n                }"
    )

    Write-File $mpPath $mp2
    Write-Host "[FIX] ModPackets: added hit-stop to TAIJUTSU_ATTACK"
}

# ============================================================
# 8. Modify ModPackets KATANA_ATTACK handler - add hit-stop
# ============================================================
$mp3 = [System.IO.File]::ReadAllText($mpPath, $utf8)

$sentinel6 = "HITSTOP_KATANA"
if ($mp3.Contains($sentinel6)) {
    Write-Host "[SKIP] KATANA_ATTACK hit-stop already added"
} else {
    $mp3 = $mp3.Replace(
        't.velocityModified = true;',
        "t.velocityModified = true;`n                }`n                // === HITSTOP_KATANA ===`n                for (LivingEntity ht : targets) {`n                    ShinobiCore.broadcastHitStop(player, ht, 100, 200);`n                }`n                if (false) {"
    )
    # The above is tricky - let me do it differently
    # Find the for loop that applies damage and add after it
    # Actually let me search for the specific pattern
    Write-Host "[WARN] KATANA hit-stop: manual patch needed, skipping for now"
}

# ============================================================
# 9. Modify ModPackets TAIJUTSU_KICK handler - add hit-stop
# ============================================================
$mp4 = [System.IO.File]::ReadAllText($mpPath, $utf8)

$sentinel7 = "HITSTOP_KICK"
if ($mp4.Contains($sentinel7)) {
    Write-Host "[SKIP] TAIJUTSU_KICK hit-stop already added"
} else {
    $mp4 = $mp4.Replace(
        "MeleeHitDetection.applyDamage((ServerWorld) player.getWorld(), player, targets, damage, knockback);`n             data.setFatigue(data.getFatigue() + style.getFatiguePerHit() * 1.5f);",
        "MeleeHitDetection.applyDamage((ServerWorld) player.getWorld(), player, targets, damage, knockback);`n             // === HITSTOP_KICK ===`n             for (LivingEntity t : targets) {`n                 ShinobiCore.broadcastHitStop(player, t, 100, 200);`n             }`n             data.setFatigue(data.getFatigue() + style.getFatiguePerHit() * 1.5f);"
    )
    Write-File $mpPath $mp4
    Write-Host "[FIX] ModPackets: added hit-stop to TAIJUTSU_KICK"
}

Write-Host ""
Write-Host "=== PHASE 4 APPLIED ==="
Write-Host "Run: .\gradlew.bat build"
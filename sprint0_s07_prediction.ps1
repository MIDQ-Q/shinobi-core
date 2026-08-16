# ============================================================
#  SPRINT 0 / S0-07: CLIENT PREDICTION FRAMEWORK
#  PS 5.1 compatible. ASCII only. UTF8 no BOM.
#  Run: powershell -ExecutionPolicy Bypass -File .\sprint0_s07_prediction.ps1
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$java = "$root\src\main\java\com\example\shinobicore"
$ok = 0; $skip = 0; $err = 0

function Write-File($p, $c) {
    $dir = [System.IO.Path]::GetDirectoryName($p)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] Created: $($p.Replace($root, ''))" -ForegroundColor Green
    $script:ok++
}

function Patch-File($p, $old, $new) {
    if (-not (Test-Path $p)) {
        Write-Host "[MISS] $p" -ForegroundColor Red
        $script:err++
        return
    }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    $cNorm = $c.Replace("`r`n", "`n")
    $oldNorm = $old.Replace("`r`n", "`n")
    $newNorm = $new.Replace("`r`n", "`n")
    
    if ($cNorm.Contains($newNorm)) {
        Write-Host "[SKIP] already: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Yellow
        $script:skip++
        return
    }
    if (-not $cNorm.Contains($oldNorm)) {
        Write-Host "[FAIL] pattern not found: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Red
        $script:err++
        return
    }
    $c = $c.Replace($oldNorm, $newNorm)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] patched: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Green
    $script:ok++
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  SPRINT 0 / S0-07: CLIENT PREDICTION FRAMEWORK" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# ================================================================
# 1. ClientPredictionManager.java
# ================================================================
Write-Host "[1/6] ClientPredictionManager.java..." -ForegroundColor White
$content1 = @'
package com.example.shinobicore.client.prediction;

import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;
import java.util.LinkedList;
import java.util.Queue;

/**
 * S0-07: Client-side prediction framework.
 * Tracks pending actions and handles smooth rollbacks on server correction.
 */
public class ClientPredictionManager {
    private static final Queue<PendingAction> pendingActions = new LinkedList<>();
    
    private static boolean correcting = false;
    private static Vec3d correctionStartPos = Vec3d.ZERO;
    private static Vec3d correctionTargetPos = Vec3d.ZERO;
    private static int correctionTicks = 0;
    private static final int CORRECTION_DURATION_TICKS = 5; // 0.25s smooth lerp

    public static void registerAction(String actionId, Vec3d appliedVelocity) {
        pendingActions.add(new PendingAction(actionId, System.currentTimeMillis(), appliedVelocity));
        if (pendingActions.size() > 20) {
            pendingActions.poll();
        }
    }

    public static void acknowledgeAction(String actionId) {
        pendingActions.removeIf(a -> a.actionId.equals(actionId));
    }

    public static void applyCorrection(ClientPlayerEntity player, Vec3d serverPos, Vec3d serverVel) {
        if (player == null) return;
        Vec3d currentPos = player.getPos();
        double distance = currentPos.distanceTo(serverPos);
        
        if (distance < 0.05) return; // Ignore micro-drifts
        
        if (distance > 10.0) {
            // Hard snap for huge divergence (anti-cheat/teleport)
            player.setPosition(serverPos.x, serverPos.y, serverPos.z);
            player.setVelocity(serverVel);
            pendingActions.clear();
            correcting = false;
            return;
        }

        // Smooth rollback (lerp)
        correcting = true;
        correctionStartPos = currentPos;
        correctionTargetPos = serverPos;
        correctionTicks = 0;
        player.setVelocity(serverVel);
        pendingActions.clear();
    }

    public static void tick(ClientPlayerEntity player) {
        if (player == null) return;
        
        if (correcting) {
            correctionTicks++;
            float progress = (float) correctionTicks / CORRECTION_DURATION_TICKS;
            if (progress >= 1.0f) {
                player.setPosition(correctionTargetPos.x, correctionTargetPos.y, correctionTargetPos.z);
                correcting = false;
            } else {
                double x = correctionStartPos.x + (correctionTargetPos.x - correctionStartPos.x) * progress;
                double y = correctionStartPos.y + (correctionTargetPos.y - correctionStartPos.y) * progress;
                double z = correctionStartPos.z + (correctionTargetPos.z - correctionStartPos.z) * progress;
                player.setPosition(x, y, z);
            }
        }
        
        long now = System.currentTimeMillis();
        pendingActions.removeIf(a -> now - a.timestamp > 1000);
    }
    
    public static boolean isCorrecting() {
        return correcting;
    }

    private record PendingAction(String actionId, long timestamp, Vec3d velocity) {}
}
'@
Write-File "$java\client\prediction\ClientPredictionManager.java" $content1

# ================================================================
# 2. PredictionCorrectionPacket.java
# ================================================================
Write-Host "[2/6] PredictionCorrectionPacket.java..." -ForegroundColor White
$content2 = @'
package com.example.shinobicore.network;

import net.minecraft.network.PacketByteBuf;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.Vec3d;

/**
 * S0-07: Server -> Client correction packet.
 * Sent when server authoritative state diverges from client prediction.
 */
public record PredictionCorrectionPacket(double x, double y, double z, double vx, double vy, double vz) {
    public static final Identifier ID = new Identifier("shinobicore", "prediction_correction");

    public void write(PacketByteBuf buf) {
        buf.writeDouble(x);
        buf.writeDouble(y);
        buf.writeDouble(z);
        buf.writeDouble(vx);
        buf.writeDouble(vy);
        buf.writeDouble(vz);
    }

    public static PredictionCorrectionPacket read(PacketByteBuf buf) {
        return new PredictionCorrectionPacket(
            buf.readDouble(), buf.readDouble(), buf.readDouble(),
            buf.readDouble(), buf.readDouble(), buf.readDouble()
        );
    }
    
    public Vec3d getPos() { return new Vec3d(x, y, z); }
    public Vec3d getVel() { return new Vec3d(vx, vy, vz); }
}
'@
$packetPath = Join-Path $java "network\PredictionCorrectionPacket.java"
Write-File $packetPath $content2

# ================================================================
# 3. Patch ModPackets.java
# ================================================================
Write-Host "[3/6] Patching ModPackets.java..." -ForegroundColor White
$modPacketsPath = "$java\network\ModPackets.java"
Patch-File $modPacketsPath `
"public static final Identifier IAI_DASH_ID = new Identifier(""shinobicore"", ""iai_dash"");" `
"public static final Identifier IAI_DASH_ID = new Identifier(""shinobicore"", ""iai_dash"");`n    public static final Identifier PREDICTION_CORRECTION_ID = new Identifier(""shinobicore"", ""prediction_correction"");"

# ================================================================
# 4. Patch ShinobiCoreClient.java
# ================================================================
Write-Host "[4/6] Patching ShinobiCoreClient.java..." -ForegroundColor White
$clientPath = "$java\client\ShinobiCoreClient.java"

# Add tick handler
Patch-File $clientPath `
"ClientTickEvents.END_CLIENT_TICK.register(CinematicCamera::tick);" `
"ClientTickEvents.END_CLIENT_TICK.register(CinematicCamera::tick);`n        ClientTickEvents.END_CLIENT_TICK.register(client -> {`n            if (client.player != null) {`n                com.example.shinobicore.client.prediction.ClientPredictionManager.tick(client.player);`n            }`n        });"

# Add packet receiver
Patch-File $clientPath `
"ClientPlayNetworking.registerGlobalReceiver(ModPackets.HIT_STOP_ID, (client, handler, buf, responseSender) -> {" `
"ClientPlayNetworking.registerGlobalReceiver(com.example.shinobicore.network.PredictionCorrectionPacket.ID, (client, handler, buf, responseSender) -> {`n            final com.example.shinobicore.network.PredictionCorrectionPacket packet = com.example.shinobicore.network.PredictionCorrectionPacket.read(buf);`n            client.execute(() -> {`n                if (client.player != null) {`n                    com.example.shinobicore.client.prediction.ClientPredictionManager.applyCorrection(client.player, packet.getPos(), packet.getVel());`n                }`n            });`n        });`n`n        ClientPlayNetworking.registerGlobalReceiver(ModPackets.HIT_STOP_ID, (client, handler, buf, responseSender) -> {"

# ================================================================
# 5. Patch ShinobiCore.java (Server-side helper)
# ================================================================
Write-Host "[5/6] Patching ShinobiCore.java..." -ForegroundColor White
$serverPath = "$java\ShinobiCore.java"
Patch-File $serverPath `
"public static void broadcastHitStop(ServerPlayerEntity attacker, net.minecraft.entity.LivingEntity target," `
"public static void sendPredictionCorrection(ServerPlayerEntity player) {`n        net.minecraft.network.PacketByteBuf buf = new net.minecraft.network.PacketByteBuf(io.netty.buffer.Unpooled.buffer());`n        new com.example.shinobicore.network.PredictionCorrectionPacket(`n            player.getX(), player.getY(), player.getZ(),`n            player.getVelocity().x, player.getVelocity().y, player.getVelocity().z`n        ).write(buf);`n        net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking.send(player, com.example.shinobicore.network.ModPackets.PREDICTION_CORRECTION_ID, buf);`n    }`n`n    public static void broadcastHitStop(ServerPlayerEntity attacker, net.minecraft.entity.LivingEntity target,"

# ================================================================
# 6. Patch DodgeAction.java (Hook into framework)
# ================================================================
Write-Host "[6/6] Patching DodgeAction.java..." -ForegroundColor White
$dodgePath = "$java\client\parkour\actions\DodgeAction.java"
Patch-File $dodgePath `
"player.addVelocity(right.x * direction * DODGE_IMPULSE, 0.2, right.z * direction * DODGE_IMPULSE);`n        player.velocityModified = true;" `
"player.addVelocity(right.x * direction * DODGE_IMPULSE, 0.2, right.z * direction * DODGE_IMPULSE);`n        player.velocityModified = true;`n        com.example.shinobicore.client.prediction.ClientPredictionManager.registerAction(""dodge"", player.getVelocity());"

# ================================================================
# SUMMARY & EXIT CODE
# ================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  S0-07 COMPLETE: OK=$ok SKIP=$skip ERR=$err" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Created:" -ForegroundColor White
Write-Host "    client/prediction/ClientPredictionManager.java" -ForegroundColor White
Write-Host "    network/PredictionCorrectionPacket.java" -ForegroundColor White
Write-Host ""
Write-Host "  Patched:" -ForegroundColor White
Write-Host "    ModPackets.java             - +PREDICTION_CORRECTION_ID" -ForegroundColor White
Write-Host "    ShinobiCoreClient.java      - +receiver + tick" -ForegroundColor White
Write-Host "    ShinobiCore.java            - +sendPredictionCorrection()" -ForegroundColor White
Write-Host "    DodgeAction.java            - hooked to prediction" -ForegroundColor White
Write-Host ""

if ($err -gt 0) {
    Write-Host "  [ABORT] $err error(s) detected - stopping sprint chain!" -ForegroundColor Red
    exit 1
}
Write-Host "  Next: .\gradlew.bat build" -ForegroundColor Yellow
exit 0
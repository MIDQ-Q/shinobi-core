# ============================================================
#  SPRINT 0 / S0-06: NETWORK LAYER
#  Centralized packet registry, debug logging, delta-sync
#  PS 5.1 compatible. ASCII only. UTF8 no BOM.
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
    Write-Host "[OK] $($p.Replace($root, ''))" -ForegroundColor Green
    $script:ok++
}

function Patch-File($p, $old, $new) {
    if (-not (Test-Path $p)) { Write-Host "[MISS] $p" -ForegroundColor Red; $script:err++; return }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    $cNorm = $c.Replace("`r`n", "`n")
    $oldNorm = $old.Replace("`r`n", "`n")
    $newNorm = $new.Replace("`r`n", "`n")
    if ($cNorm.Contains($newNorm)) { Write-Host "[SKIP] already: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Yellow; $script:skip++; return }
    if (-not $cNorm.Contains($oldNorm)) { Write-Host "[FAIL] pattern not found: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Red; $script:err++; return }
    $c = $c.Replace($oldNorm, $newNorm)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] patched: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Green
    $script:ok++
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  SPRINT 0 / S0-06: NETWORK LAYER" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# ================================================================
# 1. NetworkDebugLogger.java - packet logging in debug mode
# ================================================================
Write-Host "[1/5] NetworkDebugLogger.java..." -ForegroundColor White
$contentLogger = @'
package com.example.shinobicore.network;

import com.example.shinobicore.ShinobiCore;

/**
 * S0-06: Debug logging for all network packets.
 * Logs packet name, direction, and player in debug mode.
 * Enable via /ninja debug network on|off
 */
public class NetworkDebugLogger {
    private static boolean enabled = false;
    private static long packetCount = 0;
    private static long lastResetMs = System.currentTimeMillis();
    private static long packetsPerSecond = 0;

    public static void setEnabled(boolean value) {
        enabled = value;
        ShinobiCore.LOGGER.info("[NET-DEBUG] Packet logging {}", value ? "ENABLED" : "DISABLED");
    }

    public static boolean isEnabled() { return enabled; }

    public static void logPacket(String packetName, String direction, String playerName) {
        if (!enabled) return;
        packetCount++;
        long now = System.currentTimeMillis();
        if (now - lastResetMs >= 1000) {
            packetsPerSecond = packetCount;
            packetCount = 0;
            lastResetMs = now;
        }
        ShinobiCore.LOGGER.debug("[NET] {} {} player={} ({} p/s)",
                direction, packetName, playerName, packetsPerSecond);
    }

    public static void logPacket(String packetName, String direction, String playerName, String details) {
        if (!enabled) return;
        packetCount++;
        long now = System.currentTimeMillis();
        if (now - lastResetMs >= 1000) {
            packetsPerSecond = packetCount;
            packetCount = 0;
            lastResetMs = now;
        }
        ShinobiCore.LOGGER.debug("[NET] {} {} player={} [{}] ({} p/s)",
                direction, packetName, playerName, details, packetsPerSecond);
    }

    public static long getPacketsPerSecond() { return packetsPerSecond; }
}
'@
Write-File "$java\network\NetworkDebugLogger.java" $contentLogger

# ================================================================
# 2. PacketHelper.java - compact write/read helpers
# ================================================================
Write-Host "[2/5] PacketHelper.java..." -ForegroundColor White
$contentHelper = @'
package com.example.shinobicore.network;

import net.minecraft.network.PacketByteBuf;
import net.minecraft.util.math.Vec3d;

/**
 * S0-06: Helpers for compact packet serialization.
 * Use compact IDs instead of full NBT. Delta-sync for frequent updates.
 */
public class PacketHelper {

    /** Write Vec3d as 3 floats (12 bytes vs NBT overhead). */
    public static void writeVec3d(PacketByteBuf buf, Vec3d v) {
        buf.writeFloat((float) v.x);
        buf.writeFloat((float) v.y);
        buf.writeFloat((float) v.z);
    }

    /** Read Vec3d from 3 floats. */
    public static Vec3d readVec3d(PacketByteBuf buf) {
        return new Vec3d(buf.readFloat(), buf.readFloat(), buf.readFloat());
    }

    /** Write optional string (empty string = null). */
    public static void writeOptionalString(PacketByteBuf buf, String s) {
        buf.writeString(s != null ? s : "");
    }

    /** Read optional string (empty string = null). */
    public static String readOptionalString(PacketByteBuf buf) {
        String s = buf.readString();
        return s.isEmpty() ? null : s;
    }

    /** Write compact entity reference (entity ID, 4 bytes). */
    public static void writeEntityId(PacketByteBuf buf, int entityId) {
        buf.writeVarInt(entityId);
    }

    /** Read compact entity reference. */
    public static int readEntityId(PacketByteBuf buf) {
        return buf.readVarInt();
    }

    /** Write compact VFX type ID (byte, max 255 types). */
    public static void writeVfxType(PacketByteBuf buf, int vfxType) {
        buf.writeByte(vfxType);
    }

    /** Read compact VFX type ID. */
    public static int readVfxType(PacketByteBuf buf) {
        return buf.readByte() & 0xFF;
    }

    /** Write delta float (only if changed more than epsilon). */
    public static boolean writeDeltaFloat(PacketByteBuf buf, float current, float lastSynced, float epsilon) {
        if (Math.abs(current - lastSynced) > epsilon) {
            buf.writeFloat(current);
            return true;
        }
        return false;
    }
}
'@
Write-File "$java\network\PacketHelper.java" $contentHelper

# ================================================================
# 3. S06NetworkLayer.java - new packets for future systems
# ================================================================
Write-Host "[3/5] S06NetworkLayer.java..." -ForegroundColor White
$contentLayer = @'
package com.example.shinobicore.network;

import com.example.shinobicore.ShinobiCore;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.Identifier;

/**
 * S0-06: Network layer - new packets for future systems.
 * Kawarimi (S2-04), clones (S10), VFX, dojutsu state, hit results.
 *
 * Design rules:
 * - Server sends only needed data (no full NBT).
 * - Use compact IDs for visuals.
 * - Frequent updates use delta-sync.
 * - READ ALL DATA BEFORE server.execute() / client.execute()!
 */
public class S06NetworkLayer {

    // === S2C: Server -> Client ===
    public static final Identifier CAST_COMPLETE_ID =
            new Identifier("shinobicore", "cast_complete");
    public static final Identifier VFX_SPAWN_ID =
            new Identifier("shinobicore", "vfx_spawn");
    public static final Identifier HIT_RESULT_ID =
            new Identifier("shinobicore", "hit_result");
    public static final Identifier DOJUTSU_STATE_ID =
            new Identifier("shinobicore", "dojutsu_state");
    public static final Identifier KAWARIMI_FX_ID =
            new Identifier("shinobicore", "kawarimi_fx");
    public static final Identifier CLONE_SPAWN_ID =
            new Identifier("shinobicore", "clone_spawn");
    public static final Identifier CLONE_DESPAWN_ID =
            new Identifier("shinobicore", "clone_despawn");
    public static final Identifier SENSORY_STATE_ID =
            new Identifier("shinobicore", "sensory_state");

    // === C2S: Client -> Server ===
    public static final Identifier KAWARIMI_ID =
            new Identifier("shinobicore", "kawarimi");

    // === VFX Type IDs (compact byte, max 255) ===
    public static final int VFX_SMOKE = 0;
    public static final int VFX_FIRE_BURST = 1;
    public static final int VFX_WATER_SPLASH = 2;
    public static final int VFX_LIGHTNING_SPARK = 3;
    public static final int VFX_WIND_GUST = 4;
    public static final int VFX_EARTH_CRACK = 5;
    public static final int VFX_KAWARIMI_POOF = 6;
    public static final int VFX_CLONE_POOF = 7;
    public static final int VFX_DOJUTSU_ACTIVATE = 8;
    public static final int VFX_HIT_IMPACT = 9;

    /**
     * Register server-side receivers (C2S packets).
     * Called from ModPackets.register().
     */
    public static void register() {
        // Kawarimi request (C2S) - actual logic in S2-04
        ServerPlayNetworking.registerGlobalReceiver(KAWARIMI_ID,
                (server, player, handler, buf, responseSender) -> {
            // RULE: Read ALL data BEFORE server.execute()!
            // No extra data for now, just the request itself.
            server.execute(() -> {
                NetworkDebugLogger.logPacket("kawarimi", "C2S",
                        player.getName().getString());
                // TODO S2-04: Implement kawarimi window logic
                // 1. Check cooldown
                // 2. Open 3-second window
                // 3. If damage received during window -> substitute
            });
        });

        ShinobiCore.LOGGER.info("[S0-06] Network layer registered (server)");
    }

    // === Server-side broadcast helpers ===

    /** Broadcast VFX spawn to nearby players. Compact: type + position. */
    public static void broadcastVfx(ServerPlayerEntity source, int vfxType,
                                     double x, double y, double z, float scale) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        PacketHelper.writeVfxType(buf, vfxType);
        buf.writeDouble(x);
        buf.writeDouble(y);
        buf.writeDouble(z);
        buf.writeFloat(scale);
        for (ServerPlayerEntity p : net.fabricmc.fabric.api.networking.v1.PlayerLookup.tracking(source)) {
            ServerPlayNetworking.send(p, VFX_SPAWN_ID, buf);
        }
        ServerPlayNetworking.send(source, VFX_SPAWN_ID, buf);
        NetworkDebugLogger.logPacket("vfx_spawn", "S2C",
                source.getName().getString(), "type=" + vfxType);
    }

    /** Broadcast hit result to nearby players. */
    public static void broadcastHitResult(ServerPlayerEntity attacker,
                                           int targetEntityId, float damage, boolean crit) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        PacketHelper.writeEntityId(buf, attacker.getId());
        PacketHelper.writeEntityId(buf, targetEntityId);
        buf.writeFloat(damage);
        buf.writeBoolean(crit);
        for (ServerPlayerEntity p : net.fabricmc.fabric.api.networking.v1.PlayerLookup.tracking(attacker)) {
            ServerPlayNetworking.send(p, HIT_RESULT_ID, buf);
        }
        ServerPlayNetworking.send(attacker, HIT_RESULT_ID, buf);
        NetworkDebugLogger.logPacket("hit_result", "S2C",
                attacker.getName().getString(),
                "target=" + targetEntityId + " dmg=" + damage);
    }

    /** Send dojutsu state to player. */
    public static void sendDojutsuState(ServerPlayerEntity player,
                                         String dojutsuId, int stage, boolean active) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        PacketHelper.writeOptionalString(buf, dojutsuId);
        buf.writeByte(stage);
        buf.writeBoolean(active);
        ServerPlayNetworking.send(player, DOJUTSU_STATE_ID, buf);
        NetworkDebugLogger.logPacket("dojutsu_state", "S2C",
                player.getName().getString(),
                "id=" + dojutsuId + " stage=" + stage);
    }

    /** Broadcast kawarimi FX (log + smoke at position). */
    public static void broadcastKawarimiFx(ServerPlayerEntity player,
                                            double x, double y, double z) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeDouble(x);
        buf.writeDouble(y);
        buf.writeDouble(z);
        for (ServerPlayerEntity p : net.fabricmc.fabric.api.networking.v1.PlayerLookup.tracking(player)) {
            ServerPlayNetworking.send(p, KAWARIMI_FX_ID, buf);
        }
        ServerPlayNetworking.send(player, KAWARIMI_FX_ID, buf);
        NetworkDebugLogger.logPacket("kawarimi_fx", "S2C",
                player.getName().getString());
    }

    /** Broadcast clone spawn. */
    public static void broadcastCloneSpawn(ServerPlayerEntity owner,
                                            int cloneEntityId, double x, double y, double z) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        PacketHelper.writeEntityId(buf, owner.getId());
        PacketHelper.writeEntityId(buf, cloneEntityId);
        buf.writeDouble(x);
        buf.writeDouble(y);
        buf.writeDouble(z);
        for (ServerPlayerEntity p : net.fabricmc.fabric.api.networking.v1.PlayerLookup.tracking(owner)) {
            ServerPlayNetworking.send(p, CLONE_SPAWN_ID, buf);
        }
        ServerPlayNetworking.send(owner, CLONE_SPAWN_ID, buf);
        NetworkDebugLogger.logPacket("clone_spawn", "S2C",
                owner.getName().getString(), "clone=" + cloneEntityId);
    }

    /** Broadcast clone despawn (dispersion). */
    public static void broadcastCloneDespawn(ServerPlayerEntity owner,
                                              int cloneEntityId) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        PacketHelper.writeEntityId(buf, cloneEntityId);
        for (ServerPlayerEntity p : net.fabricmc.fabric.api.networking.v1.PlayerLookup.tracking(owner)) {
            ServerPlayNetworking.send(p, CLONE_DESPAWN_ID, buf);
        }
        ServerPlayNetworking.send(owner, CLONE_DESPAWN_ID, buf);
        NetworkDebugLogger.logPacket("clone_despawn", "S2C",
                owner.getName().getString(), "clone=" + cloneEntityId);
    }

    /** Send cast complete to player. */
    public static void sendCastComplete(ServerPlayerEntity player, String jutsuId) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        PacketHelper.writeOptionalString(buf, jutsuId);
        ServerPlayNetworking.send(player, CAST_COMPLETE_ID, buf);
        NetworkDebugLogger.logPacket("cast_complete", "S2C",
                player.getName().getString(), "jutsu=" + jutsuId);
    }

    /** Send sensory state to player. */
    public static void sendSensoryState(ServerPlayerEntity player,
                                         int tier, int radius, boolean active) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeByte(tier);
        buf.writeVarInt(radius);
        buf.writeBoolean(active);
        ServerPlayNetworking.send(player, SENSORY_STATE_ID, buf);
        NetworkDebugLogger.logPacket("sensory_state", "S2C",
                player.getName().getString(),
                "tier=" + tier + " radius=" + radius);
    }
}
'@
Write-File "$java\network\S06NetworkLayer.java" $contentLayer

# ================================================================
# 4. Patch ModPackets.java - call S06NetworkLayer.register()
# ================================================================
Write-Host "[4/5] Patching ModPackets.java..." -ForegroundColor White
Patch-File "$java\network\ModPackets.java" `
"public static void register() {" `
"public static void register() {`n        S06NetworkLayer.register(); // S0-06"

# ================================================================
# 5. Patch ShinobiCoreClient.java - register client receivers
# ================================================================
Write-Host "[5/5] Patching ShinobiCoreClient.java..." -ForegroundColor White

# 5a. Add import
Patch-File "$java\client\ShinobiCoreClient.java" `
"import com.example.shinobicore.network.AttributeSyncPacket;" `
"import com.example.shinobicore.network.AttributeSyncPacket;`nimport com.example.shinobicore.network.S06NetworkLayer;`nimport com.example.shinobicore.network.NetworkDebugLogger;"

# 5b. Add client receiver registration at end of onInitializeClient
Patch-File "$java\client\ShinobiCoreClient.java" `
"NarutoArmorRenderer.register();" `
"NarutoArmorRenderer.register();`n`n        // === S0-06: Network layer client receivers ===`n        registerS06ClientReceivers();"

# 5c. Add the client receiver method before the closing brace
Patch-File "$java\client\ShinobiCoreClient.java" `
"LivingEntityFeatureRendererRegistrationCallback.EVENT.register((entityType, entityRenderer, registrationHelper, context) -> {" `
"// === S0-06: Client receivers for new packets ===`n    private void registerS06ClientReceivers() {`n        // VFX Spawn (S2C)`n        ClientPlayNetworking.registerGlobalReceiver(S06NetworkLayer.VFX_SPAWN_ID,`n                (client, handler, buf, responseSender) -> {`n            int vfxType = buf.readByte() & 0xFF;`n            double x = buf.readDouble();`n            double y = buf.readDouble();`n            double z = buf.readDouble();`n            float scale = buf.readFloat();`n            client.execute(() -> {`n                NetworkDebugLogger.logPacket(""vfx_spawn"", ""S2C"",`n                        client.player != null ? client.player.getName().getString() : ""?"",`n                        ""type="" + vfxType);`n                // TODO S4-06: Spawn voxel VFX based on type`n            });`n        });`n`n        // Hit Result (S2C)`n        ClientPlayNetworking.registerGlobalReceiver(S06NetworkLayer.HIT_RESULT_ID,`n                (client, handler, buf, responseSender) -> {`n            int attackerId = buf.readVarInt();`n            int targetId = buf.readVarInt();`n            float damage = buf.readFloat();`n            boolean crit = buf.readBoolean();`n            client.execute(() -> {`n                NetworkDebugLogger.logPacket(""hit_result"", ""S2C"",`n                        client.player != null ? client.player.getName().getString() : ""?"",`n                        ""dmg="" + damage + "" crit="" + crit);`n                // TODO: Play hit sound/particle at target position`n            });`n        });`n`n        // Dojutsu State (S2C)`n        ClientPlayNetworking.registerGlobalReceiver(S06NetworkLayer.DOJUTSU_STATE_ID,`n                (client, handler, buf, responseSender) -> {`n            String dojutsuId = buf.readString();`n            int stage = buf.readByte();`n            boolean active = buf.readBoolean();`n            client.execute(() -> {`n                NetworkDebugLogger.logPacket(""dojutsu_state"", ""S2C"",`n                        client.player != null ? client.player.getName().getString() : ""?"",`n                        ""id="" + dojutsuId + "" stage="" + stage);`n                ClientNinjaState.activeDojutsu = dojutsuId.isEmpty() ? null : dojutsuId;`n                // TODO S6-12: Update dojutsu HUD`n            });`n        });`n`n        // Kawarimi FX (S2C)`n        ClientPlayNetworking.registerGlobalReceiver(S06NetworkLayer.KAWARIMI_FX_ID,`n                (client, handler, buf, responseSender) -> {`n            double x = buf.readDouble();`n            double y = buf.readDouble();`n            double z = buf.readDouble();`n            client.execute(() -> {`n                NetworkDebugLogger.logPacket(""kawarimi_fx"", ""S2C"",`n                        client.player != null ? client.player.getName().getString() : ""?"");`n                // TODO S2-05: Spawn smoke + log at position`n            });`n        });`n`n        // Clone Spawn (S2C)`n        ClientPlayNetworking.registerGlobalReceiver(S06NetworkLayer.CLONE_SPAWN_ID,`n                (client, handler, buf, responseSender) -> {`n            int ownerId = buf.readVarInt();`n            int cloneId = buf.readVarInt();`n            double x = buf.readDouble();`n            double y = buf.readDouble();`n            double z = buf.readDouble();`n            client.execute(() -> {`n                NetworkDebugLogger.logPacket(""clone_spawn"", ""S2C"",`n                        client.player != null ? client.player.getName().getString() : ""?"",`n                        ""clone="" + cloneId);`n                // TODO S10-07: Spawn clone visual + smoke`n            });`n        });`n`n        // Clone Despawn (S2C)`n        ClientPlayNetworking.registerGlobalReceiver(S06NetworkLayer.CLONE_DESPAWN_ID,`n                (client, handler, buf, responseSender) -> {`n            int cloneId = buf.readVarInt();`n            client.execute(() -> {`n                NetworkDebugLogger.logPacket(""clone_despawn"", ""S2C"",`n                        client.player != null ? client.player.getName().getString() : ""?"",`n                        ""clone="" + cloneId);`n                // TODO S10-07: Play dispersion sound + smoke`n            });`n        });`n`n        // Cast Complete (S2C)`n        ClientPlayNetworking.registerGlobalReceiver(S06NetworkLayer.CAST_COMPLETE_ID,`n                (client, handler, buf, responseSender) -> {`n            String jutsuId = buf.readString();`n            client.execute(() -> {`n                NetworkDebugLogger.logPacket(""cast_complete"", ""S2C"",`n                        client.player != null ? client.player.getName().getString() : ""?"",`n                        ""jutsu="" + jutsuId);`n                // TODO: Update cast bar UI`n            });`n        });`n`n        // Sensory State (S2C)`n        ClientPlayNetworking.registerGlobalReceiver(S06NetworkLayer.SENSORY_STATE_ID,`n                (client, handler, buf, responseSender) -> {`n            int tier = buf.readByte();`n            int radius = buf.readVarInt();`n            boolean active = buf.readBoolean();`n            client.execute(() -> {`n                NetworkDebugLogger.logPacket(""sensory_state"", ""S2C"",`n                        client.player != null ? client.player.getName().getString() : ""?"",`n                        ""tier="" + tier + "" radius="" + radius);`n                // TODO S6-12: Update sensory HUD`n            });`n        });`n`n        ShinobiCore.LOGGER.info(""[S0-06] Network layer client receivers registered"");`n    }`n`n        LivingEntityFeatureRendererRegistrationCallback.EVENT.register((entityType, entityRenderer, registrationHelper, context) -> {"

# ================================================================
# SUMMARY & EXIT CODE
# ================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  S0-06 COMPLETE: OK=$ok SKIP=$skip ERR=$err" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Created:" -ForegroundColor White
Write-Host "    network/NetworkDebugLogger.java  - packet debug logging" -ForegroundColor White
Write-Host "    network/PacketHelper.java        - compact serialization helpers" -ForegroundColor White
Write-Host "    network/S06NetworkLayer.java     - 9 new packets + broadcast helpers" -ForegroundColor White
Write-Host ""
Write-Host "  New packets:" -ForegroundColor White
Write-Host "    S2C: cast_complete, vfx_spawn, hit_result, dojutsu_state" -ForegroundColor White
Write-Host "    S2C: kawarimi_fx, clone_spawn, clone_despawn, sensory_state" -ForegroundColor White
Write-Host "    C2S: kawarimi" -ForegroundColor White
Write-Host ""
Write-Host "  Patched:" -ForegroundColor White
Write-Host "    ModPackets.java                  - calls S06NetworkLayer.register()" -ForegroundColor White
Write-Host "    ShinobiCoreClient.java           - 8 client receivers registered" -ForegroundColor White
Write-Host ""

if ($err -gt 0) {
    Write-Host "  [ABORT] $err error(s) detected!" -ForegroundColor Red
    exit 1
}

Write-Host "  Next: .\gradlew.bat build" -ForegroundColor Yellow
Write-Host "  Then: sprint0_s07_prediction.ps1" -ForegroundColor Yellow
exit 0
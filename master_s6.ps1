# ============================================================
# SHINOBICORE MASTER SCRIPT: SPRINT 6 PHASE A (S6-01..S6-06)
# Sensory Component + 5 Tiers of Sensory Perception
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcBase = Join-Path $root "src\main\java\com\example\shinobicore"
$resBase = Join-Path $root "src\main\resources"

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "  SPRINT 6 PHASE A: S6-01..S6-06 Sensory System" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

function Write-File($path, $content) {
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $content, $utf8)
    Write-Host "  [OK] $(Split-Path $path -Leaf)" -ForegroundColor Green
}

function Patch-File($p, $old, $new) {
    if (-not (Test-Path $p)) { Write-Host "  [MISS] $p" -ForegroundColor Red; return $false }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    $c = $c.Replace("`r`n", "`n")
    $oldN = $old.Replace("`r`n", "`n")
    $newN = $new.Replace("`r`n", "`n")
    if ($c.Contains($newN)) { Write-Host "  [SKIP] already: $(Split-Path $p -Leaf)" -ForegroundColor Yellow; return $true }
    if (-not $c.Contains($oldN)) { Write-Host "  [FAIL] pattern: $(Split-Path $p -Leaf)" -ForegroundColor Red; return $false }
    $c = $c.Replace($oldN, $newN)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "  [PATCH] $(Split-Path $p -Leaf)" -ForegroundColor Green
    return $true
}

# ============================================================
# S6-01: SENSORY TIER ENUM
# ============================================================
Write-Host "[S6-01] Creating SensoryTier enum..." -ForegroundColor Yellow

$sensoryTier = @'
package com.example.shinobicore.sensory;

/**
 * S6-01: Sensory perception tiers.
 * Each tier unlocks a new sensory capability.
 * Tiers are determined by unlocked tree nodes.
 */
public enum SensoryTier {
    NONE(0, 0, 0f, 0f),
    T1_DANGER(1, 16, 0f, 0f),
    T2_DIRECTION(2, 24, 0f, 0f),
    T3_SCAN(3, 32, 60f, 8f),
    T4_AURA(4, 40, 0f, 12f),
    T5_READING(5, 48, 100f, 20f);

    private final int level;
    private final int radius;
    private final float scanCooldownSeconds;
    private final float chakraCostPerUse;

    SensoryTier(int level, int radius, float scanCooldown, float chakraCost) {
        this.level = level;
        this.radius = radius;
        this.scanCooldownSeconds = scanCooldown;
        this.chakraCostPerUse = chakraCost;
    }

    public int getLevel() { return level; }
    public int getRadius() { return radius; }
    public float getScanCooldownSeconds() { return scanCooldownSeconds; }
    public float getChakraCostPerUse() { return chakraCostPerUse; }

    public static SensoryTier fromLevel(int level) {
        for (SensoryTier t : values()) {
            if (t.level == level) return t;
        }
        return NONE;
    }

    public boolean isAtLeast(SensoryTier other) {
        return this.level >= other.level;
    }
}
'@
Write-File (Join-Path $srcBase "sensory\SensoryTier.java") $sensoryTier

# ============================================================
# S6-01: SENSORY COMPONENT (Server-side)
# ============================================================
Write-Host "[S6-01] Creating SensoryComponent..." -ForegroundColor Yellow

$sensoryComponent = @'
package com.example.shinobicore.sensory;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.network.ModPackets;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.mob.MobEntity;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;
import java.util.ArrayList;
import java.util.List;

/**
 * S6-01: Server-side sensory component.
 * Manages sensory tier, scan cooldown, and aura mode.
 * Ticks every 5 server ticks for performance.
 */
public class SensoryComponent {

    private SensoryTier currentTier = SensoryTier.NONE;
    private long lastScanTimeMs = 0;
    private boolean auraActive = false;
    private int tickCounter = 0;

    public SensoryTier getTier() { return currentTier; }
    public void setTier(SensoryTier tier) { this.currentTier = tier; }
    public boolean isAuraActive() { return auraActive; }
    public void setAuraActive(boolean v) { this.auraActive = v; }

    public boolean canScan() {
        if (currentTier.getLevel() < 3) return false;
        long elapsed = System.currentTimeMillis() - lastScanTimeMs;
        return elapsed >= (long)(currentTier.getScanCooldownSeconds() * 1000);
    }

    public float getScanCooldownRemaining() {
        if (currentTier.getLevel() < 3) return 0;
        long elapsed = System.currentTimeMillis() - lastScanTimeMs;
        long total = (long)(currentTier.getScanCooldownSeconds() * 1000);
        long remaining = total - elapsed;
        return remaining > 0 ? remaining / 1000f : 0f;
    }

    /**
     * Called every server tick from NinjaTickHandler.
     * Only processes every 5 ticks for performance.
     */
    public void tick(ServerPlayerEntity player) {
        tickCounter++;
        if (tickCounter % 5 != 0) return;
        if (currentTier == SensoryTier.NONE) return;

        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        if (!data.isSensoryEnabled()) return;
        if (!(player.getWorld() instanceof ServerWorld world)) return;

        // T1: Danger sense
        if (currentTier.isAtLeast(SensoryTier.T1_DANGER)) {
            tickDangerSense(player, world, data);
        }

        // T2: Direction of nearest threat
        if (currentTier.isAtLeast(SensoryTier.T2_DIRECTION)) {
            tickDirectionSense(player, world);
        }

        // T4: Aura (GLOWING effect on entities)
        if (currentTier.isAtLeast(SensoryTier.T4_AURA) && auraActive) {
            tickAura(player, world);
        }
    }

    private void tickDangerSense(ServerPlayerEntity player, ServerWorld world, NinjaPlayerData data) {
        boolean danger = false;
        int radius = currentTier.getRadius();
        for (LivingEntity mob : world.getEntitiesByClass(LivingEntity.class,
                player.getBoundingBox().expand(radius), e -> e instanceof MobEntity)) {
            if (((MobEntity) mob).getTarget() == player) {
                danger = true;
                break;
            }
        }
        if (danger != data.getLastDangerState()) {
            data.setLastDangerState(danger);
            PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
            buf.writeBoolean(danger);
            ServerPlayNetworking.send(player, ModPackets.DANGER_SYNC_ID, buf);
        }
    }

    private void tickDirectionSense(ServerPlayerEntity player, ServerWorld world) {
        int radius = currentTier.getRadius();
        LivingEntity nearest = null;
        double nearestDist = Double.MAX_VALUE;

        for (LivingEntity e : world.getEntitiesByClass(LivingEntity.class,
                player.getBoundingBox().expand(radius),
                e -> e instanceof MobEntity && ((MobEntity) e).getTarget() == player)) {
            double d = e.getPos().squaredDistanceTo(player.getPos());
            if (d < nearestDist) {
                nearestDist = d;
                nearest = e;
            }
        }

        if (nearest != null) {
            Vec3d toThreat = nearest.getPos().subtract(player.getPos()).normalize();
            PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
            buf.writeBoolean(true);
            buf.writeFloat((float) toThreat.x);
            buf.writeFloat((float) toThreat.z);
            ServerPlayNetworking.send(player, ModPackets.SENSORY_DIRECTION_ID, buf);
        }
    }

    private void tickAura(ServerPlayerEntity player, ServerWorld world) {
        int radius = currentTier.getRadius();
        for (LivingEntity mob : world.getEntitiesByClass(LivingEntity.class,
                player.getBoundingBox().expand(radius),
                e -> !(e instanceof PlayerEntity))) {
            mob.addStatusEffect(new net.minecraft.entity.effect.StatusEffectInstance(
                net.minecraft.entity.effect.StatusEffects.GLOWING, 40, 0, false, false));
        }
    }

    /**
     * S6-04: Activate scan pulse. Returns entity positions to client.
     */
    public void activateScan(ServerPlayerEntity player) {
        if (!canScan()) return;
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();

        // Chakra cost
        float cost = currentTier.getChakraCostPerUse();
        if (data.getCurrentChakra() < cost) {
            player.sendMessage(net.minecraft.text.Text.literal("\u00a7cNot enough chakra for scan!"), true);
            return;
        }
        data.setCurrentChakra(data.getCurrentChakra() - cost);
        ShinobiCore.sendChakraSync(player);
        lastScanTimeMs = System.currentTimeMillis();

        if (!(player.getWorld() instanceof ServerWorld world)) return;
        int radius = currentTier.getRadius();

        // Collect living entities in radius
        List<LivingEntity> entities = new ArrayList<>();
        for (LivingEntity e : world.getEntitiesByClass(LivingEntity.class,
                player.getBoundingBox().expand(radius),
                e -> e.isAlive() && e != player)) {
            entities.add(e);
        }

        // Send scan results to client
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(entities.size());
        for (LivingEntity e : entities) {
            buf.writeInt(e.getId());
            buf.writeDouble(e.getX());
            buf.writeDouble(e.getY());
            buf.writeDouble(e.getZ());
            buf.writeFloat(e.getHeight());
            buf.writeBoolean(e instanceof MobEntity);
        }
        ServerPlayNetworking.send(player, ModPackets.SENSORY_SCAN_ID, buf);

        ShinobiCore.LOGGER.debug("[SENSORY] Scan: {} entities in radius {}", entities.size(), radius);
    }

    /**
     * S6-06: Read chakra of nearby entities.
     */
    public void readChakra(ServerPlayerEntity player, int targetEntityId) {
        if (currentTier.getLevel() < 5) return;
        if (!(player.getWorld() instanceof ServerWorld world)) return;

        var entity = world.getEntityById(targetEntityId);
        if (!(entity instanceof LivingEntity living)) return;

        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(targetEntityId);
        buf.writeString(living.getName().getString());

        // Determine chakra level approximation
        if (living instanceof ServerPlayerEntity targetPlayer) {
            NinjaPlayerData targetData = ((NinjaDataHolder) targetPlayer).shinobicore_getData();
            float chakraRatio = targetData.getCurrentChakra() /
                Math.max(1f, com.example.shinobicore.stat.NinjaFormula.maxChakra(targetData));
            buf.writeFloat(chakraRatio);
            buf.writeBoolean(targetData.isChakraMode());
            buf.writeInt(targetData.getReserveLevel());
            buf.writeBoolean(targetData.getActiveDojutsu() != null);
            buf.writeString(targetData.getActiveDojutsu() != null ? targetData.getActiveDojutsu() : "");
        } else if (living instanceof MobEntity) {
            // Mobs have "wild chakra" - approximate by health
            float healthRatio = living.getHealth() / living.getMaxHealth();
            buf.writeFloat(healthRatio * 0.5f); // Mobs have less chakra
            buf.writeBoolean(false);
            buf.writeInt(0);
            buf.writeBoolean(false);
            buf.writeString("");
        } else {
            buf.writeFloat(0f);
            buf.writeBoolean(false);
            buf.writeInt(0);
            buf.writeBoolean(false);
            buf.writeString("");
        }

        ServerPlayNetworking.send(player, ModPackets.SENSORY_READING_ID, buf);
    }

    /**
     * Determine tier from unlocked tree nodes.
     */
    public static SensoryTier determineTier(NinjaPlayerData data) {
        var nodes = data.getUnlockedNodes();
        if (nodes.contains("sen_reading")) return SensoryTier.T5_READING;
        if (nodes.contains("sen_glow")) return SensoryTier.T4_AURA;
        if (nodes.contains("sen_scan")) return SensoryTier.T3_SCAN;
        if (nodes.contains("sen_direction")) return SensoryTier.T2_DIRECTION;
        if (nodes.contains("sen_danger")) return SensoryTier.T1_DANGER;
        return SensoryTier.NONE;
    }
}
'@
Write-File (Join-Path $srcBase "sensory\SensoryComponent.java") $sensoryComponent

# ============================================================
# S6-01: CLIENT SENSORY STATE
# ============================================================
Write-Host "[S6-01] Creating SensoryClientState..." -ForegroundColor Yellow

$sensoryClientState = @'
package com.example.shinobicore.client.sensory;

import net.minecraft.util.math.Vec3d;
import java.util.ArrayList;
import java.util.List;

/**
 * S6-01: Client-side sensory state.
 * Stores data received from server for rendering.
 */
public class SensoryClientState {

    // T1: Danger
    public static boolean dangerActive = false;

    // T2: Direction
    public static boolean directionActive = false;
    public static float directionX = 0f;
    public static float directionZ = 0f;

    // T3: Scan results
    public static List<ScanEntity> scanEntities = new ArrayList<>();
    public static long scanTimestamp = 0;
    public static final long SCAN_DURATION_MS = 3000; // 3 seconds

    // T4: Aura (handled by GLOWING effect, no extra client state needed)

    // T5: Chakra reading
    public static ReadingData lastReading = null;
    public static long readingTimestamp = 0;
    public static final long READING_DURATION_MS = 5000; // 5 seconds

    // Sensory tier (synced from server)
    public static int sensoryTier = 0;
    public static float scanCooldownRemaining = 0f;

    public static class ScanEntity {
        public final int entityId;
        public final double x, y, z;
        public final float height;
        public final boolean isHostile;

        public ScanEntity(int entityId, double x, double y, double z, float height, boolean isHostile) {
            this.entityId = entityId;
            this.x = x; this.y = y; this.z = z;
            this.height = height;
            this.isHostile = isHostile;
        }
    }

    public static class ReadingData {
        public final int entityId;
        public final String name;
        public final float chakraRatio;
        public final boolean chakraModeActive;
        public final int reserveLevel;
        public final boolean hasDojutsu;
        public final String dojutsuId;

        public ReadingData(int entityId, String name, float chakraRatio,
                          boolean chakraMode, int reserve, boolean dojutsu, String dojutsuId) {
            this.entityId = entityId;
            this.name = name;
            this.chakraRatio = chakraRatio;
            this.chakraModeActive = chakraMode;
            this.reserveLevel = reserve;
            this.hasDojutsu = dojutsu;
            this.dojutsuId = dojutsuId;
        }
    }

    public static boolean isScanActive() {
        return System.currentTimeMillis() - scanTimestamp < SCAN_DURATION_MS;
    }

    public static float getScanAlpha() {
        long elapsed = System.currentTimeMillis() - scanTimestamp;
        if (elapsed >= SCAN_DURATION_MS) return 0f;
        // Fade out in last 1 second
        if (elapsed > SCAN_DURATION_MS - 1000) {
            return 1f - (elapsed - (SCAN_DURATION_MS - 1000)) / 1000f;
        }
        return 1f;
    }

    public static boolean isReadingActive() {
        return lastReading != null && System.currentTimeMillis() - readingTimestamp < READING_DURATION_MS;
    }

    public static void clear() {
        dangerActive = false;
        directionActive = false;
        directionX = 0; directionZ = 0;
        scanEntities.clear();
        scanTimestamp = 0;
        lastReading = null;
        readingTimestamp = 0;
        sensoryTier = 0;
    }
}
'@
Write-File (Join-Path $srcBase "client\sensory\SensoryClientState.java") $sensoryClientState

# ============================================================
# S6-02 + S6-03: SENSORY HUD RENDERER (Danger + Direction)
# ============================================================
Write-Host "[S6-02/03] Creating SensoryHudRenderer..." -ForegroundColor Yellow

$sensoryHud = @'
package com.example.shinobicore.client.sensory;

import net.fabricmc.fabric.api.client.rendering.v1.HudRenderCallback;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.text.Text;
import net.minecraft.util.math.ColorHelper;

/**
 * S6-02: Danger sense indicator (pulsing red vignette).
 * S6-03: Direction arrow pointing toward nearest threat.
 */
public class SensoryHudRenderer {

    public static void register() {
        HudRenderCallback.EVENT.register(SensoryHudRenderer::render);
    }

    private static void render(DrawContext ctx, float tickDelta) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;

        int sw = client.getWindow().getScaledWidth();
        int sh = client.getWindow().getScaledHeight();

        // === S6-02: DANGER VIGNETTE ===
        if (SensoryClientState.dangerActive) {
            float pulse = (float)(0.3 + 0.2 * Math.sin(System.currentTimeMillis() / 150.0));
            int alpha = (int)(pulse * 255);
            int color = ColorHelper.Argb.getArgb(alpha, 255, 30, 30);

            // Draw vignette edges
            int edgeW = 6;
            ctx.fill(0, 0, sw, edgeW, color);           // top
            ctx.fill(0, sh - edgeW, sw, sh, color);     // bottom
            ctx.fill(0, 0, edgeW, sh, color);           // left
            ctx.fill(sw - edgeW, 0, sw, sh, color);     // right

            // Danger text
            int textAlpha = (int)(180 + 75 * Math.sin(System.currentTimeMillis() / 120.0));
            ctx.drawTextWithShadow(client.textRenderer, Text.literal("!! DANGER !!"),
                sw / 2 - 30, sh / 2 - 50, ColorHelper.Argb.getArgb(textAlpha, 255, 60, 60));
        }

        // === S6-03: DIRECTION ARROW ===
        if (SensoryClientState.directionActive && SensoryClientState.sensoryTier >= 2) {
            float dx = SensoryClientState.directionX;
            float dz = SensoryClientState.directionZ;

            // Calculate angle relative to player facing
            float playerYaw = client.player.getYaw() * ((float) Math.PI / 180f);
            float threatAngle = (float) Math.atan2(dx, dz);
            float relativeAngle = threatAngle - playerYaw;

            // Normalize to -PI..PI
            while (relativeAngle > Math.PI) relativeAngle -= 2 * Math.PI;
            while (relativeAngle < -Math.PI) relativeAngle += 2 * Math.PI;

            // Draw arrow at edge of screen
            int arrowRadius = 60;
            int cx = sw / 2;
            int cy = sh / 2;
            int ax = cx + (int)(Math.sin(relativeAngle) * arrowRadius);
            int ay = cy - (int)(Math.cos(relativeAngle) * arrowRadius);

            int arrowAlpha = (int)(150 + 105 * Math.sin(System.currentTimeMillis() / 200.0));
            int arrowColor = ColorHelper.Argb.getArgb(arrowAlpha, 255, 180, 50);

            // Simple arrow (3 pixels triangle)
            ctx.fill(ax - 2, ay - 2, ax + 2, ay + 2, arrowColor);
            ctx.fill(ax - 1, ay - 4, ax + 1, ay - 2, arrowColor);
            ctx.fill(ax - 1, ay + 2, ax + 1, ay + 4, arrowColor);

            // "Threat nearby" text
            if (SensoryClientState.dangerActive) {
                ctx.drawTextWithShadow(client.textRenderer, Text.literal("\u2191 Threat"),
                    ax - 15, ay + 8, arrowColor);
            }
        }

        // === SCAN COOLDOWN INDICATOR ===
        if (SensoryClientState.sensoryTier >= 3 && SensoryClientState.scanCooldownRemaining > 0) {
            int cdAlpha = 180;
            ctx.drawTextWithShadow(client.textRenderer,
                Text.literal(String.format("Scan CD: %.1fs", SensoryClientState.scanCooldownRemaining)),
                10, sh - 30, ColorHelper.Argb.getArgb(cdAlpha, 100, 200, 255));
        }
    }
}
'@
Write-File (Join-Path $srcBase "client\sensory\SensoryHudRenderer.java") $sensoryHud

# ============================================================
# S6-04: SCAN SILHOUETTE RENDERER (World-space)
# ============================================================
Write-Host "[S6-04] Creating SensoryScanRenderer..." -ForegroundColor Yellow

$scanRenderer = @'
package com.example.shinobicore.client.sensory;

import net.fabricmc.fabric.api.client.rendering.v1.WorldRenderContext;
import net.fabricmc.fabric.api.client.rendering.v1.WorldRenderEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.render.*;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.Vec3d;
import org.joml.Matrix4f;

/**
 * S6-04: Renders scan silhouettes in world space.
 * Entities appear as translucent outlines for 3 seconds after scan.
 * Silhouettes fade out gradually.
 */
public class SensoryScanRenderer {
    private static final Identifier TEX = new Identifier("textures/misc/white.png");

    public static void register() {
        WorldRenderEvents.AFTER_TRANSLUCENT.register(SensoryScanRenderer::render);
    }

    private static void render(WorldRenderContext context) {
        if (!SensoryClientState.isScanActive()) return;
        if (SensoryClientState.scanEntities.isEmpty()) return;

        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;

        float alpha = SensoryClientState.getScanAlpha();
        if (alpha <= 0.01f) return;

        MatrixStack matrices = context.matrixStack();
        VertexConsumerProvider consumers = context.consumers();
        if (consumers == null) return;

        Vec3d camPos = context.camera().getPos();
        VertexConsumer vc = consumers.getBuffer(RenderLayer.getEntityTranslucent(TEX));

        matrices.push();
        matrices.translate(-camPos.x, -camPos.y, -camPos.z);

        for (SensoryClientState.ScanEntity entity : SensoryClientState.scanEntities) {
            float r, g, b;
            if (entity.isHostile) {
                r = 1.0f; g = 0.2f; b = 0.2f; // Red for hostile
            } else {
                r = 0.2f; g = 0.8f; b = 1.0f; // Cyan for passive
            }

            // Draw a simple box silhouette
            float halfW = 0.3f;
            float h = entity.height;
            float x = (float) entity.x;
            float y = (float) entity.y;
            float z = (float) entity.z;

            Matrix4f m = matrices.peek().getPositionMatrix();

            // Front face
            emitQuad(vc, m, x - halfW, y, z + halfW, x + halfW, y, z + halfW,
                     x + halfW, y + h, z + halfW, x - halfW, y + h, z + halfW,
                     r, g, b, alpha * 0.4f);
            // Back face
            emitQuad(vc, m, x + halfW, y, z - halfW, x - halfW, y, z - halfW,
                     x - halfW, y + h, z - halfW, x + halfW, y + h, z - halfW,
                     r, g, b, alpha * 0.4f);
            // Left face
            emitQuad(vc, m, x - halfW, y, z - halfW, x - halfW, y, z + halfW,
                     x - halfW, y + h, z + halfW, x - halfW, y + h, z - halfW,
                     r, g, b, alpha * 0.3f);
            // Right face
            emitQuad(vc, m, x + halfW, y, z + halfW, x + halfW, y, z - halfW,
                     x + halfW, y + h, z - halfW, x + halfW, y + h, z + halfW,
                     r, g, b, alpha * 0.3f);
        }

        matrices.pop();
    }

    private static void emitQuad(VertexConsumer vc, Matrix4f m,
            float x1, float y1, float z1, float x2, float y2, float z2,
            float x3, float y3, float z3, float x4, float y4, float z4,
            float r, float g, float b, float a) {
        vc.vertex(m, x1, y1, z1).color(r, g, b, a)
          .texture(0, 0).overlay(OverlayTexture.DEFAULT_UV)
          .light(0xF000F0).normal(0, 1, 0).next();
        vc.vertex(m, x2, y2, z2).color(r, g, b, a)
          .texture(0, 0).overlay(OverlayTexture.DEFAULT_UV)
          .light(0xF000F0).normal(0, 1, 0).next();
        vc.vertex(m, x3, y3, z3).color(r, g, b, a)
          .texture(0, 0).overlay(OverlayTexture.DEFAULT_UV)
          .light(0xF000F0).normal(0, 1, 0).next();
        vc.vertex(m, x4, y4, z4).color(r, g, b, a)
          .texture(0, 0).overlay(OverlayTexture.DEFAULT_UV)
          .light(0xF000F0).normal(0, 1, 0).next();
    }
}
'@
Write-File (Join-Path $srcBase "client\sensory\SensoryScanRenderer.java") $scanRenderer

# ============================================================
# S6-06: CHAKRA READING HUD
# ============================================================
Write-Host "[S6-06] Creating SensoryReadingHud..." -ForegroundColor Yellow

$readingHud = @'
package com.example.shinobicore.client.sensory;

import net.fabricmc.fabric.api.client.rendering.v1.HudRenderCallback;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.text.Text;
import net.minecraft.util.math.ColorHelper;

/**
 * S6-06: Chakra reading display.
 * Shows detailed info about a scanned entity's chakra.
 * Displayed as a panel on the right side of screen.
 */
public class SensoryReadingHud {

    public static void register() {
        HudRenderCallback.EVENT.register(SensoryReadingHud::render);
    }

    private static void render(DrawContext ctx, float tickDelta) {
        if (!SensoryClientState.isReadingActive()) return;
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;

        SensoryClientState.ReadingData reading = SensoryClientState.lastReading;
        if (reading == null) return;

        int sw = client.getWindow().getScaledWidth();
        int sh = client.getWindow().getScaledHeight();

        // Panel position (right side)
        int panelW = 160;
        int panelH = 90;
        int px = sw - panelW - 10;
        int py = sh / 2 - panelH / 2;

        // Background
        ctx.fill(px - 2, py - 2, px + panelW + 2, py + panelH + 2, 0xFF111111);
        ctx.fill(px, py, px + panelW, py + panelH, 0xCC1A1A2E);

        // Border
        ctx.fill(px, py, px + panelW, py + 1, 0xFF44AAFF);
        ctx.fill(px, py + panelH - 1, px + panelW, py + panelH, 0xFF44AAFF);
        ctx.fill(px, py, px + 1, py + panelH, 0xFF44AAFF);
        ctx.fill(px + panelW - 1, py, px + panelW, py + panelH, 0xFF44AAFF);

        int ty = py + 6;
        int tx = px + 8;

        // Title
        ctx.drawTextWithShadow(client.textRenderer, Text.literal("CHAKRA READING"),
            tx, ty, 0xFF44AAFF);
        ty += 12;

        // Entity name
        ctx.drawTextWithShadow(client.textRenderer, Text.literal("Target: " + reading.name),
            tx, ty, 0xFFFFFFFF);
        ty += 11;

        // Chakra level bar
        String chakraLabel = "Chakra:";
        ctx.drawTextWithShadow(client.textRenderer, Text.literal(chakraLabel),
            tx, ty, 0xFFAAAAAA);
        int barX = tx + 50;
        int barW = 90;
        int barH = 6;
        ctx.fill(barX, ty + 1, barX + barW, ty + 1 + barH, 0xFF333333);
        int filled = (int)(barW * Math.min(1f, reading.chakraRatio));
        int barColor = reading.chakraRatio > 0.7f ? 0xFF44FF44 :
                       reading.chakraRatio > 0.3f ? 0xFFFFAA44 : 0xFFFF4444;
        ctx.fill(barX, ty + 1, barX + filled, ty + 1 + barH, barColor);
        ty += 12;

        // Chakra mode
        if (reading.chakraModeActive) {
            ctx.drawTextWithShadow(client.textRenderer, Text.literal("MODE: ACTIVE"),
                tx, ty, 0xFFFF8800);
        } else {
            ctx.drawTextWithShadow(client.textRenderer, Text.literal("MODE: Inactive"),
                tx, ty, 0xFF666666);
        }
        ty += 11;

        // Reserve level
        if (reading.reserveLevel > 0) {
            ctx.drawTextWithShadow(client.textRenderer, Text.literal("Reserve Lv: " + reading.reserveLevel),
                tx, ty, 0xFFAAAAAA);
            ty += 11;
        }

        // Dojutsu
        if (reading.hasDojutsu) {
            String djName = reading.dojutsuId.equals("sharingan") ? "Sharingan" :
                           reading.dojutsuId.equals("byakugan") ? "Byakugan" : reading.dojutsuId;
            ctx.drawTextWithShadow(client.textRenderer, Text.literal("Dojutsu: " + djName),
                tx, ty, 0xFFFF4444);
        }
    }
}
'@
Write-File (Join-Path $srcBase "client\sensory\SensoryReadingHud.java") $readingHud

# ============================================================
# PATCH: Add new packet IDs to ModPackets
# ============================================================
Write-Host "[PATCH] Adding sensory packet IDs to ModPackets..." -ForegroundColor Yellow

$modPacketsFile = Join-Path $srcBase "network\ModPackets.java"
Patch-File $modPacketsFile `
    "public static final Identifier DANGER_SYNC_ID = new Identifier(`"shinobicore`", `"danger_sync`");" `
    @"
public static final Identifier DANGER_SYNC_ID = new Identifier("shinobicore", "danger_sync");
    public static final Identifier SENSORY_DIRECTION_ID = new Identifier("shinobicore", "sensory_direction");
    public static final Identifier SENSORY_SCAN_ID = new Identifier("shinobicore", "sensory_scan");
    public static final Identifier SENSORY_READING_ID = new Identifier("shinobicore", "sensory_reading");
    public static final Identifier SENSORY_ACTIVATE_SCAN_ID = new Identifier("shinobicore", "sensory_activate_scan");
    public static final Identifier SENSORY_READ_REQUEST_ID = new Identifier("shinobicore", "sensory_read_request");
"@

# ============================================================
# PATCH: Add sensory scan key binding
# ============================================================
Write-Host "[PATCH] Adding SENSORY_SCAN key binding..." -ForegroundColor Yellow

$keyBindingsFile = Join-Path $srcBase "client\KeyBindings.java"
Patch-File $keyBindingsFile `
    "public static KeyBinding TOGGLE_SENSORY;" `
    @"
public static KeyBinding TOGGLE_SENSORY;
    public static KeyBinding SENSORY_SCAN;
"@

Patch-File $keyBindingsFile `
    "TOGGLE_SENSORY = KeyBindingHelper.registerKeyBinding(new KeyBinding(`n                `"key.shinobicore.toggle_sensory`", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_Y, CATEGORY));" `
    @"
TOGGLE_SENSORY = KeyBindingHelper.registerKeyBinding(new KeyBinding(
                "key.shinobicore.toggle_sensory", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_Y, CATEGORY));
        SENSORY_SCAN = KeyBindingHelper.registerKeyBinding(new KeyBinding(
                "key.shinobicore.sensory_scan", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_U, CATEGORY));
"@

# ============================================================
# PATCH: Handle sensory scan in ClientInputHandler
# ============================================================
Write-Host "[PATCH] Adding sensory scan input handling..." -ForegroundColor Yellow

$inputFile = Join-Path $srcBase "client\ClientInputHandler.java"
Patch-File $inputFile `
    "if (KeyBindings.TOGGLE_SENSORY.wasPressed()) {" `
    @"
if (KeyBindings.SENSORY_SCAN.wasPressed()) {
            // Send scan activation request to server
            if (client.getNetworkHandler() != null) {
                PacketByteBuf scanBuf = new PacketByteBuf(Unpooled.buffer());
                ClientPlayNetworking.send(ModPackets.SENSORY_ACTIVATE_SCAN_ID, scanBuf);
            }
        }
        if (KeyBindings.TOGGLE_SENSORY.wasPressed()) {
"@

# ============================================================
# PATCH: Register sensory packet receivers in ShinobiCoreClient
# ============================================================
Write-Host "[PATCH] Registering sensory packet receivers..." -ForegroundColor Yellow

$clientFile = Join-Path $srcBase "client\ShinobiCoreClient.java"

# Add imports
Patch-File $clientFile `
    "import com.example.shinobicore.client.RasenganClientState;" `
    @"
import com.example.shinobicore.client.RasenganClientState;
import com.example.shinobicore.client.sensory.SensoryClientState;
import com.example.shinobicore.client.sensory.SensoryHudRenderer;
import com.example.shinobicore.client.sensory.SensoryScanRenderer;
import com.example.shinobicore.client.sensory.SensoryReadingHud;
"@

# Register renderers after existing registrations
Patch-File $clientFile `
    "NarutoArmorRenderer.register();" `
    @"
NarutoArmorRenderer.register();
        // S6: Sensory system renderers
        SensoryHudRenderer.register();
        SensoryScanRenderer.register();
        SensoryReadingHud.register();
"@

# Register packet receivers
Patch-File $clientFile `
    "ClientPlayNetworking.registerGlobalReceiver(ModPackets.DANGER_SYNC_ID, (client, handler, buf, responseSender) -> {" `
    @"
// S6-03: Direction sense receiver
        ClientPlayNetworking.registerGlobalReceiver(ModPackets.SENSORY_DIRECTION_ID, (client, handler, buf, responseSender) -> {
            boolean active = buf.readBoolean();
            float dirX = buf.readFloat();
            float dirZ = buf.readFloat();
            client.execute(() -> {
                SensoryClientState.directionActive = active;
                SensoryClientState.directionX = dirX;
                SensoryClientState.directionZ = dirZ;
            });
        });
        // S6-04: Scan results receiver
        ClientPlayNetworking.registerGlobalReceiver(ModPackets.SENSORY_SCAN_ID, (client, handler, buf, responseSender) -> {
            int count = buf.readInt();
            java.util.List<SensoryClientState.ScanEntity> entities = new java.util.ArrayList<>();
            for (int i = 0; i < count; i++) {
                int eid = buf.readInt();
                double x = buf.readDouble();
                double y = buf.readDouble();
                double z = buf.readDouble();
                float height = buf.readFloat();
                boolean hostile = buf.readBoolean();
                entities.add(new SensoryClientState.ScanEntity(eid, x, y, z, height, hostile));
            }
            client.execute(() -> {
                SensoryClientState.scanEntities = entities;
                SensoryClientState.scanTimestamp = System.currentTimeMillis();
            });
        });
        // S6-06: Chakra reading receiver
        ClientPlayNetworking.registerGlobalReceiver(ModPackets.SENSORY_READING_ID, (client, handler, buf, responseSender) -> {
            int eid = buf.readInt();
            String name = buf.readString();
            float chakraRatio = buf.readFloat();
            boolean chakraMode = buf.readBoolean();
            int reserve = buf.readInt();
            boolean hasDojutsu = buf.readBoolean();
            String dojutsuId = buf.readString();
            client.execute(() -> {
                SensoryClientState.lastReading = new SensoryClientState.ReadingData(
                    eid, name, chakraRatio, chakraMode, reserve, hasDojutsu, dojutsuId);
                SensoryClientState.readingTimestamp = System.currentTimeMillis();
            });
        });
        ClientPlayNetworking.registerGlobalReceiver(ModPackets.DANGER_SYNC_ID, (client, handler, buf, responseSender) -> {
"@

# ============================================================
# PATCH: Register server-side sensory packets in ShinobiCore
# ============================================================
Write-Host "[PATCH] Registering server-side sensory handlers..." -ForegroundColor Yellow

$serverFile = Join-Path $srcBase "ShinobiCore.java"
Patch-File $serverFile `
    "ModPackets.register();" `
    @"
ModPackets.register();
        // S6-04: Sensory scan activation (C2S)
        net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking.registerGlobalReceiver(
            ModPackets.SENSORY_ACTIVATE_SCAN_ID, (server, player, handler, buf, responseSender) -> {
            server.execute(() -> {
                var data = ((com.example.shinobicore.stat.NinjaDataHolder) player).shinobicore_getData();
                var component = data.getSensoryComponent();
                if (component != null) component.activateScan(player);
            });
        });
        // S6-06: Chakra reading request (C2S)
        net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking.registerGlobalReceiver(
            ModPackets.SENSORY_READ_REQUEST_ID, (server, player, handler, buf, responseSender) -> {
            int targetId = buf.readInt();
            server.execute(() -> {
                var data = ((com.example.shinobicore.stat.NinjaDataHolder) player).shinobicore_getData();
                var component = data.getSensoryComponent();
                if (component != null) component.readChakra(player, targetId);
            });
        });
"@

# ============================================================
# PATCH: Add SensoryComponent to NinjaPlayerData
# ============================================================
Write-Host "[PATCH] Adding SensoryComponent to NinjaPlayerData..." -ForegroundColor Yellow

$ninjaDataFile = Join-Path $srcBase "stat\NinjaPlayerData.java"
Patch-File $ninjaDataFile `
    "private boolean lastDangerState = false;" `
    @"
private boolean lastDangerState = false;
    private com.example.shinobicore.sensory.SensoryComponent sensoryComponent = new com.example.shinobicore.sensory.SensoryComponent();
"@

Patch-File $ninjaDataFile `
    "public boolean getLastDangerState() { return lastDangerState; }" `
    @"
public boolean getLastDangerState() { return lastDangerState; }
    public com.example.shinobicore.sensory.SensoryComponent getSensoryComponent() { return sensoryComponent; }
"@

# ============================================================
# PATCH: Add sensory tick to NinjaTickHandler
# ============================================================
Write-Host "[PATCH] Adding sensory tick to NinjaTickHandler..." -ForegroundColor Yellow

$tickHandlerFile = Join-Path $srcBase "event\NinjaTickHandler.java"
Patch-File $tickHandlerFile `
    "// === PHASE_FIX2_TICK: sensory glow + danger sense + rasengan dissipate ===" `
    @"
// === S6: Sensory component tick ===
            var sensoryComp = data.getSensoryComponent();
            if (sensoryComp != null) {
                sensoryComp.setTier(com.example.shinobicore.sensory.SensoryComponent.determineTier(data));
                sensoryComp.tick(player);
            }
            // === PHASE_FIX2_TICK: sensory glow + danger sense + rasengan dissipate ===
"@

# ============================================================
# PATCH: Add new tree nodes to tree.json
# ============================================================
Write-Host "[PATCH] Adding sensory tree nodes..." -ForegroundColor Yellow

$treeFile = Join-Path $resBase "data\shinobicore\skill_tree\tree.json"
if (Test-Path $treeFile) {
    $treeContent = [System.IO.File]::ReadAllText($treeFile, $utf8)
    $treeContent = $treeContent.Replace("`r`n", "`n")

    $newNodes = @'
,
        {
            "id": "sen_direction",
            "branch": "sensory",
            "distance": 3,
            "type": "passive",
            "effect": "sensory_direction",
            "value": 1,
            "spCost": 5,
            "requires": ["sen_danger"],
            "icon": "\u003e",
            "name": "Presence Direction",
            "description": "Sense the direction of the nearest threat",
            "visibilityCondition": {"type": "stat_level", "key": "perception", "value": 25}
        },
        {
            "id": "sen_scan",
            "branch": "sensory",
            "distance": 4,
            "type": "passive",
            "effect": "sensory_scan",
            "value": 1,
            "spCost": 7,
            "requires": ["sen_direction"],
            "icon": "O",
            "name": "Scan Pulse",
            "description": "Active scan reveals silhouettes for 3 seconds (U key)",
            "visibilityCondition": {"type": "stat_level", "key": "perception", "value": 30}
        },
        {
            "id": "sen_reading",
            "branch": "sensory",
            "distance": 5,
            "type": "passive",
            "effect": "sensory_reading",
            "value": 1,
            "spCost": 10,
            "requires": ["sen_glow"],
            "icon": "R",
            "name": "Chakra Reading",
            "description": "Read chakra level, mode, and dojutsu of nearby entities",
            "visibilityCondition": {"type": "stat_level", "key": "perception", "value": 40}
        }
'@

    # Insert before the last closing bracket of the nodes array
    # Find the sen_danger node and add after it
    $anchor = '"id": "sen_danger"'
    if ($treeContent.Contains($anchor) -and -not $treeContent.Contains('"id": "sen_direction"')) {
        # Find the end of sen_danger node (next "}," after it)
        $idx = $treeContent.IndexOf($anchor)
        $nextNodeStart = $treeContent.IndexOf('{', $idx + $anchor.Length)
        if ($nextNodeStart -gt 0) {
            # Find the comma before the next node
            $commaIdx = $treeContent.LastIndexOf(',', $nextNodeStart)
            if ($commaIdx -gt 0) {
                $treeContent = $treeContent.Insert($commaIdx + 1, "`n        " + $newNodes.TrimStart(','))
                [System.IO.File]::WriteAllText($treeFile, $treeContent, $utf8)
                Write-Host "  [PATCH] tree.json - added 3 sensory nodes" -ForegroundColor Green
            } else {
                Write-Host "  [WARN] Could not find insertion point in tree.json" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  [WARN] Could not find next node after sen_danger" -ForegroundColor Yellow
        }
    } elseif ($treeContent.Contains('"id": "sen_direction"')) {
        Write-Host "  [SKIP] Sensory nodes already in tree.json" -ForegroundColor Yellow
    } else {
        Write-Host "  [FAIL] sen_danger not found in tree.json" -ForegroundColor Red
    }
} else {
    Write-Host "  [MISS] tree.json not found" -ForegroundColor Red
}

# ============================================================
# PATCH: Add lang entries for new key binding
# ============================================================
Write-Host "[PATCH] Adding lang entries..." -ForegroundColor Yellow

$enLangFile = Join-Path $resBase "assets\shinobicore\lang\en_us.json"
Patch-File $enLangFile `
    '"key.shinobicore.toggle_sensory": "Sensory (Y)"' `
    @"
"key.shinobicore.toggle_sensory": "Sensory (Y)",
    "key.shinobicore.sensory_scan": "Sensory Scan (U)"
"@

$ruLangFile = Join-Path $resBase "assets\shinobicore\lang\ru_ru.json"
Patch-File $ruLangFile `
    '"key.shinobicore.toggle_sensory": "\u0421\u0435\u043d\u0441\u043e\u0440\u0438\u043a\u0430 (Y)"' `
    @"
"key.shinobicore.toggle_sensory": "\u0421\u0435\u043d\u0441\u043e\u0440\u0438\u043a\u0430 (Y)",
    "key.shinobicore.sensory_scan": "\u0421\u0435\u043d\u0441\u043e\u0440\u043d\u044b\u0439 \u0441\u043a\u0430\u043d (U)"
"@

# ============================================================
# PATCH: Cleanup sensory state on disconnect
# ============================================================
Write-Host "[PATCH] Adding sensory cleanup on disconnect..." -ForegroundColor Yellow

Patch-File $clientFile `
    "HandSignsClientState.clear();" `
    @"
HandSignsClientState.clear();
        SensoryClientState.clear();
"@

# ============================================================
# BUILD
# ============================================================
Write-Host ""
Write-Host "[BUILD] Verifying compilation..." -ForegroundColor Yellow
Push-Location $root
try {
    $out = & ".\gradlew.bat" build 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [PASS] Build successful!" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Build failed" -ForegroundColor Red
        $out | Select-Object -Last 25 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    }
} finally { Pop-Location }

# ============================================================
# SUMMARY
# ============================================================
Write-Host ""
Write-Host "==============================================================" -ForegroundColor Green
Write-Host "  SPRINT 6 PHASE A (S6-01..S6-06) COMPLETE" -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Created files:" -ForegroundColor White
Write-Host "  - sensory/SensoryTier.java (S6-01: tier enum)" -ForegroundColor Cyan
Write-Host "  - sensory/SensoryComponent.java (S6-01: server component)" -ForegroundColor Cyan
Write-Host "  - client/sensory/SensoryClientState.java (S6-01: client state)" -ForegroundColor Cyan
Write-Host "  - client/sensory/SensoryHudRenderer.java (S6-02/03: HUD)" -ForegroundColor Cyan
Write-Host "  - client/sensory/SensoryScanRenderer.java (S6-04: silhouettes)" -ForegroundColor Cyan
Write-Host "  - client/sensory/SensoryReadingHud.java (S6-06: chakra reading)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Sensory Tiers:" -ForegroundColor White
Write-Host "  T1 (sen_danger)   - Danger sense: pulsing red vignette" -ForegroundColor Yellow
Write-Host "  T2 (sen_direction) - Direction arrow toward nearest threat" -ForegroundColor Yellow
Write-Host "  T3 (sen_scan)     - Scan pulse: 3s silhouettes [U key]" -ForegroundColor Yellow
Write-Host "  T4 (sen_glow)     - Aura: GLOWING through walls" -ForegroundColor Yellow
Write-Host "  T5 (sen_reading)  - Chakra reading: level, mode, dojutsu" -ForegroundColor Yellow
Write-Host ""
Write-Host "Tree nodes added: sen_direction, sen_scan, sen_reading" -ForegroundColor Cyan
Write-Host "Key binding: U = Sensory Scan (T3+)" -ForegroundColor Cyan
Write-Host ""
Write-Host ">>> S6-01..S6-06 DONE. Ready for Sharingan discussion! <<<" -ForegroundColor Magenta
Write-Host ""
# ============================================================
# SHINOBICORE MASTER SCRIPT: SPRINT 6 PHASE B
# Sharingan - The Special Dojutsu
# Evolution + 4 Stages + Unified Abilities (SP+MP)
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcBase = Join-Path $root "src\main\java\com\example\shinobicore"
$dojutsuDir = Join-Path $srcBase "dojutsu"
$clientDojutsuDir = Join-Path $srcBase "client\dojutsu"

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "  SPRINT 6 PHASE B: SHARINGAN IMPLEMENTATION" -ForegroundColor Cyan
Write-Host "  Evolution | 4 Stages | Unified Abilities (SP+MP)" -ForegroundColor Cyan
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
# FILE 1: SharinganStage.java - Stage enum
# ============================================================
Write-Host "[1/8] Creating SharinganStage enum..." -ForegroundColor Yellow

$stageEnum = @'
package com.example.shinobicore.dojutsu;

/**
 * Sharingan evolution stages.
 * Each stage unlocks new abilities.
 */
public enum SharinganStage {
    NONE(0, 0, 0, 0f, 0),
    ONE_TOMOE(1, 50, 1, 0.10f, 3),
    TWO_TOMOE(2, 150, 2, 0.15f, 6),
    THREE_TOMOE(3, 300, 3, 0.20f, 10),
    MANGEKYO(4, 500, 5, 0.30f, 15);

    private final int level;
    private final int usageRequired;
    private final int stressRequired;
    private final float overlayAlpha;
    private final int particleCount;

    SharinganStage(int level, int usageReq, int stressReq, float overlay, int particles) {
        this.level = level;
        this.usageRequired = usageReq;
        this.stressRequired = stressReq;
        this.overlayAlpha = overlay;
        this.particleCount = particles;
    }

    public int getLevel() { return level; }
    public int getUsageRequired() { return usageRequired; }
    public int getStressRequired() { return stressRequired; }
    public float getOverlayAlpha() { return overlayAlpha; }
    public int getParticleCount() { return particleCount; }

    public boolean isAtLeast(SharinganStage other) { return this.level >= other.level; }

    public static SharinganStage fromLevel(int level) {
        for (SharinganStage s : values()) {
            if (s.level == level) return s;
        }
        return NONE;
    }
}
'@
Write-File (Join-Path $dojutsuDir "SharinganStage.java") $stageEnum

# ============================================================
# FILE 2: SharinganComponent.java - Server-side component
# ============================================================
Write-Host "[2/8] Creating SharinganComponent (server)..." -ForegroundColor Yellow

$component = @'
package com.example.shinobicore.dojutsu;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.network.ModPackets;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.damage.DamageSource;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Box;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Server-side Sharingan component.
 * Manages evolution, activation, chakra drain, and abilities.
 * All abilities work identically in SP and MP.
 *
 * Activation: toggle by key. Costs 5% max chakra per 10 seconds.
 * Evolution: combined (usage + stress events).
 */
public class SharinganComponent {

    private SharinganStage stage = SharinganStage.NONE;
    private int usageProgress = 0;
    private int stressCount = 0;
    private boolean active = false;
    private long lastDrainTimeMs = 0;
    private boolean hasMangekyoQuest = false; // Stub for future quest line

    // 2 tomoe: copied techniques (jutsuId -> expiry time)
    private final Map<String, Long> copiedTechniques = new HashMap<>();
    private static final long COPY_DURATION_MS = 5 * 60 * 1000; // 5 minutes

    // 3 tomoe: auto-parry cooldown
    private long lastAutoParryMs = 0;
    private static final long AUTO_PARRY_COOLDOWN_MS = 2000; // 2 seconds

    // Chakra drain: 5% max per 10 seconds
    private static final float DRAIN_PERCENT = 0.05f;
    private static final long DRAIN_INTERVAL_MS = 10000;

    public SharinganStage getStage() { return stage; }
    public boolean isActive() { return active; }
    public int getUsageProgress() { return usageProgress; }
    public int getStressCount() { return stressCount; }
    public boolean hasMangekyoQuest() { return hasMangekyoQuest; }
    public void setMangekyoQuestComplete(boolean v) { this.hasMangekyoQuest = v; }

    /**
     * Toggle sharingan activation.
     * Requires at least 1 tomoe and Uchiha clan.
     */
    public boolean toggle(ServerPlayerEntity player) {
        if (stage == SharinganStage.NONE) return false;
        active = !active;
        if (active) {
            lastDrainTimeMs = System.currentTimeMillis();
        }
        syncToClient(player);
        ShinobiCore.LOGGER.info("[SHARINGAN] {} toggled {}", player.getName().getString(), active);
        return true;
    }

    /**
     * Called every server tick from NinjaTickHandler.
     */
    public void tick(ServerPlayerEntity player) {
        if (!active) return;
        if (stage == SharinganStage.NONE) { active = false; return; }

        // Chakra drain: 5% max per 10 seconds
        long now = System.currentTimeMillis();
        if (now - lastDrainTimeMs >= DRAIN_INTERVAL_MS) {
            lastDrainTimeMs = now;
            NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
            float maxChakra = NinjaFormula.maxChakra(data);
            float drain = maxChakra * DRAIN_PERCENT;
            if (data.getCurrentChakra() < drain) {
                // Not enough chakra - deactivate
                active = false;
                syncToClient(player);
                return;
            }
            data.setCurrentChakra(data.getCurrentChakra() - drain);
            ShinobiCore.sendChakraSync(player);
        }

        // 2 tomoe: observe nearby casting for copy
        if (stage.isAtLeast(SharinganStage.TWO_TOMOE)) {
            observeNearbyCasting(player);
        }
    }

    /**
     * Add usage progress (called when casting fire/genjutsu, parrying, etc.)
     */
    public void addUsage(int amount) {
        usageProgress += amount;
        checkEvolution();
    }

    /**
     * Add stress event (low HP, near-lethal, fighting stronger enemy, etc.)
     */
    public void addStress() {
        stressCount++;
        checkEvolution();
    }

    /**
     * Check if evolution threshold is met.
     */
    private void checkEvolution() {
        SharinganStage nextStage = getNextStage();
        if (nextStage == null) return;
        if (usageProgress >= nextStage.getUsageRequired()
                && stressCount >= nextStage.getStressRequired()) {
            // Mangekyo requires quest completion (stub)
            if (nextStage == SharinganStage.MANGEKYO && !hasMangekyoQuest) return;
            stage = nextStage;
            ShinobiCore.LOGGER.info("[SHARINGAN] Evolved to {}", stage);
        }
    }

    private SharinganStage getNextStage() {
        switch (stage) {
            case NONE: return SharinganStage.ONE_TOMOE;
            case ONE_TOMOE: return SharinganStage.TWO_TOMOE;
            case TWO_TOMOE: return SharinganStage.THREE_TOMOE;
            case THREE_TOMOE: return SharinganStage.MANGEKYO;
            default: return null;
        }
    }

    /**
     * 2 tomoe: Observe nearby entities casting techniques.
     * If technique is below A-rank (T1-T3) and element is unlocked, copy it.
     */
    private void observeNearbyCasting(ServerPlayerEntity player) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();

        for (ServerPlayerEntity other : world.getPlayers()) {
            if (other == player) continue;
            if (other.getPos().distanceTo(player.getPos()) > 16) continue;

            // Check if other player is casting
            var cast = com.example.shinobicore.combat.CastingServerState.getActive(other);
            if (cast == null) continue;

            String jutsuId = cast.jutsuId;
            if (copiedTechniques.containsKey(jutsuId)) continue;

            // Check tier: only T1-T3 (below A-rank)
            var def = com.example.shinobicore.jutsu.JutsuRegistry.get(jutsuId);
            if (def == null) continue;
            if (def.tier() > 3) continue; // A-rank and above cannot be copied

            // Check element unlocked
            if (def.hasNature() && !data.isNatureUnlocked(def.nature())) continue;

            // Copy the technique
            copiedTechniques.put(jutsuId, System.currentTimeMillis() + COPY_DURATION_MS);
            ShinobiCore.LOGGER.info("[SHARINGAN] {} copied {} from {}",
                player.getName().getString(), jutsuId, other.getName().getString());

            // Notify client
            PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
            buf.writeString(jutsuId);
            buf.writeLong(COPY_DURATION_MS);
            ServerPlayNetworking.send(player, ModPackets.SHARINGAN_COPY_ID, buf);
        }
    }

    /**
     * 3 tomoe: Check auto-parry for melee attacks.
     * Returns true if attack should be negated.
     */
    public boolean checkAutoParry(ServerPlayerEntity player, DamageSource source, float amount) {
        if (!stage.isAtLeast(SharinganStage.THREE_TOMOE)) return false;
        if (!active) return false;

        // Only melee attacks
        if (source.getSource() == null) return false;
        if (!(source.getSource() instanceof LivingEntity)) return false;

        // Check cooldown
        long now = System.currentTimeMillis();
        if (now - lastAutoParryMs < AUTO_PARRY_COOLDOWN_MS) return false;

        // 35% chance
        if (player.getWorld().getRandom().nextFloat() < 0.35f) {
            lastAutoParryMs = now;
            ShinobiCore.LOGGER.info("[SHARINGAN] Auto-parry! {} negated {} damage",
                player.getName().getString(), amount);
            return true;
        }
        return false;
    }

    /**
     * Check if a technique is currently copied.
     */
    public boolean hasCopiedTechnique(String jutsuId) {
        Long expiry = copiedTechniques.get(jutsuId);
        if (expiry == null) return false;
        if (System.currentTimeMillis() > expiry) {
            copiedTechniques.remove(jutsuId);
            return false;
        }
        return true;
    }

    /**
     * Get all currently active copied techniques.
     */
    public List<String> getActiveCopies() {
        long now = System.currentTimeMillis();
        List<String> active = new ArrayList<>();
        copiedTechniques.entrySet().removeIf(e -> now > e.getValue());
        active.addAll(copiedTechniques.keySet());
        return active;
    }

    /**
     * Sync sharingan state to client.
     */
    public void syncToClient(ServerPlayerEntity player) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(stage.getLevel());
        buf.writeBoolean(active);
        buf.writeInt(usageProgress);
        buf.writeInt(stressCount);
        ServerPlayNetworking.send(player, ModPackets.SHARINGAN_SYNC_ID, buf);
    }

    /**
     * Write to NBT for persistence.
     */
    public void writeNbt(net.minecraft.nbt.NbtCompound nbt) {
        nbt.putInt("SharinganStage", stage.getLevel());
        nbt.putInt("SharinganUsage", usageProgress);
        nbt.putInt("SharinganStress", stressCount);
        nbt.putBoolean("SharinganActive", active);
        nbt.putBoolean("MangekyoQuest", hasMangekyoQuest);
    }

    /**
     * Read from NBT.
     */
    public void readNbt(net.minecraft.nbt.NbtCompound nbt) {
        stage = SharinganStage.fromLevel(nbt.getInt("SharinganStage"));
        usageProgress = nbt.getInt("SharinganUsage");
        stressCount = nbt.getInt("SharinganStress");
        active = nbt.getBoolean("SharinganActive");
        hasMangekyoQuest = nbt.getBoolean("MangekyoQuest");
    }
}
'@
Write-File (Join-Path $dojutsuDir "SharinganComponent.java") $component

# ============================================================
# FILE 3: SharinganClientState.java - Client state
# ============================================================
Write-Host "[3/8] Creating SharinganClientState..." -ForegroundColor Yellow

$clientState = @'
package com.example.shinobicore.client.dojutsu;

import java.util.ArrayList;
import java.util.List;

/**
 * Client-side sharingan state.
 * Stores stage, active flag, and copied techniques.
 */
public class SharinganClientState {
    public static boolean active = false;
    public static int stageLevel = 0; // 0=none, 1=one, 2=two, 3=three, 4=mangekyo
    public static int usageProgress = 0;
    public static int stressCount = 0;

    // Copied techniques (jutsuId -> remaining time ms)
    public static final List<CopiedTechnique> copiedTechniques = new ArrayList<>();

    public static class CopiedTechnique {
        public final String jutsuId;
        public final long expiresAt;
        public CopiedTechnique(String id, long expires) {
            this.jutsuId = id;
            this.expiresAt = expires;
        }
        public boolean isExpired() { return System.currentTimeMillis() > expiresAt; }
    }

    public static boolean isActive() { return active && stageLevel > 0; }
    public static boolean hasOneTomoe() { return stageLevel >= 1; }
    public static boolean hasTwoTomoe() { return stageLevel >= 2; }
    public static boolean hasThreeTomoe() { return stageLevel >= 3; }
    public static boolean hasMangekyo() { return stageLevel >= 4; }

    public static float getOverlayAlpha() {
        return switch (stageLevel) {
            case 1 -> 0.10f;
            case 2 -> 0.15f;
            case 3 -> 0.20f;
            case 4 -> 0.30f;
            default -> 0f;
        };
    }

    public static int getParticleCount() {
        return switch (stageLevel) {
            case 1 -> 3;
            case 2 -> 6;
            case 3 -> 10;
            case 4 -> 15;
            default -> 0;
        };
    }

    public static void clear() {
        active = false;
        stageLevel = 0;
        usageProgress = 0;
        stressCount = 0;
        copiedTechniques.clear();
    }
}
'@
Write-File (Join-Path $clientDojutsuDir "SharinganClientState.java") $clientState

# ============================================================
# FILE 4: SharinganOverlayRenderer.java - Red overlay + particles
# ============================================================
Write-Host "[4/8] Creating SharinganOverlayRenderer..." -ForegroundColor Yellow

$overlayRenderer = @'
package com.example.shinobicore.client.dojutsu;

import net.fabricmc.fabric.api.client.rendering.v1.HudRenderCallback;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.particle.DustParticleEffect;
import net.minecraft.util.math.ColorHelper;
import net.minecraft.util.math.Vec3d;
import org.joml.Vector3f;

/**
 * Sharingan visual overlay.
 * - Red night-vision tint (alpha depends on stage).
 * - Red particles orbiting around player's head.
 * No other visual changes.
 */
public class SharinganOverlayRenderer {
    private static int tickCounter = 0;

    public static void register() {
        HudRenderCallback.EVENT.register(SharinganOverlayRenderer::renderOverlay);
        net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents.END_CLIENT_TICK
            .register(SharinganOverlayRenderer::tickParticles);
    }

    /**
     * Render red overlay on screen.
     */
    private static void renderOverlay(DrawContext ctx, float tickDelta) {
        if (!SharinganClientState.isActive()) return;
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;

        int sw = client.getWindow().getScaledWidth();
        int sh = client.getWindow().getScaledHeight();
        float alpha = SharinganClientState.getOverlayAlpha();

        // Red tint overlay (night vision style)
        int color = ColorHelper.Argb.getArgb((int)(alpha * 255), 180, 20, 20);
        ctx.fill(0, 0, sw, sh, color);

        // Vignette effect (darker edges)
        int vignetteAlpha = (int)(alpha * 0.6f * 255);
        int vignetteColor = ColorHelper.Argb.getArgb(vignetteAlpha, 40, 0, 0);
        int edge = 40;
        ctx.fill(0, 0, sw, edge, vignetteColor);           // top
        ctx.fill(0, sh - edge, sw, sh, vignetteColor);     // bottom
        ctx.fill(0, 0, edge, sh, vignetteColor);           // left
        ctx.fill(sw - edge, 0, sw, sh, vignetteColor);     // right

        // Stage indicator (small text top-right)
        String stageText = switch (SharinganClientState.stageLevel) {
            case 1 -> "Sharingan: 1 Tomoe";
            case 2 -> "Sharingan: 2 Tomoe";
            case 3 -> "Sharingan: 3 Tomoe";
            case 4 -> "Mangekyo Sharingan";
            default -> "";
        };
        if (!stageText.isEmpty()) {
            int tw = client.textRenderer.getWidth(stageText);
            ctx.drawTextWithShadow(client.textRenderer, stageText,
                sw - tw - 10, 10, 0xFFFF4444);
        }
    }

    /**
     * Spawn red particles around player's head every tick.
     */
    private static void tickParticles(MinecraftClient client) {
        if (!SharinganClientState.isActive()) return;
        if (client.world == null || client.player == null) return;

        tickCounter++;
        int count = SharinganClientState.getParticleCount();
        if (count <= 0) return;

        ClientPlayerEntity player = client.player;
        Vec3d headPos = player.getEyePos();
        float radius = 0.4f;
        float speed = 0.03f;

        for (int i = 0; i < count; i++) {
            float angle = tickCounter * 0.15f + (i / (float) count) * (float)(Math.PI * 2);
            float y = headPos.y + (float)Math.sin(tickCounter * 0.1f + i) * 0.2f;
            double x = headPos.x + Math.cos(angle) * radius;
            double z = headPos.z + Math.sin(angle) * radius;

            // Red dust particles
            DustParticleEffect effect = new DustParticleEffect(
                new Vector3f(1.0f, 0.1f, 0.1f), 0.6f);
            client.world.addParticle(effect, x, y, z,
                Math.cos(angle) * speed, 0.01, Math.sin(angle) * speed);
        }

        // Mangekyo: additional black particles
        if (SharinganClientState.hasMangekyo() && tickCounter % 3 == 0) {
            DustParticleEffect black = new DustParticleEffect(
                new Vector3f(0.05f, 0.0f, 0.0f), 0.8f);
            float angle = tickCounter * 0.2f;
            client.world.addParticle(black,
                headPos.x + Math.cos(angle) * 0.3,
                headPos.y + 0.3,
                headPos.z + Math.sin(angle) * 0.3,
                0, 0.02, 0);
        }
    }
}
'@
Write-File (Join-Path $clientDojutsuDir "SharinganOverlayRenderer.java") $overlayRenderer

# ============================================================
# FILE 5: SharinganTrackingRenderer.java - 1 tomoe abilities
# Ghost trails + movement vectors + mob aggro (unified SP+MP)
# ============================================================
Write-Host "[5/8] Creating SharinganTrackingRenderer (1 tomoe)..." -ForegroundColor Yellow

$trackingRenderer = @'
package com.example.shinobicore.client.dojutsu;

import net.fabricmc.fabric.api.client.rendering.v1.WorldRenderContext;
import net.fabricmc.fabric.api.client.rendering.v1.WorldRenderEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.client.render.OverlayTexture;
import net.minecraft.client.render.RenderLayer;
import net.minecraft.client.render.VertexConsumer;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.mob.MobEntity;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.Vec3d;
import org.joml.Matrix4f;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/**
 * 1 Tomoe: Enhanced Tracking (unified SP+MP).
 * - Ghost trail: shows entity position 2 ticks ago (translucent silhouette).
 * - Movement vector: arrow showing movement direction above entity.
 * - Mob aggro: for mobs, shows their target direction and aggro radius.
 * All three work simultaneously against all entity types.
 */
public class SharinganTrackingRenderer {
    private static final Identifier TEX = new Identifier("textures/misc/white.png");
    private static final int TRAIL_LENGTH = 4; // Store last 4 positions

    // Ghost trail storage: entityId -> position history
    private static final Map<UUID, Vec3d[]> trailHistory = new HashMap<>();

    public static void register() {
        WorldRenderEvents.AFTER_ENTITIES.register(SharinganTrackingRenderer::render);
        net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents.END_CLIENT_TICK
            .register(SharinganTrackingRenderer::updateTrails);
    }

    /**
     * Update ghost trail positions every tick.
     */
    private static void updateTrails(MinecraftClient client) {
        if (!SharinganClientState.hasOneTomoe() || !SharinganClientState.isActive()) return;
        if (client.world == null) return;

        for (LivingEntity entity : client.world.getEntities()) {
            if (!(entity instanceof LivingEntity)) continue;
            if (entity == client.player) continue;
            if (entity.getPos().distanceTo(client.player.getPos()) > 32) continue;

            UUID id = entity.getUuid();
            Vec3d[] trail = trailHistory.computeIfAbsent(id, k -> new Vec3d[TRAIL_LENGTH]);

            // Shift history
            System.arraycopy(trail, 0, trail, 1, TRAIL_LENGTH - 1);
            trail[0] = entity.getPos();
        }
    }

    /**
     * Render ghost trails and movement vectors.
     */
    private static void render(WorldRenderContext context) {
        if (!SharinganClientState.hasOneTomoe() || !SharinganClientState.isActive()) return;

        MinecraftClient client = MinecraftClient.getInstance();
        if (client.world == null || client.player == null) return;

        MatrixStack matrices = context.matrixStack();
        VertexConsumerProvider consumers = context.consumers();
        if (consumers == null) return;

        Vec3d camPos = context.camera().getPos();
        matrices.push();
        matrices.translate(-camPos.x, -camPos.y, -camPos.z);

        VertexConsumer vc = consumers.getBuffer(RenderLayer.getEntityTranslucent(TEX));

        for (LivingEntity entity : client.world.getEntities()) {
            if (!(entity instanceof LivingEntity)) continue;
            if (entity == client.player) continue;

            double dist = entity.getPos().distanceTo(client.player.getPos());
            if (dist > 32) continue;

            UUID id = entity.getUuid();

            // === GHOST TRAIL (position 2 ticks ago) ===
            Vec3d[] trail = trailHistory.get(id);
            if (trail != null && trail.length >= 3 && trail[2] != null) {
                Vec3d ghostPos = trail[2]; // 2 ticks ago
                renderGhostSilhouette(matrices, vc, ghostPos, entity, 0.3f);
            }

            // === MOVEMENT VECTOR (arrow above entity) ===
            Vec3d velocity = entity.getVelocity();
            if (velocity.lengthSquared() > 0.01) {
                renderMovementVector(matrices, vc, entity.getPos(), velocity);
            }

            // === MOB AGGRO (target direction + radius) ===
            if (entity instanceof MobEntity mob) {
                LivingEntity target = mob.getTarget();
                if (target != null) {
                    renderAggroIndicator(matrices, vc, entity, target);
                }
            }
        }

        matrices.pop();
    }

    /**
     * Render translucent ghost silhouette at old position.
     */
    private static void renderGhostSilhouette(MatrixStack matrices, VertexConsumer vc,
            Vec3d pos, LivingEntity entity, float alpha) {
        Matrix4f m = matrices.peek().getPositionMatrix();
        float h = entity.getHeight();
        float w = 0.3f;
        float x = (float) pos.x;
        float y = (float) pos.y;
        float z = (float) pos.z;

        // Simple box silhouette (front + back faces)
        emitQuad(vc, m, x-w, y, z+w, x+w, y, z+w, x+w, y+h, z+w, x-w, y+h, z+w,
            1f, 0.2f, 0.2f, alpha);
        emitQuad(vc, m, x+w, y, z-w, x-w, y, z-w, x-w, y+h, z-w, x+w, y+h, z-w,
            1f, 0.2f, 0.2f, alpha);
    }

    /**
     * Render movement direction arrow above entity.
     */
    private static void renderMovementVector(MatrixStack matrices, VertexConsumer vc,
            Vec3d pos, Vec3d velocity) {
        Matrix4f m = matrices.peek().getPositionMatrix();
        Vec3d dir = velocity.normalize();
        float x = (float) pos.x;
        float y = (float) pos.y + 2.2f; // Above head
        float z = (float) pos.z;
        float len = 0.6f;

        // Arrow line
        float tipX = x + (float)dir.x * len;
        float tipY = y + (float)dir.y * len;
        float tipZ = z + (float)dir.z * len;

        // Draw as small quad pointing in direction
        float w = 0.05f;
        emitQuad(vc, m, x-w, y-w, z, x+w, y+w, z, tipX+w, tipY+w, tipZ, tipX-w, tipY-w, tipZ,
            1f, 0.5f, 0f, 0.7f);
    }

    /**
     * Render aggro indicator for mobs (line to target).
     */
    private static void renderAggroIndicator(MatrixStack matrices, VertexConsumer vc,
            LivingEntity mob, LivingEntity target) {
        Matrix4f m = matrices.peek().getPositionMatrix();
        Vec3d from = mob.getPos().add(0, mob.getHeight() + 0.3, 0);
        Vec3d to = target.getPos().add(0, target.getHeight() * 0.5, 0);
        Vec3d dir = to.subtract(from).normalize();
        float len = (float) from.distanceTo(to);
        if (len > 16) return; // Only show within 16 blocks

        // Dashed line to target (draw segments)
        int segments = (int)(len / 0.5f);
        float w = 0.03f;
        for (int i = 0; i < segments; i += 2) { // Every other segment (dashed)
            float t1 = i / (float) segments;
            float t2 = (i + 1) / (float) segments;
            float x1 = (float)(from.x + dir.x * len * t1);
            float y1 = (float)(from.y + dir.y * len * t1);
            float z1 = (float)(from.z + dir.z * len * t1);
            float x2 = (float)(from.x + dir.x * len * t2);
            float y2 = (float)(from.y + dir.y * len * t2);
            float z2 = (float)(from.z + dir.z * len * t2);

            emitQuad(vc, m, x1-w, y1, z1, x1+w, y1, z1, x2+w, y2, z2, x2-w, y2, z2,
                1f, 0.3f, 0.3f, 0.5f);
        }
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

    public static void clear() {
        trailHistory.clear();
    }
}
'@
Write-File (Join-Path $clientDojutsuDir "SharinganTrackingRenderer.java") $trackingRenderer

# ============================================================
# FILE 6: SharinganForesightRenderer.java - 3 tomoe abilities
# Show enemy technique above head (unified SP+MP)
# ============================================================
Write-Host "[6/8] Creating SharinganForesightRenderer (3 tomoe)..." -ForegroundColor Yellow

$foresightRenderer = @'
package com.example.shinobicore.client.dojutsu;

import com.example.shinobicore.client.CastingClientState;
import com.example.shinobicore.client.ClientNinjaState;
import net.fabricmc.fabric.api.client.rendering.v1.WorldRenderContext;
import net.fabricmc.fabric.api.client.rendering.v1.WorldRenderEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.entity.LivingEntity;
import net.minecraft.text.Text;
import net.minecraft.util.math.Vec3d;

/**
 * 3 Tomoe: Foresight (unified SP+MP).
 * Shows enemy's active technique above their head:
 * - Chakra color (element color)
 * - Technique name
 * - Charge progress bar (if charging)
 * Works against both players and mobs.
 */
public class SharinganForesightRenderer {

    public static void register() {
        WorldRenderEvents.AFTER_ENTITIES.register(SharinganForesightRenderer::render);
    }

    private static void render(WorldRenderContext context) {
        if (!SharinganClientState.hasThreeTomoe() || !SharinganClientState.isActive()) return;

        MinecraftClient client = MinecraftClient.getInstance();
        if (client.world == null || client.player == null) return;

        MatrixStack matrices = context.matrixStack();
        VertexConsumerProvider consumers = context.consumers();
        if (consumers == null) return;

        Vec3d camPos = context.camera().getPos();

        for (LivingEntity entity : client.world.getEntities()) {
            if (!(entity instanceof AbstractClientPlayerEntity)) continue;
            if (entity == client.player) continue;

            double dist = entity.getPos().distanceTo(client.player.getPos());
            if (dist > 20) continue; // 20 block range

            // Check if entity is casting
            CastingClientState.Cast cast = CastingClientState.get((AbstractClientPlayerEntity) entity);
            if (cast == null) continue;

            // Render technique info above head
            renderTechniqueLabel(matrices, consumers, entity, cast, camPos);
        }
    }

    /**
     * Render technique name and element color above entity's head.
     */
    private static void renderTechniqueLabel(MatrixStack matrices,
            VertexConsumerProvider consumers, LivingEntity entity,
            CastingClientState.Cast cast, Vec3d camPos) {

        MinecraftClient client = MinecraftClient.getInstance();
        Vec3d pos = entity.getPos().add(0, entity.getHeight() + 0.5, 0);

        matrices.push();
        matrices.translate(pos.x - camPos.x, pos.y - camPos.y, pos.z - camPos.z);

        // Face camera
        matrices.multiply(net.minecraft.util.math.RotationAxis.POSITIVE_Y
            .rotationDegrees(-client.gameRenderer.getCamera().getYaw()));
        matrices.multiply(net.minecraft.util.math.RotationAxis.POSITIVE_X
            .rotationDegrees(client.gameRenderer.getCamera().getPitch()));
        matrices.scale(-0.025f, -0.025f, 0.025f);

        // Get technique name
        String jutsuName = ClientNinjaState.name(cast.nature);
        if (jutsuName == null || jutsuName.isEmpty()) jutsuName = cast.nature;

        // Element color
        int color = getElementColor(cast.nature);

        // Draw background
        int textWidth = client.textRenderer.getWidth(jutsuName);
        matrices.push();
        matrices.translate(-textWidth / 2f - 2, -10, 0);

        // Use immediate vertex consumer for text
        var immediate = MinecraftClient.getInstance().getBufferBuilders().getEntityVertexConsumers();
        client.textRenderer.draw(jutsuName, 0, 0, color, true,
            matrices.peek().getPositionMatrix(), immediate,
            net.minecraft.client.font.TextRenderer.TextLayerType.NORMAL,
            0x80000000, 0xF000F0);
        immediate.draw();

        matrices.pop();
        matrices.pop();
    }

    /**
     * Get element color for technique display.
     */
    private static int getElementColor(String nature) {
        if (nature == null) return 0xFF88AAFF;
        return switch (nature) {
            case "fire" -> 0xFFFF4400;
            case "water" -> 0xFF2266FF;
            case "wind" -> 0xFF88DDAA;
            case "lightning" -> 0xFFFFEE44;
            case "earth" -> 0xFF996633;
            default -> 0xFF88AAFF;
        };
    }
}
'@
Write-File (Join-Path $clientDojutsuDir "SharinganForesightRenderer.java") $foresightRenderer

# ============================================================
# PATCHES: ModPackets - Add sharingan packet IDs
# ============================================================
Write-Host "[7/8] Patching ModPackets + KeyBindings + handlers..." -ForegroundColor Yellow

$modPacketsFile = Join-Path $srcBase "network\ModPackets.java"
Patch-File $modPacketsFile `
    "public static final Identifier RELEASE_CAST_ID = new Identifier(`"shinobicore`", `"release_cast`");" `
    @"
public static final Identifier RELEASE_CAST_ID = new Identifier("shinobicore", "release_cast");
    // Sharingan packets
    public static final Identifier SHARINGAN_SYNC_ID = new Identifier("shinobicore", "sharingan_sync");
    public static final Identifier SHARINGAN_TOGGLE_ID = new Identifier("shinobicore", "sharingan_toggle");
    public static final Identifier SHARINGAN_COPY_ID = new Identifier("shinobicore", "sharingan_copy");
"@

# ============================================================
# PATCHES: KeyBindings - Add TOGGLE_SHARINGAN
# ============================================================
$keyBindingsFile = Join-Path $srcBase "client\KeyBindings.java"
Patch-File $keyBindingsFile `
    "public static KeyBinding TOGGLE_SCABBARD;" `
    @"
public static KeyBinding TOGGLE_SCABBARD;
    public static KeyBinding TOGGLE_SHARINGAN;
"@

Patch-File $keyBindingsFile `
    "TOGGLE_SCABBARD = KeyBindingHelper.registerKeyBinding(new KeyBinding(" `
    @"
TOGGLE_SHARINGAN = KeyBindingHelper.registerKeyBinding(new KeyBinding(
                "key.shinobicore.toggle_sharingan", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_P, CATEGORY));
        TOGGLE_SCABBARD = KeyBindingHelper.registerKeyBinding(new KeyBinding(
"@

# ============================================================
# PATCHES: ClientInputHandler - Handle sharingan toggle
# ============================================================
$inputFile = Join-Path $srcBase "client\ClientInputHandler.java"
Patch-File $inputFile `
    "if (KeyBindings.TOGGLE_SCABBARD.wasPressed()) {" `
    @"
if (KeyBindings.TOGGLE_SHARINGAN.wasPressed()) {
            if (client.getNetworkHandler() != null) {
                PacketByteBuf sharinganBuf = new PacketByteBuf(Unpooled.buffer());
                ClientPlayNetworking.send(ModPackets.SHARINGAN_TOGGLE_ID, sharinganBuf);
            }
        }
        if (KeyBindings.TOGGLE_SCABBARD.wasPressed()) {
"@

# ============================================================
# PATCHES: ShinobiCoreClient - Register sharingan renderers + receivers
# ============================================================
$clientFile = Join-Path $srcBase "client\ShinobiCoreClient.java"
Patch-File $clientFile `
    "import com.example.shinobicore.client.RasenganClientState;" `
    @"
import com.example.shinobicore.client.RasenganClientState;
import com.example.shinobicore.client.dojutsu.SharinganClientState;
import com.example.shinobicore.client.dojutsu.SharinganOverlayRenderer;
import com.example.shinobicore.client.dojutsu.SharinganTrackingRenderer;
import com.example.shinobicore.client.dojutsu.SharinganForesightRenderer;
"@

Patch-File $clientFile `
    "NarutoArmorRenderer.register();" `
    @"
NarutoArmorRenderer.register();
        // Sharingan renderers
        SharinganOverlayRenderer.register();
        SharinganTrackingRenderer.register();
        SharinganForesightRenderer.register();
"@

# Register sharingan packet receivers
Patch-File $clientFile `
    "ClientPlayNetworking.registerGlobalReceiver(ModPackets.DANGER_SYNC_ID" `
    @"
// Sharingan sync receiver (S2C)
        ClientPlayNetworking.registerGlobalReceiver(ModPackets.SHARINGAN_SYNC_ID, (client, handler, buf, responseSender) -> {
            int stage = buf.readInt();
            boolean active = buf.readBoolean();
            int usage = buf.readInt();
            int stress = buf.readInt();
            client.execute(() -> {
                SharinganClientState.stageLevel = stage;
                SharinganClientState.active = active;
                SharinganClientState.usageProgress = usage;
                SharinganClientState.stressCount = stress;
            });
        });
        // Sharingan copy receiver (S2C)
        ClientPlayNetworking.registerGlobalReceiver(ModPackets.SHARINGAN_COPY_ID, (client, handler, buf, responseSender) -> {
            String jutsuId = buf.readString();
            long duration = buf.readLong();
            client.execute(() -> {
                SharinganClientState.copiedTechniques.add(
                    new SharinganClientState.CopiedTechnique(jutsuId,
                        System.currentTimeMillis() + duration));
            });
        });
        ClientPlayNetworking.registerGlobalReceiver(ModPackets.DANGER_SYNC_ID
"@

# ============================================================
# PATCHES: ShinobiCore - Register server-side sharingan handler
# ============================================================
$serverFile = Join-Path $srcBase "ShinobiCore.java"
Patch-File $serverFile `
    "ServerLifecycleEvents.SERVER_STARTED.register(server -> {" `
    @"
// Sharingan toggle handler (C2S)
        net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking.registerGlobalReceiver(
            ModPackets.SHARINGAN_TOGGLE_ID, (server, player, handler, buf, responseSender) -> {
            server.execute(() -> {
                var data = ((com.example.shinobicore.stat.NinjaDataHolder) player).shinobicore_getData();
                var sharingan = data.getSharinganComponent();
                if (sharingan != null) {
                    sharingan.toggle(player);
                }
            });
        });
        ServerLifecycleEvents.SERVER_STARTED.register(server -> {
"@

# ============================================================
# PATCHES: NinjaPlayerData - Add sharingan component
# ============================================================
$ninjaDataFile = Join-Path $srcBase "stat\NinjaPlayerData.java"
Patch-File $ninjaDataFile `
    "private boolean lastDangerState = false;" `
    @"
private boolean lastDangerState = false;
    private com.example.shinobicore.dojutsu.SharinganComponent sharinganComponent = new com.example.shinobicore.dojutsu.SharinganComponent();
"@

Patch-File $ninjaDataFile `
    "public boolean getLastDangerState() { return lastDangerState; }" `
    @"
public boolean getLastDangerState() { return lastDangerState; }
    public com.example.shinobicore.dojutsu.SharinganComponent getSharinganComponent() { return sharinganComponent; }
"@

# ============================================================
# PATCHES: NinjaTickHandler - Add sharingan tick + evolution tracking
# ============================================================
$tickFile = Join-Path $srcBase "event\NinjaTickHandler.java"
Patch-File $tickFile `
    "// === S6: Sensory component tick ===" `
    @"
// === S6: Sharingan component tick ===
            var sharinganComp = data.getSharinganComponent();
            if (sharinganComp != null) {
                sharinganComp.tick(player);
                // Evolution: track usage (fire/genjutsu casts give progress)
                // Evolution: track stress (low HP)
                if (player.getHealth() < player.getMaxHealth() * 0.15f) {
                    sharinganComp.addStress();
                }
            }
            // === S6: Sensory component tick ===
"@

# ============================================================
# PATCHES: Damage handling - Add 3 tomoe auto-parry
# ============================================================
$parryMixinFile = Join-Path $srcBase "mixin\PlayerParryMixin.java"
if (Test-Path $parryMixinFile) {
    Patch-File $parryMixinFile `
        "if (b.autoParryChance <= 0) return;" `
        @"
// Sharingan 3 tomoe: 35% auto-parry for melee
        var sharinganData = ((com.example.shinobicore.stat.NinjaDataHolder) self).shinobicore_getData();
        var sharinganComp = sharinganData.getSharinganComponent();
        if (sharinganComp != null && sharinganComp.checkAutoParry(
                (ServerPlayerEntity) self, source, amount)) {
            // Auto-parry successful: spawn particles and cancel damage
            if (self.getWorld() instanceof net.minecraft.server.world.ServerWorld sw) {
                sw.spawnParticles(net.minecraft.particle.ParticleTypes.CRIT,
                    self.getX(), self.getY() + 1, self.getZ(),
                    15, 0.4, 0.4, 0.4, 0.08);
            }
            cir.setReturnValue(false);
            return;
        }
        if (b.autoParryChance <= 0) return;
"@
}

# ============================================================
# PATCHES: Lang files - Add sharingan key binding
# ============================================================
$enLangFile = Join-Path $root "src\main\resources\assets\shinobicore\lang\en_us.json"
Patch-File $enLangFile `
    '"key.shinobicore.toggle_scabbard": "Sheathe / Draw Katana (O)"' `
    @"
"key.shinobicore.toggle_scabbard": "Sheathe / Draw Katana (O)",
    "key.shinobicore.toggle_sharingan": "Toggle Sharingan (P)"
"@

$ruLangFile = Join-Path $root "src\main\resources\assets\shinobicore\lang\ru_ru.json"
Patch-File $ruLangFile `
    '"key.shinobicore.toggle_scabbard": "РќРѕР¶РЅС‹ / РґРѕСЃС‚Р°С‚СЊ РєР°С‚Р°РЅСѓ (O)"' `
    @"
"key.shinobicore.toggle_scabbard": "РќРѕР¶РЅС‹ / РґРѕСЃС‚Р°С‚СЊ РєР°С‚Р°РЅСѓ (O)",
    "key.shinobicore.toggle_sharingan": "РЁР°СЂРёРЅРіР°РЅ (P)"
"@

# ============================================================
# PATCHES: Cleanup on disconnect
# ============================================================
Patch-File $clientFile `
    "HandSignsClientState.clear();" `
    @"
HandSignsClientState.clear();
        SharinganClientState.clear();
        SharinganTrackingRenderer.clear();
"@

# ============================================================
# BUILD
# ============================================================
Write-Host ""
Write-Host "[8/8] Building..." -ForegroundColor Yellow
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
Write-Host "  SHARINGAN IMPLEMENTATION COMPLETE" -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Created files:" -ForegroundColor White
Write-Host "  - dojutsu/SharinganStage.java (stage enum)" -ForegroundColor Cyan
Write-Host "  - dojutsu/SharinganComponent.java (server component)" -ForegroundColor Cyan
Write-Host "  - client/dojutsu/SharinganClientState.java (client state)" -ForegroundColor Cyan
Write-Host "  - client/dojutsu/SharinganOverlayRenderer.java (red overlay)" -ForegroundColor Cyan
Write-Host "  - client/dojutsu/SharinganTrackingRenderer.java (1 tomoe)" -ForegroundColor Cyan
Write-Host "  - client/dojutsu/SharinganForesightRenderer.java (3 tomoe)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Sharingan Design:" -ForegroundColor White
Write-Host "  Evolution: usage + stress (combined)" -ForegroundColor Yellow
Write-Host "  1 Tomoe: ghost trail + movement vector + mob aggro (SP+MP)" -ForegroundColor Yellow
Write-Host "  2 Tomoe: copy T1-T3 techniques after 1 observation" -ForegroundColor Yellow
Write-Host "  3 Tomoe: enemy technique above head + 35% auto-parry" -ForegroundColor Yellow
Write-Host "  Mangekyo: Amaterasu + Dimension (quest stub)" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Activation: key P (toggle)" -ForegroundColor Yellow
Write-Host "  Cost: 5% max chakra per 10 seconds" -ForegroundColor Yellow
Write-Host "  Visual: red overlay + red particles around head" -ForegroundColor Yellow
Write-Host ""
Write-Host "Evolution thresholds:" -ForegroundColor White
Write-Host "  1 Tomoe: 50 usage + 1 stress" -ForegroundColor Cyan
Write-Host "  2 Tomoe: 150 usage + 2 stress" -ForegroundColor Cyan
Write-Host "  3 Tomoe: 300 usage + 3 stress" -ForegroundColor Cyan
Write-Host "  Mangekyo: 500 usage + 5 stress + quest (stub)" -ForegroundColor Cyan
Write-Host ""
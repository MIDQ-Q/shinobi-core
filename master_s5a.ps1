# ============================================================
# SHINOBICORE MASTER SCRIPT: SPRINT 5 PHASE B
# S5-04 Dragons (segmented voxel serpents)
# S5-05 Custom Particle System (instanced, pooled)
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcBase = Join-Path $root "src\main\java\com\example\shinobicore"
$entityDir = Join-Path $srcBase "entity"
$clientVfxDir = Join-Path $srcBase "client\vfx"
$particlesDir = Join-Path $clientVfxDir "particles"
$modelsDir = Join-Path $clientVfxDir "models"
$jutsuDir = Join-Path $srcBase "jutsu\custom"

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "  SPRINT 5 PHASE B: Dragons + Particles" -ForegroundColor Cyan
Write-Host "  S5-04 Segmented Voxel Serpents" -ForegroundColor Cyan
Write-Host "  S5-05 Custom Particle System" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

function Write-SafeFile($path, $content) {
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $content, $utf8)
    Write-Host "  [OK] $(Split-Path $path -Leaf)" -ForegroundColor Green
}

function Patch-SafeFile($p, $old, $new) {
    if (-not (Test-Path $p)) { Write-Host "  [MISS] $p" -ForegroundColor Red; return $false }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    $c = $c.Replace("`r`n", "`n")
    $oldN = $old.Replace("`r`n", "`n")
    $newN = $new.Replace("`r`n", "`n")
    if ($c.Contains($newN)) { Write-Host "  [SKIP] already: $(Split-Path $p -Leaf)" -ForegroundColor Yellow; return $true }
    if (-not $c.Contains($oldN)) { Write-Host "  [FAIL] pattern not found: $(Split-Path $p -Leaf)" -ForegroundColor Red; return $false }
    $c = $c.Replace($oldN, $newN)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "  [PATCH] $(Split-Path $p -Leaf)" -ForegroundColor Green
    return $true
}

# ============================================================
# S5-04: DRAGON ENTITY (server-side segmented serpent)
# ============================================================
Write-Host "[S5-04] Creating DragonEntity..." -ForegroundColor Yellow

$dragonEntity = @'
package com.example.shinobicore.entity;

import com.example.shinobicore.jutsu.ElementInteractionManager;
import com.example.shinobicore.jutsu.WallRemovalTask;
import net.minecraft.block.Blocks;
import net.minecraft.entity.Entity;
import net.minecraft.entity.EntityType;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.data.DataTracker;
import net.minecraft.entity.data.TrackedData;
import net.minecraft.entity.data.TrackedDataHandlerRegistry;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.hit.BlockHitResult;
import net.minecraft.util.hit.HitResult;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.RaycastContext;
import net.minecraft.world.World;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * S5-04: Segmented dragon entity.
 * Server handles head movement + segment hitboxes.
 * Client renders voxel segments along the trail.
 */
public class DragonEntity extends Entity {
    private static final TrackedData<String> ELEMENT = DataTracker.registerData(
        DragonEntity.class, TrackedDataHandlerRegistry.STRING);
    private static final TrackedData<Float> DAMAGE = DataTracker.registerData(
        DragonEntity.class, TrackedDataHandlerRegistry.FLOAT);
    private static final TrackedData<Integer> SEGMENTS = DataTracker.registerData(
        DragonEntity.class, TrackedDataHandlerRegistry.INTEGER);
    private static final TrackedData<Float> RADIUS = DataTracker.registerData(
        DragonEntity.class, TrackedDataHandlerRegistry.FLOAT);

    private UUID ownerId;
    public int age = 0;
    private static final int MAX_LIFETIME = 140;
    private static final int MAX_SEGMENTS = 12;

    public DragonEntity(EntityType<?> type, World world) { super(type, world); }

    public DragonEntity(World world, LivingEntity owner, Vec3d velocity,
                        String element, float damage, float radius, int segments) {
        super(ModEntities.DRAGON, world);
        this.ownerId = owner.getUuid();
        this.setPosition(owner.getX(), owner.getEyeY() - 0.2, owner.getZ());
        this.setVelocity(velocity);
        this.velocityDirty = true;
        this.dataTracker.set(ELEMENT, element);
        this.dataTracker.set(DAMAGE, damage);
        this.dataTracker.set(SEGMENTS, Math.min(segments, MAX_SEGMENTS));
        this.dataTracker.set(RADIUS, radius);
    }

    @Override protected void initDataTracker() {
        this.dataTracker.startTracking(ELEMENT, "fire");
        this.dataTracker.startTracking(DAMAGE, 10f);
        this.dataTracker.startTracking(SEGMENTS, 6);
        this.dataTracker.startTracking(RADIUS, 3f);
    }

    public String getElement() { return this.dataTracker.get(ELEMENT); }
    public float getDamage() { return this.dataTracker.get(DAMAGE); }
    public int getSegmentCount() { return this.dataTracker.get(SEGMENTS); }
    public float getRadius() { return this.dataTracker.get(RADIUS); }

    public Entity getOwner() {
        return ownerId == null ? null : getWorld().getPlayerByUuid(ownerId);
    }

    @Override
    public void tick() {
        super.tick();
        age++;
        if (age > MAX_LIFETIME) { discard(); return; }

        Vec3d vel = getVelocity();
        Vec3d startPos = getPos();
        Vec3d endPos = startPos.add(vel);

        // Sinusoidal flight offset
        float wave = (float) Math.sin(age * 0.15) * 0.3;
        endPos = endPos.add(0, wave * 0.1, 0);

        // Block collision for head
        HitResult blockHit = getWorld().raycast(new RaycastContext(
            startPos, endPos, RaycastContext.ShapeType.COLLIDER,
            RaycastContext.FluidHandling.NONE, this));

        // Entity collision for head
        LivingEntity hitEntity = null;
        double closestDist = Double.MAX_VALUE;
        Box searchBox = getBoundingBox().stretch(vel).expand(0.3);
        for (Entity e : getWorld().getOtherEntities(this, searchBox)) {
            if (e instanceof LivingEntity liv && !liv.getUuid().equals(ownerId)) {
                var opt = liv.getBoundingBox().expand(0.4).raycast(startPos, endPos);
                if (opt.isPresent()) {
                    double d = startPos.squaredDistanceTo(opt.get());
                    if (d < closestDist) { closestDist = d; hitEntity = liv; }
                }
            }
        }

        // Segment hitbox check (simplified: expanded box around head)
        LivingEntity segHit = null;
        if (hitEntity == null) {
            float segRadius = getRadius() * 0.5f;
            Box segBox = getBoundingBox().expand(segRadius);
            for (Entity e : getWorld().getOtherEntities(this, segBox)) {
                if (e instanceof LivingEntity liv && !liv.getUuid().equals(ownerId)) {
                    if (liv.getBoundingBox().intersects(segBox)) {
                        segHit = liv;
                        break;
                    }
                }
            }
        }

        boolean hit = false;
        if (hitEntity != null) {
            hitEntity.damage(getDamageSources().magic(), getDamage());
            hit = true;
        } else if (segHit != null) {
            segHit.damage(getDamageSources().magic(), getDamage() * 0.4f);
        }

        if (blockHit.getType() == HitResult.Type.BLOCK) hit = true;

        if (hit) {
            onImpact();
            discard();
            return;
        }

        setPosition(endPos.x, endPos.y, endPos.z);
        setVelocity(vel);

        // Trail particles on server
        if (getWorld() instanceof ServerWorld sw && age % 3 == 0) {
            String elem = getElement();
            if ("fire".equals(elem)) {
                sw.spawnParticles(ParticleTypes.FLAME, getX(), getY(), getZ(), 3, 0.3, 0.3, 0.3, 0.05);
            } else if ("water".equals(elem)) {
                sw.spawnParticles(ParticleTypes.FALLING_WATER, getX(), getY(), getZ(), 3, 0.3, 0.3, 0.3, 0.05);
            } else {
                sw.spawnParticles(ParticleTypes.POOF, getX(), getY(), getZ(), 2, 0.3, 0.3, 0.3, 0.03);
            }
        }
    }

    private void onImpact() {
        if (!(getWorld() instanceof ServerWorld sw)) return;
        String elem = getElement();
        float radius = getRadius();
        Vec3d pos = getPos();
        ServerPlayerEntity owner = null;
        if (getOwner() instanceof ServerPlayerEntity sp) owner = sp;

        // Elemental interaction
        ElementInteractionManager.onElementalImpact(sw, elem.equals("fire") ? "fire" : "water", pos, radius, owner);

        // Element-specific effects
        if ("water".equals(elem)) {
            BlockPos bp = getBlockPos();
            List<BlockPos> placed = new ArrayList<>();
            for (int dx = -2; dx <= 2; dx++) {
                for (int dz = -2; dz <= 2; dz++) {
                    if (dx * dx + dz * dz <= 5) {
                        BlockPos p = bp.add(dx, 0, dz);
                        if (sw.getBlockState(p).isAir()) {
                            sw.setBlockState(p, Blocks.WATER.getDefaultState(), 3);
                            placed.add(p);
                        }
                    }
                }
            }
            if (!placed.isEmpty()) WallRemovalTask.schedule(sw, placed, 200);
        } else if ("earth".equals(elem)) {
            Box aoe = new Box(getBlockPos()).expand(3.0);
            for (Entity e : sw.getOtherEntities(this, aoe)) {
                if (e instanceof LivingEntity liv && !liv.getUuid().equals(ownerId)) {
                    liv.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, 100, 2, false, false));
                    liv.addStatusEffect(new StatusEffectInstance(StatusEffects.MINING_FATIGUE, 100, 1, false, false));
                }
            }
        }

        // AOE damage
        for (Entity e : getWorld().getOtherEntities(this, getBoundingBox().expand(radius))) {
            if (e instanceof LivingEntity liv && !liv.getUuid().equals(ownerId)) {
                liv.damage(getDamageSources().magic(), getDamage() * 0.5f);
            }
        }
    }

    @Override protected void readCustomDataFromNbt(NbtCompound nbt) {
        this.dataTracker.set(ELEMENT, nbt.getString("Element"));
        this.dataTracker.set(DAMAGE, nbt.getFloat("Damage"));
        this.dataTracker.set(SEGMENTS, nbt.getInt("Segments"));
        this.dataTracker.set(RADIUS, nbt.getFloat("Radius"));
        if (nbt.containsUuid("OwnerUUID")) ownerId = nbt.getUuid("OwnerUUID");
    }

    @Override protected void writeCustomDataToNbt(NbtCompound nbt) {
        nbt.putString("Element", getElement());
        nbt.putFloat("Damage", getDamage());
        nbt.putInt("Segments", getSegmentCount());
        nbt.putFloat("Radius", getRadius());
        if (ownerId != null) nbt.putUuid("OwnerUUID", ownerId);
    }
}
'@
Write-SafeFile (Join-Path $entityDir "DragonEntity.java") $dragonEntity

# ============================================================
# S5-04: DRAGON RENDERER (client-side voxel segments)
# ============================================================
Write-Host "[S5-04] Creating DragonRenderer..." -ForegroundColor Yellow

$dragonRenderer = @'
package com.example.shinobicore.entity;

import com.example.shinobicore.client.vfx.VoxelMeshCache;
import com.example.shinobicore.client.vfx.VoxelModel;
import com.example.shinobicore.client.vfx.VoxelShapeGenerators;
import com.example.shinobicore.client.vfx.VoxelRenderManager;
import net.minecraft.client.render.RenderLayer;
import net.minecraft.client.render.VertexConsumer;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.render.entity.EntityRenderer;
import net.minecraft.client.render.entity.EntityRendererFactory;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.RotationAxis;
import net.minecraft.util.math.Vec3d;

/**
 * S5-04: Renders dragon as segmented voxel serpent.
 * Maintains a local trail for smooth visual, independent of server.
 */
public class DragonRenderer extends EntityRenderer<DragonEntity> {
    private static final Identifier TEX = new Identifier("textures/misc/white.png");
    private static final int TRAIL_LENGTH = 16;
    private final Vec3d[] trail = new Vec3d[TRAIL_LENGTH];
    private Vec3d lastPos = Vec3d.ZERO;
    private boolean initialized = false;

    public DragonRenderer(EntityRendererFactory.Context ctx) { super(ctx); }

    @Override
    public void render(DragonEntity entity, float yaw, float tickDelta,
                       MatrixStack matrices, VertexConsumerProvider vc, int light) {
        super.render(entity, yaw, tickDelta, matrices, vc, light);

        Vec3d currentPos = entity.getPos();
        String elem = entity.getElement();
        int segCount = entity.getSegmentCount();
        float age = entity.age + tickDelta;

        // Update local trail
        if (!initialized) {
            for (int i = 0; i < TRAIL_LENGTH; i++) trail[i] = currentPos;
            lastPos = currentPos;
            initialized = true;
        } else if (lastPos.squaredDistanceTo(currentPos) > 0.001) {
            System.arraycopy(trail, 0, trail, 1, TRAIL_LENGTH - 1);
            trail[0] = currentPos;
            lastPos = currentPos;
        }

        // Element colors
        float r, g, b;
        if ("fire".equals(elem)) { r = 1.0f; g = 0.3f; b = 0.1f; }
        else if ("water".equals(elem)) { r = 0.2f; g = 0.5f; b = 1.0f; }
        else { r = 0.6f; g = 0.45f; b = 0.2f; }

        matrices.push();

        // Render head (larger)
        renderSegment(matrices, vc, currentPos, elem, 1.2f, age, light, r, g, b);

        // Render body segments along trail
        for (int i = 1; i < segCount; i++) {
            if (i >= TRAIL_LENGTH || trail[i] == null) break;
            Vec3d segPos = trail[i];
            float scale = 1.0f - (float) i / segCount * 0.5f;
            float wave = (float) Math.sin(age * 0.3 + i * 0.5) * 0.15f;
            Vec3d offsetPos = segPos.add(0, wave, 0);
            renderSegment(matrices, vc, offsetPos, elem, scale, age + i, light, r, g, b);
        }

        // Render tail tip (smallest)
        if (segCount < TRAIL_LENGTH && trail[segCount] != null) {
            Vec3d tailPos = trail[segCount];
            renderSegment(matrices, vc, tailPos, elem, 0.4f, age + segCount, light, r, g, b);
        }

        matrices.pop();
    }

    private void renderSegment(MatrixStack matrices, VertexConsumerProvider vc,
                               Vec3d pos, String elem, float scale, float age,
                               int light, float r, float g, float b) {
        matrices.push();
        matrices.translate(pos.x - lastPos.x, pos.y - lastPos.y, pos.z - lastPos.z);
        matrices.scale(scale, scale, scale);

        // Rotation for visual interest
        float rot = age * 5f;
        matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(rot));

        // Use snakeSegment generator for body, sphere for head
        String modelId = "dragon_seg_" + elem + "_" + (int)(scale * 10);
        VoxelModel model = VoxelMeshCache.getOrBakeModel(modelId, () ->
            VoxelShapeGenerators.snakeSegment(0.4f, 0.8f, r, g, b, 0.9f)
        );

        VertexConsumer consumer = vc.getBuffer(RenderLayer.getEntityTranslucent(TEX));
        VoxelMeshCache.renderBaked(matrices.peek().getPositionMatrix(), consumer, model, light);

        matrices.pop();
    }

    @Override
    public Identifier getTexture(DragonEntity entity) { return TEX; }
}
'@
Write-SafeFile (Join-Path $entityDir "DragonRenderer.java") $dragonRenderer

# ============================================================
# S5-05: VOXEL PARTICLE DATA
# ============================================================
Write-Host "[S5-05] Creating VoxelParticle..." -ForegroundColor Yellow

$voxelParticle = @'
package com.example.shinobicore.client.vfx.particles;

/**
 * S5-05: Single particle data. No entity per particle.
 * Stored in a pool, rendered via instancing.
 */
public class VoxelParticle {
    public float x, y, z;
    public float vx, vy, vz;
    public float r, g, b, a;
    public float size;
    public int life;
    public int maxLife;
    public boolean emissive;
    public float gravity;
    public float drag;

    public VoxelParticle() { reset(); }

    public void reset() {
        x = y = z = 0; vx = vy = vz = 0;
        r = g = b = 1; a = 1;
        size = 0.1f; life = 0; maxLife = 20;
        emissive = false; gravity = 0.02f; drag = 0.98f;
    }

    public void init(float px, float py, float pz,
                     float pvx, float pvy, float pvz,
                     float pr, float pg, float pb, float pa,
                     float pSize, int pLife, boolean pEmissive) {
        x = px; y = py; z = pz;
        vx = pvx; vy = pvy; vz = pvz;
        r = pr; g = pg; b = pb; a = pa;
        size = pSize; life = pLife; maxLife = pLife;
        emissive = pEmissive; gravity = 0.02f; drag = 0.98f;
    }

    public boolean isAlive() { return life > 0; }

    public void update() {
        life--;
        vx *= drag;
        vy = vy * drag - gravity;
        vz *= drag;
        x += vx; y += vy; z += vz;
    }

    public float getAlpha() {
        return a * ((float) life / maxLife);
    }

    public float getSize() {
        return size * (0.5f + 0.5f * ((float) life / maxLife));
    }
}
'@
Write-SafeFile (Join-Path $particlesDir "VoxelParticle.java") $voxelParticle

# ============================================================
# S5-05: PARTICLE MANAGER (pooled, instanced rendering)
# ============================================================
Write-Host "[S5-05] Creating VoxelParticleManager..." -ForegroundColor Yellow

$particleManager = @'
package com.example.shinobicore.client.vfx.particles;

import com.example.shinobicore.client.vfx.VfxBudget;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.render.OverlayTexture;
import net.minecraft.client.render.RenderLayer;
import net.minecraft.client.render.VertexConsumer;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.Vec3d;
import org.joml.Matrix4f;
import java.util.ArrayList;
import java.util.List;

/**
 * S5-05: Pooled particle manager. No entity per particle.
 * All particles rendered in a single draw call via VertexConsumer.
 * Respects VfxBudget limits.
 */
public class VoxelParticleManager {
    private static final List<VoxelParticle> pool = new ArrayList<>();
    private static final List<VoxelParticle> active = new ArrayList<>();
    private static final int MAX_PARTICLES = 400;
    private static final Identifier TEX = new Identifier("textures/misc/white.png");

    static {
        for (int i = 0; i < MAX_PARTICLES; i++) pool.add(new VoxelParticle());
    }

    /** Spawn a single particle. Returns false if budget exceeded. */
    public static boolean spawn(float x, float y, float z,
                                float vx, float vy, float vz,
                                float r, float g, float b, float a,
                                float size, int life, boolean emissive) {
        if (active.size() >= MAX_PARTICLES) return false;
        if (!VfxBudget.canSpawn()) return false;
        VoxelParticle p = pool.stream().filter(pp -> !pp.isAlive()).findFirst().orElse(null);
        if (p == null) return false;
        p.init(x, y, z, vx, vy, vz, r, g, b, a, size, life, emissive);
        active.add(p);
        return true;
    }

    /** Spawn a burst of particles. */
    public static void spawnBurst(float x, float y, float z, int count,
                                  float r, float g, float b, float a,
                                  float size, int life, boolean emissive, float spread) {
        int adjusted = VoxelRenderManager.adjustParticleCount(count);
        for (int i = 0; i < adjusted; i++) {
            float vx = (float)(Math.random() - 0.5) * spread;
            float vy = (float)(Math.random() - 0.5) * spread;
            float vz = (float)(Math.random() - 0.5) * spread;
            spawn(x, y, z, vx, vy, vz, r, g, b, a, size, life, emissive);
        }
    }

    /** Update all active particles. Called every client tick. */
    public static void update() {
        for (int i = active.size() - 1; i >= 0; i--) {
            VoxelParticle p = active.get(i);
            p.update();
            if (!p.isAlive()) {
                active.remove(i);
            }
        }
    }

    /** Render all active particles in one draw call. */
    public static void render(MatrixStack matrices, VertexConsumerProvider vc) {
        if (active.isEmpty()) return;
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;

        Vec3d camPos = client.player.getPos();
        VertexConsumer consumer = vc.getBuffer(RenderLayer.getEntityTranslucent(TEX));
        Matrix4f m = matrices.peek().getPositionMatrix();

        for (VoxelParticle p : active) {
            float alpha = p.getAlpha();
            if (alpha <= 0.01f) continue;

            // Distance culling
            double dx = p.x - camPos.x;
            double dy = p.y - camPos.y;
            double dz = p.z - camPos.z;
            if (dx * dx + dy * dy + dz * dz > 4096) continue; // 64 blocks

            float s = p.getSize();
            int light = p.emissive ? 0xF000F0 : 15728640;

            // Billboard quad facing camera
            float x1 = p.x - s, y1 = p.y - s;
            float x2 = p.x + s, y2 = p.y + s;

            consumer.vertex(m, (float)dx - s, (float)dy - s, (float)dz)
                .color(p.r, p.g, p.b, alpha)
                .texture(0, 0).overlay(OverlayTexture.DEFAULT_UV)
                .light(light).normal(0, 1, 0).next();
            consumer.vertex(m, (float)dx + s, (float)dy - s, (float)dz)
                .color(p.r, p.g, p.b, alpha)
                .texture(0, 0).overlay(OverlayTexture.DEFAULT_UV)
                .light(light).normal(0, 1, 0).next();
            consumer.vertex(m, (float)dx + s, (float)dy + s, (float)dz)
                .color(p.r, p.g, p.b, alpha)
                .texture(0, 0).overlay(OverlayTexture.DEFAULT_UV)
                .light(light).normal(0, 1, 0).next();
            consumer.vertex(m, (float)dx - s, (float)dy + s, (float)dz)
                .color(p.r, p.g, p.b, alpha)
                .texture(0, 0).overlay(OverlayTexture.DEFAULT_UV)
                .light(light).normal(0, 1, 0).next();
        }
    }

    /** Get active particle count (for debug overlay). */
    public static int getActiveCount() { return active.size(); }

    /** Clear all particles (on disconnect). */
    public static void clear() {
        active.clear();
        for (VoxelParticle p : pool) p.reset();
    }
}
'@
Write-SafeFile (Join-Path $particlesDir "VoxelParticleManager.java") $particleManager

# ============================================================
# S5-05: PARTICLE EMITTER (element-colored presets)
# ============================================================
Write-Host "[S5-05] Creating VoxelParticleEmitter..." -ForegroundColor Yellow

$particleEmitter = @'
package com.example.shinobicore.client.vfx.particles;

import net.minecraft.util.math.Vec3d;

/**
 * S5-05: Element-colored particle presets.
 * Static methods for spawning themed particle effects.
 */
public class VoxelParticleEmitter {

    /** Fire burst: orange/red particles. */
    public static void fireBurst(Vec3d pos, int count, float spread) {
        VoxelParticleManager.spawnBurst(
            (float)pos.x, (float)pos.y, (float)pos.z, count,
            1.0f, 0.4f, 0.1f, 0.9f, 0.12f, 25, true, spread);
    }

    /** Water splash: blue particles. */
    public static void waterSplash(Vec3d pos, int count, float spread) {
        VoxelParticleManager.spawnBurst(
            (float)pos.x, (float)pos.y, (float)pos.z, count,
            0.2f, 0.5f, 1.0f, 0.8f, 0.1f, 20, false, spread);
    }

    /** Wind gust: pale green particles. */
    public static void windGust(Vec3d pos, int count, float spread) {
        VoxelParticleManager.spawnBurst(
            (float)pos.x, (float)pos.y, (float)pos.z, count,
            0.6f, 0.9f, 0.7f, 0.6f, 0.08f, 15, false, spread);
    }

    /** Lightning spark: yellow particles. */
    public static void lightningSpark(Vec3d pos, int count, float spread) {
        VoxelParticleManager.spawnBurst(
            (float)pos.x, (float)pos.y, (float)pos.z, count,
            1.0f, 1.0f, 0.3f, 0.9f, 0.08f, 12, true, spread);
    }

    /** Earth crumble: brown particles. */
    public static void earthCrumble(Vec3d pos, int count, float spread) {
        VoxelParticleManager.spawnBurst(
            (float)pos.x, (float)pos.y, (float)pos.z, count,
            0.6f, 0.45f, 0.2f, 0.8f, 0.12f, 20, false, spread);
    }

    /** Chakra flow: blue-white particles. */
    public static void chakraFlow(Vec3d pos, int count, float spread) {
        VoxelParticleManager.spawnBurst(
            (float)pos.x, (float)pos.y, (float)pos.z, count,
            0.4f, 0.7f, 1.0f, 0.7f, 0.06f, 18, true, spread);
    }

    /** Smoke: gray particles. */
    public static void smoke(Vec3d pos, int count, float spread) {
        VoxelParticleManager.spawnBurst(
            (float)pos.x, (float)pos.y, (float)pos.z, count,
            0.5f, 0.5f, 0.5f, 0.5f, 0.15f, 30, false, spread * 0.5f);
    }

    /** Kawarimi poof: large smoke burst. */
    public static void kawarimiPoof(Vec3d pos) {
        VoxelParticleManager.spawnBurst(
            (float)pos.x, (float)pos.y, (float)pos.z, 40,
            0.6f, 0.6f, 0.6f, 0.6f, 0.2f, 35, false, 0.4f);
    }

    /** Clone dispersion: smoke + sparks. */
    public static void cloneDispersion(Vec3d pos) {
        smoke(pos, 25, 0.5f);
        VoxelParticleManager.spawnBurst(
            (float)pos.x, (float)pos.y, (float)pos.z, 15,
            0.8f, 0.8f, 1.0f, 0.8f, 0.05f, 10, true, 0.3f);
    }
}
'@
Write-SafeFile (Join-Path $particlesDir "VoxelParticleEmitter.java") $particleEmitter

# ============================================================
# S5-05: PARTICLE RENDERER (Fabric API integration)
# ============================================================
Write-Host "[S5-05] Creating VoxelParticleRenderer..." -ForegroundColor Yellow

$particleRenderer = @'
package com.example.shinobicore.client.vfx.particles;

import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.rendering.v1.WorldRenderContext;
import net.fabricmc.fabric.api.client.rendering.v1.WorldRenderEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.util.math.MatrixStack;

/**
 * S5-05: Registers particle update and render hooks.
 * Update: every client tick via ClientTickEvents.
 * Render: after translucent layer via WorldRenderEvents.
 */
public class VoxelParticleRenderer {

    public static void register() {
        // Update particles every tick
        ClientTickEvents.END_CLIENT_TICK.register(client -> {
            if (client.world == null) return;
            VoxelParticleManager.update();
        });

        // Render particles after world translucent pass
        WorldRenderEvents.AFTER_TRANSLUCENT.register(context -> {
            MatrixStack matrices = context.matrixStack();
            VertexConsumerProvider consumers = context.consumers();
            if (consumers == null) return;
            MinecraftClient client = MinecraftClient.getInstance();
            if (client.player == null || client.world == null) return;
            VoxelParticleManager.render(matrices, consumers);
        });
    }
}
'@
Write-SafeFile (Join-Path $particlesDir "VoxelParticleRenderer.java") $particleRenderer

# ============================================================
# PATCH: Add getOrBakeModel helper to VoxelMeshCache
# ============================================================
Write-Host "[PATCH] Adding getOrBakeModel to VoxelMeshCache..." -ForegroundColor Yellow

$meshCacheFile = Join-Path $clientVfxDir "VoxelMeshCache.java"
$oldCache = "public static void clear() { CACHE.clear(); }"
$newCache = @"
/**
     * S5-04: Get or create a baked mesh using a model factory.
     */
    public static BakedMesh getOrBakeModel(String modelId, java.util.function.Supplier<VoxelModel> factory) {
        return CACHE.computeIfAbsent(modelId, id -> bake(factory.get()));
    }

    public static void clear() { CACHE.clear(); }
"@
Patch-SafeFile $meshCacheFile $oldCache $newCache

# ============================================================
# PATCH: Register DRAGON entity in ModEntities
# ============================================================
Write-Host "[PATCH] Registering DRAGON in ModEntities..." -ForegroundColor Yellow

$modEntitiesFile = Join-Path $entityDir "ModEntities.java"
$oldReg = "public static void register() {"
$newReg = @"
public static final EntityType<DragonEntity> DRAGON = Registry.register(
        Registries.ENTITY_TYPE,
        new Identifier(ShinobiCore.MOD_ID, "dragon"),
        FabricEntityTypeBuilder.<DragonEntity>create(SpawnGroup.MISC, DragonEntity::new)
            .dimensions(EntityDimensions.fixed(1.0f, 1.0f))
            .trackRangeChunks(64)
            .trackedUpdateRate(2)
            .build()
    );

    public static void register() {
"@
Patch-SafeFile $modEntitiesFile $oldReg $newReg

# ============================================================
# PATCH: Register DragonRenderer + ParticleRenderer in ShinobiCoreClient
# ============================================================
Write-Host "[PATCH] Registering renderer + particles in ShinobiCoreClient..." -ForegroundColor Yellow

$clientFile = Join-Path $srcBase "client\ShinobiCoreClient.java"
$oldClientReg = "EntityRendererRegistry.register(ModEntities.RASENGAN_HAND, com.example.shinobicore.entity.RasenganHandRenderer::new);"
$newClientReg = @"
EntityRendererRegistry.register(ModEntities.RASENGAN_HAND, com.example.shinobicore.entity.RasenganHandRenderer::new);
        EntityRendererRegistry.register(ModEntities.DRAGON, com.example.shinobicore.entity.DragonRenderer::new);
        // S5-05: Register custom particle system
        com.example.shinobicore.client.vfx.particles.VoxelParticleRenderer.register();
"@
Patch-SafeFile $clientFile $oldClientReg $newClientReg

# ============================================================
# PATCH: Update DragonProjectileBehavior to use DragonEntity
# ============================================================
Write-Host "[PATCH] Updating DragonProjectileBehavior..." -ForegroundColor Yellow

$dragonBehaviorFile = Join-Path $jutsuDir "DragonProjectileBehavior.java"
$oldDragonSpawn = @"
NinjaProjectileEntity proj = new NinjaProjectileEntity(world, player, look.multiply(speed), damage, radius, particle, model, 120);
        proj.setPosition(eye.x, eye.y, eye.z);
        proj.setPierceCount(2);
        world.spawnEntity(proj);
"@
$newDragonSpawn = @"
// S5-04: Use segmented DragonEntity instead of flat NinjaProjectileEntity
        com.example.shinobicore.entity.DragonEntity dragon = new com.example.shinobicore.entity.DragonEntity(
            world, player, look.multiply(speed), model.replace("_dragon", ""), damage, radius, 8
        );
        world.spawnEntity(dragon);
"@
Patch-SafeFile $dragonBehaviorFile $oldDragonSpawn $newDragonSpawn

# ============================================================
# PATCH: Update WaterDragonBehavior to use DragonEntity
# ============================================================
Write-Host "[PATCH] Updating WaterDragonBehavior..." -ForegroundColor Yellow

$waterDragonFile = Join-Path $jutsuDir "WaterDragonBehavior.java"
$oldWaterSpawn = @"
NinjaProjectileEntity proj = new NinjaProjectileEntity(
            world, player, look.multiply(speed), damage, radius, "water", "water_dragon", lifetime
        );
        proj.setPosition(eye.x, eye.y - 0.2, eye.z);
        proj.setHasGravity(false);
        proj.setPierceCount(3);
        world.spawnEntity(proj);
"@
$newWaterSpawn = @"
// S5-04: Segmented water dragon
        com.example.shinobicore.entity.DragonEntity dragon = new com.example.shinobicore.entity.DragonEntity(
            world, player, look.multiply(speed), "water", damage, radius, 8
        );
        world.spawnEntity(dragon);
"@
Patch-SafeFile $waterDragonFile $oldWaterSpawn $newWaterSpawn

# ============================================================
# PATCH: Update FireDragonBehavior to use DragonEntity
# ============================================================
Write-Host "[PATCH] Updating FireDragonBehavior..." -ForegroundColor Yellow

$fireDragonFile = Join-Path $jutsuDir "FireDragonBehavior.java"
$oldFireSpawn = @"
NinjaProjectileEntity proj = new NinjaProjectileEntity(
            world, player, look.multiply(speed), damage, radius, "flame", "fire_dragon", lifetime
        );
        proj.setPosition(eye.x, eye.y - 0.2, eye.z);
        proj.setHasGravity(false);
        proj.setPierceCount(5);
        world.spawnEntity(proj);
"@
$newFireSpawn = @"
// S5-04: Segmented fire dragon
        com.example.shinobicore.entity.DragonEntity dragon = new com.example.shinobicore.entity.DragonEntity(
            world, player, look.multiply(speed), "fire", damage, radius, 8
        );
        world.spawnEntity(dragon);
"@
Patch-SafeFile $fireDragonFile $oldFireSpawn $newFireSpawn

# ============================================================
# PATCH: Clear particles on disconnect
# ============================================================
Write-Host "[PATCH] Adding particle cleanup on disconnect..." -ForegroundColor Yellow

$oldDisconnect = "HandSignsClientState.clear();"
$newDisconnect = @"
HandSignsClientState.clear();
        com.example.shinobicore.client.vfx.particles.VoxelParticleManager.clear();
"@
Patch-SafeFile $clientFile $oldDisconnect $newDisconnect

# ============================================================
# BUILD VERIFICATION
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
        $out | Select-Object -Last 20 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    }
} finally { Pop-Location }

# ============================================================
# SUMMARY
# ============================================================
Write-Host ""
Write-Host "==============================================================" -ForegroundColor Green
Write-Host "  SPRINT 5 PHASE B COMPLETE" -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Created files:" -ForegroundColor White
Write-Host "  - entity/DragonEntity.java (S5-04: server segmented serpent)" -ForegroundColor Cyan
Write-Host "  - entity/DragonRenderer.java (S5-04: client voxel trail)" -ForegroundColor Cyan
Write-Host "  - client/vfx/particles/VoxelParticle.java (S5-05: particle data)" -ForegroundColor Cyan
Write-Host "  - client/vfx/particles/VoxelParticleManager.java (S5-05: pooled pool)" -ForegroundColor Cyan
Write-Host "  - client/vfx/particles/VoxelParticleEmitter.java (S5-05: element presets)" -ForegroundColor Cyan
Write-Host "  - client/vfx/particles/VoxelParticleRenderer.java (S5-05: Fabric hooks)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Patched files:" -ForegroundColor White
Write-Host "  - entity/ModEntities.java (DRAGON registration)" -ForegroundColor Cyan
Write-Host "  - client/ShinobiCoreClient.java (renderer + particle registration)" -ForegroundColor Cyan
Write-Host "  - jutsu/custom/DragonProjectileBehavior.java" -ForegroundColor Cyan
Write-Host "  - jutsu/custom/WaterDragonBehavior.java" -ForegroundColor Cyan
Write-Host "  - jutsu/custom/FireDragonBehavior.java" -ForegroundColor Cyan
Write-Host "  - client/vfx/VoxelMeshCache.java (getOrBakeModel helper)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Architecture:" -ForegroundColor White
Write-Host "  Dragon: Server DragonEntity (head + hitboxes) -> Client DragonRenderer (voxel trail)" -ForegroundColor Yellow
Write-Host "  Particles: VoxelParticleManager (pool) -> WorldRenderEvents.AFTER_TRANSLUCENT (single draw)" -ForegroundColor Yellow
Write-Host "  Element colors: VoxelParticleEmitter presets (fire/water/wind/lightning/earth)" -ForegroundColor Yellow
Write-Host ""
Write-Host "Next: Phase C (Sound Pipeline + Shader Compat + Performance)" -ForegroundColor Yellow
Write-Host ""
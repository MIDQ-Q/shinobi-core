# ============================================================
# SHINOBICORE MASTER SCRIPT: SPRINT 5 PHASE A
# S5-01 Rasengan | S5-03 Dot Zone | S5-02 Rasenshuriken
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcBase = Join-Path $root "src\main\java\com\example\shinobicore"
$clientVfxDir = Join-Path $srcBase "client\vfx"
$entityDir = Join-Path $srcBase "entity"
$jutsuCustomDir = Join-Path $srcBase "jutsu\custom"

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "  SPRINT 5 PHASE A: Iconic Techniques (Voxel)" -ForegroundColor Cyan
Write-Host "  S5-01 Rasengan | S5-03 Dot Zone | S5-02 Rasenshuriken" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

# --- Helper Functions ---
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
    $oldNorm = $old.Replace("`r`n", "`n")
    $newNorm = $new.Replace("`r`n", "`n")
    
    if ($c.Contains($newNorm)) { Write-Host "  [SKIP] Already applied: $(Split-Path $p -Leaf)" -ForegroundColor Yellow; return $true }
    if (-not $c.Contains($oldNorm)) { Write-Host "  [FAIL] Pattern not found in $(Split-Path $p -Leaf)" -ForegroundColor Red; return $false }
    
    $c = $c.Replace($oldNorm, $newNorm)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "  [PATCH] $(Split-Path $p -Leaf)" -ForegroundColor Green
    return $true
}

# ============================================================
# S5-01: RASENGAN VOXEL MODEL & RENDERER
# ============================================================
Write-Host "[S5-01] Creating Voxel Rasengan Model & Renderer..." -ForegroundColor Yellow

$rasenganModel = @'
package com.example.shinobicore.client.vfx.models;

import com.example.shinobicore.client.vfx.VoxelCube;
import com.example.shinobicore.client.vfx.VoxelModel;
import com.example.shinobicore.client.vfx.VoxelShapeGenerators;

/**
 * S5-01: Voxel Rasengan with 5 animation states.
 * States: FORMING, STABILIZING, HELD, STRIKE, DISSIPATING
 */
public class VoxelRasenganModel {
    
    public enum State {
        FORMING, STABILIZING, HELD, STRIKE, DISSIPATING
    }
    
    /**
     * Generate Rasengan model for current state and progress.
     * @param state Current animation state
     * @param progress 0.0 to 1.0 within current state
     * @param rotation Continuous rotation angle (degrees)
     * @return Baked VoxelModel ready for rendering
     */
    public static VoxelModel generate(State state, float progress, float rotation) {
        String id = "rasengan_" + state.name() + "_" + (int)(progress * 10) + "_" + (int)(rotation % 360);
        VoxelModel model = new VoxelModel(id);
        
        float baseRadius = 0.35f;
        float r = 0.3f, g = 0.6f, b = 1.0f, a = 0.9f;
        
        switch (state) {
            case FORMING -> {
                // Small chaotic sphere growing
                float scale = 0.2f + progress * 0.8f;
                float chaos = (1.0f - progress) * 0.15f;
                VoxelModel core = VoxelShapeGenerators.sphere(baseRadius * scale, 6, r, g, b, a * progress);
                // Add random offset cubes for chaos effect
                for (int i = 0; i < 8; i++) {
                    float ox = (float)(Math.random() - 0.5) * chaos * 2;
                    float oy = (float)(Math.random() - 0.5) * chaos * 2;
                    float oz = (float)(Math.random() - 0.5) * chaos * 2;
                    core.addCube(VoxelCube.translucent(ox, oy, oz, 0.08f, 0.08f, 0.08f, r, g, b, a * 0.6f));
                }
                return core;
            }
            case STABILIZING -> {
                // Sphere becoming smooth, rings appearing
                VoxelModel core = VoxelShapeGenerators.sphere(baseRadius, 8, r, g, b, a);
                if (progress > 0.3f) {
                    float ringAlpha = (progress - 0.3f) / 0.7f;
                    VoxelModel ring = VoxelShapeGenerators.ring(baseRadius * 1.2f, baseRadius * 1.35f, 0.03f, 12, 0.6f, 0.8f, 1.0f, ringAlpha * 0.7f);
                    // Merge ring cubes into core
                    for (var cube : ring.getCubes()) core.addCube(cube);
                }
                return core;
            }
            case HELD -> {
                // Full stable rasengan with rotating rings
                VoxelModel core = VoxelShapeGenerators.sphere(baseRadius, 8, r, g, b, a);
                // Inner glow
                VoxelModel glow = VoxelShapeGenerators.sphere(baseRadius * 0.6f, 6, 0.6f, 0.85f, 1.0f, 0.5f);
                for (var cube : glow.getCubes()) core.addCube(cube);
                // Ring 1
                VoxelModel ring1 = VoxelShapeGenerators.ring(baseRadius * 1.2f, baseRadius * 1.35f, 0.03f, 16, 0.6f, 0.8f, 1.0f, 0.7f);
                for (var cube : ring1.getCubes()) core.addCube(cube);
                // Ring 2 (perpendicular approximation via offset cubes)
                VoxelModel ring2 = VoxelShapeGenerators.ring(baseRadius * 1.1f, baseRadius * 1.25f, 0.025f, 14, 0.5f, 0.7f, 1.0f, 0.5f);
                for (var cube : ring2.getCubes()) core.addCube(cube);
                return core;
            }
            case STRIKE -> {
                // Compressed, brighter, trailing
                float compression = 1.0f - progress * 0.3f;
                float brightness = 1.0f + progress * 0.5f;
                VoxelModel core = VoxelShapeGenerators.sphere(baseRadius * compression, 8, 
                    Math.min(1f, r * brightness), Math.min(1f, g * brightness), Math.min(1f, b * brightness), a);
                // Impact flash
                if (progress > 0.7f) {
                    float flashAlpha = (progress - 0.7f) / 0.3f;
                    VoxelModel flash = VoxelShapeGenerators.sphere(baseRadius * 2.0f, 6, 1.0f, 1.0f, 1.0f, flashAlpha * 0.4f);
                    for (var cube : flash.getCubes()) core.addCube(cube);
                }
                return core;
            }
            case DISSIPATING -> {
                // Expanding, fading, breaking apart
                float expansion = 1.0f + progress * 1.5f;
                float fade = 1.0f - progress;
                VoxelModel core = VoxelShapeGenerators.sphere(baseRadius * expansion, 6, r, g, b, a * fade);
                // Scatter particles
                int scatterCount = (int)(progress * 12);
                for (int i = 0; i < scatterCount; i++) {
                    float angle = (i / 12.0f) * (float)(Math.PI * 2);
                    float dist = baseRadius * expansion * (1.0f + progress);
                    float sx = (float)Math.cos(angle) * dist;
                    float sy = (float)(Math.random() - 0.5) * dist * 0.5f;
                    float sz = (float)Math.sin(angle) * dist;
                    core.addCube(VoxelCube.translucent(sx, sy, sz, 0.06f, 0.06f, 0.06f, r, g, b, fade * 0.5f));
                }
                return core;
            }
        }
        return VoxelShapeGenerators.sphere(baseRadius, 6, r, g, b, a);
    }
}
'@
Write-SafeFile (Join-Path $clientVfxDir "models\VoxelRasenganModel.java") $rasenganModel

# New RasenganHandRenderer using voxel system
$rasenganRenderer = @'
package com.example.shinobicore.entity;

import com.example.shinobicore.client.vfx.VoxelModel;
import com.example.shinobicore.client.vfx.VoxelRenderManager;
import com.example.shinobicore.client.vfx.models.VoxelRasenganModel;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.render.entity.EntityRenderer;
import net.minecraft.client.render.entity.EntityRendererFactory;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.RotationAxis;

/**
 * S5-01: Voxel Rasengan renderer replacing old 2D quad renderer.
 * Uses VoxelRenderManager for LOD/culling and VoxelMeshCache for performance.
 */
public class RasenganHandRenderer extends EntityRenderer<RasenganHandEntity> {
    private static final Identifier TEX = new Identifier("textures/misc/white.png");
    
    public RasenganHandRenderer(EntityRendererFactory.Context ctx) { super(ctx); }
    
    @Override
    public void render(RasenganHandEntity entity, float yaw, float tickDelta,
                       MatrixStack matrices, VertexConsumerProvider vc, int light) {
        super.render(entity, yaw, tickDelta, matrices, vc, light);
        
        float age = entity.age + tickDelta;
        float rotation = age * 12f;
        
        // Determine state based on entity age/lifecycle
        VoxelRasenganModel.State state;
        float stateProgress;
        
        if (entity.age < 20) {
            state = VoxelRasenganModel.State.FORMING;
            stateProgress = entity.age / 20f;
        } else if (entity.age < 60) {
            state = VoxelRasenganModel.State.STABILIZING;
            stateProgress = (entity.age - 20) / 40f;
        } else if (entity.age < 500) {
            state = VoxelRasenganModel.State.HELD;
            stateProgress = ((entity.age - 60) % 100) / 100f; // Cycle for ring rotation
        } else if (entity.age < 560) {
            state = VoxelRasenganModel.State.DISSIPATING;
            stateProgress = (entity.age - 500) / 60f;
        } else {
            state = VoxelRasenganModel.State.DISSIPATING;
            stateProgress = 1.0f;
        }
        
        // Pulse effect
        float pulse = 0.95f + 0.05f * (float)Math.sin(age * 0.2);
        
        matrices.push();
        matrices.scale(pulse, pulse, pulse);
        matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(rotation));
        matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(rotation * 0.3f));
        
        VoxelModel model = VoxelRasenganModel.generate(state, stateProgress, rotation);
        
        // Use VoxelRenderManager for optimized rendering
        VoxelRenderManager.renderWithCulling(matrices, vc, model, 
            entity.getPos(), yaw, 0f, 1.0f, light);
        
        matrices.pop();
    }
    
    @Override
    public Identifier getTexture(RasenganHandEntity entity) { return TEX; }
}
'@
Write-SafeFile (Join-Path $entityDir "RasenganHandRenderer.java") $rasenganRenderer

# ============================================================
# S5-03: DOT ZONE ENTITY & RENDERER
# ============================================================
Write-Host "[S5-03] Creating Dot Zone Entity & Renderer..." -ForegroundColor Yellow

$dotZoneEntity = @'
package com.example.shinobicore.entity;

import net.minecraft.entity.Entity;
import net.minecraft.entity.EntityType;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.data.DataTracker;
import net.minecraft.entity.data.TrackedData;
import net.minecraft.entity.data.TrackedDataHandlerRegistry;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Box;
import net.minecraft.world.World;
import java.util.UUID;

/**
 * S5-03: Server-side DoT zone entity.
 * Created by Rasenshuriken impact and other area effects.
 * Deals periodic damage to enemies within radius.
 */
public class DotZoneEntity extends Entity {
    private static final TrackedData<Float> RADIUS = DataTracker.registerData(DotZoneEntity.class, TrackedDataHandlerRegistry.FLOAT);
    private static final TrackedData<Float> DAMAGE_PER_TICK = DataTracker.registerData(DotZoneEntity.class, TrackedDataHandlerRegistry.FLOAT);
    private static final TrackedData<Integer> DURATION_TICKS = DataTracker.registerData(DotZoneEntity.class, TrackedDataHandlerRegistry.INTEGER);
    private static final TrackedData<String> ELEMENT = DataTracker.registerData(DotZoneEntity.class, TrackedDataHandlerRegistry.STRING);
    
    private UUID ownerId;
    private int ticksActive = 0;
    private int tickInterval = 10; // Damage every 10 ticks (0.5s)
    
    public DotZoneEntity(EntityType<?> type, World world) { super(type, world); }
    
    public DotZoneEntity(World world, LivingEntity owner, double x, double y, double z,
                         float radius, float damagePerTick, int durationTicks, String element) {
        super(ModEntities.DOT_ZONE, world);
        this.ownerId = owner.getUuid();
        this.setPosition(x, y, z);
        this.dataTracker.set(RADIUS, radius);
        this.dataTracker.set(DAMAGE_PER_TICK, damagePerTick);
        this.dataTracker.set(DURATION_TICKS, durationTicks);
        this.dataTracker.set(ELEMENT, element != null ? element : "wind");
    }
    
    @Override
    protected void initDataTracker() {
        this.dataTracker.startTracking(RADIUS, 5.0f);
        this.dataTracker.startTracking(DAMAGE_PER_TICK, 2.0f);
        this.dataTracker.startTracking(DURATION_TICKS, 100);
        this.dataTracker.startTracking(ELEMENT, "wind");
    }
    
    public float getRadius() { return this.dataTracker.get(RADIUS); }
    public float getDamagePerTick() { return this.dataTracker.get(DAMAGE_PER_TICK); }
    public int getDurationTicks() { return this.dataTracker.get(DURATION_TICKS); }
    public String getElement() { return this.dataTracker.get(ELEMENT); }
    public float getProgress() { return Math.min(1f, (float)ticksActive / getDurationTicks()); }
    public Entity getOwner() {
        return ownerId == null ? null : getWorld().getPlayerByUuid(ownerId);
    }
    
    @Override
    public void tick() {
        super.tick();
        ticksActive++;
        
        if (ticksActive >= getDurationTicks()) {
            discard();
            return;
        }
        
        // Server-side damage logic
        if (!getWorld().isClient && ticksActive % tickInterval == 0) {
            float radius = getRadius();
            float damage = getDamagePerTick();
            Box aoe = new Box(getPos(), getPos()).expand(radius);
            
            for (Entity e : getWorld().getOtherEntities(this, aoe)) {
                if (e instanceof LivingEntity liv) {
                    // Don't damage owner or allies
                    if (ownerId != null && liv.getUuid().equals(ownerId)) continue;
                    
                    liv.damage(getDamageSources().magic(), damage);
                    // Apply element-specific effects
                    String elem = getElement();
                    if ("wind".equals(elem)) {
                        // Wind shreds: slowness + weakness
                        liv.addStatusEffect(new net.minecraft.entity.effect.StatusEffectInstance(
                            net.minecraft.entity.effect.StatusEffects.SLOWNESS, 30, 1, false, false));
                    } else if ("fire".equals(elem)) {
                        liv.setOnFireFor(2);
                    }
                }
            }
        }
        
        // Zero velocity - zone stays in place
        setVelocity(0, 0, 0);
    }
    
    @Override
    protected void readCustomDataFromNbt(NbtCompound nbt) {
        this.dataTracker.set(RADIUS, nbt.getFloat("Radius"));
        this.dataTracker.set(DAMAGE_PER_TICK, nbt.getFloat("Damage"));
        this.dataTracker.set(DURATION_TICKS, nbt.getInt("Duration"));
        this.dataTracker.set(ELEMENT, nbt.getString("Element"));
        ticksActive = nbt.getInt("TicksActive");
        if (nbt.containsUuid("OwnerUUID")) ownerId = nbt.getUuid("OwnerUUID");
    }
    
    @Override
    protected void writeCustomDataToNbt(NbtCompound nbt) {
        nbt.putFloat("Radius", getRadius());
        nbt.putFloat("Damage", getDamagePerTick());
        nbt.putInt("Duration", getDurationTicks());
        nbt.putString("Element", getElement());
        nbt.putInt("TicksActive", ticksActive);
        if (ownerId != null) nbt.putUuid("OwnerUUID", ownerId);
    }
}
'@
Write-SafeFile (Join-Path $entityDir "DotZoneEntity.java") $dotZoneEntity

$dotZoneRenderer = @'
package com.example.shinobicore.entity;

import com.example.shinobicore.client.vfx.VoxelModel;
import com.example.shinobicore.client.vfx.VoxelRenderManager;
import com.example.shinobicore.client.vfx.VoxelShapeGenerators;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.render.entity.EntityRenderer;
import net.minecraft.client.render.entity.EntityRendererFactory;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.RotationAxis;

/**
 * S5-03: Voxel renderer for DoT zones.
 * Renders as expanding/fading dome or vortex depending on element.
 */
public class DotZoneRenderer extends EntityRenderer<DotZoneEntity> {
    private static final Identifier TEX = new Identifier("textures/misc/white.png");
    
    public DotZoneRenderer(EntityRendererFactory.Context ctx) { super(ctx); }
    
    @Override
    public void render(DotZoneEntity entity, float yaw, float tickDelta,
                       MatrixStack matrices, VertexConsumerProvider vc, int light) {
        super.render(entity, yaw, tickDelta, matrices, vc, light);
        
        float radius = entity.getRadius();
        float progress = entity.getProgress();
        String element = entity.getElement();
        float age = entity.age + tickDelta;
        
        // Fade out in last 30% of lifetime
        float alpha = progress > 0.7f ? (1.0f - progress) / 0.3f : 1.0f;
        alpha *= 0.6f; // Base transparency
        
        // Element colors
        float r, g, b;
        switch (element) {
            case "fire" -> { r = 1.0f; g = 0.4f; b = 0.1f; }
            case "water" -> { r = 0.2f; g = 0.5f; b = 1.0f; }
            case "lightning" -> { r = 1.0f; g = 1.0f; b = 0.3f; }
            case "earth" -> { r = 0.7f; g = 0.5f; b = 0.2f; }
            default -> { r = 0.5f; g = 0.8f; b = 1.0f; } // wind
        }
        
        matrices.push();
        
        // Expand animation at start
        float scale = progress < 0.1f ? progress / 0.1f : 1.0f;
        matrices.scale(scale, scale, scale);
        
        // Rotation for vortex effect
        matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(age * 3f));
        
        // Generate dome/vortex model
        VoxelModel model;
        if ("wind".equals(element)) {
            // Vortex: ring stack
            model = VoxelShapeGenerators.ring(radius * 0.8f, radius, 0.15f, 16, r, g, b, alpha);
            // Add inner turbulence
            VoxelModel inner = VoxelShapeGenerators.sphere(radius * 0.4f, 6, r, g, b, alpha * 0.4f);
            for (var cube : inner.getCubes()) model.addCube(cube);
        } else {
            // Dome for other elements
            model = VoxelShapeGenerators.sphere(radius, 8, r, g, b, alpha * 0.3f);
            // Outer shell ring
            VoxelModel shell = VoxelShapeGenerators.ring(radius * 0.9f, radius, 0.08f, 20, r, g, b, alpha);
            for (var cube : shell.getCubes()) model.addCube(cube);
        }
        
        VoxelRenderManager.renderWithCulling(matrices, vc, model,
            entity.getPos(), yaw, 0f, 1.0f, light);
        
        matrices.pop();
    }
    
    @Override
    public Identifier getTexture(DotZoneEntity entity) { return TEX; }
}
'@
Write-SafeFile (Join-Path $entityDir "DotZoneRenderer.java") $dotZoneRenderer

# ============================================================
# S5-02: RASENSHURIKEN VOXEL MODEL & UPDATED BEHAVIOR
# ============================================================
Write-Host "[S5-02] Creating Voxel Rasenshuriken Model..." -ForegroundColor Yellow

$rasenshurikenModel = @'
package com.example.shinobicore.client.vfx.models;

import com.example.shinobicore.client.vfx.VoxelCube;
import com.example.shinobicore.client.vfx.VoxelModel;
import com.example.shinobicore.client.vfx.VoxelShapeGenerators;

/**
 * S5-02: Voxel Rasenshuriken model.
 * Central sphere + 4 rotating wind blades.
 */
public class VoxelRasenshurikenModel {
    
    /**
     * Generate Rasenshuriken model.
     * @param rotation Blade rotation angle (degrees)
     * @param chargeProgress 0.0 (forming) to 1.0 (full)
     * @return VoxelModel ready for rendering
     */
    public static VoxelModel generate(float rotation, float chargeProgress) {
        String id = "rasenshuriken_" + (int)(rotation % 360) + "_" + (int)(chargeProgress * 10);
        VoxelModel model = new VoxelModel(id);
        
        float r = 0.4f, g = 0.75f, b = 1.0f, a = 0.85f;
        float coreRadius = 0.3f * chargeProgress;
        
        if (coreRadius < 0.05f) coreRadius = 0.05f;
        
        // Central sphere (mini-rasengan core)
        VoxelModel core = VoxelShapeGenerators.sphere(coreRadius, 8, 0.5f, 0.8f, 1.0f, a);
        for (var cube : core.getCubes()) model.addCube(cube);
        
        // Inner glow
        VoxelModel glow = VoxelShapeGenerators.sphere(coreRadius * 0.5f, 6, 0.7f, 0.9f, 1.0f, 0.5f);
        for (var cube : glow.getCubes()) model.addCube(cube);
        
        // 4 Wind Blades
        float bladeLength = 1.2f * chargeProgress;
        float bladeWidth = 0.25f * chargeProgress;
        float bladeThickness = 0.06f;
        
        if (bladeLength < 0.1f) return model;
        
        for (int i = 0; i < 4; i++) {
            float bladeAngle = (float)(i * Math.PI / 2.0);
            float cos = (float)Math.cos(bladeAngle);
            float sin = (float)Math.sin(bladeAngle);
            
            // Each blade is a tapered shape made of segments
            int segments = 6;
            for (int s = 0; s < segments; s++) {
                float t = (s + 0.5f) / segments;
                float dist = coreRadius + t * bladeLength;
                float segWidth = bladeWidth * (1.0f - t * 0.6f); // Taper towards tip
                
                float bx = cos * dist;
                float bz = sin * dist;
                
                model.addCube(new VoxelCube(bx, 0, bz, 
                    segWidth, bladeThickness, segWidth, 
                    r, g, b, a * (1.0f - t * 0.3f), false, false));
            }
        }
        
        // Outer ring (torus approximation)
        if (chargeProgress > 0.5f) {
            float ringAlpha = (chargeProgress - 0.5f) * 2.0f;
            VoxelModel ring = VoxelShapeGenerators.ring(
                bladeLength * 0.7f, bladeLength * 0.85f, 0.04f, 20, 
                r, g, b, ringAlpha * 0.5f);
            for (var cube : ring.getCubes()) model.addCube(cube);
        }
        
        return model;
    }
}
'@
Write-SafeFile (Join-Path $clientVfxDir "models\VoxelRasenshurikenModel.java") $rasenshurikenModel

# Updated RasenshurikenRenderer
$rasenshurikenRenderer = @'
package com.example.shinobicore.entity;

import com.example.shinobicore.client.vfx.VoxelModel;
import com.example.shinobicore.client.vfx.VoxelRenderManager;
import com.example.shinobicore.client.vfx.models.VoxelRasenshurikenModel;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.render.entity.EntityRenderer;
import net.minecraft.client.render.entity.EntityRendererFactory;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.RotationAxis;

/**
 * S5-02: Voxel Rasenshuriken renderer replacing old 2D quad renderer.
 */
public class RasenshurikenRenderer extends EntityRenderer<RasenshurikenEntity> {
    private static final Identifier TEX = new Identifier("textures/misc/white.png");
    
    public RasenshurikenRenderer(EntityRendererFactory.Context ctx) { super(ctx); }
    
    @Override
    public void render(RasenshurikenEntity entity, float yaw, float tickDelta,
                       MatrixStack matrices, VertexConsumerProvider vc, int light) {
        super.render(entity, yaw, tickDelta, matrices, vc, light);
        
        float age = entity.age + tickDelta;
        float rotation = age * 20f; // Fast spin
        
        // Charge progress: grows over first 60 ticks when held
        float chargeProgress;
        if (!entity.isLaunched()) {
            chargeProgress = Math.min(1.0f, entity.age / 60f);
        } else {
            chargeProgress = 1.0f;
        }
        
        matrices.push();
        matrices.translate(0, 0.3, 0);
        
        // Spin around Y axis
        matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(rotation));
        // Slight tilt for visual interest
        matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(5f));
        
        VoxelModel model = VoxelRasenshurikenModel.generate(rotation, chargeProgress);
        
        VoxelRenderManager.renderWithCulling(matrices, vc, model,
            entity.getPos(), yaw, 0f, 1.0f, light);
        
        matrices.pop();
    }
    
    @Override
    public Identifier getTexture(RasenshurikenEntity entity) { return TEX; }
}
'@
Write-SafeFile (Join-Path $entityDir "RasenshurikenRenderer.java") $rasenshurikenRenderer

# ============================================================
# REGISTRATION: ModEntities + ShinobiCoreClient
# ============================================================
Write-Host "[REG] Registering new entities and renderers..." -ForegroundColor Yellow

# Register DOT_ZONE entity type
$modEntitiesFile = Join-Path $entityDir "ModEntities.java"
$dotZoneReg = @"

    public static final EntityType<com.example.shinobicore.entity.DotZoneEntity> DOT_ZONE = Registry.register(
            Registries.ENTITY_TYPE,
            new Identifier(ShinobiCore.MOD_ID, "dot_zone"),
            FabricEntityTypeBuilder.<com.example.shinobicore.entity.DotZoneEntity>create(SpawnGroup.MISC, com.example.shinobicore.entity.DotZoneEntity::new)
                .dimensions(EntityDimensions.fixed(1.0f, 1.0f))
                .trackRangeChunks(64)
                .trackedUpdateRate(4)
                .build()
    );
"@
Patch-SafeFile $modEntitiesFile "public static void register()" "$dotZoneReg`n`n    public static void register()"

# Register renderer in ShinobiCoreClient
$clientFile = Join-Path $srcBase "client\ShinobiCoreClient.java"
$rendererReg = @"
EntityRendererRegistry.register(ModEntities.RASENSHURIKEN, com.example.shinobicore.entity.RasenshurikenRenderer::new);
        EntityRendererRegistry.register(ModEntities.RASENGAN_HAND, com.example.shinobicore.entity.RasenganHandRenderer::new);
        EntityRendererRegistry.register(ModEntities.DOT_ZONE, com.example.shinobicore.entity.DotZoneRenderer::new);
"@
$oldRendererReg = @"
EntityRendererRegistry.register(ModEntities.RASENSHURIKEN, com.example.shinobicore.entity.RasenshurikenRenderer::new);
        EntityRendererRegistry.register(ModEntities.RASENGAN_HAND, com.example.shinobicore.entity.RasenganHandRenderer::new);
"@
Patch-SafeFile $clientFile $oldRendererReg $rendererReg

# ============================================================
# UPDATE RasenshurikenBehavior to spawn DotZone on impact
# ============================================================
Write-Host "[S5-02] Updating RasenshurikenBehavior for DoT zone spawn..." -ForegroundColor Yellow

$behaviorFile = Join-Path $jutsuCustomDir "RasenshurikenBehavior.java"
if (Test-Path $behaviorFile) {
    # The behavior already has createExpandingSphere via TickScheduler
    # We need to add DotZoneEntity spawn alongside it
    $oldImpact = "createExpandingSphere();"
    $newImpact = @"
createExpandingSphere();
            // S5-03: Spawn DoT zone at impact point
            if (this.getWorld() instanceof ServerWorld sw) {
                com.example.shinobicore.entity.DotZoneEntity zone = new com.example.shinobicore.entity.DotZoneEntity(
                    sw, player, this.getX(), this.getY(), this.getZ(),
                    8.0f, 3.0f, 100, "wind"
                );
                sw.spawnEntity(zone);
            }
"@
    Patch-SafeFile $behaviorFile $oldImpact $newImpact
} else {
    Write-Host "  [WARN] RasenshurikenBehavior.java not found - DoT zone must be added manually" -ForegroundColor Yellow
}

# ============================================================
# BUILD VERIFICATION
# ============================================================
Write-Host ""
Write-Host "[BUILD] Verifying compilation..." -ForegroundColor Yellow
Push-Location $root
try {
    $buildOut = & ".\gradlew.bat" build 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [PASS] Build successful!" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Build failed" -ForegroundColor Red
        $buildOut | Select-Object -Last 20 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    }
} finally { Pop-Location }

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Green
Write-Host "  SPRINT 5 PHASE A COMPLETE" -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Created files:" -ForegroundColor White
Write-Host "  - client/vfx/models/VoxelRasenganModel.java (S5-01: 5-state voxel rasengan)" -ForegroundColor Cyan
Write-Host "  - client/vfx/models/VoxelRasenshurikenModel.java (S5-02: sphere + 4 blades)" -ForegroundColor Cyan
Write-Host "  - entity/DotZoneEntity.java (S5-03: server-side DoT zone)" -ForegroundColor Cyan
Write-Host "  - entity/DotZoneRenderer.java (S5-03: voxel dome/vortex renderer)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Updated files:" -ForegroundColor White
Write-Host "  - entity/RasenganHandRenderer.java (S5-01: voxel replacement)" -ForegroundColor Cyan
Write-Host "  - entity/RasenshurikenRenderer.java (S5-02: voxel replacement)" -ForegroundColor Cyan
Write-Host "  - entity/ModEntities.java (DOT_ZONE registration)" -ForegroundColor Cyan
Write-Host "  - client/ShinobiCoreClient.java (renderer registration)" -ForegroundColor Cyan
Write-Host "  - jutsu/custom/RasenshurikenBehavior.java (DoT zone spawn on impact)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next: S5-04 (Dragon Segments) | S5-05 (Custom Particles)" -ForegroundColor Yellow
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcBase = Join-Path $root "src\main\java\com\example\shinobicore"

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
    if ($c.Contains($newN)) { Write-Host "  [SKIP] already applied: $(Split-Path $p -Leaf)" -ForegroundColor Yellow; return $true }
    if (-not $c.Contains($oldN)) { Write-Host "  [FAIL] pattern not found: $(Split-Path $p -Leaf)" -ForegroundColor Red; return $false }
    $c = $c.Replace($oldN, $newN)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "  [OK] $(Split-Path $p -Leaf)" -ForegroundColor Green
    return $true
}

Write-Host ""
Write-Host "=== FIX: S5 Phase B Build Errors ===" -ForegroundColor Cyan

# ============================================================
# 1. FIX DragonEntity.java (Lossy conversion double->float)
# ============================================================
Write-Host "[1/3] Fixing DragonEntity.java (type casting)..." -ForegroundColor Yellow

$dragonEntityCode = @'
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
    private static final TrackedData<String> ELEMENT = DataTracker.registerData(DragonEntity.class, TrackedDataHandlerRegistry.STRING);
    private static final TrackedData<Float> DAMAGE = DataTracker.registerData(DragonEntity.class, TrackedDataHandlerRegistry.FLOAT);
    private static final TrackedData<Integer> SEGMENTS = DataTracker.registerData(DragonEntity.class, TrackedDataHandlerRegistry.INTEGER);
    private static final TrackedData<Float> RADIUS = DataTracker.registerData(DragonEntity.class, TrackedDataHandlerRegistry.FLOAT);

    private UUID ownerId;
    public int age = 0;
    private static final int MAX_LIFETIME = 140;

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
        this.dataTracker.set(SEGMENTS, Math.min(segments, 12));
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

        // FIX: Explicit cast to float to avoid lossy conversion error
        float wave = (float) Math.sin(age * 0.15) * 0.3f;
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
Write-SafeFile (Join-Path $srcBase "entity\DragonEntity.java") $dragonEntityCode

# ============================================================
# 2. PATCH WaterDragonBehavior.java (Exact pattern from dump)
# ============================================================
Write-Host "[2/3] Patching WaterDragonBehavior.java..." -ForegroundColor Yellow

$waterOld = @"
NinjaProjectileEntity proj = new NinjaProjectileEntity(
world, player, look.multiply(speed), damage, radius, "water", "water_dragon", lifetime
);
proj.setPosition(eye.x, eye.y - 0.2, eye.z);
proj.setHasGravity(false);
proj.setPierceCount(3);
world.spawnEntity(proj);
"@

$waterNew = @"
// S5-04: Segmented water dragon
com.example.shinobicore.entity.DragonEntity dragon = new com.example.shinobicore.entity.DragonEntity(
world, player, look.multiply(speed), "water", damage, radius, 8
);
world.spawnEntity(dragon);
"@

Patch-SafeFile (Join-Path $srcBase "jutsu\custom\WaterDragonBehavior.java") $waterOld $waterNew

# ============================================================
# 3. PATCH FireDragonBehavior.java (Exact pattern from dump)
# ============================================================
Write-Host "[3/3] Patching FireDragonBehavior.java..." -ForegroundColor Yellow

$fireOld = @"
NinjaProjectileEntity proj = new NinjaProjectileEntity(
world, player, look.multiply(speed), damage, radius, "flame", "fire_dragon", lifetime
);
proj.setPosition(eye.x, eye.y - 0.2, eye.z);
proj.setHasGravity(false);
proj.setPierceCount(5);
world.spawnEntity(proj);
"@

$fireNew = @"
// S5-04: Segmented fire dragon
com.example.shinobicore.entity.DragonEntity dragon = new com.example.shinobicore.entity.DragonEntity(
world, player, look.multiply(speed), "fire", damage, radius, 8
);
world.spawnEntity(dragon);
"@

Patch-SafeFile (Join-Path $srcBase "jutsu\custom\FireDragonBehavior.java") $fireOld $fireNew

# ============================================================
# BUILD
# ============================================================
Write-Host ""
Write-Host "=== BUILD ===" -ForegroundColor Cyan
Push-Location $root
try {
    $out = & ".\gradlew.bat" build 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [PASS] Build successful!" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Build failed" -ForegroundColor Red
        $out | Select-Object -Last 15 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    }
} finally { Pop-Location }
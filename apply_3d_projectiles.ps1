$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main"
$javaBase = "$base\java\com\example\shinobicore"
$resBase = "$base\resources"

function Write-File($p, $c) {
    $dir = [System.IO.Path]::GetDirectoryName($p)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] $p"
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗"
Write-Host "║   RASENGAN + RASENSHURIKEN 3D PROJECTILE SYSTEM     ║"
Write-Host "╚══════════════════════════════════════════════════════╝"
Write-Host ""

# ============================================================
# SECTION 1: RASENGAN ENTITY (3D projectile)
# ============================================================
Write-Host "--- Creating RasenganEntity ---"
Write-File "$javaBase\entity\RasenganEntity.java" @'
package com.example.shinobicore.entity;

import net.minecraft.entity.Entity;
import net.minecraft.entity.EntityType;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.data.DataTracker;
import net.minecraft.entity.data.TrackedData;
import net.minecraft.entity.data.TrackedDataHandlerRegistry;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.hit.HitResult;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.RaycastContext;
import net.minecraft.world.World;
import java.util.UUID;

public class RasenganEntity extends Entity {
    private static final TrackedData<Float> DAMAGE = DataTracker.registerData(RasenganEntity.class, TrackedDataHandlerRegistry.FLOAT);
    private UUID ownerId;
    private int age = 0;
    private static final int MAX_AGE = 50;

    public RasenganEntity(EntityType<?> type, World world) {
        super(type, world);
    }

    public RasenganEntity(World world, LivingEntity owner, Vec3d velocity, float damage) {
        super(ModEntities.RASENGAN_PROJECTILE, world);
        this.ownerId = owner.getUuid();
        this.setPosition(owner.getX() + owner.getRotationVector().x * 0.8,
                         owner.getEyeY() - 0.3,
                         owner.getZ() + owner.getRotationVector().z * 0.8);
        this.setVelocity(velocity);
        this.velocityDirty = true;
        this.dataTracker.set(DAMAGE, damage);
    }

    @Override
    protected void initDataTracker() {
        this.dataTracker.startTracking(DAMAGE, 32f);
    }

    public float getDamage() { return this.dataTracker.get(DAMAGE); }

    @Override
    public void tick() {
        super.tick();
        age++;
        Vec3d vel = this.getVelocity();
        Vec3d startPos = this.getPos();
        Vec3d endPos = startPos.add(vel);

        // Block collision
        HitResult blockHit = this.getWorld().raycast(new RaycastContext(
            startPos, endPos, RaycastContext.ShapeType.COLLIDER,
            RaycastContext.FluidHandling.NONE, this));

        // Entity collision
        LivingEntity hitEntity = null;
        double closestDist = Double.MAX_VALUE;
        Box searchBox = this.getBoundingBox().stretch(vel).expand(0.5);
        for (Entity entity : this.getWorld().getOtherEntities(this, searchBox)) {
            if (entity instanceof LivingEntity living && !living.getUuid().equals(this.ownerId)) {
                var opt = entity.getBoundingBox().expand(0.4).raycast(startPos, endPos);
                if (opt.isPresent()) {
                    double d = startPos.squaredDistanceTo(opt.get());
                    if (d < closestDist) { closestDist = d; hitEntity = living; }
                }
            }
        }

        boolean explode = hitEntity != null
            || blockHit.getType() == HitResult.Type.BLOCK
            || age >= MAX_AGE;

        if (explode) {
            float damage = this.dataTracker.get(DAMAGE);
            float radius = 3.0f;
            // AOE damage + knockback
            for (Entity entity : this.getWorld().getOtherEntities(this,
                    this.getBoundingBox().expand(radius))) {
                if (entity instanceof LivingEntity living && !living.getUuid().equals(this.ownerId)) {
                    living.damage(this.getDamageSources().magic(), damage);
                    Vec3d kb = living.getPos().subtract(this.getPos()).normalize().multiply(1.8);
                    living.addVelocity(kb.x, 0.4, kb.z);
                    living.velocityModified = true;
                }
            }
            // Explosion particles
            if (this.getWorld() instanceof ServerWorld sw) {
                for (int i = 0; i < 80; i++) {
                    double a = (i / 80.0) * Math.PI * 2;
                    double r = radius * (0.3 + Math.random() * 0.7);
                    sw.spawnParticles(ParticleTypes.SOUL_FIRE_FLAME,
                        this.getX() + Math.cos(a) * r,
                        this.getY() + Math.random() * 1.5,
                        this.getZ() + Math.sin(a) * r,
                        1, (Math.random()-0.5)*0.2, Math.random()*0.2, (Math.random()-0.5)*0.2, 0.05);
                }
                for (int i = 0; i < 30; i++) {
                    sw.spawnParticles(ParticleTypes.END_ROD,
                        this.getX() + (Math.random()-0.5)*radius*2,
                        this.getY() + Math.random()*2,
                        this.getZ() + (Math.random()-0.5)*radius*2,
                        1, 0, 0.08, 0, 0.03);
                }
                sw.spawnParticles(ParticleTypes.EXPLOSION, this.getX(), this.getY()+0.5, this.getZ(),
                    3, 0.3, 0.3, 0.3, 0.02);
            }
            this.discard();
            return;
        }

        // Move
        this.setPosition(this.getX() + vel.x, this.getY() + vel.y, this.getZ() + vel.z);

        // Trail particles
        if (this.getWorld() instanceof ServerWorld sw) {
            for (int i = 0; i < 4; i++) {
                sw.spawnParticles(ParticleTypes.SOUL_FIRE_FLAME,
                    this.getX() + (Math.random()-0.5)*0.4,
                    this.getY() + (Math.random()-0.5)*0.4,
                    this.getZ() + (Math.random()-0.5)*0.4,
                    1, 0.01, 0.01, 0.01, 0.01);
            }
            if (age % 2 == 0) {
                sw.spawnParticles(ParticleTypes.END_ROD,
                    this.getX(), this.getY(), this.getZ(),
                    1, 0.05, 0.05, 0.05, 0.01);
            }
        }
    }

    @Override
    protected void readCustomDataFromNbt(NbtCompound nbt) {
        this.dataTracker.set(DAMAGE, nbt.getFloat("Damage"));
        if (nbt.containsUuid("OwnerUUID")) ownerId = nbt.getUuid("OwnerUUID");
    }

    @Override
    protected void writeCustomDataToNbt(NbtCompound nbt) {
        nbt.putFloat("Damage", this.dataTracker.get(DAMAGE));
        if (ownerId != null) nbt.putUuid("OwnerUUID", ownerId);
    }
}
'@

# ============================================================
# SECTION 2: RASENSHURIKEN ENTITY (3D projectile)
# ============================================================
Write-Host "--- Creating RasenshurikenEntity ---"
Write-File "$javaBase\entity\RasenshurikenEntity.java" @'
package com.example.shinobicore.entity;

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
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.hit.HitResult;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.RaycastContext;
import net.minecraft.world.World;
import java.util.UUID;

public class RasenshurikenEntity extends Entity {
    private static final TrackedData<Float> DAMAGE = DataTracker.registerData(RasenshurikenEntity.class, TrackedDataHandlerRegistry.FLOAT);
    private UUID ownerId;
    private int age = 0;
    private boolean expanded = false;
    private int expandTicks = 0;
    private static final int TRAVEL_TICKS = 45;
    private static final int EXPAND_DURATION = 70;

    public RasenshurikenEntity(EntityType<?> type, World world) {
        super(type, world);
    }

    public RasenshurikenEntity(World world, LivingEntity owner, Vec3d velocity, float damage) {
        super(ModEntities.RASENSHURIKEN_PROJECTILE, world);
        this.ownerId = owner.getUuid();
        this.setPosition(owner.getX() + owner.getRotationVector().x * 0.8,
                         owner.getEyeY() + 0.5,
                         owner.getZ() + owner.getRotationVector().z * 0.8);
        this.setVelocity(velocity);
        this.velocityDirty = true;
        this.dataTracker.set(DAMAGE, damage);
    }

    @Override
    protected void initDataTracker() {
        this.dataTracker.startTracking(DAMAGE, 45f);
    }

    public float getDamage() { return this.dataTracker.get(DAMAGE); }

    @Override
    public void tick() {
        super.tick();
        age++;

        if (!expanded) {
            // === TRAVEL PHASE ===
            Vec3d vel = this.getVelocity();
            Vec3d startPos = this.getPos();
            Vec3d endPos = startPos.add(vel);

            // Hit entities during travel (minor damage)
            Box searchBox = this.getBoundingBox().stretch(vel).expand(2.0);
            for (Entity entity : this.getWorld().getOtherEntities(this, searchBox)) {
                if (entity instanceof LivingEntity living && !living.getUuid().equals(this.ownerId)) {
                    float dmg = this.dataTracker.get(DAMAGE) * 0.15f;
                    living.damage(this.getDamageSources().magic(), dmg);
                    Vec3d kb = living.getPos().subtract(this.getPos()).normalize().multiply(0.4);
                    living.addVelocity(kb.x, 0.1, kb.z);
                    living.velocityModified = true;
                }
            }

            // Block collision or max travel
            HitResult blockHit = this.getWorld().raycast(new RaycastContext(
                startPos, endPos, RaycastContext.ShapeType.COLLIDER,
                RaycastContext.FluidHandling.NONE, this));

            if (blockHit.getType() == HitResult.Type.BLOCK || age >= TRAVEL_TICKS) {
                expanded = true;
                expandTicks = 0;
                this.setVelocity(Vec3d.ZERO);
            } else {
                this.setPosition(this.getX() + vel.x, this.getY() + vel.y, this.getZ() + vel.z);
            }

            // Travel particles — swirling wind
            if (this.getWorld() instanceof ServerWorld sw) {
                float rot = age * 0.4f;
                for (int i = 0; i < 6; i++) {
                    double a = rot + (i / 6.0) * Math.PI * 2;
                    double r = 1.0;
                    sw.spawnParticles(ParticleTypes.CLOUD,
                        this.getX() + Math.cos(a) * r,
                        this.getY() + Math.sin(a * 1.5) * 0.3,
                        this.getZ() + Math.sin(a) * r,
                        1, 0.04, 0.04, 0.04, 0.02);
                }
                if (age % 2 == 0) {
                    sw.spawnParticles(ParticleTypes.END_ROD,
                        this.getX(), this.getY(), this.getZ(),
                        2, 0.08, 0.08, 0.08, 0.01);
                }
            }
        } else {
            // === EXPAND/AOE PHASE ===
            expandTicks++;
            float damage = this.dataTracker.get(DAMAGE);
            float maxRadius = 10f;
            float radius = maxRadius * Math.min(1f, expandTicks / 12f);

            // Damage tick every 5 ticks
            if (expandTicks % 5 == 0) {
                for (Entity entity : this.getWorld().getOtherEntities(this,
                        this.getBoundingBox().expand(radius))) {
                    if (entity instanceof LivingEntity living && !living.getUuid().equals(this.ownerId)) {
                        living.damage(this.getDamageSources().magic(), damage * 0.08f);
                        living.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, 40, 2, false, false));
                        living.addStatusEffect(new StatusEffectInstance(StatusEffects.WEAKNESS, 40, 1, false, false));
                        Vec3d pull = this.getPos().subtract(living.getPos()).normalize().multiply(0.15);
                        living.addVelocity(pull.x, 0, pull.z);
                        living.velocityModified = true;
                    }
                }
            }

            // Massive AOE particles
            if (this.getWorld() instanceof ServerWorld sw) {
                float rot = expandTicks * 0.15f;
                for (int i = 0; i < 16; i++) {
                    double a = rot + (i / 16.0) * Math.PI * 2;
                    double r = radius * (0.2 + (i % 4) * 0.2);
                    sw.spawnParticles(ParticleTypes.CLOUD,
                        this.getX() + Math.cos(a) * r,
                        this.getY() + Math.random() * 2.5 - 0.5,
                        this.getZ() + Math.sin(a) * r,
                        1, 0.04, 0.08, 0.04, 0.02);
                }
                if (expandTicks % 3 == 0) {
                    for (int i = 0; i < 8; i++) {
                        double a = Math.random() * Math.PI * 2;
                        double r = Math.random() * radius;
                        sw.spawnParticles(ParticleTypes.END_ROD,
                            this.getX() + Math.cos(a) * r,
                            this.getY() + Math.random() * 3 - 0.5,
                            this.getZ() + Math.sin(a) * r,
                            1, 0, 0.04, 0, 0.01);
                    }
                }
            }

            if (expandTicks >= EXPAND_DURATION) {
                this.discard();
            }
        }
    }

    @Override
    protected void readCustomDataFromNbt(NbtCompound nbt) {
        this.dataTracker.set(DAMAGE, nbt.getFloat("Damage"));
        if (nbt.containsUuid("OwnerUUID")) ownerId = nbt.getUuid("OwnerUUID");
    }

    @Override
    protected void writeCustomDataToNbt(NbtCompound nbt) {
        nbt.putFloat("Damage", this.dataTracker.get(DAMAGE));
        if (ownerId != null) nbt.putUuid("OwnerUUID", ownerId);
    }
}
'@

# ============================================================
# SECTION 3: RASENGAN RENDERER (3D sphere model)
# ============================================================
Write-Host "--- Creating RasenganRenderer ---"
Write-File "$javaBase\entity\RasenganRenderer.java" @'
package com.example.shinobicore.entity;

import net.minecraft.client.render.*;
import net.minecraft.client.render.entity.EntityRenderer;
import net.minecraft.client.render.entity.EntityRendererFactory;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.RotationAxis;
import org.joml.Matrix4f;

public class RasenganRenderer extends EntityRenderer<RasenganEntity> {
    private static final Identifier TEX = new Identifier("textures/misc/white.png");

    public RasenganRenderer(EntityRendererFactory.Context ctx) { super(ctx); }

    @Override
    public void render(RasenganEntity entity, float yaw, float tickDelta,
                       MatrixStack matrices, VertexConsumerProvider vc, int light) {
        super.render(entity, yaw, tickDelta, matrices, vc, light);
        matrices.push();

        float age = entity.age + tickDelta;
        float pulse = 0.45f + 0.05f * (float)Math.sin(age * 0.3);

        // Spin animation
        matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(age * 12f));
        matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(age * 8f));

        VertexConsumer consumer = vc.getBuffer(RenderLayer.getEntityTranslucent(TEX));

        // === CORE SPHERE: multiple overlapping quads at different angles ===
        // Layer 1: inner bright core
        renderSphereLayer(matrices, consumer, light, pulse * 0.6f,
            0.3f, 0.6f, 1.0f, 0.9f);

        // Layer 2: mid sphere
        renderSphereLayer(matrices, consumer, light, pulse * 0.85f,
            0.2f, 0.5f, 1.0f, 0.6f);

        // Layer 3: outer glow
        renderSphereLayer(matrices, consumer, light, pulse * 1.2f,
            0.4f, 0.7f, 1.0f, 0.25f);

        // === SWIRLING RING around equator ===
        matrices.push();
        matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(age * 20f));
        renderRing(matrices, consumer, light, pulse * 1.0f,
            0.6f, 0.85f, 1.0f, 0.5f);
        matrices.pop();

        // Second ring at 90 degrees
        matrices.push();
        matrices.multiply(RotationAxis.POSITIVE_Z.rotationDegrees(90f));
        matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(-age * 15f));
        renderRing(matrices, consumer, light, pulse * 0.9f,
            0.5f, 0.8f, 1.0f, 0.35f);
        matrices.pop();

        matrices.pop();
    }

    private void renderSphereLayer(MatrixStack matrices, VertexConsumer vc, int light,
                                    float size, float r, float g, float b, float a) {
        // 6 quads forming a rough sphere (cube-ish with rotated faces)
        float h = size;
        Matrix4f m;

        // XY plane
        m = matrices.peek().getPositionMatrix();
        emitQuad(vc, m, -h, -h, 0, h, -h, 0, h, h, 0, -h, h, 0, r, g, b, a, light);

        // XZ plane
        matrices.push();
        matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(90));
        m = matrices.peek().getPositionMatrix();
        emitQuad(vc, m, -h, -h, 0, h, -h, 0, h, h, 0, -h, h, 0, r, g, b, a, light);
        matrices.pop();

        // YZ plane
        matrices.push();
        matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(90));
        m = matrices.peek().getPositionMatrix();
        emitQuad(vc, m, -h, -h, 0, h, -h, 0, h, h, 0, -h, h, 0, r, g, b, a, light);
        matrices.pop();

        // Diagonal 45°
        matrices.push();
        matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(45));
        m = matrices.peek().getPositionMatrix();
        emitQuad(vc, m, -h*0.8f, -h*0.8f, 0, h*0.8f, -h*0.8f, 0, h*0.8f, h*0.8f, 0, -h*0.8f, h*0.8f, 0, r, g, b, a*0.7f, light);
        matrices.pop();

        // Diagonal -45°
        matrices.push();
        matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(-45));
        matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(45));
        m = matrices.peek().getPositionMatrix();
        emitQuad(vc, m, -h*0.7f, -h*0.7f, 0, h*0.7f, -h*0.7f, 0, h*0.7f, h*0.7f, 0, -h*0.7f, h*0.7f, 0, r*0.9f, g*0.9f, b, a*0.5f, light);
        matrices.pop();
    }

    private void renderRing(MatrixStack matrices, VertexConsumer vc, int light,
                            float radius, float r, float g, float b, float a) {
        int segments = 16;
        float thickness = 0.06f;
        Matrix4f m = matrices.peek().getPositionMatrix();

        for (int i = 0; i < segments; i++) {
            float a1 = (float)(i * 2 * Math.PI / segments);
            float a2 = (float)((i + 1) * 2 * Math.PI / segments);

            float x1 = (float)Math.cos(a1) * radius;
            float z1 = (float)Math.sin(a1) * radius;
            float x2 = (float)Math.cos(a2) * radius;
            float z2 = (float)Math.sin(a2) * radius;

            float x1i = (float)Math.cos(a1) * (radius - thickness);
            float z1i = (float)Math.sin(a1) * (radius - thickness);
            float x2i = (float)Math.cos(a2) * (radius - thickness);
            float z2i = (float)Math.sin(a2) * (radius - thickness);

            // Outer face
            vc.vertex(m, x1, -thickness, z1).color(r, g, b, a).texture(0, 0)
                .overlay(OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
            vc.vertex(m, x2, -thickness, z2).color(r, g, b, a).texture(1, 0)
                .overlay(OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
            vc.vertex(m, x2, thickness, z2).color(r, g, b, a).texture(1, 1)
                .overlay(OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
            vc.vertex(m, x1, thickness, z1).color(r, g, b, a).texture(0, 1)
                .overlay(OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
        }
    }

    private void emitQuad(VertexConsumer vc, Matrix4f m,
                           float x1, float y1, float z1,
                           float x2, float y2, float z2,
                           float x3, float y3, float z3,
                           float x4, float y4, float z4,
                           float r, float g, float b, float a, int light) {
        // Front
        v(vc, m, x1, y1, z1, 0, 1, r, g, b, a, light);
        v(vc, m, x2, y2, z2, 1, 1, r, g, b, a, light);
        v(vc, m, x3, y3, z3, 1, 0, r, g, b, a, light);
        v(vc, m, x4, y4, z4, 0, 0, r, g, b, a, light);
        // Back
        v(vc, m, x4, y4, z4, 0, 0, r, g, b, a, light);
        v(vc, m, x3, y3, z3, 1, 0, r, g, b, a, light);
        v(vc, m, x2, y2, z2, 1, 1, r, g, b, a, light);
        v(vc, m, x1, y1, z1, 0, 1, r, g, b, a, light);
    }

    private void v(VertexConsumer vc, Matrix4f m, float x, float y, float z,
                    float u, float t, float r, float g, float b, float a, int light) {
        vc.vertex(m, x, y, z).color(r, g, b, a).texture(u, t)
            .overlay(OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
    }

    @Override
    public Identifier getTexture(RasenganEntity entity) { return TEX; }
}
'@

# ============================================================
# SECTION 4: RASENSHURIKEN RENDERER (3D shuriken model)
# ============================================================
Write-Host "--- Creating RasenshurikenRenderer ---"
Write-File "$javaBase\entity\RasenshurikenRenderer.java" @'
package com.example.shinobicore.entity;

import net.minecraft.client.render.*;
import net.minecraft.client.render.entity.EntityRenderer;
import net.minecraft.client.render.entity.EntityRendererFactory;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.RotationAxis;
import org.joml.Matrix4f;

public class RasenshurikenRenderer extends EntityRenderer<RasenshurikenEntity> {
    private static final Identifier TEX = new Identifier("textures/misc/white.png");

    public RasenshurikenRenderer(EntityRendererFactory.Context ctx) { super(ctx); }

    @Override
    public void render(RasenshurikenEntity entity, float yaw, float tickDelta,
                       MatrixStack matrices, VertexConsumerProvider vc, int light) {
        super.render(entity, yaw, tickDelta, matrices, vc, light);
        matrices.push();

        float age = entity.age + tickDelta;

        // Face the movement direction (flat orientation)
        matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(90));

        // Fast spin
        float spinSpeed = entity.expanded ? 6f : 18f;
        matrices.multiply(RotationAxis.POSITIVE_Z.rotationDegrees(age * spinSpeed));

        VertexConsumer consumer = vc.getBuffer(RenderLayer.getEntityTranslucent(TEX));

        float scale;
        if (entity.expanded) {
            float expandProgress = Math.min(1f, entity.expandTicks / 12f);
            scale = 1.0f + expandProgress * 2.5f; // grows from 1x to 3.5x
        } else {
            scale = 1.0f;
        }

        // Wind colors: white core + green/cyan glow
        float coreR = 0.85f, coreG = 1.0f, coreB = 0.95f;
        float glowR = 0.4f, glowG = 0.9f, glowB = 0.7f;

        // === 4 BLADES ===
        for (int blade = 0; blade < 4; blade++) {
            matrices.push();
            matrices.multiply(RotationAxis.POSITIVE_Z.rotationDegrees(blade * 90f));
            renderBlade(matrices, consumer, light, scale, coreR, coreG, coreB, 0.85f);
            // Glow layer (larger, more transparent)
            renderBlade(matrices, consumer, light, scale * 1.15f, glowR, glowG, glowB, 0.3f);
            matrices.pop();
        }

        // === CENTER HUB ===
        renderHub(matrices, consumer, light, scale, coreR, coreG, coreB, 0.9f);
        renderHub(matrices, consumer, light, scale * 1.3f, glowR, glowG, glowB, 0.25f);

        // === OUTER RING (when expanded) ===
        if (entity.expanded) {
            float expandProgress = Math.min(1f, entity.expandTicks / 12f);
            float ringRadius = scale * (0.8f + expandProgress * 0.6f);
            renderOuterRing(matrices, consumer, light, ringRadius, glowR, glowG, glowB, 0.35f * expandProgress);
        }

        matrices.pop();
    }

    private void renderBlade(MatrixStack matrices, VertexConsumer vc, int light,
                              float scale, float r, float g, float b, float a) {
        Matrix4f m = matrices.peek().getPositionMatrix();

        // Blade shape: tapered from hub to tip
        // Hub end (narrow): width 0.08
        // Tip end (wide then tapered): width 0.25 then back to 0.05
        float len = 0.9f * scale;
        float hubW = 0.06f * scale;
        float midW = 0.22f * scale;
        float tipW = 0.03f * scale;
        float hubDist = 0.15f * scale;
        float midDist = 0.5f * scale;

        float thick = 0.03f * scale;

        // Blade polygon (top view, extruded in Z for thickness):
        // Point 1: (hubW, hubDist) — hub right
        // Point 2: (midW, midDist) — mid right (widest)
        // Point 3: (tipW, len)     — tip right
        // Point 4: (0, len + 0.05*scale) — tip center (point)
        // Point 5: (-tipW, len)    — tip left
        // Point 6: (-midW, midDist) — mid left
        // Point 7: (-hubW, hubDist) — hub left

        // Top face
        v(vc, m, -hubW, hubDist, thick, r, g, b, a, light);
        v(vc, m,  hubW, hubDist, thick, r, g, b, a, light);
        v(vc, m,  midW, midDist, thick, r, g, b, a, light);
        v(vc, m, -midW, midDist, thick, r, g, b, a, light);

        v(vc, m, -midW, midDist, thick, r, g, b, a, light);
        v(vc, m,  midW, midDist, thick, r, g, b, a, light);
        v(vc, m,  tipW, len, thick, r, g, b, a, light);
        v(vc, m, -tipW, len, thick, r, g, b, a, light);

        v(vc, m, -tipW, len, thick, r, g, b, a, light);
        v(vc, m,  tipW, len, thick, r, g, b, a, light);
        v(vc, m,  0, len + 0.08f*scale, thick, r*1.2f, g*1.2f, b*1.2f, a, light);
        v(vc, m,  0, len + 0.08f*scale, thick, r*1.2f, g*1.2f, b*1.2f, a, light);

        // Bottom face (reversed winding)
        v(vc, m, -hubW, hubDist, -thick, r, g, b, a, light);
        v(vc, m, -midW, midDist, -thick, r, g, b, a, light);
        v(vc, m,  midW, midDist, -thick, r, g, b, a, light);
        v(vc, m,  hubW, hubDist, -thick, r, g, b, a, light);

        v(vc, m, -midW, midDist, -thick, r, g, b, a, light);
        v(vc, m, -tipW, len, -thick, r, g, b, a, light);
        v(vc, m,  tipW, len, -thick, r, g, b, a, light);
        v(vc, m,  midW, midDist, -thick, r, g, b, a, light);

        v(vc, m, -tipW, len, -thick, r, g, b, a, light);
        v(vc, m,  0, len + 0.08f*scale, -thick, r*1.2f, g*1.2f, b*1.2f, a, light);
        v(vc, m,  0, len + 0.08f*scale, -thick, r*1.2f, g*1.2f, b*1.2f, a, light);
        v(vc, m,  tipW, len, -thick, r, g, b, a, light);

        // Edge strips (connect top and bottom)
        // Right edge
        v(vc, m, hubW, hubDist, thick, r*0.8f, g*0.8f, b*0.8f, a, light);
        v(vc, m, hubW, hubDist, -thick, r*0.8f, g*0.8f, b*0.8f, a, light);
        v(vc, m, midW, midDist, -thick, r*0.8f, g*0.8f, b*0.8f, a, light);
        v(vc, m, midW, midDist, thick, r*0.8f, g*0.8f, b*0.8f, a, light);

        v(vc, m, midW, midDist, thick, r*0.8f, g*0.8f, b*0.8f, a, light);
        v(vc, m, midW, midDist, -thick, r*0.8f, g*0.8f, b*0.8f, a, light);
        v(vc, m, tipW, len, -thick, r*0.8f, g*0.8f, b*0.8f, a, light);
        v(vc, m, tipW, len, thick, r*0.8f, g*0.8f, b*0.8f, a, light);
    }

    private void renderHub(MatrixStack matrices, VertexConsumer vc, int light,
                            float scale, float r, float g, float b, float a) {
        Matrix4f m = matrices.peek().getPositionMatrix();
        float hubR = 0.18f * scale;
        float thick = 0.05f * scale;
        int segs = 12;

        for (int i = 0; i < segs; i++) {
            float a1 = (float)(i * 2 * Math.PI / segs);
            float a2 = (float)((i + 1) * 2 * Math.PI / segs);
            float x1 = (float)Math.cos(a1) * hubR;
            float y1 = (float)Math.sin(a1) * hubR;
            float x2 = (float)Math.cos(a2) * hubR;
            float y2 = (float)Math.sin(a2) * hubR;

            // Top face
            v(vc, m, 0, 0, thick, r, g, b, a, light);
            v(vc, m, x1, y1, thick, r, g, b, a, light);
            v(vc, m, x2, y2, thick, r, g, b, a, light);
            v(vc, m, x2, y2, thick, r, g, b, a, light);

            // Bottom face
            v(vc, m, 0, 0, -thick, r, g, b, a, light);
            v(vc, m, x2, y2, -thick, r, g, b, a, light);
            v(vc, m, x1, y1, -thick, r, g, b, a, light);
            v(vc, m, x1, y1, -thick, r, g, b, a, light);
        }
    }

    private void renderOuterRing(MatrixStack matrices, VertexConsumer vc, int light,
                                  float radius, float r, float g, float b, float a) {
        Matrix4f m = matrices.peek().getPositionMatrix();
        int segs = 24;
        float thick = 0.04f;

        for (int i = 0; i < segs; i++) {
            float a1 = (float)(i * 2 * Math.PI / segs);
            float a2 = (float)((i + 1) * 2 * Math.PI / segs);
            float x1o = (float)Math.cos(a1) * (radius + thick);
            float y1o = (float)Math.sin(a1) * (radius + thick);
            float x1i = (float)Math.cos(a1) * (radius - thick);
            float y1i = (float)Math.sin(a1) * (radius - thick);
            float x2o = (float)Math.cos(a2) * (radius + thick);
            float y2o = (float)Math.sin(a2) * (radius + thick);
            float x2i = (float)Math.cos(a2) * (radius - thick);
            float y2i = (float)Math.sin(a2) * (radius - thick);

            v(vc, m, x1i, y1i, 0, r, g, b, a, light);
            v(vc, m, x1o, y1o, 0, r, g, b, a*0.5f, light);
            v(vc, m, x2o, y2o, 0, r, g, b, a*0.5f, light);
            v(vc, m, x2i, y2i, 0, r, g, b, a, light);
        }
    }

    private void v(VertexConsumer vc, Matrix4f m, float x, float y, float z,
                    float r, float g, float b, float a, int light) {
        vc.vertex(m, x, y, z).color(r, g, b, a).texture(0, 0)
            .overlay(OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
    }

    @Override
    public Identifier getTexture(RasenshurikenEntity entity) { return TEX; }
}
'@

# ============================================================
# SECTION 5: RASENSHURIKEN CLIENT STATE
# ============================================================
Write-Host "--- Creating RasenshurikenClientState ---"
Write-File "$javaBase\client\RasenshurikenClientState.java" @'
package com.example.shinobicore.client;

public class RasenshurikenClientState {
    public static boolean charging = false;
    public static float chargeProgress = 0f;
    public static boolean ready = false;

    public static void reset() {
        charging = false;
        chargeProgress = 0f;
        ready = false;
    }
}
'@

# ============================================================
# SECTION 6: RASENSHURIKEN CLIENT VISUAL (charging particles)
# ============================================================
Write-Host "--- Creating RasenshurikenClientVisual ---"
Write-File "$javaBase\client\RasenshurikenClientVisual.java" @'
package com.example.shinobicore.client;

import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.util.math.Vec3d;

public class RasenshurikenClientVisual {
    private static int tickCounter = 0;

    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(RasenshurikenClientVisual::onClientTick);
    }

    private static void onClientTick(MinecraftClient client) {
        ClientPlayerEntity player = client.player;
        if (player == null) return;
        tickCounter++;

        if (RasenshurikenClientState.charging) {
            float progress = RasenshurikenClientState.chargeProgress;
            spawnChargingParticles(client, player, progress);
        }
        if (RasenshurikenClientState.ready) {
            spawnReadyParticles(client, player);
        }
    }

    private static void spawnChargingParticles(MinecraftClient client, ClientPlayerEntity player, float progress) {
        Vec3d handPos = getHandPosition(player);
        float radius = 0.15f + progress * 0.5f;
        int count = (int)(3 + progress * 10);

        for (int i = 0; i < count; i++) {
            float theta = (float)Math.random() * (float)(Math.PI * 2);
            float phi = (float)Math.acos(2 * Math.random() - 1);
            double x = handPos.x + radius * Math.sin(phi) * Math.cos(theta);
            double y = handPos.y + radius * Math.cos(phi);
            double z = handPos.z + radius * Math.sin(phi) * Math.sin(theta);

            client.world.addParticle(ParticleTypes.CLOUD, x, y, z,
                (Math.random()-0.5)*0.03, (Math.random()-0.5)*0.03, (Math.random()-0.5)*0.03);
        }
        if (progress > 0.3f && tickCounter % 2 == 0) {
            client.world.addParticle(ParticleTypes.END_ROD,
                handPos.x + (Math.random()-0.5)*radius,
                handPos.y + (Math.random()-0.5)*radius,
                handPos.z + (Math.random()-0.5)*radius,
                0, 0.02, 0);
        }
    }

    private static void spawnReadyParticles(MinecraftClient client, ClientPlayerEntity player) {
        Vec3d handPos = getHandPosition(player);
        float rot = tickCounter * 0.25f;

        // Spinning shuriken shape
        for (int blade = 0; blade < 4; blade++) {
            float bladeAngle = rot + blade * (float)(Math.PI / 2);
            for (int i = 0; i < 4; i++) {
                float dist = 0.2f + i * 0.15f;
                double x = handPos.x + Math.cos(bladeAngle) * dist;
                double z = handPos.z + Math.sin(bladeAngle) * dist;
                client.world.addParticle(ParticleTypes.CLOUD, x, handPos.y, z, 0, 0, 0);
            }
        }
        if (tickCounter % 3 == 0) {
            client.world.addParticle(ParticleTypes.END_ROD,
                handPos.x, handPos.y, handPos.z, 0, 0.03, 0);
        }
    }

    private static Vec3d getHandPosition(ClientPlayerEntity player) {
        Vec3d look = player.getRotationVector();
        Vec3d right = new Vec3d(-look.z, 0, look.x).normalize();
        return player.getEyePos()
            .add(look.multiply(0.8))
            .add(right.multiply(0.4))
            .add(0, -0.3, 0);
    }
}
'@

# ============================================================
# SECTION 7: PROJECTILE THROW HANDLER (server-side)
# ============================================================
Write-Host "--- Creating ProjectileThrowHandler ---"
Write-File "$javaBase\network\ProjectileThrowHandler.java" @'
package com.example.shinobicore.network;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.entity.RasenganEntity;
import com.example.shinobicore.entity.RasenshurikenEntity;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuRegistry;
import net.fabricmc.api.ModInitializer;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.Vec3d;

public class ProjectileThrowHandler implements ModInitializer {
    public static final Identifier THROW_RASENGAN_ID = new Identifier("shinobicore", "throw_rasengan");
    public static final Identifier THROW_RASENSHURIKEN_ID = new Identifier("shinobicore", "throw_rasenshuriken");

    @Override
    public void onInitialize() {
        ServerPlayNetworking.registerGlobalReceiver(THROW_RASENGAN_ID, (server, player, handler, buf, responseSender) -> {
            server.execute(() -> handleRasenganThrow(player));
        });
        ServerPlayNetworking.registerGlobalReceiver(THROW_RASENSHURIKEN_ID, (server, player, handler, buf, responseSender) -> {
            server.execute(() -> handleRasenshurikenThrow(player));
        });
        ShinobiCore.LOGGER.info("Registered projectile throw handlers");
    }

    private void handleRasenganThrow(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        if (!data.isRasenganReady()) return;

        // Get damage from jutsu definition
        JutsuDefinition def = JutsuRegistry.get("shinobicore:rasengan");
        float damage = 32f;
        if (def != null) {
            damage = def.baseDamage() * NinjaFormula.damageMultiplier(data, def);
        }

        // Spawn entity
        Vec3d look = player.getRotationVector();
        Vec3d velocity = look.multiply(2.0);
        RasenganEntity entity = new RasenganEntity(player.getWorld(), player, velocity, damage);
        player.getWorld().spawnEntity(entity);

        // Reset state
        data.setRasenganReady(false);
        data.setRasenganReadyTicks(0);
        ShinobiCore.sendRasenganSync(player);

        ShinobiCore.LOGGER.info("[RASENGAN] {} threw rasengan, damage={}", player.getName().getString(), damage);
    }

    private void handleRasenshurikenThrow(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        if (!data.isRasenshurikenReady()) return;

        // Get damage from jutsu definition
        JutsuDefinition def = JutsuRegistry.get("shinobicore:rasenshuriken");
        float damage = 45f;
        if (def != null) {
            damage = def.baseDamage() * NinjaFormula.damageMultiplier(data, def);
        }

        // Spawn entity
        Vec3d look = player.getRotationVector();
        Vec3d velocity = look.multiply(1.8);
        RasenshurikenEntity entity = new RasenshurikenEntity(player.getWorld(), player, velocity, damage);
        player.getWorld().spawnEntity(entity);

        // Reset state
        data.setRasenshurikenReady(false);
        data.setRasenshurikenReadyTicks(0);
        ShinobiCore.sendRasenshurikenSync(player);

        ShinobiCore.LOGGER.info("[RASENSHURIKEN] {} threw rasenshuriken, damage={}", player.getName().getString(), damage);
    }
}
'@

# ============================================================
# SECTION 8: SIMPLIFIED RASENSHURIKEN BEHAVIOR (just charge)
# ============================================================
Write-Host "--- Rewriting RasenshurikenBehavior (charge-only) ---"
Write-File "$javaBase\jutsu\custom\RasenshurikenBehavior.java" @'
package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.stat.StatType;
import com.google.gson.JsonObject;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;

public class RasenshurikenBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (data.isRasenshurikenCharging() || data.isRasenshurikenReady()) {
            player.sendMessage(Text.literal("\u00a77Rasenshuriken is already active!"), false);
            return;
        }

        int controlLevel = data.getStatLevel(StatType.CONTROL);
        int baseChargeTicks = params.has("chargeTicks") ? params.get("chargeTicks").getAsInt() : 60;
        int minChargeTicks = 20;
        int chargeTicks = Math.max(minChargeTicks, baseChargeTicks - (int)(controlLevel * 0.5));

        data.setRasenshurikenCharging(true);
        data.setRasenshurikenChargeTicks(0);
        data.setRasenshurikenChargeTarget(chargeTicks);
        data.setRasenshurikenReady(false);

        float chargeSeconds = chargeTicks / 20.0f;
        player.sendMessage(Text.literal("\u00a7bRasenshuriken charging... " + String.format("%.1f", chargeSeconds) + "s"), false);
        ShinobiCore.sendRasenshurikenSync(player);

        JutsuLogger.logBehavior("rasenshuriken", String.format(
            "CHARGE START: player=%s, control=%d, chargeTicks=%d (%.1fs)",
            player.getName().getString(), controlLevel, chargeTicks, chargeSeconds));
    }
}
'@

# ============================================================
# SECTION 9: MODIFY ModEntities — register new entities
# ============================================================
Write-Host "--- Modifying ModEntities.java ---"
$modEntitiesPath = "$javaBase\entity\ModEntities.java"
$me = [System.IO.File]::ReadAllText($modEntitiesPath, $utf8)

# Add new entity registrations after SHURIKEN
if (-not $me.Contains("RASENGAN_PROJECTILE")) {
    $insertCode = @'

    public static final EntityType<RasenganEntity> RASENGAN_PROJECTILE = Registry.register(
        Registries.ENTITY_TYPE,
        new Identifier(ShinobiCore.MOD_ID, "rasengan_projectile"),
        FabricEntityTypeBuilder.<RasenganEntity>create(SpawnGroup.MISC, RasenganEntity::new)
            .dimensions(EntityDimensions.fixed(0.6f, 0.6f))
            .trackRangeChunks(32)
            .trackedUpdateRate(2)
            .build()
    );

    public static final EntityType<RasenshurikenEntity> RASENSHURIKEN_PROJECTILE = Registry.register(
        Registries.ENTITY_TYPE,
        new Identifier(ShinobiCore.MOD_ID, "rasenshuriken_projectile"),
        FabricEntityTypeBuilder.<RasenshurikenEntity>create(SpawnGroup.MISC, RasenshurikenEntity::new)
            .dimensions(EntityDimensions.fixed(1.5f, 0.3f))
            .trackRangeChunks(48)
            .trackedUpdateRate(2)
            .build()
    );
'@
    $me = $me.Replace(
        "    public static void register() {",
        $insertCode + "`n`n    public static void register() {"
    )
    [System.IO.File]::WriteAllText($modEntitiesPath, $me, $utf8)
    Write-Host "[OK] ModEntities: registered RASENGAN_PROJECTILE + RASENSHURIKEN_PROJECTILE"
} else {
    Write-Host "[SKIP] ModEntities: already has projectile entities"
}

# ============================================================
# SECTION 10: MODIFY ShinobiCoreClient — register renderers + sync
# ============================================================
Write-Host "--- Modifying ShinobiCoreClient.java ---"
$sccPath = "$javaBase\client\ShinobiCoreClient.java"
$scc = [System.IO.File]::ReadAllText($sccPath, $utf8)

# 10a: Register entity renderers
if (-not $scc.Contains("RasenganRenderer")) {
    $scc = $scc.Replace(
        "EntityRendererRegistry.register(ModEntities.SHURIKEN, ShurikenRenderer::new);",
        "EntityRendererRegistry.register(ModEntities.SHURIKEN, ShurikenRenderer::new);`n        EntityRendererRegistry.register(ModEntities.RASENGAN_PROJECTILE, com.example.shinobicore.entity.RasenganRenderer::new);`n        EntityRendererRegistry.register(ModEntities.RASENSHURIKEN_PROJECTILE, com.example.shinobicore.entity.RasenshurikenRenderer::new);"
    )
    Write-Host "[OK] ShinobiCoreClient: registered entity renderers"
}

# 10b: Register RasenshurikenClientVisual
if (-not $scc.Contains("RasenshurikenClientVisual.register")) {
    $scc = $scc.Replace(
        "RasenganClientVisual.register();",
        "RasenganClientVisual.register();`n        com.example.shinobicore.client.RasenshurikenClientVisual.register();"
    )
    Write-Host "[OK] ShinobiCoreClient: registered RasenshurikenClientVisual"
}

# 10c: Add rasenshuriken sync packet receiver
if (-not $scc.Contains("RASENSHURIKEN_SYNC_ID")) {
    $syncReceiver = @'

        ClientPlayNetworking.registerGlobalReceiver(new net.minecraft.util.Identifier("shinobicore", "rasenshuriken_sync"), (client, handler, buf, responseSender) -> {
            boolean charging = buf.readBoolean();
            float progress = buf.readFloat();
            boolean ready = buf.readBoolean();
            client.execute(() -> {
                com.example.shinobicore.client.RasenshurikenClientState.charging = charging;
                com.example.shinobicore.client.RasenshurikenClientState.chargeProgress = progress;
                com.example.shinobicore.client.RasenshurikenClientState.ready = ready;
            });
        });
'@
    # Insert before the last closing brace of onInitializeClient
    $lastBrace = $scc.LastIndexOf("}")
    $secondLastBrace = $scc.LastIndexOf("}", $lastBrace - 1)
    $scc = $scc.Insert($secondLastBrace, $syncReceiver)
    Write-Host "[OK] ShinobiCoreClient: added rasenshuriken sync receiver"
}

# 10d: Reset rasenshuriken state on disconnect
if (-not $scc.Contains("RasenshurikenClientState.reset")) {
    $scc = $scc.Replace(
        "RasenganClientState.reset();",
        "RasenganClientState.reset();`n                com.example.shinobicore.client.RasenshurikenClientState.reset();"
    )
    # If that didn't exist, add to disconnect handler
    if (-not $scc.Contains("RasenshurikenClientState.reset")) {
        $scc = $scc.Replace(
            "HitStopManager.clear();",
            "HitStopManager.clear();`n            com.example.shinobicore.client.RasenshurikenClientState.reset();"
        )
    }
    Write-Host "[OK] ShinobiCoreClient: reset rasenshuriken on disconnect"
}

[System.IO.File]::WriteAllText($sccPath, $scc, $utf8)

# ============================================================
# SECTION 11: MODIFY TaijutsuClientHandler — LMB throws both
# ============================================================
Write-Host "--- Modifying TaijutsuClientHandler.java ---"
$tchPath = "$javaBase\client\combat\TaijutsuClientHandler.java"
$tch = [System.IO.File]::ReadAllText($tchPath, $utf8)

# Replace the rasengan-only check with rasengan + rasenshuriken
$oldRasenganBlock = @'
        // === РАСЕНГАН: если готов — удар Расенганом вместо обычной атаки ===
        if (RasenganClientState.ready) {
            ShinobiCore.LOGGER.info("[RASENGAN] Strike! Sending packet to server");
            PacketByteBuf rasenganBuf = new PacketByteBuf(Unpooled.buffer());
            ClientPlayNetworking.send(ModPackets.RASENGAN_STRIKE_ID, rasenganBuf);
            RasenganClientState.ready = false;
            RasenganClientState.charging = false;
            RasenganClientState.chargeProgress = 0f;
            return true;
        }
'@

$newThrowBlock = @'
        // === РАСЕНГАН: если готов — бросок снаряда ===
        if (com.example.shinobicore.client.RasenganClientState.ready) {
            ShinobiCore.LOGGER.info("[RASENGAN] Throw! Sending packet to server");
            PacketByteBuf rasenganBuf = new PacketByteBuf(Unpooled.buffer());
            ClientPlayNetworking.send(new net.minecraft.util.Identifier("shinobicore", "throw_rasengan"), rasenganBuf);
            com.example.shinobicore.client.RasenganClientState.ready = false;
            com.example.shinobicore.client.RasenganClientState.charging = false;
            com.example.shinobicore.client.RasenganClientState.chargeProgress = 0f;
            return true;
        }
        // === РАСЕНСЮРИКЕН: если готов — бросок снаряда ===
        if (com.example.shinobicore.client.RasenshurikenClientState.ready) {
            ShinobiCore.LOGGER.info("[RASENSHURIKEN] Throw! Sending packet to server");
            PacketByteBuf rsBuf = new PacketByteBuf(Unpooled.buffer());
            ClientPlayNetworking.send(new net.minecraft.util.Identifier("shinobicore", "throw_rasenshuriken"), rsBuf);
            com.example.shinobicore.client.RasenshurikenClientState.ready = false;
            com.example.shinobicore.client.RasenshurikenClientState.charging = false;
            com.example.shinobicore.client.RasenshurikenClientState.chargeProgress = 0f;
            return true;
        }
'@

if ($tch.Contains($oldRasenganBlock)) {
    $tch = $tch.Replace($oldRasenganBlock, $newThrowBlock)
    Write-Host "[OK] TaijutsuClientHandler: replaced rasengan block with throw block"
} else {
    # Try a simpler pattern match
    $tch = $tch -replace 'if \(RasenganClientState\.ready\) \{[^}]+ClientPlayNetworking\.send\(ModPackets\.RASENGAN_STRIKE_ID[^}]+\}[^}]+return true;\s*\}', $newThrowBlock
    Write-Host "[OK] TaijutsuClientHandler: replaced via regex"
}

[System.IO.File]::WriteAllText($tchPath, $tch, $utf8)

# ============================================================
# SECTION 12: MODIFY NinjaTickHandler — tick rasenshuriken charge
# ============================================================
Write-Host "--- Modifying NinjaTickHandler.java ---"
$nthPath = "$javaBase\event\NinjaTickHandler.java"
$nth = [System.IO.File]::ReadAllText($nthPath, $utf8)

# Find the rasengan charge block and add rasenshuriken after it
if (-not $nth.Contains("isRasenshurikenCharging")) {
    # Find the rasengan ready dissipate block and add rasenshuriken logic after it
    $rasenshurikenTick = @'

                // === RASENSHURIKEN CHARGE TICK ===
                if (data.isRasenshurikenCharging()) {
                    data.setRasenshurikenChargeTicks(data.getRasenshurikenChargeTicks() + 1);
                    if (data.getRasenshurikenChargeTicks() >= data.getRasenshurikenChargeTarget()) {
                        data.setRasenshurikenCharging(false);
                        data.setRasenshurikenReady(true);
                        player.sendMessage(Text.literal("\u00a7b\u2726 Rasenshuriken ready! Press LMB to throw!"), false);
                        ShinobiCore.sendRasenshurikenSync(player);
                    }
                    if (data.getRasenshurikenChargeTicks() % 5 == 0) {
                        ShinobiCore.sendRasenshurikenSync(player);
                    }
                } else if (data.isRasenshurikenReady()) {
                    data.setRasenshurikenReadyTicks(data.getRasenshurikenReadyTicks() + 20);
                    if (data.getRasenshurikenReadyTicks() >= 800) {
                        data.setRasenshurikenReady(false);
                        data.setRasenshurikenReadyTicks(0);
                        player.sendMessage(Text.literal("\u00a77Rasenshuriken dissipated..."), false);
                        ShinobiCore.sendRasenshurikenSync(player);
                    }
                } else {
                    data.setRasenshurikenReadyTicks(0);
                }
'@

    # Insert after the rasengan ready dissipate block
    $rasenganDissipateEnd = "data.setRasenganReadyTicks(0);`n                }"
    if ($nth.Contains($rasenganDissipateEnd)) {
        $nth = $nth.Replace($rasenganDissipateEnd, $rasenganDissipateEnd + $rasenshurikenTick)
        Write-Host "[OK] NinjaTickHandler: added rasenshuriken charge tick"
    } else {
        # Try alternative pattern
        $altPattern = "data.setRasenganReadyTicks(0);"
        $altIdx = $nth.IndexOf($altPattern)
        if ($altIdx -ge 0) {
            $endIdx = $nth.IndexOf("}", $altIdx)
            $endIdx = $nth.IndexOf("}", $endIdx + 1)
            if ($endIdx -ge 0) {
                $nth = $nth.Insert($endIdx + 1, $rasenshurikenTick)
                Write-Host "[OK] NinjaTickHandler: inserted rasenshuriken tick via position"
            }
        } else {
            Write-Host "[WARN] Could not find insertion point for rasenshuriken tick"
        }
    }
}

[System.IO.File]::WriteAllText($nthPath, $nth, $utf8)

# ============================================================
# SECTION 13: MODIFY NinjaPlayerData — add rasenshuriken fields
# ============================================================
Write-Host "--- Modifying NinjaPlayerData.java ---"
# Find the file
$npdFiles = Get-ChildItem -Path $javaBase -Recurse -Filter "NinjaPlayerData.java"
if ($npdFiles.Count -gt 0) {
    $npdPath = $npdFiles[0].FullName
    $npd = [System.IO.File]::ReadAllText($npdPath, $utf8)

    if (-not $npd.Contains("rasenshurikenCharging")) {
        # Find rasengan fields and add rasenshuriken after them
        $rasenganFieldPattern = "private int rasenganChargeTicks;"
        $rasenganIdx = $npd.IndexOf($rasenganFieldPattern)

        if ($rasenganIdx -ge 0) {
            # Find end of rasengan field block
            $rasenganBlock = @'
private int rasenganChargeTicks;
'@
            # Find all rasengan-related fields
            $fieldInsert = @'

    // === RASENSHURIKEN STATE ===
    private boolean rasenshurikenCharging = false;
    private int rasenshurikenChargeTicks = 0;
    private int rasenshurikenChargeTarget = 0;
    private boolean rasenshurikenReady = false;
    private int rasenshurikenReadyTicks = 0;
'@
            # Insert after the last rasengan field
            $rasReadyIdx = $npd.IndexOf("private boolean rasenganReady")
            if ($rasReadyIdx -ge 0) {
                $rasReadyEnd = $npd.IndexOf(";", $rasReadyIdx)
                # Check if there's rasenganReadyTicks after it
                $readyTicksIdx = $npd.IndexOf("rasenganReadyTicks", $rasReadyEnd)
                if ($readyTicksIdx -ge 0 -and $readyTicksIdx -lt ($rasReadyEnd + 100)) {
                    $readyTicksEnd = $npd.IndexOf(";", $readyTicksIdx)
                    $npd = $npd.Insert($readyTicksEnd + 1, $fieldInsert)
                } else {
                    $npd = $npd.Insert($rasReadyEnd + 1, $fieldInsert)
                }
            } else {
                # Just insert after rasenganChargeTicks
                $endOfLine = $npd.IndexOf("`n", $rasenganIdx)
                $npd = $npd.Insert($endOfLine + 1, $fieldInsert)
            }
            Write-Host "[OK] NinjaPlayerData: added rasenshuriken fields"
        } else {
            Write-Host "[WARN] Could not find rasenganChargeTicks field"
        }

        # Add getter/setter methods
        if (-not $npd.Contains("isRasenshurikenCharging")) {
            $methodInsert = @'

    // === RASENSHURIKEN GETTERS/SETTERS ===
    public boolean isRasenshurikenCharging() { return rasenshurikenCharging; }
    public void setRasenshurikenCharging(boolean v) { rasenshurikenCharging = v; statsDirty = true; }
    public int getRasenshurikenChargeTicks() { return rasenshurikenChargeTicks; }
    public void setRasenshurikenChargeTicks(int v) { rasenshurikenChargeTicks = v; }
    public int getRasenshurikenChargeTarget() { return rasenshurikenChargeTarget; }
    public void setRasenshurikenChargeTarget(int v) { rasenshurikenChargeTarget = v; }
    public boolean isRasenshurikenReady() { return rasenshurikenReady; }
    public void setRasenshurikenReady(boolean v) { rasenshurikenReady = v; statsDirty = true; }
    public int getRasenshurikenReadyTicks() { return rasenshurikenReadyTicks; }
    public void setRasenshurikenReadyTicks(int v) { rasenshurikenReadyTicks = v; }
'@
            # Insert before the last closing brace
            $lastBrace = $npd.LastIndexOf("}")
            $npd = $npd.Insert($lastBrace, $methodInsert)
            Write-Host "[OK] NinjaPlayerData: added rasenshuriken getters/setters"
        }

        # Add NBT serialization
        if (-not $npd.Contains("rasenshurikenCharging") -or -not $npd.Contains("putBoolean(`"RasenshurikenCharging`"")) {
            # Find writeCustomDataToNbt or writeNbt
            $writeNbtIdx = $npd.IndexOf("writeCustomDataToNbt")
            if ($writeNbtIdx -lt 0) { $writeNbtIdx = $npd.IndexOf("writeNbt") }

            if ($writeNbtIdx -ge 0) {
                # Find rasengan NBT write and add after it
                $rasNbtPattern = "nbt.putBoolean(`"RasenganReady`""
                $rasNbtIdx = $npd.IndexOf($rasNbtPattern)
                if ($rasNbtIdx -lt 0) { $rasNbtPattern = "nbt.putBoolean(`"RasenganReady`")"; $rasNbtIdx = $npd.IndexOf($rasNbtPattern) }
                if ($rasNbtIdx -lt 0) { $rasNbtPattern = "putBoolean(`"RasenganReady`""; $rasNbtIdx = $npd.IndexOf($rasNbtPattern) }

                if ($rasNbtIdx -ge 0) {
                    # Find the rasenganReadyTicks line
                    $readyTicksNbt = $npd.IndexOf("RasenganReadyTicks", $rasNbtIdx)
                    if ($readyTicksNbt -ge 0) {
                        $endOfReadyTicks = $npd.IndexOf("`n", $readyTicksNbt)
                        $nbtInsert = @'

        nbt.putBoolean("RasenshurikenCharging", rasenshurikenCharging);
        nbt.putInt("RasenshurikenChargeTicks", rasenshurikenChargeTicks);
        nbt.putInt("RasenshurikenChargeTarget", rasenshurikenChargeTarget);
        nbt.putBoolean("RasenshurikenReady", rasenshurikenReady);
        nbt.putInt("RasenshurikenReadyTicks", rasenshurikenReadyTicks);
'@
                        $npd = $npd.Insert($endOfReadyTicks + 1, $nbtInsert)
                        Write-Host "[OK] NinjaPlayerData: added rasenshuriken NBT write"
                    }
                }
            }

            # Find readCustomDataFromNbt or readNbt
            $readNbtIdx = $npd.IndexOf("readCustomDataFromNbt")
            if ($readNbtIdx -lt 0) { $readNbtIdx = $npd.IndexOf("readNbt") }

            if ($readNbtIdx -ge 0) {
                $rasReadPattern = "getBoolean(`"RasenganReady`""
                $rasReadIdx = $npd.IndexOf($rasReadPattern)
                if ($rasReadIdx -lt 0) { $rasReadPattern = "RasenganReady"; $rasReadIdx = $npd.IndexOf($rasReadPattern, $readNbtIdx) }

                if ($rasReadIdx -ge 0) {
                    $readyTicksRead = $npd.IndexOf("RasenganReadyTicks", $rasReadIdx)
                    if ($readyTicksRead -ge 0) {
                        $endOfReadyTicksRead = $npd.IndexOf("`n", $readyTicksRead)
                        $readInsert = @'

        rasenshurikenCharging = nbt.getBoolean("RasenshurikenCharging");
        rasenshurikenChargeTicks = nbt.getInt("RasenshurikenChargeTicks");
        rasenshurikenChargeTarget = nbt.getInt("RasenshurikenChargeTarget");
        rasenshurikenReady = nbt.getBoolean("RasenshurikenReady");
        rasenshurikenReadyTicks = nbt.getInt("RasenshurikenReadyTicks");
'@
                        $npd = $npd.Insert($endOfReadyTicksRead + 1, $readInsert)
                        Write-Host "[OK] NinjaPlayerData: added rasenshuriken NBT read"
                    }
                }
            }
        }

        [System.IO.File]::WriteAllText($npdPath, $npd, $utf8)
    } else {
        Write-Host "[SKIP] NinjaPlayerData: already has rasenshuriken fields"
    }
} else {
    Write-Host "[ERROR] NinjaPlayerData.java not found!"
}

# ============================================================
# SECTION 14: ADD sendRasenshurikenSync to ShinobiCore
# ============================================================
Write-Host "--- Adding sendRasenshurikenSync to ShinobiCore.java ---"
$scFiles = Get-ChildItem -Path $javaBase -Recurse -Filter "ShinobiCore.java" | Where-Object { $_.Name -eq "ShinobiCore.java" -and $_.DirectoryName -notmatch "client" }
if ($scFiles.Count -gt 0) {
    $scPath = $scFiles[0].FullName
    $sc = [System.IO.File]::ReadAllText($scPath, $utf8)

    if (-not $sc.Contains("sendRasenshurikenSync")) {
        # Find sendRasenganSync and add similar method after it
        $rasenganSyncIdx = $sc.IndexOf("sendRasenganSync")
        if ($rasenganSyncIdx -ge 0) {
            # Find the end of the sendRasenganSync method
            $methodStart = $sc.LastIndexOf("public static", $rasenganSyncIdx)
            $braceCount = 0
            $methodEnd = $rasenganSyncIdx
            $started = false
            for ($i = $methodStart; $i -lt $sc.Length; $i++) {
                if ($sc[$i] -eq '{') { $braceCount++; $started = true }
                if ($sc[$i] -eq '}') { $braceCount--; if ($started -and $braceCount -eq 0) { $methodEnd = $i; break } }
            }

            $syncMethod = @'

    public static void sendRasenshurikenSync(ServerPlayerEntity player) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        buf.writeBoolean(data.isRasenshurikenCharging());
        float progress = data.getRasenshurikenChargeTarget() > 0
            ? (float) data.getRasenshurikenChargeTicks() / data.getRasenshurikenChargeTarget()
            : 0f;
        buf.writeFloat(progress);
        buf.writeBoolean(data.isRasenshurikenReady());
        PacketByteBuf copy = new PacketByteBuf(Unpooled.buffer());
        copy.writeBytes(buf.copy());
        ServerPlayNetworking.send(player, new Identifier(MOD_ID, "rasenshuriken_sync"), copy);
    }
'@
            $sc = $sc.Insert($methodEnd + 1, $syncMethod)
            [System.IO.File]::WriteAllText($scPath, $sc, $utf8)
            Write-Host "[OK] ShinobiCore: added sendRasenshurikenSync method"
        } else {
            Write-Host "[WARN] Could not find sendRasenganSync in ShinobiCore"
        }
    } else {
        Write-Host "[SKIP] ShinobiCore: already has sendRasenshurikenSync"
    }
} else {
    Write-Host "[ERROR] ShinobiCore.java not found!"
}

# ============================================================
# SECTION 15: FIX CHAKRA AURA PARTICLES (reduce + white)
# ============================================================
Write-Host "--- Fixing chakra aura particles ---"

# Fix ChakraAuraVisual.java
$cavPath = "$javaBase\client\ChakraAuraVisual.java"
if (Test-Path $cavPath) {
    Write-File $cavPath @'
package com.example.shinobicore.client;

import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.particle.DustParticleEffect;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.util.math.Vec3d;
import org.joml.Vector3f;

public class ChakraAuraVisual {
    private static int tickCounter = 0;
    // White chakra color
    private static final Vector3f WHITE_CHAKRA = new Vector3f(0.9f, 0.92f, 1.0f);

    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(ChakraAuraVisual::tick);
    }

    private static void tick(MinecraftClient client) {
        if (client.world == null || client.player == null) return;
        tickCounter++;

        boolean chakraOn = ClientNinjaState.chakraMode && ChakraHudRenderer.currentChakra > 0;
        if (!chakraOn) return;

        // Only spawn every 6 ticks (reduced from every tick)
        if (tickCounter % 6 != 0) return;

        float chakraRatio = ChakraHudRenderer.maxChakra > 0
            ? ChakraHudRenderer.currentChakra / ChakraHudRenderer.maxChakra : 0;
        boolean flicker = chakraRatio < 0.25f;
        if (flicker && (tickCounter % 12 > 6)) return;

        Vec3d pos = client.player.getPos();

        // === REDUCED: subtle white wisps (only 2 particles per tick) ===
        DustParticleEffect effect = new DustParticleEffect(WHITE_CHAKRA, 0.6f);

        for (int i = 0; i < 2; i++) {
            double angle = tickCounter * 0.15 + i * Math.PI;
            double r = 0.3;
            client.world.addParticle(effect,
                pos.x + Math.cos(angle) * r,
                pos.y + 0.2 + Math.random() * 0.8,
                pos.z + Math.sin(angle) * r,
                (Math.random() - 0.5) * 0.005,
                0.02,
                (Math.random() - 0.5) * 0.005);
        }

        // Very occasional white spark (every 12 ticks = ~0.6s)
        if (tickCounter % 12 == 0) {
            client.world.addParticle(ParticleTypes.END_ROD,
                pos.x + (Math.random() - 0.5) * 0.5,
                pos.y + 0.5 + Math.random() * 1.0,
                pos.z + (Math.random() - 0.5) * 0.5,
                0, 0.02, 0);
        }
    }
}
'@
    Write-Host "[OK] ChakraAuraVisual: reduced + white particles"
}

# Fix ChakraAuraRenderer.java (the other particle spawner)
$carPath = "$javaBase\client\ChakraAuraRenderer.java"
if (Test-Path $carPath) {
    Write-File $carPath @'
package com.example.shinobicore.client;

import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.particle.DustParticleEffect;
import net.minecraft.util.math.Vec3d;
import org.joml.Vector3f;

/**
 * Chakra Aura: minimal white particles around body in chakra mode.
 */
public class ChakraAuraRenderer {
    private static int tickCounter = 0;
    private static final Vector3f WHITE_CHAKRA = new Vector3f(0.9f, 0.92f, 1.0f);

    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(ChakraAuraRenderer::tick);
    }

    private static void tick(MinecraftClient client) {
        if (client.world == null) return;
        tickCounter++;

        // Only every 8 ticks (greatly reduced)
        if (tickCounter % 8 != 0) return;

        for (AbstractClientPlayerEntity p : client.world.getPlayers()) {
            boolean isLocal = (p == client.player);
            boolean hasChakra;

            if (isLocal) {
                hasChakra = ClientNinjaState.chakraMode && ChakraHudRenderer.currentChakra > 0;
            } else {
                hasChakra = CastingClientState.isCasting(p);
            }
            if (!hasChakra) continue;

            Vec3d pos = p.getPos();
            DustParticleEffect effect = new DustParticleEffect(WHITE_CHAKRA, 0.5f);

            // Just 2 subtle particles
            int count = isLocal ? 2 : 1;
            float rotation = tickCounter * 0.1f;
            for (int i = 0; i < count; i++) {
                float angle = rotation + (i / (float) count) * (float)(Math.PI * 2);
                double x = pos.x + Math.cos(angle) * 0.35;
                double z = pos.z + Math.sin(angle) * 0.35;
                double y = pos.y + 0.5 + Math.random() * 0.8;

                client.world.addParticle(effect, x, y, z, 0, 0.015, 0);
            }
        }
    }
}
'@
    Write-Host "[OK] ChakraAuraRenderer: reduced + white particles"
}

# ============================================================
# SECTION 16: ADD ENTRYPOINT to fabric.mod.json
# ============================================================
Write-Host "--- Modifying fabric.mod.json ---"
$fmPath = "$resBase\fabric.mod.json"
$fm = [System.IO.File]::ReadAllText($fmPath, $utf8)

if (-not $fm.Contains("ProjectileThrowHandler")) {
    $fm = $fm.Replace(
        '"com.example.shinobicore.DebugCommands"',
        '"com.example.shinobicore.DebugCommands",
"com.example.shinobicore.network.ProjectileThrowHandler"'
    )
    [System.IO.File]::WriteAllText($fmPath, $fm, $utf8)
    Write-Host "[OK] fabric.mod.json: added ProjectileThrowHandler entrypoint"
} else {
    Write-Host "[SKIP] fabric.mod.json: already has ProjectileThrowHandler"
}

# ============================================================
# SECTION 17: UPDATE HUD — add rasenshuriken charge bar
# ============================================================
Write-Host "--- Modifying ChakraHudRenderer.java ---"
$hudPath = "$javaBase\client\ChakraHudRenderer.java"
if (Test-Path $hudPath) {
    $hud = [System.IO.File]::ReadAllText($hudPath, $utf8)

    if (-not $hud.Contains("RasenshurikenClientState")) {
        # Find the rasengan charge bar section and add rasenshuriken after it
        $rasenganReadyBlock = 'if (RasenganClientState.ready) {'
        $rasenganReadyIdx = $hud.IndexOf($rasenganReadyBlock)

        if ($rasenganReadyIdx -ge 0) {
            # Find the end of the rasengan ready block
            $braceCount = 0
            $blockEnd = $rasenganReadyIdx
            $started = false
            for ($i = $rasenganReadyIdx; $i -lt $hud.Length; $i++) {
                if ($hud[$i] -eq '{') { $braceCount++; $started = true }
                if ($hud[$i] -eq '}') { $braceCount--; if ($started -and $braceCount -eq 0) { $blockEnd = $i; break } }
            }

            $rsHudBlock = @'

            // === RASENSHURIKEN CHARGE/READY ===
            if (com.example.shinobicore.client.RasenshurikenClientState.charging) {
                float rsProgress = com.example.shinobicore.client.RasenshurikenClientState.chargeProgress;
                int rsBarW = 60, rsBarH = 4;
                context.fill(10, y + 8, 10 + rsBarW, y + 8 + rsBarH, 0xCC222222);
                context.fill(10, y + 8, 10 + (int)(rsBarW * rsProgress), y + 8 + rsBarH, 0xFF44FFAA);
                context.drawTextWithShadow(client.textRenderer, net.minecraft.text.Text.literal("RASENSHURIKEN " + (int)(rsProgress * 100) + "%"),
                    10, y + 14, 0xFF44FFAA);
                y += 24;
            }
            if (com.example.shinobicore.client.RasenshurikenClientState.ready) {
                int rsAlpha = (int)(150 + 105 * Math.sin(System.currentTimeMillis() / 100.0));
                context.drawTextWithShadow(client.textRenderer, net.minecraft.text.Text.literal("\u2726 RASENSHURIKEN READY \u2014 LMB!"),
                    10, y + 8, net.minecraft.util.math.ColorHelper.Argb.getArgb(rsAlpha, 68, 255, 170));
                y += 18;
            }
'@
            $hud = $hud.Insert($blockEnd + 1, $rsHudBlock)
            [System.IO.File]::WriteAllText($hudPath, $hud, $utf8)
            Write-Host "[OK] ChakraHudRenderer: added rasenshuriken HUD"
        } else {
            Write-Host "[WARN] Could not find rasengan ready block in HUD"
        }
    } else {
        Write-Host "[SKIP] ChakraHudRenderer: already has rasenshuriken HUD"
    }
}

# ============================================================
# SECTION 18: UPDATE JSON files
# ============================================================
Write-Host "--- Updating jutsu JSON files ---"

# Rasengan JSON — ensure correct behavior class
Write-File "$resBase\data\shinobicore\jutsu\rasengan.json" @'
{
    "id": "shinobicore:rasengan",
    "name": "Rasengan",
    "category": "shape_ninjutsu",
    "type": "custom",
    "behaviorClass": "com.example.shinobicore.jutsu.custom.RasenganBehavior",
    "params": {
        "baseChargeTicks": 40,
        "minChargeTicks": 15,
        "dashDistance": 6.0,
        "hitRadius": 3.0,
        "knockback": 2.5,
        "particleCount": 60
    },
    "baseCost": 80,
    "baseDamage": 32,
    "strain": 15,
    "requiredUsesForFullProficiency": 100,
    "requirements": {
        "control": 30,
        "ninjutsu": 30
    }
}
'@

# Rasenshuriken JSON — simplified to charge-only
Write-File "$resBase\data\shinobicore\jutsu\rasenshuriken.json" @'
{
    "id": "shinobicore:rasenshuriken",
    "name": "Wind Release: Rasenshuriken",
    "category": "shape_ninjutsu",
    "nature": "wind",
    "type": "custom",
    "behaviorClass": "com.example.shinobicore.jutsu.custom.RasenshurikenBehavior",
    "params": {
        "chargeTicks": 60
    },
    "baseCost": 100,
    "baseDamage": 45,
    "strain": 20,
    "requiredUsesForFullProficiency": 120,
    "requirements": {
        "control": 40,
        "nature_wind": 45,
        "ninjutsu": 40
    }
}
'@
Write-Host "[OK] Updated rasengan.json + rasenshuriken.json"

# ============================================================
# FINAL SUMMARY
# ============================================================
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗"
Write-Host "║              ALL CHANGES APPLIED!                    ║"
Write-Host "╚══════════════════════════════════════════════════════╝"
Write-Host ""
Write-Host "What was done:"
Write-Host "  1. RasenganEntity + RasenshurikenEntity — 3D projectile entities"
Write-Host "  2. RasenganRenderer — 3D sphere model (blue/white swirling chakra)"
Write-Host "  3. RasenshurikenRenderer — 3D 4-blade shuriken (green/white wind)"
Write-Host "  4. RasenshurikenClientState + Visual — client charge tracking"
Write-Host "  5. ProjectileThrowHandler — server-side packet handler"
Write-Host "  6. RasenshurikenBehavior — simplified to charge-only"
Write-Host "  7. TaijutsuClientHandler — LMB throws both projectiles"
Write-Host "  8. NinjaTickHandler — ticks rasenshuriken charge"
Write-Host "  9. NinjaPlayerData — added rasenshuriken fields + NBT"
Write-Host " 10. ShinobiCore — added sendRasenshurikenSync"
Write-Host " 11. ChakraAuraVisual/Renderer — WHITE particles, greatly reduced"
Write-Host " 12. ChakraHudRenderer — rasenshuriken charge bar"
Write-Host " 13. fabric.mod.json — ProjectileThrowHandler entrypoint"
Write-Host ""
Write-Host "How it works:"
Write-Host "  1. Assign Rasenshuriken to a slot (K menu)"
Write-Host "  2. Press cast key (R/T) -> charging starts (~3s)"
Write-Host "  3. 'Rasenshuriken ready!' appears"
Write-Host "  4. Press LMB -> throws 3D shuriken projectile"
Write-Host "  5. Projectile travels, then expands into massive AOE"
Write-Host ""
Write-Host "Same flow for Rasengan (shorter charge, smaller AOE)"
Write-Host ""
Write-Host "Run: .\gradlew.bat build"
Write-Host "Then: .\gradlew.bat runClient"
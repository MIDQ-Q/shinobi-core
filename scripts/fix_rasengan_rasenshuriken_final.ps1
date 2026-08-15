$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main"

function Write-File($p, $c) {
    $dir = [System.IO.Path]::GetDirectoryName($p)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] $($p.Replace('E:\Games\mod\src\main\', ''))" -ForegroundColor Green
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  FIX: RASENGAN LMB + RASENSHURIKEN RMB + 3D MODELS     ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ================================================================
# 1. RASENGAN HAND ENTITY (3D sphere in hand)
# ================================================================
Write-File "$base\java\com\example\shinobicore\entity\RasenganHandEntity.java" @'
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
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.World;
import java.util.UUID;

public class RasenganHandEntity extends Entity {
    private static final TrackedData<Float> DAMAGE = DataTracker.registerData(RasenganHandEntity.class, TrackedDataHandlerRegistry.FLOAT);
    private UUID ownerId;
    public int age = 0;
    private static final int MAX_LIFETIME = 600;

    public RasenganHandEntity(EntityType<?> type, World world) {
        super(type, world);
    }

    public RasenganHandEntity(World world, LivingEntity owner, float damage) {
        super(ModEntities.RASENGAN_HAND, world);
        this.ownerId = owner.getUuid();
        this.dataTracker.set(DAMAGE, damage);
        updatePosition(owner);
    }

    @Override
    protected void initDataTracker() {
        this.dataTracker.startTracking(DAMAGE, 32f);
    }

    public float getDamage() { return this.dataTracker.get(DAMAGE); }

    public Entity getOwner() {
        if (ownerId == null) return null;
        if (this.getWorld() instanceof ServerWorld sw) return sw.getPlayerByUuid(ownerId);
        return null;
    }

    private void updatePosition(LivingEntity owner) {
        Vec3d look = owner.getRotationVector();
        Vec3d right = new Vec3d(-look.z, 0, look.x).normalize();
        Vec3d handPos = owner.getEyePos()
                .add(look.multiply(0.6))
                .add(right.multiply(0.35))
                .add(0, -0.25, 0);
        this.setPosition(handPos.x, handPos.y, handPos.z);
    }

    @Override
    public void tick() {
        super.tick();
        age++;
        if (age > MAX_LIFETIME) {
            if (this.getWorld() instanceof ServerWorld sw) {
                sw.spawnParticles(ParticleTypes.CLOUD,
                        this.getX(), this.getY(), this.getZ(),
                        15, 0.3, 0.3, 0.3, 0.05);
            }
            this.discard();
            return;
        }
        Entity owner = getOwner();
        if (owner instanceof LivingEntity liv) {
            updatePosition(liv);
        } else {
            this.discard();
            return;
        }
        // Частицы
        if (this.getWorld() instanceof ServerWorld sw && age % 2 == 0) {
            float rot = age * 0.2f;
            float radius = 0.2f + (float) Math.sin(age * 0.1) * 0.05f;
            for (int i = 0; i < 6; i++) {
                double a = rot + (i / 6.0) * Math.PI * 2;
                sw.spawnParticles(ParticleTypes.SOUL_FIRE_FLAME,
                        this.getX() + Math.cos(a) * radius,
                        this.getY() + Math.sin(a * 2) * radius * 0.5,
                        this.getZ() + Math.sin(a) * radius,
                        1, 0.01, 0.01, 0.01, 0.005);
            }
            if (age % 4 == 0) {
                sw.spawnParticles(ParticleTypes.END_ROD,
                        this.getX(), this.getY(), this.getZ(),
                        1, 0.01, 0.01, 0.01, 0);
            }
        }
        this.setVelocity(0, 0, 0);
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

# ================================================================
# 2. RASENSHURIKEN ENTITY (hovering + launchable)
# ================================================================
Write-File "$base\java\com\example\shinobicore\entity\RasenshurikenEntity.java" @'
package com.example.shinobicore.entity;

import com.example.shinobicore.util.TickScheduler;
import net.minecraft.entity.Entity;
import net.minecraft.entity.EntityType;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.data.DataTracker;
import net.minecraft.entity.data.TrackedData;
import net.minecraft.entity.data.TrackedDataHandlerRegistry;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.hit.BlockHitResult;
import net.minecraft.util.hit.HitResult;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.RaycastContext;
import net.minecraft.world.World;
import java.util.List;
import java.util.UUID;

public class RasenshurikenEntity extends Entity {
    private static final TrackedData<Float> DAMAGE = DataTracker.registerData(RasenshurikenEntity.class, TrackedDataHandlerRegistry.FLOAT);
    private static final TrackedData<Boolean> LAUNCHED = DataTracker.registerData(RasenshurikenEntity.class, TrackedDataHandlerRegistry.BOOLEAN);
    private UUID ownerId;
    public int age = 0;

    public RasenshurikenEntity(EntityType<?> type, World world) {
        super(type, world);
    }

    public RasenshurikenEntity(World world, LivingEntity owner, float damage) {
        super(ModEntities.RASENSHURIKEN, world);
        this.ownerId = owner.getUuid();
        this.setPosition(owner.getX(), owner.getY() + owner.getHeight() + 0.8, owner.getZ());
        this.setVelocity(0, 0, 0);
        this.velocityDirty = true;
        this.noClip = false;
        this.dataTracker.set(DAMAGE, damage);
        this.dataTracker.set(LAUNCHED, false);
    }

    @Override
    protected void initDataTracker() {
        this.dataTracker.startTracking(DAMAGE, 45f);
        this.dataTracker.startTracking(LAUNCHED, false);
    }

    public boolean isLaunched() { return this.dataTracker.get(LAUNCHED); }
    public float getDamage() { return this.dataTracker.get(DAMAGE); }

    public Entity getOwner() {
        if (ownerId == null) return null;
        if (this.getWorld() instanceof ServerWorld sw) return sw.getPlayerByUuid(ownerId);
        return null;
    }

    public void launch(Vec3d direction) {
        this.dataTracker.set(LAUNCHED, true);
        this.setVelocity(direction.multiply(2.5));
        this.velocityDirty = true;
    }

    @Override
    public void tick() {
        super.tick();
        age++;
        if (age > 600) { this.discard(); return; }

        Entity owner = getOwner();

        if (!isLaunched()) {
            // Зависание над головой — следовать за игроком
            if (owner instanceof LivingEntity liv) {
                this.setPosition(liv.getX(), liv.getY() + liv.getHeight() + 0.8, liv.getZ());
                this.setVelocity(0, 0, 0);
                // Частицы вращения
                if (this.getWorld() instanceof ServerWorld sw && age % 2 == 0) {
                    float rot = age * 0.3f;
                    for (int i = 0; i < 8; i++) {
                        double a = rot + (i / 8.0) * Math.PI * 2;
                        double r = 0.8;
                        sw.spawnParticles(ParticleTypes.CLOUD,
                                this.getX() + Math.cos(a) * r,
                                this.getY() + Math.sin(a * 2) * 0.2,
                                this.getZ() + Math.sin(a) * r,
                                1, 0.02, 0.02, 0.02, 0.01);
                    }
                }
            } else {
                this.discard();
            }
            return;
        }

        // === Летящий снаряд ===
        Vec3d vel = this.getVelocity();
        Vec3d startPos = this.getPos();
        Vec3d endPos = startPos.add(vel);

        HitResult blockHit = this.getWorld().raycast(new RaycastContext(
                startPos, endPos,
                RaycastContext.ShapeType.COLLIDER,
                RaycastContext.FluidHandling.NONE, this));

        LivingEntity hitEntity = null;
        double closestDist = Double.MAX_VALUE;
        Box searchBox = this.getBoundingBox().stretch(vel).expand(0.5);
        List<Entity> entities = this.getWorld().getOtherEntities(this, searchBox);
        for (Entity entity : entities) {
            if (entity instanceof LivingEntity living
                    && (ownerId == null || !living.getUuid().equals(ownerId))) {
                Box entityBox = entity.getBoundingBox().expand(0.3);
                var optionalHit = entityBox.raycast(startPos, endPos);
                if (optionalHit.isPresent()) {
                    double dist = startPos.squaredDistanceTo(optionalHit.get());
                    if (dist < closestDist) { closestDist = dist; hitEntity = living; }
                }
            }
        }

        if (hitEntity != null || (blockHit.getType() == HitResult.Type.BLOCK)) {
            createExpandingSphere();
            this.discard();
            return;
        }

        this.setPosition(this.getX() + vel.x, this.getY() + vel.y, this.getZ() + vel.z);

        // Частицы полёта
        if (this.getWorld() instanceof ServerWorld sw) {
            float rot = age * 0.5f;
            for (int i = 0; i < 12; i++) {
                double a = rot + (i / 12.0) * Math.PI * 2;
                double r = 1.2;
                sw.spawnParticles(ParticleTypes.CLOUD,
                        this.getX() + Math.cos(a) * r,
                        this.getY() + Math.sin(a * 3) * 0.3,
                        this.getZ() + Math.sin(a) * r,
                        2, 0.08, 0.08, 0.08, 0.04);
            }
            sw.spawnParticles(ParticleTypes.END_ROD,
                    this.getX(), this.getY(), this.getZ(),
                    1, 0.02, 0.02, 0.02, 0.01);
        }
    }

    private void createExpandingSphere() {
        if (!(this.getWorld() instanceof ServerWorld world)) return;
        final Vec3d center = this.getPos();
        final float damage = this.dataTracker.get(DAMAGE);
        final float maxRadius = 10f;
        final int duration = 60;

        world.playSound(null, this.getBlockPos(),
                net.minecraft.sound.SoundEvents.ENTITY_GENERIC_EXPLODE,
                net.minecraft.sound.SoundCategory.PLAYERS, 3.0f, 0.8f);

        for (int t = 0; t < duration; t++) {
            final int tick = t;
            TickScheduler.schedule(world, t, 1, 1, w -> {
                float expandR = maxRadius * ((float) tick / duration);
                for (int i = 0; i < 25; i++) {
                    double theta = Math.random() * Math.PI * 2;
                    double phi = Math.acos(2 * Math.random() - 1);
                    double x = center.x + expandR * Math.sin(phi) * Math.cos(theta);
                    double y = center.y + expandR * Math.cos(phi);
                    double z = center.z + expandR * Math.sin(phi) * Math.sin(theta);
                    w.spawnParticles(ParticleTypes.CLOUD, x, y, z, 2, 0.05, 0.05, 0.05, 0.03);
                    if (tick > duration / 3) {
                        w.spawnParticles(ParticleTypes.END_ROD, x, y, z, 1, 0.02, 0.02, 0.02, 0.01);
                    }
                }
                if (tick < duration / 2) {
                    w.spawnParticles(ParticleTypes.EXPLOSION_EMITTER, center.x, center.y, center.z, 1, 0, 0, 0, 0);
                }
                if (tick % 3 == 0) {
                    Entity ownerEntity = getOwner();
                    Box aoeBox = new Box(center, center).expand(expandR);
                    for (Entity e : w.getOtherEntities(ownerEntity, aoeBox)) {
                        if (e instanceof LivingEntity liv
                                && (ownerId == null || !liv.getUuid().equals(ownerId))) {
                            float dmg = damage * 0.15f * (1f - (float) tick / duration);
                            liv.damage(w.getDamageSources().magic(), dmg);
                            Vec3d kb = liv.getPos().subtract(center).normalize().multiply(0.5);
                            liv.addVelocity(kb.x, 0.2, kb.z);
                            liv.velocityModified = true;
                            liv.addStatusEffect(new net.minecraft.entity.effect.StatusEffectInstance(
                                    net.minecraft.entity.effect.StatusEffects.SLOWNESS, 40, 2, false, false));
                            liv.addStatusEffect(new net.minecraft.entity.effect.StatusEffectInstance(
                                    net.minecraft.entity.effect.StatusEffects.WEAKNESS, 40, 1, false, false));
                        }
                    }
                }
            });
        }
    }

    @Override
    protected void readCustomDataFromNbt(NbtCompound nbt) {
        this.dataTracker.set(DAMAGE, nbt.getFloat("Damage"));
        this.dataTracker.set(LAUNCHED, nbt.getBoolean("Launched"));
        if (nbt.containsUuid("OwnerUUID")) ownerId = nbt.getUuid("OwnerUUID");
    }

    @Override
    protected void writeCustomDataToNbt(NbtCompound nbt) {
        nbt.putFloat("Damage", this.dataTracker.get(DAMAGE));
        nbt.putBoolean("Launched", this.dataTracker.get(LAUNCHED));
        if (ownerId != null) nbt.putUuid("OwnerUUID", ownerId);
    }
}
'@

# ================================================================
# 3. RASENGAN HAND RENDERER (3D sphere + rings)
# ================================================================
Write-File "$base\java\com\example\shinobicore\entity\RasenganHandRenderer.java" @'
package com.example.shinobicore.entity;

import net.minecraft.client.render.OverlayTexture;
import net.minecraft.client.render.RenderLayer;
import net.minecraft.client.render.VertexConsumer;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.render.entity.EntityRenderer;
import net.minecraft.client.render.entity.EntityRendererFactory;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.RotationAxis;
import org.joml.Matrix4f;

public class RasenganHandRenderer extends EntityRenderer<RasenganHandEntity> {
    private static final Identifier TEX = new Identifier("textures/misc/white.png");

    public RasenganHandRenderer(EntityRendererFactory.Context ctx) { super(ctx); }

    @Override
    public void render(RasenganHandEntity entity, float yaw, float tickDelta,
                       MatrixStack matrices, VertexConsumerProvider vc, int light) {
        super.render(entity, yaw, tickDelta, matrices, vc, light);
        matrices.push();

        float pulse = 0.9f + 0.1f * (float) Math.sin((entity.age + tickDelta) * 0.15);
        matrices.scale(pulse, pulse, pulse);

        float rotation = (entity.age + tickDelta) * 8f;
        matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(rotation));

        // ЯДРО
        renderSphere(matrices, vc, 0.2f, 0.3f, 0.6f, 1.0f, 0.95f, light);
        // ОБОЛОЧКА
        renderSphere(matrices, vc, 0.3f, 0.2f, 0.4f, 0.9f, 0.5f, light);

        // КОЛЬЦО 1
        float ringRot = (entity.age + tickDelta) * 12f;
        matrices.push();
        matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(ringRot));
        renderRing(matrices, vc, 0.25f, 0.03f, 0.6f, 0.8f, 1.0f, 0.8f, light);
        matrices.pop();

        // КОЛЬЦО 2
        matrices.push();
        matrices.multiply(RotationAxis.POSITIVE_Z.rotationDegrees(ringRot * 0.7f));
        renderRing(matrices, vc, 0.22f, 0.02f, 0.4f, 0.6f, 1.0f, 0.6f, light);
        matrices.pop();

        // СВЕЧЕНИЕ
        renderSphere(matrices, vc, 0.4f, 0.3f, 0.5f, 1.0f, 0.2f, light);

        matrices.pop();
    }

    private void renderSphere(MatrixStack matrices, VertexConsumerProvider vc,
                              float radius, float r, float g, float b, float a, int light) {
        VertexConsumer consumer = vc.getBuffer(RenderLayer.getEntityTranslucent(TEX));
        float half = radius;
        for (int i = 0; i < 3; i++) {
            float angle = i * 60f;
            matrices.push();
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(angle));
            Matrix4f m = matrices.peek().getPositionMatrix();
            emitQuad(consumer, m, -half, -half, 0, half, -half, 0, half, half, 0, -half, half, 0, r, g, b, a, light);
            matrices.pop();
        }
        matrices.push();
        matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(90));
        Matrix4f mH = matrices.peek().getPositionMatrix();
        emitQuad(consumer, mH, -half, -half, 0, half, -half, 0, half, half, 0, -half, half, 0, r, g, b, a, light);
        matrices.pop();
    }

    private void renderRing(MatrixStack matrices, VertexConsumerProvider vc,
                            float radius, float thickness, float r, float g, float b, float a, int light) {
        VertexConsumer consumer = vc.getBuffer(RenderLayer.getEntityTranslucent(TEX));
        int segments = 12;
        for (int i = 0; i < segments; i++) {
            float a1 = (float)(i * 2 * Math.PI / segments);
            float a2 = (float)((i + 1) * 2 * Math.PI / segments);
            float x1 = (float) Math.cos(a1) * radius;
            float z1 = (float) Math.sin(a1) * radius;
            float x2 = (float) Math.cos(a2) * radius;
            float z2 = (float) Math.sin(a2) * radius;
            float ix1 = (float) Math.cos(a1) * (radius - thickness);
            float iz1 = (float) Math.sin(a1) * (radius - thickness);
            float ix2 = (float) Math.cos(a2) * (radius - thickness);
            float iz2 = (float) Math.sin(a2) * (radius - thickness);
            Matrix4f m = matrices.peek().getPositionMatrix();
            emitQuad(consumer, m, x1, thickness, z1, x2, thickness, z2, ix2, thickness, iz2, ix1, thickness, iz1, r, g, b, a, light);
            emitQuad(consumer, m, ix1, -thickness, iz1, ix2, -thickness, iz2, x2, -thickness, z2, x1, -thickness, z1, r, g, b, a, light);
        }
    }

    private void emitQuad(VertexConsumer consumer, Matrix4f matrix,
                          float x1, float y1, float z1, float x2, float y2, float z2,
                          float x3, float y3, float z3, float x4, float y4, float z4,
                          float r, float g, float b, float a, int light) {
        vertex(consumer, matrix, x1, y1, z1, 0, 1, r, g, b, a, light);
        vertex(consumer, matrix, x2, y2, z2, 1, 1, r, g, b, a, light);
        vertex(consumer, matrix, x3, y3, z3, 1, 0, r, g, b, a, light);
        vertex(consumer, matrix, x4, y4, z4, 0, 0, r, g, b, a, light);
        vertex(consumer, matrix, x4, y4, z4, 0, 0, r, g, b, a, light);
        vertex(consumer, matrix, x3, y3, z3, 1, 0, r, g, b, a, light);
        vertex(consumer, matrix, x2, y2, z2, 1, 1, r, g, b, a, light);
        vertex(consumer, matrix, x1, y1, z1, 0, 1, r, g, b, a, light);
    }

    private void vertex(VertexConsumer consumer, Matrix4f matrix,
                        float x, float y, float z, float u, float v,
                        float r, float g, float b, float a, int light) {
        consumer.vertex(matrix, x, y, z).color(r, g, b, a).texture(u, v)
                .overlay(OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
    }

    @Override
    public Identifier getTexture(RasenganHandEntity entity) { return TEX; }
}
'@

# ================================================================
# 4. RASENSHURIKEN RENDERER (4 blades + sphere)
# ================================================================
Write-File "$base\java\com\example\shinobicore\entity\RasenshurikenRenderer.java" @'
package com.example.shinobicore.entity;

import net.minecraft.client.render.OverlayTexture;
import net.minecraft.client.render.RenderLayer;
import net.minecraft.client.render.VertexConsumer;
import net.minecraft.client.render.VertexConsumerProvider;
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
        matrices.translate(0, 0.3, 0);

        float rotation = (entity.age + tickDelta) * 15f;
        matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(rotation));

        // 4 ЛЕЗВИЯ
        for (int i = 0; i < 4; i++) {
            matrices.push();
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(i * 90));
            Matrix4f m = matrices.peek().getPositionMatrix();
            float len = 1.5f;
            float width = 0.3f;
            VertexConsumer consumer = vc.getBuffer(RenderLayer.getEntityTranslucent(TEX));
            // Верхняя грань
            emitQuad(consumer, m, 0, 0.05f, 0, len, 0.05f, -width, len, 0.05f, width, 0, 0.05f, 0, 0.3f, 0.6f, 1.0f, 0.9f, light);
            // Нижняя грань
            emitQuad(consumer, m, 0, -0.05f, 0, len, -0.05f, width, len, -0.05f, -width, 0, -0.05f, 0, 0.2f, 0.4f, 0.9f, 0.8f, light);
            // Передняя грань
            emitQuad(consumer, m, 0, -0.05f, 0, len, -0.05f, -width, len, 0.05f, -width, 0, 0.05f, 0, 0.4f, 0.7f, 1.0f, 0.85f, light);
            // Задняя грань
            emitQuad(consumer, m, 0, 0.05f, 0, len, 0.05f, width, len, -0.05f, width, 0, -0.05f, 0, 0.4f, 0.7f, 1.0f, 0.85f, light);
            matrices.pop();
        }

        // ЦЕНТРАЛЬНАЯ СФЕРА
        renderSphere(matrices, vc, 0.35f, 0.2f, 0.5f, 1.0f, 0.95f, light);
        // КОЛЬЦО
        renderRing(matrices, vc, 0.6f, 0.08f, 0.5f, 0.8f, 1.0f, 0.7f, light);
        // СВЕЧЕНИЕ
        renderSphere(matrices, vc, 0.55f, 0.3f, 0.6f, 1.0f, 0.3f, light);

        matrices.pop();
    }

    private void renderSphere(MatrixStack matrices, VertexConsumerProvider vc,
                              float radius, float r, float g, float b, float a, int light) {
        VertexConsumer consumer = vc.getBuffer(RenderLayer.getEntityTranslucent(TEX));
        float half = radius;
        for (int i = 0; i < 3; i++) {
            float angle = i * 60f;
            matrices.push();
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(angle));
            Matrix4f m = matrices.peek().getPositionMatrix();
            emitQuad(consumer, m, -half, -half, 0, half, -half, 0, half, half, 0, -half, half, 0, r, g, b, a, light);
            matrices.pop();
        }
        matrices.push();
        matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(90));
        Matrix4f mH = matrices.peek().getPositionMatrix();
        emitQuad(consumer, mH, -half, -half, 0, half, -half, 0, half, half, 0, -half, half, 0, r, g, b, a, light);
        matrices.pop();
    }

    private void renderRing(MatrixStack matrices, VertexConsumerProvider vc,
                            float radius, float thickness, float r, float g, float b, float a, int light) {
        VertexConsumer consumer = vc.getBuffer(RenderLayer.getEntityTranslucent(TEX));
        int segments = 16;
        for (int i = 0; i < segments; i++) {
            float a1 = (float)(i * 2 * Math.PI / segments);
            float a2 = (float)((i + 1) * 2 * Math.PI / segments);
            float x1 = (float) Math.cos(a1) * radius;
            float z1 = (float) Math.sin(a1) * radius;
            float x2 = (float) Math.cos(a2) * radius;
            float z2 = (float) Math.sin(a2) * radius;
            float ix1 = (float) Math.cos(a1) * (radius - thickness);
            float iz1 = (float) Math.sin(a1) * (radius - thickness);
            float ix2 = (float) Math.cos(a2) * (radius - thickness);
            float iz2 = (float) Math.sin(a2) * (radius - thickness);
            Matrix4f m = matrices.peek().getPositionMatrix();
            emitQuad(consumer, m, x1, thickness, z1, x2, thickness, z2, ix2, thickness, iz2, ix1, thickness, iz1, r, g, b, a, light);
            emitQuad(consumer, m, ix1, -thickness, iz1, ix2, -thickness, iz2, x2, -thickness, z2, x1, -thickness, z1, r, g, b, a, light);
        }
    }

    private void emitQuad(VertexConsumer consumer, Matrix4f matrix,
                          float x1, float y1, float z1, float x2, float y2, float z2,
                          float x3, float y3, float z3, float x4, float y4, float z4,
                          float r, float g, float b, float a, int light) {
        vertex(consumer, matrix, x1, y1, z1, 0, 1, r, g, b, a, light);
        vertex(consumer, matrix, x2, y2, z2, 1, 1, r, g, b, a, light);
        vertex(consumer, matrix, x3, y3, z3, 1, 0, r, g, b, a, light);
        vertex(consumer, matrix, x4, y4, z4, 0, 0, r, g, b, a, light);
        vertex(consumer, matrix, x4, y4, z4, 0, 0, r, g, b, a, light);
        vertex(consumer, matrix, x3, y3, z3, 1, 0, r, g, b, a, light);
        vertex(consumer, matrix, x2, y2, z2, 1, 1, r, g, b, a, light);
        vertex(consumer, matrix, x1, y1, z1, 0, 1, r, g, b, a, light);
    }

    private void vertex(VertexConsumer consumer, Matrix4f matrix,
                        float x, float y, float z, float u, float v,
                        float r, float g, float b, float a, int light) {
        consumer.vertex(matrix, x, y, z).color(r, g, b, a).texture(u, v)
                .overlay(OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
    }

    @Override
    public Identifier getTexture(RasenshurikenEntity entity) { return TEX; }
}
'@

# ================================================================
# 5. PATCH: ShinobiCoreClient.java — register renderers
# ================================================================
$sccPath = "$base\java\com\example\shinobicore\client\ShinobiCoreClient.java"
$scc = [System.IO.File]::ReadAllText($sccPath, $utf8)

if (-not $scc.Contains("RasenshurikenRenderer")) {
    $scc = $scc.Replace(
        "EntityRendererRegistry.register(ModEntities.SHURIKEN, ShurikenRenderer::new);",
        "EntityRendererRegistry.register(ModEntities.SHURIKEN, ShurikenRenderer::new);`n" +
        "        EntityRendererRegistry.register(ModEntities.RASENSHURIKEN, com.example.shinobicore.entity.RasenshurikenRenderer::new);`n" +
        "        EntityRendererRegistry.register(ModEntities.RASENGAN_HAND, com.example.shinobicore.entity.RasenganHandRenderer::new);"
    )
    [System.IO.File]::WriteAllText($sccPath, $scc, $utf8)
    Write-Host "[OK] ShinobiCoreClient: renderers registered" -ForegroundColor Green
} else {
    Write-Host "[SKIP] Renderers already registered" -ForegroundColor Yellow
}

# ================================================================
# 6. PATCH: ShinobiCore.java — server packet handlers
# ================================================================
$scPath = "$base\java\com\example\shinobicore\ShinobiCore.java"
$sc = [System.IO.File]::ReadAllText($scPath, $utf8)

if (-not $sc.Contains("THROW_RASENSHURIKEN_ID")) {
    # Add imports
    if (-not $sc.Contains("import com.example.shinobicore.entity.RasenshurikenEntity")) {
        $sc = $sc.Replace(
            "import com.example.shinobicore.stat.NinjaPlayerData;",
            "import com.example.shinobicore.stat.NinjaPlayerData;`n" +
            "import com.example.shinobicore.entity.RasenshurikenEntity;`n" +
            "import com.example.shinobicore.entity.RasenganHandEntity;"
        )
    }

    $handlerCode = @'

        // === RASENSHURIKEN THROW HANDLER ===
        ServerPlayNetworking.registerGlobalReceiver(ModPackets.THROW_RASENSHURIKEN_ID,
                (server, player, handler, buf, responseSender) -> {
                    server.execute(() -> {
                        for (var e : player.getWorld().getOtherEntities(player,
                                player.getBoundingBox().expand(3))) {
                            if (e instanceof RasenshurikenEntity rs && !rs.isLaunched()) {
                                Vec3d dir = player.getRotationVector();
                                rs.launch(dir);
                                ShinobiCore.LOGGER.info("[SERVER] Rasenshuriken launched by {}",
                                        player.getName().getString());
                                break;
                            }
                        }
                    });
                });

        // === RASENGAN STRIKE HANDLER ===
        ServerPlayNetworking.registerGlobalReceiver(ModPackets.RASENGAN_STRIKE_ID,
                (server, player, handler, buf, responseSender) -> {
                    server.execute(() -> {
                        RasenganHandEntity rasengan = null;
                        for (var e : player.getWorld().getOtherEntities(player,
                                player.getBoundingBox().expand(3))) {
                            if (e instanceof RasenganHandEntity rg) {
                                rasengan = rg;
                                break;
                            }
                        }
                        if (rasengan != null) {
                            float damage = rasengan.getDamage();
                            Vec3d look = player.getRotationVector();
                            Vec3d strikeCenter = player.getPos().add(look.multiply(1.5)).add(0, 0.5, 0);
                            float radius = 2.5f;
                            for (var e : player.getWorld().getOtherEntities(player,
                                    new net.minecraft.util.math.Box(strikeCenter, strikeCenter).expand(radius))) {
                                if (e instanceof net.minecraft.entity.LivingEntity liv) {
                                    liv.damage(player.getDamageSources().magic(), damage);
                                    Vec3d kb = liv.getPos().subtract(player.getPos()).normalize().multiply(2.0);
                                    liv.addVelocity(kb.x, 0.5, kb.z);
                                    liv.velocityModified = true;
                                }
                            }
                            if (player.getWorld() instanceof net.minecraft.server.world.ServerWorld sw) {
                                for (int i = 0; i < 40; i++) {
                                    double a = (i / 40.0) * Math.PI * 2;
                                    double r = radius * Math.random();
                                    sw.spawnParticles(net.minecraft.particle.ParticleTypes.CLOUD,
                                            strikeCenter.x + Math.cos(a) * r,
                                            strikeCenter.y + Math.random() * 1.5,
                                            strikeCenter.z + Math.sin(a) * r,
                                            3, 0.1, 0.1, 0.1, 0.05);
                                }
                                sw.spawnParticles(net.minecraft.particle.ParticleTypes.EXPLOSION,
                                        strikeCenter.x, strikeCenter.y, strikeCenter.z,
                                        2, 0.3, 0.3, 0.3, 0.02);
                                sw.playSound(null, player.getBlockPos(),
                                        net.minecraft.sound.SoundEvents.ENTITY_GENERIC_EXPLODE,
                                        net.minecraft.sound.SoundCategory.PLAYERS, 1.5f, 1.2f);
                            }
                            rasengan.discard();
                            ShinobiCore.LOGGER.info("[SERVER] Rasengan strike by {}",
                                    player.getName().getString());
                        }
                    });
                });
'@

    # Insert handlers after ModConfig.load() or before last }
    if ($sc.Contains("ModConfig.load();")) {
        $sc = $sc.Replace("ModConfig.load();", "ModConfig.load();" + $handlerCode)
    } else {
        $lastBrace = $sc.LastIndexOf("}")
        $sc = $sc.Insert($lastBrace, $handlerCode + "`n")
    }

    # Add ServerPlayNetworking import if missing
    if (-not $sc.Contains("import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking")) {
        $sc = $sc.Replace(
            "import net.fabricmc.api.ModInitializer;",
            "import net.fabricmc.api.ModInitializer;`n" +
            "import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;`n" +
            "import net.minecraft.util.math.Vec3d;"
        )
    }

    [System.IO.File]::WriteAllText($scPath, $sc, $utf8)
    Write-Host "[OK] ShinobiCore: server handlers added" -ForegroundColor Green
} else {
    Write-Host "[SKIP] Server handlers already exist" -ForegroundColor Yellow
}

# ================================================================
# 7. PATCH: ModPackets.java — ensure packet IDs exist
# ================================================================
$mpPath = "$base\java\com\example\shinobicore\network\ModPackets.java"
$mp = [System.IO.File]::ReadAllText($mpPath, $utf8)

if (-not $mp.Contains("THROW_RASENSHURIKEN_ID")) {
    $newPackets = @'
    public static final Identifier THROW_RASENSHURIKEN_ID = new Identifier("shinobicore", "throw_rasenshuriken");
    public static final Identifier RASENGAN_STRIKE_ID = new Identifier("shinobicore", "rasengan_strike");
'@
    $lastBrace = $mp.LastIndexOf("}")
    $mp = $mp.Insert($lastBrace, $newPackets + "`n")
    [System.IO.File]::WriteAllText($mpPath, $mp, $utf8)
    Write-Host "[OK] ModPackets: packet IDs added" -ForegroundColor Green
} else {
    Write-Host "[SKIP] Packet IDs already exist" -ForegroundColor Yellow
}

# ================================================================
# 8. PATCH: ClientInputHandler.java — RMB/LMB handling
# ================================================================
$cihPath = "$base\java\com\example\shinobicore\client\ClientInputHandler.java"
$cih = [System.IO.File]::ReadAllText($cihPath, $utf8)

# Add imports
if (-not $cih.Contains("import com.example.shinobicore.entity.RasenshurikenEntity")) {
    $cih = $cih.Replace(
        "import com.example.shinobicore.ShinobiCore;",
        "import com.example.shinobicore.ShinobiCore;`n" +
        "import com.example.shinobicore.entity.RasenshurikenEntity;`n" +
        "import com.example.shinobicore.entity.RasenganHandEntity;"
    )
}

# Add prevRmbDown/prevLmbDown fields
if (-not $cih.Contains("prevRmbDown")) {
    $cih = $cih.Replace(
        "private static boolean prevDeflectDown = false;",
        "private static boolean prevDeflectDown = false;`n" +
        "    private static boolean prevRmbDown = false;`n" +
        "    private static boolean prevLmbDown = false;"
    )
}

# Add RMB/LMB handling before CRAWL check
if (-not $cih.Contains("prevRmbDown = rmbDown")) {
    $rmbLmbCode = @'
        // === RMB: throw rasenshuriken ===
        boolean rmbDown = client.options.useKey.isPressed();
        if (rmbDown && !prevRmbDown) {
            boolean hasRs = false;
            if (client.world != null && client.player != null) {
                for (var e : client.world.getOtherEntities(client.player,
                        client.player.getBoundingBox().expand(3))) {
                    if (e instanceof RasenshurikenEntity rs && !rs.isLaunched()) {
                        hasRs = true;
                        break;
                    }
                }
            }
            if (hasRs) {
                PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
                ClientPlayNetworking.send(ModPackets.THROW_RASENSHURIKEN_ID, buf);
                ShinobiCore.LOGGER.info("[INPUT] RMB: throwing rasenshuriken");
            }
        }
        prevRmbDown = rmbDown;

        // === LMB: rasengan strike ===
        boolean lmbDown = client.options.attackKey.isPressed();
        if (lmbDown && !prevLmbDown) {
            boolean hasRg = false;
            if (client.world != null && client.player != null) {
                for (var e : client.world.getOtherEntities(client.player,
                        client.player.getBoundingBox().expand(3))) {
                    if (e instanceof RasenganHandEntity) {
                        hasRg = true;
                        break;
                    }
                }
            }
            if (hasRg) {
                PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
                ClientPlayNetworking.send(ModPackets.RASENGAN_STRIKE_ID, buf);
                ShinobiCore.LOGGER.info("[INPUT] LMB: rasengan strike");
            }
        }
        prevLmbDown = lmbDown;

'@
    $cih = $cih.Replace(
        "if (KeyBindings.CRAWL.wasPressed()) ShinobiCore.LOGGER.info(""[INPUT] CRAWL (N) pressed"");",
        $rmbLmbCode + "        if (KeyBindings.CRAWL.wasPressed()) ShinobiCore.LOGGER.info(""[INPUT] CRAWL (N) pressed"");"
    )
    [System.IO.File]::WriteAllText($cihPath, $cih, $utf8)
    Write-Host "[OK] ClientInputHandler: RMB/LMB handlers added" -ForegroundColor Green
} else {
    Write-Host "[SKIP] ClientInputHandler already has handlers" -ForegroundColor Yellow
}

# ================================================================
# 9. PATCH: ModEntities.java — ensure entities registered
# ================================================================
$mePath = "$base\java\com\example\shinobicore\entity\ModEntities.java"
$me = [System.IO.File]::ReadAllText($mePath, $utf8)

if (-not $me.Contains("RASENSHURIKEN")) {
    $newEntities = @'
    public static final EntityType<RasenshurikenEntity> RASENSHURIKEN = Registry.register(
            Registries.ENTITY_TYPE,
            new Identifier(ShinobiCore.MOD_ID, "rasenshuriken"),
            FabricEntityTypeBuilder.<RasenshurikenEntity>create(SpawnGroup.MISC, RasenshurikenEntity::new)
                    .dimensions(EntityDimensions.fixed(1.5f, 1.5f))
                    .trackRangeChunks(64)
                    .trackedUpdateRate(2)
                    .build()
    );

    public static final EntityType<RasenganHandEntity> RASENGAN_HAND = Registry.register(
            Registries.ENTITY_TYPE,
            new Identifier(ShinobiCore.MOD_ID, "rasengan_hand"),
            FabricEntityTypeBuilder.<RasenganHandEntity>create(SpawnGroup.MISC, RasenganHandEntity::new)
                    .dimensions(EntityDimensions.fixed(0.5f, 0.5f))
                    .trackRangeChunks(32)
                    .trackedUpdateRate(1)
                    .build()
    );

'@
    $me = $me.Replace("public static void register() {", $newEntities + "    public static void register() {")
    [System.IO.File]::WriteAllText($mePath, $me, $utf8)
    Write-Host "[OK] ModEntities: RASENSHURIKEN + RASENGAN_HAND registered" -ForegroundColor Green
} else {
    Write-Host "[SKIP] Entities already registered" -ForegroundColor Yellow
}

# ================================================================
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║              ALL FIXES APPLIED!                          ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "Что исправлено:" -ForegroundColor White
Write-Host "  1. RasenganHandEntity — 3D сфера в руке + кольца" -ForegroundColor White
Write-Host "  2. RasenshurikenEntity — 4 лезвия + сфера, зависание над головой" -ForegroundColor White
Write-Host "  3. RasenganHandRenderer — 3D рендерер сферы" -ForegroundColor White
Write-Host "  4. RasenshurikenRenderer — 3D рендерер сюрикена" -ForegroundColor White
Write-Host "  5. ShinobiCoreClient — рендереры зарегистрированы" -ForegroundColor White
Write-Host "  6. ShinobiCore — серверные обработчики ПКМ/ЛКМ" -ForegroundColor White
Write-Host "  7. ModPackets — ID пакетов" -ForegroundColor White
Write-Host "  8. ClientInputHandler — детект ПКМ/ЛКМ + отправка пакетов" -ForegroundColor White
Write-Host "  9. ModEntities — регистрация сущностей" -ForegroundColor White
Write-Host ""
Write-Host "Запуск: .\gradlew.bat build" -ForegroundColor Yellow
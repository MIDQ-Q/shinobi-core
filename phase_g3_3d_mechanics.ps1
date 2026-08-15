$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main"
$java = "$base\java\com\example\shinobicore"
$res = "$base\resources\data\shinobicore\jutsu"

function Write-File($p, $c) {
    $dir = [System.IO.Path]::GetDirectoryName($p)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] $($p.Replace($base, ''))" -ForegroundColor Green
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "  PHASE G3: PROCEDURAL 3D MODELS & UNIQUE MECHANICS" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

# ==========================================
# 1. NinjaProjectileEntity (Добавляем уникальные эффекты при ударе)
# ==========================================
Write-File "$java\entity\NinjaProjectileEntity.java" @'
package com.example.shinobicore.entity;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.combat.MarkTracker;
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
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.hit.BlockHitResult;
import net.minecraft.util.hit.HitResult;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.RaycastContext;
import net.minecraft.world.World;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

public class NinjaProjectileEntity extends Entity {
    private static final TrackedData<Float> DAMAGE = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.FLOAT);
    private static final TrackedData<Float> RADIUS = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.FLOAT);
    private static final TrackedData<String> PARTICLE_TYPE = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.STRING);
    private static final TrackedData<String> MODEL_TYPE = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.STRING);
    private static final TrackedData<Integer> LIFETIME = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.INTEGER);
    private static final TrackedData<Boolean> HAS_GRAVITY = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.BOOLEAN);
    private static final TrackedData<Integer> PIERCE_COUNT = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.INTEGER);
    private static final TrackedData<Integer> BOUNCE_COUNT = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.INTEGER);

    public float getRadius() { return this.dataTracker.get(RADIUS); }
    public String getParticleType() { return this.dataTracker.get(PARTICLE_TYPE); }
    public String getModelType() { return this.dataTracker.get(MODEL_TYPE); }
    
    public int age = 0;
    private UUID ownerId;
    private int pierceRemaining = 0;
    private int bounceRemaining = 0;

    public NinjaProjectileEntity(EntityType<?> type, World world) { super(type, world); }

    public NinjaProjectileEntity(World world, LivingEntity owner, Vec3d velocity, float damage, float radius, String particle, String model, int lifetime) {
        super(ModEntities.NINJA_PROJECTILE, world);
        this.ownerId = owner.getUuid();
        this.setPosition(owner.getX(), owner.getEyeY() - 0.2, owner.getZ());
        this.setVelocity(velocity);
        this.velocityDirty = true;
        this.noClip = false;
        this.dataTracker.set(DAMAGE, damage);
        this.dataTracker.set(RADIUS, radius);
        this.dataTracker.set(PARTICLE_TYPE, particle);
        this.dataTracker.set(MODEL_TYPE, model != null ? model : "sphere");
        this.dataTracker.set(LIFETIME, lifetime);
    }

    public void setHasGravity(boolean gravity) { this.dataTracker.set(HAS_GRAVITY, gravity); }
    public void setPierceCount(int count) { this.dataTracker.set(PIERCE_COUNT, count); this.pierceRemaining = count; }
    public void setBounceCount(int count) { this.dataTracker.set(BOUNCE_COUNT, count); this.bounceRemaining = count; }

    @Override
    protected void initDataTracker() {
        this.dataTracker.startTracking(DAMAGE, 5f);
        this.dataTracker.startTracking(RADIUS, 1f);
        this.dataTracker.startTracking(PARTICLE_TYPE, "flame");
        this.dataTracker.startTracking(MODEL_TYPE, "sphere");
        this.dataTracker.startTracking(LIFETIME, 100);
        this.dataTracker.startTracking(HAS_GRAVITY, false);
        this.dataTracker.startTracking(PIERCE_COUNT, 0);
        this.dataTracker.startTracking(BOUNCE_COUNT, 0);
    }

    public Entity getOwner() {
        if (ownerId == null) return null;
        if (this.getWorld() instanceof ServerWorld sw) return sw.getPlayerByUuid(ownerId);
        return null;
    }

    @Override
    public void tick() {
        super.tick();
        age++;
        if (age > this.dataTracker.get(LIFETIME)) { this.discard(); return; }

        Vec3d vel = this.getVelocity();
        if (this.dataTracker.get(HAS_GRAVITY)) {
            vel = new Vec3d(vel.x, vel.y - 0.04, vel.z);
            this.setVelocity(vel);
        }

        Vec3d startPos = this.getPos();
        Vec3d endPos = startPos.add(vel);
        HitResult blockHit = this.getWorld().raycast(new RaycastContext(startPos, endPos, RaycastContext.ShapeType.COLLIDER, RaycastContext.FluidHandling.NONE, this));
        
        LivingEntity hitEntity = null;
        double closestDist = Double.MAX_VALUE;
        Box searchBox = this.getBoundingBox().stretch(vel).expand(0.15);
        List<Entity> entities = this.getWorld().getOtherEntities(this, searchBox);

        for (Entity entity : entities) {
            if (entity instanceof LivingEntity living && !living.getUuid().equals(this.ownerId)) {
                Box entityBox = entity.getBoundingBox().expand(0.3);
                var optionalHit = entityBox.raycast(startPos, endPos);
                if (optionalHit.isPresent()) {
                    double dist = startPos.squaredDistanceTo(optionalHit.get());
                    if (dist < closestDist) { closestDist = dist; hitEntity = living; }
                }
            }
        }

        boolean hit = false;
        if (hitEntity != null) {
            float damage = this.dataTracker.get(DAMAGE);
            hitEntity.damage(this.getDamageSources().magic(), MarkTracker.boost(hitEntity, damage));
            if (pierceRemaining > 0) { pierceRemaining--; } else { hit = true; }
        }

        if (blockHit.getType() == HitResult.Type.BLOCK && !hit) {
            BlockHitResult bhr = (BlockHitResult) blockHit;
            if (bounceRemaining > 0) {
                bounceRemaining--;
                Vec3d normal = Vec3d.of(bhr.getSide().getVector());
                double dot = vel.dotProduct(normal);
                Vec3d reflected = vel.subtract(normal.multiply(2 * dot)).multiply(0.7);
                this.setVelocity(reflected);
                this.setPosition(bhr.getPos().add(normal.multiply(0.01)));
                return;
            } else { hit = true; }
        }

        if (hit) {
            float radius = this.dataTracker.get(RADIUS);
            float damage = this.dataTracker.get(DAMAGE);
            String model = this.dataTracker.get(MODEL_TYPE);

            if (radius > 0.5f) {
                for (Entity entity : this.getWorld().getOtherEntities(this, this.getBoundingBox().expand(radius))) {
                    if (entity instanceof LivingEntity living && !living.getUuid().equals(this.ownerId)) {
                        living.damage(this.getDamageSources().magic(), damage * 0.5f);
                    }
                }
            }

            // === UNIQUE IMPACT MECHANICS ===
            if (this.getWorld() instanceof ServerWorld sw) {
                if ("water_dragon".equals(model)) {
                    // Water Puddle
                    BlockPos impactPos = this.getBlockPos();
                    List<net.minecraft.util.math.BlockPos> placed = new ArrayList<>();
                    for (int dx = -2; dx <= 2; dx++) {
                        for (int dz = -2; dz <= 2; dz++) {
                            if (dx*dx + dz*dz <= 5) {
                                BlockPos p = impactPos.add(dx, 0, dz);
                                if (sw.getBlockState(p).isAir()) {
                                    sw.setBlockState(p, Blocks.WATER.getDefaultState(), 3);
                                    placed.add(p);
                                }
                            }
                        }
                    }
                    if (!placed.isEmpty()) com.example.shinobicore.jutsu.WallRemovalTask.schedule(sw, placed, 200);
                } else if ("earth_dragon".equals(model)) {
                    // Mud Pit (Slowness + Fatigue)
                    BlockPos impactPos = this.getBlockPos();
                    Box aoe = new Box(impactPos, impactPos).expand(3.0);
                    for (Entity e : sw.getOtherEntities(this, aoe)) {
                        if (e instanceof LivingEntity liv && !liv.getUuid().equals(this.ownerId)) {
                            liv.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, 100, 2, false, false));
                            liv.addStatusEffect(new StatusEffectInstance(StatusEffects.MINING_FATIGUE, 100, 1, false, false));
                        }
                    }
                } else if ("blade".equals(model)) {
                    // Bleed (Wither)
                    if (hitEntity != null) {
                        hitEntity.addStatusEffect(new StatusEffectInstance(StatusEffects.WITHER, 60, 1, false, false));
                    }
                } else if ("hound".equals(model)) {
                    // Paralysis
                    if (hitEntity != null) {
                        hitEntity.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, 80, 4, false, false));
                        hitEntity.addStatusEffect(new StatusEffectInstance(StatusEffects.MINING_FATIGUE, 80, 4, false, false));
                        hitEntity.addStatusEffect(new StatusEffectInstance(StatusEffects.WEAKNESS, 80, 2, false, false));
                    }
                }
            }
            this.discard();
            return;
        }

        this.setPosition(this.getX() + vel.x, this.getY() + vel.y, this.getZ() + vel.z);
        
        if (this.getWorld() instanceof ServerWorld serverWorld && age % 2 == 0) {
            String particle = this.dataTracker.get(PARTICLE_TYPE);
            net.minecraft.particle.ParticleEffect particleType = switch (particle) {
                case "water" -> net.minecraft.particle.ParticleTypes.FALLING_WATER;
                case "smoke" -> net.minecraft.particle.ParticleTypes.SMOKE;
                case "lightning" -> net.minecraft.particle.ParticleTypes.ELECTRIC_SPARK;
                case "wind" -> net.minecraft.particle.ParticleTypes.CLOUD;
                case "earth" -> net.minecraft.particle.ParticleTypes.POOF;
                default -> net.minecraft.particle.ParticleTypes.FLAME;
            };
            serverWorld.spawnParticles(particleType, this.getX(), this.getY(), this.getZ(), 1, 0.01, 0.01, 0.01, 0.01);
        }
    }

    @Override protected void readCustomDataFromNbt(NbtCompound nbt) {
        this.dataTracker.set(DAMAGE, nbt.getFloat("Damage"));
        this.dataTracker.set(RADIUS, nbt.getFloat("Radius"));
        this.dataTracker.set(PARTICLE_TYPE, nbt.getString("Particle"));
        this.dataTracker.set(MODEL_TYPE, nbt.getString("Model"));
        this.dataTracker.set(LIFETIME, nbt.getInt("Lifetime"));
        this.dataTracker.set(HAS_GRAVITY, nbt.getBoolean("HasGravity"));
        this.dataTracker.set(PIERCE_COUNT, nbt.getInt("PierceCount"));
        this.dataTracker.set(BOUNCE_COUNT, nbt.getInt("BounceCount"));
        this.pierceRemaining = this.dataTracker.get(PIERCE_COUNT);
        this.bounceRemaining = this.dataTracker.get(BOUNCE_COUNT);
        if (nbt.containsUuid("OwnerUUID")) ownerId = nbt.getUuid("OwnerUUID");
    }

    @Override protected void writeCustomDataToNbt(NbtCompound nbt) {
        nbt.putFloat("Damage", this.dataTracker.get(DAMAGE));
        nbt.putFloat("Radius", this.dataTracker.get(RADIUS));
        nbt.putString("Particle", this.dataTracker.get(PARTICLE_TYPE));
        nbt.putString("Model", this.dataTracker.get(MODEL_TYPE));
        nbt.putInt("Lifetime", this.dataTracker.get(LIFETIME));
        nbt.putBoolean("HasGravity", this.dataTracker.get(HAS_GRAVITY));
        nbt.putInt("PierceCount", this.dataTracker.get(PIERCE_COUNT));
        nbt.putInt("BounceCount", this.dataTracker.get(BOUNCE_COUNT));
        if (ownerId != null) nbt.putUuid("OwnerUUID", ownerId);
    }
}
'@

# ==========================================
# 2. NinjaProjectileRenderer (Процедурные 3D модели)
# ==========================================
Write-File "$java\entity\NinjaProjectileRenderer.java" @'
package com.example.shinobicore.entity;

import net.minecraft.client.render.OverlayTexture;
import net.minecraft.client.render.RenderLayer;
import net.minecraft.client.render.VertexConsumer;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.render.entity.EntityRenderer;
import net.minecraft.client.render.entity.EntityRendererFactory;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.MathHelper;
import net.minecraft.util.math.RotationAxis;
import org.joml.Matrix4f;

public class NinjaProjectileRenderer extends EntityRenderer<NinjaProjectileEntity> {
    private static final Identifier WHITE_TEXTURE = new Identifier("textures/misc/white.png");

    public NinjaProjectileRenderer(EntityRendererFactory.Context ctx) { super(ctx); }

    @Override
    public void render(NinjaProjectileEntity entity, float yaw, float tickDelta, MatrixStack matrices, VertexConsumerProvider vertexConsumers, int light) {
        super.render(entity, yaw, tickDelta, matrices, vertexConsumers, light);
        float radius = entity.getRadius() * 0.25f;
        if (radius < 0.1f) radius = 0.1f;
        
        String model = entity.getModelType();
        String particle = entity.getParticleType();
        float age = entity.age + tickDelta;
        
        matrices.push();
        matrices.translate(0, entity.getHeight() / 2.0, 0);
        VertexConsumer vc = vertexConsumers.getBuffer(RenderLayer.getEntityTranslucent(WHITE_TEXTURE));
        
        int innerColor = getInnerColor(particle);
        
        if ("water_dragon".equals(model) || "earth_dragon".equals(model) || "fire_dragon".equals(model)) {
            renderDragon(matrices, vc, radius, age, innerColor, light);
        } else if ("blade".equals(model)) {
            renderBlade(matrices, vc, radius, age, innerColor, light);
        } else if ("hound".equals(model)) {
            renderHound(matrices, vc, radius, age, innerColor, light);
        } else {
            render3DSphere(matrices, vc, radius, innerColor, light);
        }
        matrices.pop();
    }

    private void renderDragon(MatrixStack matrices, VertexConsumer vc, float radius, float age, int color, int light) {
        float r = ((color >> 16) & 0xFF) / 255f;
        float g = ((color >> 8) & 0xFF) / 255f;
        float b = (color & 0xFF) / 255f;
        float a = 0.9f;
        int segments = 12;
        
        for (int i = 0; i < segments; i++) {
            matrices.push();
            float offsetZ = -i * 0.5f * radius;
            float offsetY = MathHelper.sin(age * 0.3f + i * 0.6f) * 0.4f * radius;
            float offsetX = MathHelper.cos(age * 0.2f + i * 0.4f) * 0.2f * radius;
            matrices.translate(offsetX, offsetY, offsetZ);
            
            float scale = 1.0f - (i / (float)segments) * 0.7f;
            if (i == 0) scale = 1.8f; // Head
            matrices.scale(scale * radius * 2.0f, scale * radius * 2.0f, scale * radius * 2.0f);
            
            Matrix4f m = matrices.peek().getPositionMatrix();
            emitQuad(vc, m, -0.5f, -0.5f, 0, 0.5f, -0.5f, 0, 0.5f, 0.5f, 0, -0.5f, 0.5f, 0, r, g, b, a, light);
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(90));
            Matrix4f m2 = matrices.peek().getPositionMatrix();
            emitQuad(vc, m2, -0.5f, -0.5f, 0, 0.5f, -0.5f, 0, 0.5f, 0.5f, 0, -0.5f, 0.5f, 0, r, g, b, a, light);
            
            if (i == 0) { // Horns
                matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(-90));
                matrices.translate(0, 0.6f, -0.2f);
                matrices.scale(0.3f, 0.8f, 0.3f);
                Matrix4f mh = matrices.peek().getPositionMatrix();
                emitQuad(vc, mh, -0.5f, 0, -0.5f, 0.5f, 0, -0.5f, 0.5f, 1f, -0.5f, -0.5f, 1f, r*0.8f, g*0.8f, b*0.8f, a, light);
            }
            matrices.pop();
        }
    }

    private void renderBlade(MatrixStack matrices, VertexConsumer vc, float radius, float age, int color, int light) {
        float r = ((color >> 16) & 0xFF) / 255f;
        float g = ((color >> 8) & 0xFF) / 255f;
        float b = (color & 0xFF) / 255f;
        float a = 0.9f;
        matrices.scale(radius * 2.5f, radius * 2.5f, radius * 0.2f);
        matrices.multiply(RotationAxis.POSITIVE_Z.rotationDegrees(age * 45f));
        Matrix4f m = matrices.peek().getPositionMatrix();
        emitQuad(vc, m, 0f, -1f, 0, 0.5f, 0f, 0, 0f, 1f, 0, -0.5f, 0f, 0, r, g, b, a, light);
        matrices.scale(0.6f, 0.6f, 1.5f);
        Matrix4f m2 = matrices.peek().getPositionMatrix();
        emitQuad(vc, m2, 0f, -1f, 0, 0.5f, 0f, 0, 0f, 1f, 0, -0.5f, 0f, 0, 1f, 1f, 1f, a, light);
    }

    private void renderHound(MatrixStack matrices, VertexConsumer vc, float radius, float age, int color, int light) {
        float r = ((color >> 16) & 0xFF) / 255f;
        float g = ((color >> 8) & 0xFF) / 255f;
        float b = (color & 0xFF) / 255f;
        float a = 0.9f;
        float s = radius * 2.0f;
        matrices.scale(s, s, s);
        Matrix4f m = matrices.peek().getPositionMatrix();
        emitBox(vc, m, -0.4f, -0.2f, -1.0f, 0.4f, 0.4f, 0.5f, r, g, b, a, light);
        matrices.push();
        matrices.translate(0, 0.1f, -1.2f);
        matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(MathHelper.sin(age * 0.5f) * 10f));
        Matrix4f mh = matrices.peek().getPositionMatrix();
        emitBox(vc, mh, -0.3f, -0.3f, -0.6f, 0.3f, 0.3f, 0f, r, g, b, a, light);
        emitBox(vc, mh, -0.25f, 0.3f, -0.4f, -0.1f, 0.6f, -0.2f, r, g, b, a, light);
        emitBox(vc, mh, 0.1f, 0.3f, -0.4f, 0.25f, 0.6f, -0.2f, r, g, b, a, light);
        matrices.pop();
        float legAnim = MathHelper.sin(age * 0.8f) * 0.5f;
        matrices.push();
        matrices.translate(0, -0.2f, 0);
        Matrix4f ml = matrices.peek().getPositionMatrix();
        emitBox(vc, ml, -0.3f, -0.6f + legAnim, -0.8f, -0.1f, 0f + legAnim, -0.6f, r, g, b, a, light);
        emitBox(vc, ml, 0.1f, -0.6f - legAnim, -0.8f, 0.3f, 0f - legAnim, -0.6f, r, g, b, a, light);
        emitBox(vc, ml, -0.3f, -0.6f - legAnim, 0.2f, -0.1f, 0f - legAnim, 0.4f, r, g, b, a, light);
        emitBox(vc, ml, 0.1f, -0.6f + legAnim, 0.2f, 0.3f, 0f + legAnim, 0.4f, r, g, b, a, light);
        matrices.pop();
    }

    private void render3DSphere(MatrixStack matrices, VertexConsumer vc, float radius, int color, int light) {
        float r = ((color >> 16) & 0xFF) / 255f;
        float g = ((color >> 8) & 0xFF) / 255f;
        float b = (color & 0xFF) / 255f;
        float a = 0.9f;
        float half = radius;
        for (int i = 0; i < 3; i++) {
            float angle = i * 60f;
            matrices.push();
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(angle));
            Matrix4f m = matrices.peek().getPositionMatrix();
            emitQuad(vc, m, -half, -half, 0, half, -half, 0, half, half, 0, -half, half, 0, r, g, b, a, light);
            matrices.pop();
        }
        matrices.push();
        matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(90));
        Matrix4f mH = matrices.peek().getPositionMatrix();
        emitQuad(vc, mH, -half, -half, 0, half, -half, 0, half, half, 0, -half, half, 0, r, g, b, a, light);
        matrices.pop();
    }

    private void emitBox(VertexConsumer vc, Matrix4f m, float x1, float y1, float z1, float x2, float y2, float z2, float r, float g, float b, float a, int light) {
        emitQuad(vc, m, x1, y1, z1, x2, y1, z1, x2, y2, z1, x1, y2, z1, r, g, b, a, light);
        emitQuad(vc, m, x2, y1, z2, x1, y1, z2, x1, y2, z2, x2, y2, z2, r, g, b, a, light);
        emitQuad(vc, m, x1, y1, z2, x1, y1, z1, x1, y2, z1, x1, y2, z2, r, g, b, a, light);
        emitQuad(vc, m, x2, y1, z1, x2, y1, z2, x2, y2, z2, x2, y2, z1, r, g, b, a, light);
        emitQuad(vc, m, x1, y2, z1, x2, y2, z1, x2, y2, z2, x1, y2, z2, r, g, b, a, light);
        emitQuad(vc, m, x1, y1, z2, x2, y1, z2, x2, y1, z1, x1, y1, z1, r, g, b, a, light);
    }

    private void emitQuad(VertexConsumer vc, Matrix4f m, float x1, float y1, float z1, float x2, float y2, float z2, float x3, float y3, float z3, float x4, float y4, float z4, float r, float g, float b, float a, int light) {
        v(vc, m, x1, y1, z1, 0, 1, r, g, b, a, light); v(vc, m, x2, y2, z2, 1, 1, r, g, b, a, light);
        v(vc, m, x3, y3, z3, 1, 0, r, g, b, a, light); v(vc, m, x4, y4, z4, 0, 0, r, g, b, a, light);
        v(vc, m, x4, y4, z4, 0, 0, r, g, b, a, light); v(vc, m, x3, y3, z3, 1, 0, r, g, b, a, light);
        v(vc, m, x2, y2, z2, 1, 1, r, g, b, a, light); v(vc, m, x1, y1, z1, 0, 1, r, g, b, a, light);
    }

    private void v(VertexConsumer vc, Matrix4f m, float x, float y, float z, float u, float v, float r, float g, float b, float a, int light) {
        vc.vertex(m, x, y, z).color(r, g, b, a).texture(u, v).overlay(OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
    }

    private int getInnerColor(String particle) {
        return switch (particle) {
            case "fire" -> 0xFFFF5500;
            case "water" -> 0xFF2288FF;
            case "lightning" -> 0xFFFFFF44;
            case "wind" -> 0xFFCCFFCC;
            case "earth" -> 0xFF996633;
            default -> 0xFFFF5500;
        };
    }

    @Override public Identifier getTexture(NinjaProjectileEntity entity) { return WHITE_TEXTURE; }
}
'@

# ==========================================
# 3. Behavior Classes (Уникальные механики)
# ==========================================
Write-File "$java\jutsu\custom\DragonProjectileBehavior.java" @'
package com.example.shinobicore.jutsu.custom;
import com.example.shinobicore.entity.NinjaProjectileEntity;
import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;
public class DragonProjectileBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data, JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float speed = params.has("speed") ? params.get("speed").getAsFloat() : 1.5f;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 3.0f;
        String model = params.has("model") ? params.get("model").getAsString() : "water_dragon";
        String particle = params.has("particle") ? params.get("particle").getAsString() : "water";
        Vec3d eye = player.getEyePos();
        Vec3d look = player.getRotationVector();
        NinjaProjectileEntity proj = new NinjaProjectileEntity(world, player, look.multiply(speed), damage, radius, particle, model, 120);
        proj.setPosition(eye.x, eye.y, eye.z);
        proj.setPierceCount(2);
        world.spawnEntity(proj);
    }
}
'@

Write-File "$java\jutsu\custom\BladeProjectileBehavior.java" @'
package com.example.shinobicore.jutsu.custom;
import com.example.shinobicore.entity.NinjaProjectileEntity;
import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;
public class BladeProjectileBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data, JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float speed = params.has("speed") ? params.get("speed").getAsFloat() : 2.5f;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 2.0f;
        Vec3d eye = player.getEyePos();
        Vec3d look = player.getRotationVector();
        NinjaProjectileEntity proj = new NinjaProjectileEntity(world, player, look.multiply(speed), damage, radius, "wind", "blade", 80);
        proj.setPosition(eye.x, eye.y, eye.z);
        proj.setPierceCount(10);
        proj.setBounceCount(2);
        world.spawnEntity(proj);
        TickScheduler.schedule(world, 30, 30, 1, w -> {
            if (!proj.isRemoved()) {
                Vec3d toPlayer = player.getPos().add(0, 1, 0).subtract(proj.getPos()).normalize();
                proj.setVelocity(toPlayer.multiply(speed * 1.2));
                proj.velocityDirty = true;
            }
        });
    }
}
'@

Write-File "$java\jutsu\custom\LightningBeastBehavior.java" @'
package com.example.shinobicore.jutsu.custom;
import com.example.shinobicore.entity.NinjaProjectileEntity;
import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;
public class LightningBeastBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data, JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float speed = params.has("speed") ? params.get("speed").getAsFloat() : 2.0f;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 1.5f;
        Vec3d eye = player.getEyePos();
        Vec3d look = player.getRotationVector();
        NinjaProjectileEntity proj = new NinjaProjectileEntity(world, player, look.multiply(speed), damage, radius, "lightning", "hound", 100);
        proj.setPosition(eye.x, eye.y, eye.z);
        world.spawnEntity(proj);
        TickScheduler.schedule(world, 1, 2, 40, w -> {
            if (proj.isRemoved()) return;
            LivingEntity target = findClosest(w, proj.getPos(), 16, player);
            if (target != null) {
                Vec3d to = target.getPos().add(0, target.getHeight() / 2, 0).subtract(proj.getPos()).normalize();
                Vec3d vel = proj.getVelocity();
                Vec3d newVel = vel.multiply(0.85).add(to.multiply(0.4));
                proj.setVelocity(newVel);
                proj.velocityDirty = true;
            }
        });
    }
    private LivingEntity findClosest(ServerWorld world, Vec3d from, float range, ServerPlayerEntity caster) {
        LivingEntity best = null; double bestDist = Double.MAX_VALUE;
        for (Entity e : world.getOtherEntities(caster, new net.minecraft.util.math.Box(from, from).expand(range))) {
            if (e instanceof LivingEntity liv && !liv.equals(caster)) {
                double d = liv.getPos().distanceTo(from);
                if (d < bestDist) { bestDist = d; best = liv; }
            }
        }
        return best;
    }
}
'@

# ==========================================
# 4. Обновление JSON файлов флагманов
# ==========================================
Write-File "$res\water_dragon_bullet.json" @'
{"id":"shinobicore:water_dragon_bullet","name":"Water Release: Water Dragon Bullet","category":"elemental_ninjutsu","nature":"water","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.DragonProjectileBehavior","params":{"speed":1.8,"radius":4.0,"model":"water_dragon","particle":"water"},"baseCost":45,"baseDamage":18,"strain":12,"requiredUsesForFullProficiency":60,"requirements":{"control":28,"nature_water":35,"ninjutsu":24}}
'@

Write-File "$res\earth_dragon_bullet.json" @'
{"id":"shinobicore:earth_dragon_bullet","name":"Earth Release: Earth Dragon Bullet","category":"elemental_ninjutsu","nature":"earth","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.DragonProjectileBehavior","params":{"speed":1.5,"radius":4.0,"model":"earth_dragon","particle":"earth"},"baseCost":40,"baseDamage":16,"strain":11,"requiredUsesForFullProficiency":55,"requirements":{"control":26,"nature_earth":32,"ninjutsu":22}}
'@

Write-File "$res\wind_vacuum_blade.json" @'
{"id":"shinobicore:wind_vacuum_blade","name":"Wind Release: Vacuum Blade","category":"elemental_ninjutsu","nature":"wind","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.BladeProjectileBehavior","params":{"speed":3.0,"radius":2.5},"baseCost":30,"baseDamage":12,"strain":8,"requiredUsesForFullProficiency":45,"requirements":{"control":22,"nature_wind":28,"ninjutsu":20}}
'@

Write-File "$res\lightning_golem.json" @'
{"id":"shinobicore:lightning_golem","name":"Lightning Release: Lightning Beast","category":"elemental_ninjutsu","nature":"lightning","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.LightningBeastBehavior","params":{"speed":2.2,"radius":2.0},"baseCost":35,"baseDamage":14,"strain":9,"requiredUsesForFullProficiency":50,"requirements":{"control":24,"nature_lightning":30,"ninjutsu":22}}
'@

Write-Host ""
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "  PHASE G3 COMPLETE! 3D Models & Unique Mechanics Injected." -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "Next Step: Run .\gradlew.bat build" -ForegroundColor Yellow
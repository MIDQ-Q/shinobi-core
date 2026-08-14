$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main"

function Write-File($p, $c) {
    $dir = [System.IO.Path]::GetDirectoryName($p)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] $p"
}

Write-Host "=== APPLYING PHASE G3: 3D PROJECTILE MODELS ==="

# ============ 1. NinjaProjectileEntity.java ============
Write-File "$base\java\com\example\shinobicore\entity\NinjaProjectileEntity.java" @'
package com.example.shinobicore.entity;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.combat.MarkTracker;
import net.minecraft.entity.Entity;
import net.minecraft.entity.EntityType;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.data.DataTracker;
import net.minecraft.entity.data.TrackedData;
import net.minecraft.entity.data.TrackedDataHandlerRegistry;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.hit.BlockHitResult;
import net.minecraft.util.hit.HitResult;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.RaycastContext;
import net.minecraft.world.World;
import java.util.List;
import java.util.UUID;

public class NinjaProjectileEntity extends Entity {
    private static final TrackedData<Float> DAMAGE = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.FLOAT);
    private static final TrackedData<Float> RADIUS = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.FLOAT);
    private static final TrackedData<String> PARTICLE_TYPE = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.STRING);
    private static final TrackedData<String> MODEL_TYPE = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.STRING); // НОВОЕ
    private static final TrackedData<Integer> LIFETIME = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.INTEGER);
    private static final TrackedData<Boolean> HAS_GRAVITY = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.BOOLEAN);
    private static final TrackedData<Integer> PIERCE_COUNT = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.INTEGER);
    private static final TrackedData<Integer> BOUNCE_COUNT = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.INTEGER);

    public float getRadius() { return this.dataTracker.get(RADIUS); }
    public String getParticleType() { return this.dataTracker.get(PARTICLE_TYPE); }
    public String getModelType() { return this.dataTracker.get(MODEL_TYPE); } // НОВОЕ

    private UUID ownerId;
    public Entity getOwner() {
        if (ownerId == null) return null;
        if (this.getWorld() instanceof ServerWorld sw) return sw.getPlayerByUuid(ownerId);
        return null;
    }

    // Изменено на public, чтобы рендерер мог читать age для анимации вращения
    public int age = 0; 
    private int pierceRemaining = 0;
    private int bounceRemaining = 0;

    public NinjaProjectileEntity(EntityType<?> type, World world) {
        super(type, world);
    }

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
            if (radius > 0.5f) {
                for (Entity entity : this.getWorld().getOtherEntities(this, this.getBoundingBox().expand(radius))) {
                    if (entity instanceof LivingEntity living && !living.getUuid().equals(this.ownerId)) {
                        living.damage(this.getDamageSources().magic(), damage * 0.5f);
                    }
                }
            }
            this.discard();
            return;
        }

        this.setPosition(this.getX() + vel.x, this.getY() + vel.y, this.getZ() + vel.z);

        if (this.getWorld() instanceof ServerWorld serverWorld) {
            String particle = this.dataTracker.get(PARTICLE_TYPE);
            float radius = this.dataTracker.get(RADIUS);
            net.minecraft.particle.ParticleEffect particleType = switch (particle) {
                case "water" -> net.minecraft.particle.ParticleTypes.FALLING_WATER;
                case "smoke" -> net.minecraft.particle.ParticleTypes.SMOKE;
                case "lightning" -> net.minecraft.particle.ParticleTypes.ELECTRIC_SPARK;
                case "wind" -> net.minecraft.particle.ParticleTypes.CLOUD;
                case "earth" -> net.minecraft.particle.ParticleTypes.POOF;
                default -> net.minecraft.particle.ParticleTypes.FLAME;
            };
            int count = Math.max(3, (int)(radius * 1.5));
            float spread = radius * 0.2f;
            for (int i = 0; i < count; i++) {
                serverWorld.spawnParticles(particleType,
                    this.getX() + (Math.random() - 0.5) * spread, 
                    this.getY() + (Math.random() - 0.5) * spread, 
                    this.getZ() + (Math.random() - 0.5) * spread,
                    1, 0.01, 0.01, 0.01, 0.01);
            }
        }
    }

    @Override
    protected void readCustomDataFromNbt(NbtCompound nbt) {
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

    @Override
    protected void writeCustomDataToNbt(NbtCompound nbt) {
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

# ============ 2. ProjectileBehavior.java ============
Write-File "$base\java\com\example\shinobicore\jutsu\ProjectileBehavior.java" @'
package com.example.shinobicore.jutsu;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.entity.NinjaProjectileEntity;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.math.Vec3d;

public class ProjectileBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data, JsonObject params, float damage) {
        float speed = params.has("speed") ? params.get("speed").getAsFloat() : 1.5f;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 1.0f;
        String particle = params.has("particle") ? params.get("particle").getAsString() : "flame";
        String model = params.has("model") ? params.get("model").getAsString() : "sphere"; // НОВОЕ
        int lifetime = params.has("lifetime") ? params.get("lifetime").getAsInt() : 100;
        boolean hasGravity = params.has("gravity") && params.get("gravity").getAsBoolean();
        int pierceCount = params.has("pierce") ? params.get("pierce").getAsInt() : 0;
        int bounceCount = params.has("bounce") ? params.get("bounce").getAsInt() : 0;
        int projectileCount = params.has("count") ? params.get("count").getAsInt() : 1;
        float spread = params.has("spread") ? params.get("spread").getAsFloat() : 0f;

        Vec3d baseDir = player.getRotationVector().normalize();

        for (int i = 0; i < projectileCount; i++) {
            Vec3d dir = baseDir;
            if (projectileCount > 1 && spread > 0) {
                float angle = (float) ((i - (projectileCount - 1) / 2.0) * spread * Math.PI / 180.0);
                double cos = Math.cos(angle);
                double sin = Math.sin(angle);
                dir = new Vec3d(baseDir.x * cos - baseDir.z * sin, baseDir.y, baseDir.x * sin + baseDir.z * cos).normalize();
            }
            Vec3d velocity = dir.multiply(speed);
            Vec3d spawnOffset = dir.multiply(2.0);
            double spawnX = player.getX() + spawnOffset.x;
            double spawnY = player.getEyeY() - 0.2 + spawnOffset.y;
            double spawnZ = player.getZ() + spawnOffset.z;

            NinjaProjectileEntity projectile = new NinjaProjectileEntity(
                player.getWorld(), player, velocity, damage, radius, particle, model, lifetime
            );
            projectile.setPosition(spawnX, spawnY, spawnZ);
            projectile.setHasGravity(hasGravity);
            projectile.setPierceCount(pierceCount);
            projectile.setBounceCount(bounceCount);
            player.getWorld().spawnEntity(projectile);
        }
    }
}
'@

# ============ 3. NinjaProjectileRenderer.java ============
Write-File "$base\java\com\example\shinobicore\entity\NinjaProjectileRenderer.java" @'
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

public class NinjaProjectileRenderer extends EntityRenderer<NinjaProjectileEntity> {
    private static final Identifier WHITE_TEXTURE = new Identifier("textures/misc/white.png");

    public NinjaProjectileRenderer(EntityRendererFactory.Context ctx) {
        super(ctx);
    }

    @Override
    public void render(NinjaProjectileEntity entity, float yaw, float tickDelta,
                       MatrixStack matrices, VertexConsumerProvider vertexConsumers, int light) {
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
        int outerColor = getOuterColor(particle);

        if ("rasengan".equals(model)) {
            renderRasengan(matrices, vc, radius, age, light);
        } else {
            // Базовая 3D сфера (ядро)
            render3DSphere(matrices, vc, radius, innerColor, light);
            // Внешнее свечение (чуть больше, полупрозрачное)
            render3DSphere(matrices, vc, radius * 1.4f, outerColor, light);
        }

        matrices.pop();
    }

    // === МАТЕМАТИКА 3D СФЕРЫ ===
    private void render3DSphere(MatrixStack matrices, VertexConsumer vc, float radius, int color, int light) {
        float r = ((color >> 16) & 0xFF) / 255f;
        float g = ((color >> 8) & 0xFF) / 255f;
        float b = (color & 0xFF) / 255f;
        float a = ((color >> 24) & 0xFF) / 255f;
        if (a == 0) a = 1.0f;

        int segments = 12;
        int rings = 8;
        Matrix4f m = matrices.peek().getPositionMatrix();

        for (int i = 0; i < rings; i++) {
            float theta1 = (float) i / rings * (float) Math.PI;
            float theta2 = (float) (i + 1) / rings * (float) Math.PI;
            
            for (int j = 0; j < segments; j++) {
                float phi1 = (float) j / segments * 2 * (float) Math.PI;
                float phi2 = (float) (j + 1) / segments * 2 * (float) Math.PI;
                
                float x1 = radius * (float)Math.sin(theta1) * (float)Math.cos(phi1);
                float y1 = radius * (float)Math.cos(theta1);
                float z1 = radius * (float)Math.sin(theta1) * (float)Math.sin(phi1);

                float x2 = radius * (float)Math.sin(theta1) * (float)Math.cos(phi2);
                float y2 = radius * (float)Math.cos(theta1);
                float z2 = radius * (float)Math.sin(theta1) * (float)Math.sin(phi2);

                float x3 = radius * (float)Math.sin(theta2) * (float)Math.cos(phi2);
                float y3 = radius * (float)Math.cos(theta2);
                float z3 = radius * (float)Math.sin(theta2) * (float)Math.sin(phi2);

                float x4 = radius * (float)Math.sin(theta2) * (float)Math.cos(phi1);
                float y4 = radius * (float)Math.cos(theta2);
                float z4 = radius * (float)Math.sin(theta2) * (float)Math.sin(phi1);

                vertex(vc, m, x1, y1, z1, 0, 0, r, g, b, a, light);
                vertex(vc, m, x2, y2, z2, 1, 0, r, g, b, a, light);
                vertex(vc, m, x3, y3, z3, 1, 1, r, g, b, a, light);
                vertex(vc, m, x4, y4, z4, 0, 1, r, g, b, a, light);
            }
        }
    }

    // === РАСЕНГАН: Сфера + 2 вращающихся кольца (Тор) ===
    private void renderRasengan(MatrixStack matrices, VertexConsumer vc, float radius, float age, int light) {
        // Ядро (синее)
        render3DSphere(matrices, vc, radius, 0xFF2266FF, light);
        
        // Кольцо 1 (горизонтальное, быстрое)
        matrices.push();
        matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(age * 25f));
        matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(15f));
        renderTorus(matrices, vc, radius * 1.2f, radius * 0.15f, 0xFFFFFFFF, light);
        matrices.pop();
        
        // Кольцо 2 (вертикальное, обратное)
        matrices.push();
        matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(-age * 18f));
        matrices.multiply(RotationAxis.POSITIVE_Z.rotationDegrees(60f));
        renderTorus(matrices, vc, radius * 1.4f, radius * 0.1f, 0xFF88CCFF, light);
        matrices.pop();
        
        // Внешняя аура
        render3DSphere(matrices, vc, radius * 1.6f, 0x4488CCFF, light);
    }

    // === МАТЕМАТИКА ТОРА (КОЛЬЦА) ===
    private void renderTorus(MatrixStack matrices, VertexConsumer vc, float majorRadius, float minorRadius, int color, int light) {
        float r = ((color >> 16) & 0xFF) / 255f;
        float g = ((color >> 8) & 0xFF) / 255f;
        float b = (color & 0xFF) / 255f;
        float a = ((color >> 24) & 0xFF) / 255f;
        if (a == 0) a = 1.0f;

        int majorSegments = 24;
        int minorSegments = 8;
        Matrix4f m = matrices.peek().getPositionMatrix();

        for (int i = 0; i < majorSegments; i++) {
            float theta1 = (float) i / majorSegments * 2 * (float) Math.PI;
            float theta2 = (float) (i + 1) / majorSegments * 2 * (float) Math.PI;
            
            for (int j = 0; j < minorSegments; j++) {
                float phi1 = (float) j / minorSegments * 2 * (float) Math.PI;
                float phi2 = (float) (j + 1) / minorSegments * 2 * (float) Math.PI;
                
                float x1 = (majorRadius + minorRadius * (float)Math.cos(phi1)) * (float)Math.cos(theta1);
                float y1 = minorRadius * (float)Math.sin(phi1);
                float z1 = (majorRadius + minorRadius * (float)Math.cos(phi1)) * (float)Math.sin(theta1);

                float x2 = (majorRadius + minorRadius * (float)Math.cos(phi1)) * (float)Math.cos(theta2);
                float y2 = minorRadius * (float)Math.sin(phi1);
                float z2 = (majorRadius + minorRadius * (float)Math.cos(phi1)) * (float)Math.sin(theta2);

                float x3 = (majorRadius + minorRadius * (float)Math.cos(phi2)) * (float)Math.cos(theta2);
                float y3 = minorRadius * (float)Math.sin(phi2);
                float z3 = (majorRadius + minorRadius * (float)Math.cos(phi2)) * (float)Math.sin(theta2);

                float x4 = (majorRadius + minorRadius * (float)Math.cos(phi2)) * (float)Math.cos(theta1);
                float y4 = minorRadius * (float)Math.sin(phi2);
                float z4 = (majorRadius + minorRadius * (float)Math.cos(phi2)) * (float)Math.sin(theta1);

                vertex(vc, m, x1, y1, z1, 0, 0, r, g, b, a, light);
                vertex(vc, m, x2, y2, z2, 1, 0, r, g, b, a, light);
                vertex(vc, m, x3, y3, z3, 1, 1, r, g, b, a, light);
                vertex(vc, m, x4, y4, z4, 0, 1, r, g, b, a, light);
            }
        }
    }

    private void vertex(VertexConsumer vc, Matrix4f m, float x, float y, float z, float u, float v, float r, float g, float b, float a, int light) {
        vc.vertex(m, x, y, z).color(r, g, b, a).texture(u, v).overlay(OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
    }

    private int getInnerColor(String particle) {
        return switch (particle) {
            case "fire" -> 0xFFFF6600;
            case "water" -> 0xFF2288FF;
            case "lightning" -> 0xFFFFFF44;
            case "wind" -> 0xFFDDDDDD;
            case "earth" -> 0xFF996633;
            case "smoke" -> 0xFF888888;
            default -> 0xFFFF6600;
        };
    }

    private int getOuterColor(String particle) {
        return switch (particle) {
            case "fire" -> 0x66FF4400;
            case "water" -> 0x662266FF;
            case "lightning" -> 0x66FFFF00;
            case "wind" -> 0x66CCCCCC;
            case "earth" -> 0x66774422;
            case "smoke" -> 0x66666666;
            default -> 0x66FF4400;
        };
    }

    @Override
    public Identifier getTexture(NinjaProjectileEntity entity) {
        return WHITE_TEXTURE;
    }
}
'@

Write-Host " "
Write-Host "=== PHASE G3 SCRIPT EXECUTED SUCCESSFULLY ==="
Write-Host "Next step: Run .\gradlew.bat build to compile."
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
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  PHASE G3: NARUTO 3D MODELS & UNIQUE JUTSU         ║" -ForegroundColor Cyan
Write-Host "║  Огненный/Водяной драконы, Чидори, Аматерасу,     ║" -ForegroundColor Cyan
Write-Host "║  Теневые клоны, Песчаный гроб, Большой расенган   ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ================================================================
# 1. ProjectileBehavior.java — добавляем параметр model
# ================================================================
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
String model = params.has("model") ? params.get("model").getAsString() : "sphere";
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

# ================================================================
# 2. NinjaProjectileRenderer.java — полная замена с 3D моделями
# ================================================================
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
import net.minecraft.util.math.MathHelper;
import net.minecraft.util.math.RotationAxis;
import org.joml.Matrix4f;
public class NinjaProjectileRenderer extends EntityRenderer<NinjaProjectileEntity> {
private static final Identifier WHITE_TEXTURE = new Identifier("textures/misc/white.png");
private static final Identifier LAVA_TEXTURE = new Identifier("textures/block/lava_still.png");
private static final Identifier WATER_TEXTURE = new Identifier("textures/block/water_still.png");
public NinjaProjectileRenderer(EntityRendererFactory.Context ctx) { super(ctx); }
@Override
public void render(NinjaProjectileEntity entity, float yaw, float tickDelta,
MatrixStack matrices, VertexConsumerProvider vertexConsumers, int light) {
super.render(entity, yaw, tickDelta, matrices, vertexConsumers, light);
float radius = entity.getRadius() * 0.25f;
if (radius < 0.1f) radius = 0.1f;
String particle = entity.getParticleType();
String model = entity.getModelType();
matrices.push();
matrices.translate(0, entity.getHeight() / 2.0, 0);
float animTime = (float)(System.currentTimeMillis() % 10000) / 50.0f;
switch (model) {
case "fire_dragon":
renderFireDragon(matrices, vertexConsumers, radius, light, animTime);
break;
case "water_dragon":
renderWaterDragon(matrices, vertexConsumers, radius, light, animTime);
break;
case "amaterasu":
renderAmaterasu(matrices, vertexConsumers, radius, light, animTime);
break;
case "chidori":
renderChidori(matrices, vertexConsumers, radius, light, animTime);
break;
case "rasengan":
renderRasengan(matrices, vertexConsumers, radius, light, animTime);
break;
case "fireball":
renderFireball(matrices, vertexConsumers, radius, light, animTime);
break;
default:
Identifier texture = getTextureForParticle(particle);
int innerColor = getInnerColor(particle);
int outerColor = getOuterColor(particle);
renderSphereQuads(matrices, vertexConsumers, radius, innerColor, light, texture);
renderSphereQuads(matrices, vertexConsumers, radius * 1.4f, outerColor, light, WHITE_TEXTURE);
break;
}
matrices.pop();
}
// ==================== ОГНЕННЫЙ ДРАКОН ====================
private void renderFireDragon(MatrixStack matrices, VertexConsumerProvider vc, float radius, int light, float age) {
// Тело дракона — цепочка сфер вдоль синусоиды
int segments = 8;
for (int i = 0; i < segments; i++) {
float progress = (float)i / segments;
float wave = MathHelper.sin(age * 0.3f + progress * 4f) * 0.5f;
float waveX = MathHelper.cos(age * 0.25f + progress * 3f) * 0.3f;
float segRadius = radius * (1.0f - progress * 0.6f);
matrices.push();
matrices.translate(waveX, wave, -progress * radius * 4f);
renderSphereQuads(matrices, vc, segRadius, 0xFFFF4400, light, WHITE_TEXTURE);
matrices.pop();
}
// Голова дракона (большая сфера спереди)
renderSphereQuads(matrices, vc, radius * 1.3f, 0xFFFF6600, light, WHITE_TEXTURE);
// Рога
matrices.push();
matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(-30f));
matrices.translate(0, radius * 0.8f, -radius * 0.3f);
renderSphereQuads(matrices, vc, radius * 0.2f, 0xFFCC2200, light, WHITE_TEXTURE);
matrices.pop();
// Внешнее свечение
renderSphereQuads(matrices, vc, radius * 1.8f, 0x66FF2200, light, WHITE_TEXTURE);
}
// ==================== ВОДЯНОЙ ДРАКОН ====================
private void renderWaterDragon(MatrixStack matrices, VertexConsumerProvider vc, float radius, int light, float age) {
int segments = 10;
for (int i = 0; i < segments; i++) {
float progress = (float)i / segments;
float wave = MathHelper.sin(age * 0.4f + progress * 5f) * 0.6f;
float waveX = MathHelper.cos(age * 0.35f + progress * 4f) * 0.4f;
float segRadius = radius * (1.0f - progress * 0.5f);
matrices.push();
matrices.translate(waveX, wave, -progress * radius * 5f);
renderSphereQuads(matrices, vc, segRadius, 0xFF2288FF, light, WATER_TEXTURE);
matrices.pop();
}
// Голова
renderSphereQuads(matrices, vc, radius * 1.4f, 0xFF44AAFF, light, WATER_TEXTURE);
// Плавники
for (int f = 0; f < 2; f++) {
matrices.push();
matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(f * 180f));
matrices.translate(radius * 0.8f, 0, -radius * 0.5f);
matrices.multiply(RotationAxis.POSITIVE_Z.rotationDegrees(45f));
emitQuad(matrices.peek().getPositionMatrix(), vc,
-radius*0.5f, 0, 0, radius*0.5f, 0, 0,
radius*0.5f, radius*0.8f, 0, -radius*0.5f, radius*0.8f, 0,
0.2f, 0.5f, 1.0f, 0.5f, light);
matrices.pop();
}
// Свечение
renderSphereQuads(matrices, vc, radius * 1.9f, 0x442266FF, light, WHITE_TEXTURE);
}
// ==================== АМАТЕРАСУ ====================
private void renderAmaterasu(MatrixStack matrices, VertexConsumerProvider vc, float radius, int light, float age) {
// Черное ядро
renderSphereQuads(matrices, vc, radius, 0xFF000000, light, WHITE_TEXTURE);
// Красное свечение вокруг черного
renderSphereQuads(matrices, vc, radius * 1.3f, 0x88FF0000, light, WHITE_TEXTURE);
// Черное внешнее
renderSphereQuads(matrices, vc, radius * 1.6f, 0x44000000, light, WHITE_TEXTURE);
// Вращающиеся черные лепестки пламени
for (int i = 0; i < 4; i++) {
matrices.push();
matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(age * 15f + i * 90f));
matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(20f));
matrices.translate(radius * 1.2f, 0, 0);
renderSphereQuads(matrices, vc, radius * 0.3f, 0xFF111111, light, WHITE_TEXTURE);
matrices.pop();
}
}
// ==================== ЧИДОРИ ====================
private void renderChidori(MatrixStack matrices, VertexConsumerProvider vc, float radius, int light, float age) {
// Яркое белое ядро
renderSphereQuads(matrices, vc, radius * 0.8f, 0xFFFFFFFF, light, WHITE_TEXTURE);
// Молнии — вращающиеся линии
for (int i = 0; i < 6; i++) {
float angle = age * 8f + i * 60f;
matrices.push();
matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(angle));
matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(30f + (i % 3) * 20f));
emitQuad(matrices.peek().getPositionMatrix(), vc,
-radius*0.2f, 0, 0, radius*0.2f, 0, 0,
radius*0.1f, radius*1.8f, 0, -radius*0.1f, radius*1.8f, 0,
0.8f, 0.9f, 1.0f, 0.7f, light);
matrices.pop();
}
// Синее свечение
renderSphereQuads(matrices, vc, radius * 1.5f, 0x664488FF, light, WHITE_TEXTURE);
}
// ==================== РАСЕНГАН ====================
private void renderRasengan(MatrixStack matrices, VertexConsumerProvider vc, float radius, int light, float age) {
renderSphereQuads(matrices, vc, radius, 0xFF44AAFF, light, WHITE_TEXTURE);
for (int i = 0; i < 3; i++) {
matrices.push();
matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(age * 20f + i * 60f));
matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(90f));
renderRing(matrices, vc, radius * 1.6f, 0.08f, 0xCCFFFFFF, light);
matrices.pop();
}
renderSphereQuads(matrices, vc, radius * 1.8f, 0x4488DDFF, light, WHITE_TEXTURE);
}
// ==================== ФАЙЕРБОЛ ====================
private void renderFireball(MatrixStack matrices, VertexConsumerProvider vc, float radius, int light, float age) {
float pulse = 1.0f + MathHelper.sin(age * 0.5f) * 0.15f;
float r = radius * pulse;
renderSphereQuads(matrices, vc, r, 0xFFFFFFFF, light, LAVA_TEXTURE);
renderSphereQuads(matrices, vc, r * 1.5f, 0x88FF4400, light, WHITE_TEXTURE);
}
// ==================== КОЛЬЦО ====================
private void renderRing(MatrixStack matrices, VertexConsumerProvider vc, float radius, float thickness, int color, int light) {
VertexConsumer consumer = vc.getBuffer(RenderLayer.getEntityTranslucent(WHITE_TEXTURE));
Matrix4f m = matrices.peek().getPositionMatrix();
float r = ((color >> 16) & 0xFF) / 255f;
float g = ((color >> 8) & 0xFF) / 255f;
float b = (color & 0xFF) / 255f;
float a = ((color >> 24) & 0xFF) / 255f;
int segments = 24;
for (int i = 0; i < segments; i++) {
float angle1 = (float)(i * 2 * Math.PI / segments);
float angle2 = (float)((i + 1) * 2 * Math.PI / segments);
float x1 = MathHelper.cos(angle1) * radius;
float z1 = MathHelper.sin(angle1) * radius;
float x2 = MathHelper.cos(angle2) * radius;
float z2 = MathHelper.sin(angle2) * radius;
consumer.vertex(m, x1, -thickness, z1).color(r, g, b, a).texture(0, 0).overlay(OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
consumer.vertex(m, x2, -thickness, z2).color(r, g, b, a).texture(1, 0).overlay(OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
consumer.vertex(m, x2, thickness, z2).color(r, g, b, a).texture(1, 1).overlay(OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
consumer.vertex(m, x1, thickness, z1).color(r, g, b, a).texture(0, 1).overlay(OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
}
}
// ==================== СФЕРА ИЗ КВАДОВ ====================
private void renderSphereQuads(MatrixStack matrices, VertexConsumerProvider vc,
float size, int color, int light, Identifier texture) {
VertexConsumer consumer = vc.getBuffer(RenderLayer.getEntityTranslucent(texture));
float r = ((color >> 16) & 0xFF) / 255f;
float g = ((color >> 8) & 0xFF) / 255f;
float b = (color & 0xFF) / 255f;
float a = ((color >> 24) & 0xFF) / 255f;
float half = size;
for (int i = 0; i < 3; i++) {
float angle = i * 60f;
matrices.push();
matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(angle));
emitQuad(matrices.peek().getPositionMatrix(), consumer,
-half, -half, 0, half, -half, 0, half, half, 0, -half, half, 0, r, g, b, a, light);
matrices.pop();
}
matrices.push();
matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(90));
emitQuad(matrices.peek().getPositionMatrix(), consumer,
-half, -half, 0, half, -half, 0, half, half, 0, -half, half, 0, r, g, b, a, light);
matrices.pop();
for (int i = 0; i < 2; i++) {
matrices.push();
matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(i * 90f));
matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(45));
emitQuad(matrices.peek().getPositionMatrix(), consumer,
-half, -half, 0, half, -half, 0, half, half, 0, -half, half, 0, r, g, b, a, light);
matrices.pop();
}
}
private void emitQuad(Matrix4f m, VertexConsumer consumer,
float x1, float y1, float z1, float x2, float y2, float z2,
float x3, float y3, float z3, float x4, float y4, float z4,
float r, float g, float b, float a, int light) {
vertex(consumer, m, x1, y1, z1, 0, 1, r, g, b, a, light);
vertex(consumer, m, x2, y2, z2, 1, 1, r, g, b, a, light);
vertex(consumer, m, x3, y3, z3, 1, 0, r, g, b, a, light);
vertex(consumer, m, x4, y4, z4, 0, 0, r, g, b, a, light);
vertex(consumer, m, x2, y2, z2, 0, 1, r, g, b, a, light);
vertex(consumer, m, x1, y1, z1, 1, 1, r, g, b, a, light);
vertex(consumer, m, x4, y4, z4, 1, 0, r, g, b, a, light);
vertex(consumer, m, x3, y3, z3, 0, 0, r, g, b, a, light);
}
private void vertex(VertexConsumer consumer, Matrix4f matrix,
float x, float y, float z, float u, float v,
float r, float g, float b, float a, int light) {
consumer.vertex(matrix, x, y, z).color(r, g, b, a).texture(u, v)
.overlay(OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
}
private Identifier getTextureForParticle(String particle) {
if ("fire".equals(particle) || "flame".equals(particle) || "fireball".equals(particle)) return LAVA_TEXTURE;
if ("water".equals(particle)) return WATER_TEXTURE;
return WHITE_TEXTURE;
}
private int getInnerColor(String particle) {
return switch (particle) {
case "fire", "flame", "fireball" -> 0xFFFFFFFF;
case "water" -> 0xFFFFFFFF;
case "lightning" -> 0xFFFFFF44;
case "wind" -> 0xFFDDDDDD;
case "earth" -> 0xFF996633;
case "smoke" -> 0xFF888888;
default -> 0xFFFF6600;
};
}
private int getOuterColor(String particle) {
return switch (particle) {
case "fire", "flame", "fireball" -> 0x66FF4400;
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
return getTextureForParticle(entity.getParticleType());
}
}
'@

# ================================================================
# 3. FireDragonBehavior.java
# ================================================================
Write-File "$base\java\com\example\shinobicore\jutsu\custom\FireDragonBehavior.java" @'
package com.example.shinobicore.jutsu.custom;
import com.example.shinobicore.entity.NinjaProjectileEntity;
import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;
import net.minecraft.util.math.Vec3d;
public class FireDragonBehavior implements JutsuBehavior {
@Override
public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
JsonObject params, float damage) {
if (!(player.getWorld() instanceof ServerWorld world)) return;
float speed = params.has("speed") ? params.get("speed").getAsFloat() : 1.5f;
float radius = params.has("radius") ? params.get("radius").getAsFloat() : 4f;
int lifetime = params.has("lifetime") ? params.get("lifetime").getAsInt() : 80;
Vec3d eye = player.getEyePos();
Vec3d look = player.getRotationVector();
NinjaProjectileEntity proj = new NinjaProjectileEntity(
world, player, look.multiply(speed), damage, radius, "flame", "fire_dragon", lifetime
);
proj.setPosition(eye.x, eye.y - 0.2, eye.z);
proj.setHasGravity(false);
proj.setPierceCount(5);
world.spawnEntity(proj);
world.playSound(null, player.getBlockPos(), SoundEvents.ENTITY_ENDER_DRAGON_GROWL, SoundCategory.PLAYERS, 1.5f, 1.2f);
TickScheduler.schedule(world, 1, 2, 20, w -> {
if (!proj.isRemoved()) {
w.spawnParticles(ParticleTypes.FLAME, proj.getX(), proj.getY(), proj.getZ(), 5, 0.5, 0.5, 0.5, 0.1);
w.spawnParticles(ParticleTypes.LARGE_SMOKE, proj.getX(), proj.getY() + 0.5, proj.getZ(), 2, 0.3, 0.3, 0.3, 0.02);
}
});
JutsuLogger.logBehavior("fire_dragon", "speed=" + speed + " radius=" + radius);
}
}
'@

# ================================================================
# 4. WaterDragonBehavior.java
# ================================================================
Write-File "$base\java\com\example\shinobicore\jutsu\custom\WaterDragonBehavior.java" @'
package com.example.shinobicore.jutsu.custom;
import com.example.shinobicore.entity.NinjaProjectileEntity;
import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
public class WaterDragonBehavior implements JutsuBehavior {
@Override
public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
JsonObject params, float damage) {
if (!(player.getWorld() instanceof ServerWorld world)) return;
float speed = params.has("speed") ? params.get("speed").getAsFloat() : 1.4f;
float radius = params.has("radius") ? params.get("radius").getAsFloat() : 4f;
int lifetime = params.has("lifetime") ? params.get("lifetime").getAsInt() : 100;
Vec3d eye = player.getEyePos();
Vec3d look = player.getRotationVector();
NinjaProjectileEntity proj = new NinjaProjectileEntity(
world, player, look.multiply(speed), damage, radius, "water", "water_dragon", lifetime
);
proj.setPosition(eye.x, eye.y - 0.2, eye.z);
proj.setHasGravity(false);
proj.setPierceCount(3);
world.spawnEntity(proj);
world.playSound(null, player.getBlockPos(), SoundEvents.ENTITY_GENERIC_SPLASH, SoundCategory.PLAYERS, 2.0f, 0.8f);
TickScheduler.schedule(world, 1, 3, 25, w -> {
if (!proj.isRemoved()) {
w.spawnParticles(ParticleTypes.FALLING_WATER, proj.getX(), proj.getY(), proj.getZ(), 4, 0.5, 0.5, 0.5, 0.1);
w.spawnParticles(ParticleTypes.BUBBLE_POP, proj.getX(), proj.getY() + 0.3, proj.getZ(), 2, 0.3, 0.3, 0.3, 0.02);
for (var e : w.getOtherEntities(player, new Box(proj.getPos(), proj.getPos()).expand(2.5))) {
if (e instanceof LivingEntity liv && !liv.equals(player)) {
liv.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, 40, 1, false, false));
}
}
}
});
JutsuLogger.logBehavior("water_dragon", "speed=" + speed + " radius=" + radius);
}
}
'@

# ================================================================
# 5. ShadowCloneBehavior.java
# ================================================================
Write-File "$base\java\com\example\shinobicore\jutsu\custom\ShadowCloneBehavior.java" @'
package com.example.shinobicore.jutsu.custom;
import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.mixin.MobEntityAccessor;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.EntityType;
import net.minecraft.entity.ai.goal.ActiveTargetGoal;
import net.minecraft.entity.mob.MobEntity;
import net.minecraft.entity.mob.Monster;
import net.minecraft.entity.passive.WolfEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;
import net.minecraft.util.math.Vec3d;
public class ShadowCloneBehavior implements JutsuBehavior {
@Override
public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
JsonObject params, float damage) {
if (!(player.getWorld() instanceof ServerWorld world)) return;
int count = params.has("count") ? params.get("count").getAsInt() : 3;
int duration = params.has("duration") ? params.get("duration").getAsInt() : 400;
for (int i = 0; i < count; i++) {
double angle = (i / (double) count) * Math.PI * 2;
double x = player.getX() + Math.cos(angle) * 2;
double z = player.getZ() + Math.sin(angle) * 2;
WolfEntity clone = EntityType.WOLF.create(world);
if (clone == null) continue;
clone.setPosition(x, player.getY(), z);
clone.setOwner(player);
clone.setTamed(true);
clone.setCustomName(Text.literal("Shadow Clone"));
clone.setCustomNameVisible(true);
world.spawnEntity(clone);
world.spawnParticles(ParticleTypes.POOF, x, player.getY() + 1, z, 10, 0.5, 0.5, 0.5, 0.1);
final Entity summon = clone;
TickScheduler.schedule(world, duration, duration, 1, w -> {
if (!summon.isRemoved()) {
w.spawnParticles(ParticleTypes.POOF, summon.getX(), summon.getY() + 1, summon.getZ(), 10, 0.5, 0.5, 0.5, 0.1);
summon.discard();
}
});
}
player.sendMessage(Text.literal("\u00a77Shadow Clone Jutsu! " + count + " clones created."), true);
JutsuLogger.logBehavior("shadow_clone", "count=" + count + " duration=" + duration);
}
}
'@

# ================================================================
# 6. ChidoriBehavior.java
# ================================================================
Write-File "$base\java\com\example\shinobicore\jutsu\custom\ChidoriBehavior.java" @'
package com.example.shinobicore.jutsu.custom;
import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
public class ChidoriBehavior implements JutsuBehavior {
@Override
public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
JsonObject params, float damage) {
if (!(player.getWorld() instanceof ServerWorld world)) return;
float dashDistance = params.has("dashDistance") ? params.get("dashDistance").getAsFloat() : 8f;
float hitRadius = params.has("hitRadius") ? params.get("hitRadius").getAsFloat() : 2f;
Vec3d look = player.getRotationVector();
Vec3d startPos = player.getPos();
player.addVelocity(look.x * 2, 0.1, look.z * 2);
player.velocityModified = true;
world.spawnParticles(ParticleTypes.ELECTRIC_SPARK, startPos.x, startPos.y + 1, startPos.z, 30, 1, 1, 1, 0.2);
world.playSound(null, player.getBlockPos(), SoundEvents.ENTITY_LIGHTNING_BOLT_THUNDER, SoundCategory.PLAYERS, 1.5f, 1.0f);
player.addStatusEffect(new StatusEffectInstance(StatusEffects.SPEED, 40, 2, false, false));
TickScheduler.schedule(world, 2, 2, 8, w -> {
Vec3d currentPos = player.getPos();
for (Entity e : w.getOtherEntities(player, new Box(currentPos, currentPos).expand(hitRadius))) {
if (e instanceof LivingEntity liv && !liv.equals(player)) {
liv.damage(player.getDamageSources().magic(), damage * 0.3f);
liv.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, 40, 2, false, false));
Vec3d kb = liv.getPos().subtract(player.getPos()).normalize().multiply(0.5);
liv.addVelocity(kb.x, 0.3, kb.z);
liv.velocityModified = true;
}
}
w.spawnParticles(ParticleTypes.ELECTRIC_SPARK, currentPos.x, currentPos.y + 1, currentPos.z, 8, 0.5, 0.5, 0.5, 0.1);
});
TickScheduler.schedule(world, 20, 20, 1, w -> {
Vec3d endPos = player.getPos();
for (Entity e : w.getOtherEntities(player, new Box(endPos, endPos).expand(hitRadius * 1.5))) {
if (e instanceof LivingEntity liv && !liv.equals(player)) {
liv.damage(player.getDamageSources().magic(), damage * 0.5f);
}
}
w.spawnParticles(ParticleTypes.FLASH, endPos.x, endPos.y + 1, endPos.z, 3, 0.5, 0.5, 0.5, 0.05);
});
JutsuLogger.logBehavior("chidori", "dash=" + dashDistance + " hitRadius=" + hitRadius);
}
}
'@

# ================================================================
# 7. AmaterasuBehavior.java
# ================================================================
Write-File "$base\java\com\example\shinobicore\jutsu\custom\AmaterasuBehavior.java" @'
package com.example.shinobicore.jutsu.custom;
import com.example.shinobicore.entity.NinjaProjectileEntity;
import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
public class AmaterasuBehavior implements JutsuBehavior {
@Override
public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
JsonObject params, float damage) {
if (!(player.getWorld() instanceof ServerWorld world)) return;
float speed = params.has("speed") ? params.get("speed").getAsFloat() : 2.0f;
float radius = params.has("radius") ? params.get("radius").getAsFloat() : 2f;
int lifetime = params.has("lifetime") ? params.get("lifetime").getAsInt() : 60;
Vec3d eye = player.getEyePos();
Vec3d look = player.getRotationVector();
NinjaProjectileEntity proj = new NinjaProjectileEntity(
world, player, look.multiply(speed), damage, radius, "smoke", "amaterasu", lifetime
);
proj.setPosition(eye.x, eye.y - 0.2, eye.z);
proj.setHasGravity(false);
world.spawnEntity(proj);
world.playSound(null, player.getBlockPos(), SoundEvents.ENTITY_BLAZE_SHOOT, SoundCategory.PLAYERS, 1.5f, 0.6f);
TickScheduler.schedule(world, 1, 3, 15, w -> {
if (!proj.isRemoved()) {
w.spawnParticles(ParticleTypes.SMOKE, proj.getX(), proj.getY(), proj.getZ(), 4, 0.3, 0.3, 0.3, 0.05);
w.spawnParticles(ParticleTypes.LARGE_SMOKE, proj.getX(), proj.getY(), proj.getZ(), 2, 0.2, 0.2, 0.2, 0.03);
}
});
JutsuLogger.logBehavior("amaterasu", "speed=" + speed + " radius=" + radius);
}
}
'@

# ================================================================
# 8. SandCoffinBehavior.java
# ================================================================
Write-File "$base\java\com\example\shinobicore\jutsu\custom\SandCoffinBehavior.java" @'
package com.example.shinobicore.jutsu.custom;
import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;
import net.minecraft.text.Text;
import net.minecraft.util.math.Vec3d;
public class SandCoffinBehavior implements JutsuBehavior {
@Override
public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
JsonObject params, float damage) {
if (!(player.getWorld() instanceof ServerWorld world)) return;
float range = params.has("range") ? params.get("range").getAsFloat() : 15f;
LivingEntity target = null;
double closestDist = Double.MAX_VALUE;
for (Entity e : world.getOtherEntities(player, player.getBoundingBox().expand(range))) {
if (e instanceof LivingEntity liv && !liv.equals(player)) {
double d = liv.getPos().distanceTo(player.getPos());
if (d < closestDist) {
closestDist = d;
target = liv;
}
}
}
if (target == null) {
player.sendMessage(Text.literal("\u00a7cNo target in range!"), false);
return;
}
final LivingEntity finalTarget = target;
finalTarget.addStatusEffect(new StatusEffectInstance(StatusEffects.LEVITATION, 60, 2, false, false));
finalTarget.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, 60, 255, false, false));
finalTarget.addStatusEffect(new StatusEffectInstance(StatusEffects.MINING_FATIGUE, 60, 255, false, false));
world.playSound(null, player.getBlockPos(), SoundEvents.BLOCK_SAND_PLACE, SoundCategory.PLAYERS, 1.5f, 0.8f);
player.sendMessage(Text.literal("\u00a76Sand Coffin!"), true);
TickScheduler.schedule(world, 1, 5, 12, w -> {
Vec3d pos = finalTarget.getPos();
w.spawnParticles(ParticleTypes.POOF, pos.x, pos.y + 1, pos.z, 15, 1, 1, 1, 0.1);
w.spawnParticles(ParticleTypes.FALLING_NECTAR, pos.x, pos.y + 1.5, pos.z, 5, 0.5, 0.5, 0.5, 0.05);
});
TickScheduler.schedule(world, 60, 60, 1, w -> {
Vec3d pos = finalTarget.getPos();
finalTarget.damage(player.getDamageSources().magic(), damage);
Vec3d kb = finalTarget.getPos().subtract(player.getPos()).normalize().multiply(2.0);
finalTarget.addVelocity(kb.x, 0.5, kb.z);
finalTarget.velocityModified = true;
w.spawnParticles(ParticleTypes.EXPLOSION, pos.x, pos.y + 1, pos.z, 5, 0.5, 0.5, 0.5, 0.05);
w.playSound(null, finalTarget.getBlockPos(), SoundEvents.ENTITY_GENERIC_EXPLODE, SoundCategory.PLAYERS, 1.0f, 1.0f);
});
JutsuLogger.logBehavior("sand_coffin", "target=" + target.getName().getString());
}
}
'@

# ================================================================
# 9-16. JSON файлы техник
# ================================================================
Write-File "$base\resources\data\shinobicore\jutsu\fire_dragon.json" @'
{"id":"shinobicore:fire_dragon","name":"Fire Release: Dragon Flame Bullet","category":"elemental_ninjutsu","nature":"fire","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.FireDragonBehavior","params":{"speed":1.5,"radius":4,"lifetime":80,"model":"fire_dragon"},"baseCost":45,"baseDamage":16,"strain":12,"requiredUsesForFullProficiency":60,"requirements":{"control":28,"nature_fire":35,"ninjutsu":24}}
'@
Write-File "$base\resources\data\shinobicore\jutsu\water_dragon_n.json" @'
{"id":"shinobicore:water_dragon_n","name":"Water Release: Water Dragon Bullet","category":"elemental_ninjutsu","nature":"water","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.WaterDragonBehavior","params":{"speed":1.4,"radius":4,"lifetime":100,"model":"water_dragon"},"baseCost":45,"baseDamage":14,"strain":12,"requiredUsesForFullProficiency":60,"requirements":{"control":28,"nature_water":35,"ninjutsu":24}}
'@
Write-File "$base\resources\data\shinobicore\jutsu\shadow_clone.json" @'
{"id":"shinobicore:shadow_clone","name":"Shadow Clone Jutsu","category":"general","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.ShadowCloneBehavior","params":{"count":3,"duration":400},"baseCost":50,"baseDamage":0,"strain":12,"requiredUsesForFullProficiency":50,"requirements":{"control":25,"ninjutsu":30}}
'@
Write-File "$base\resources\data\shinobicore\jutsu\chidori.json" @'
{"id":"shinobicore:chidori","name":"Chidori","category":"elemental_ninjutsu","nature":"lightning","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.ChidoriBehavior","params":{"dashDistance":8,"hitRadius":2},"baseCost":60,"baseDamage":22,"strain":16,"requiredUsesForFullProficiency":80,"requirements":{"control":35,"nature_lightning":40,"ninjutsu":30}}
'@
Write-File "$base\resources\data\shinobicore\jutsu\amaterasu.json" @'
{"id":"shinobicore:amaterasu","name":"Amaterasu","category":"elemental_ninjutsu","nature":"fire","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.AmaterasuBehavior","params":{"speed":2.0,"radius":2,"lifetime":60,"model":"amaterasu"},"baseCost":70,"baseDamage":15,"strain":20,"requiredUsesForFullProficiency":100,"requirements":{"control":40,"nature_fire":45,"genjutsu":25}}
'@
Write-File "$base\resources\data\shinobicore\jutsu\sand_coffin.json" @'
{"id":"shinobicore:sand_coffin","name":"Sand Coffin","category":"elemental_ninjutsu","nature":"earth","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.SandCoffinBehavior","params":{"range":15,"radius":5},"baseCost":55,"baseDamage":18,"strain":14,"requiredUsesForFullProficiency":70,"requirements":{"control":32,"nature_earth":35,"ninjutsu":28}}
'@
Write-File "$base\resources\data\shinobicore\jutsu\big_rasengan.json" @'
{"id":"shinobicore:big_rasengan","name":"Big Rasengan","category":"shape_ninjutsu","type":"custom","behaviorClass":"com.example.shinobicore.jutsu.custom.RasenganBehavior","params":{"baseChargeTicks":60,"minChargeTicks":15,"dashDistance":8.0,"hitRadius":4.0,"knockback":4.0,"particleCount":100,"model":"rasengan"},"baseCost":100,"baseDamage":40,"strain":20,"requiredUsesForFullProficiency":120,"requirements":{"control":40,"ninjutsu":40}}
'@
Write-File "$base\resources\data\shinobicore\jutsu\phoenix_fire.json" @'
{"id":"shinobicore:phoenix_fire","name":"Fire Release: Phoenix Sage Fire","category":"elemental_ninjutsu","nature":"fire","type":"projectile","params":{"speed":2.0,"radius":1.5,"particle":"fireball","lifetime":70,"count":6,"spread":15,"model":"fireball"},"baseCost":32,"baseDamage":6,"strain":8,"requiredUsesForFullProficiency":45,"requirements":{"control":20,"nature_fire":25,"ninjutsu":18}}
'@

# ================================================================
# 17. Патч tree.json — добавляем новые узлы
# ================================================================
$treeFile = "$base\resources\data\shinobicore\skill_tree\tree.json"
$tree = [System.IO.File]::ReadAllText($treeFile, $utf8)
if (-not $tree.Contains('"fire_dragon_n"')) {
$newNodes = @'
,
{"id":"fire_dragon_n","branch":"fire","distance":8,"type":"jutsu","jutsuId":"shinobicore:fire_dragon","spCost":10,"requires":["fire_bakuton_n"],"icon":"F","name":"Dragon Flame","description":"3D fire dragon projectile"},
{"id":"water_dragon_n","branch":"water","distance":8,"type":"jutsu","jutsuId":"shinobicore:water_dragon_n","spCost":10,"requires":["water_maelstrom"],"icon":"W","name":"Water Dragon","description":"3D water dragon projectile"},
{"id":"shadow_clone_n","branch":"general","distance":5,"type":"jutsu","jutsuId":"shinobicore:shadow_clone","spCost":8,"requires":["gen_substitution"],"icon":"N","name":"Shadow Clone","description":"Summon shadow clones"},
{"id":"chidori_n","branch":"lightning","distance":8,"type":"jutsu","jutsuId":"shinobicore:chidori","spCost":12,"requires":["light_storm_n"],"icon":"L","name":"Chidori","description":"Lightning blade dash"},
{"id":"amaterasu_n","branch":"fire","distance":8,"angleOffset":24,"type":"jutsu","jutsuId":"shinobicore:amaterasu","spCost":14,"requires":["fire_bakuton_n"],"icon":"A","name":"Amaterasu","description":"Black flame projectile"},
{"id":"sand_coffin_n","branch":"earth","distance":8,"type":"jutsu","jutsuId":"shinobicore:sand_coffin","spCost":11,"requires":["earth_maus_n"],"icon":"S","name":"Sand Coffin","description":"Imprison and crush target"},
{"id":"big_rasengan_n","branch":"general","distance":6,"type":"jutsu","jutsuId":"shinobicore:big_rasengan","spCost":16,"requires":["rasengan"],"icon":"R","name":"Big Rasengan","description":"Oversized Rasengan"},
{"id":"phoenix_fire_n","branch":"fire","distance":7,"angleOffset":18,"type":"jutsu","jutsuId":"shinobicore:phoenix_fire","spCost":8,"requires":["fire_phoenix_f_n"],"icon":"F","name":"Phoenix Sage","description":"6 homing fireballs"}
'@
$lastBracket = $tree.LastIndexOf("]")
if ($lastBracket -gt 0) {
$tree = $tree.Substring(0, $lastBracket) + $newNodes + $tree.Substring($lastBracket)
[System.IO.File]::WriteAllText($treeFile, $tree, $utf8)
Write-Host "[OK] tree.json patched with 8 new nodes" -ForegroundColor Green
} else {
Write-Host "[ERROR] tree.json: could not find nodes array end" -ForegroundColor Red
}
} else {
Write-Host "[SKIP] tree.json already has new nodes" -ForegroundColor Yellow
}

# ================================================================
# Итоговое сообщение
# ================================================================
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  ALL FILES CREATED SUCCESSFULLY!                    ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "Created:" -ForegroundColor Cyan
Write-Host "  [Java] ProjectileBehavior.java (updated with model param)" -ForegroundColor White
Write-Host "  [Java] NinjaProjectileRenderer.java (3D models: fire/water dragon, amaterasu, chidori)" -ForegroundColor White
Write-Host "  [Java] FireDragonBehavior.java" -ForegroundColor White
Write-Host "  [Java] WaterDragonBehavior.java" -ForegroundColor White
Write-Host "  [Java] ShadowCloneBehavior.java" -ForegroundColor White
Write-Host "  [Java] ChidoriBehavior.java" -ForegroundColor White
Write-Host "  [Java] AmaterasuBehavior.java" -ForegroundColor White
Write-Host "  [Java] SandCoffinBehavior.java" -ForegroundColor White
Write-Host "  [JSON] fire_dragon, water_dragon_n, shadow_clone, chidori," -ForegroundColor White
Write-Host "         amaterasu, sand_coffin, big_rasengan, phoenix_fire" -ForegroundColor White
Write-Host "  [Tree] 8 new nodes added" -ForegroundColor White
Write-Host ""
Write-Host "Next: .\gradlew.bat build" -ForegroundColor Yellow
Write-Host "Then: .\gradlew.bat runClient" -ForegroundColor Yellow
Write-Host "Test: /unlockall -> K -> assign new jutsu" -ForegroundColor Yellow
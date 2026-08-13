$utf8 = New-Object System.Text.UTF8Encoding($false)
$src = "E:\Games\mod\src\main\java\com\example\shinobicore"
$res = "E:\Games\mod\src\main\resources"
Write-Host "=== SHURIKEN + MARK + IDLE ANIMS ===" -ForegroundColor Cyan

function Patch($file, $marker, $insert, $name) {
    $c = [System.IO.File]::ReadAllText($file, $utf8)
    if ($c.Contains($marker)) {
        $c = $c.Replace($marker, $insert)
        [System.IO.File]::WriteAllText($file, $c, $utf8)
        Write-Host "[OK] $name" -ForegroundColor Green
    } else {
        Write-Host "[SKIP] $name (marker not found)" -ForegroundColor Yellow
    }
}

# === [1] MarkTracker.java ===
$file = "$src\combat\MarkTracker.java"
$code = @'
package com.example.shinobicore.combat;

import net.minecraft.entity.LivingEntity;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

public class MarkTracker {
    private static final Map<UUID, Long> MARKS = new ConcurrentHashMap<>();

    public static void mark(LivingEntity e, long ms) {
        MARKS.put(e.getUuid(), System.currentTimeMillis() + ms);
    }

    public static boolean isMarked(LivingEntity e) {
        Long t = MARKS.get(e.getUuid());
        return t != null && t > System.currentTimeMillis();
    }

    public static float boost(LivingEntity e, float dmg) {
        return isMarked(e) ? dmg * 1.2f : dmg;
    }

    public static void cleanup() {
        long now = System.currentTimeMillis();
        MARKS.entrySet().removeIf(en -> en.getValue() <= now);
    }
}
'@
[System.IO.File]::WriteAllText($file, $code, $utf8)
Write-Host "[1] MarkTracker.java" -ForegroundColor Green

# === [2] ThrowingHelper.java (aim assist) ===
$file = "$src\combat\ThrowingHelper.java"
$code = @'
package com.example.shinobicore.combat;

import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.stat.StatType;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.math.Vec3d;

public class ThrowingHelper {

    public static double assistConeDeg(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        int perception = data.getStatLevel(StatType.PERCEPTION);
        double cone = 3.0 + perception * 0.12;
        if (data.isNodeUnlocked("shuriken_accuracy")) cone += 5.0;
        return cone;
    }

    public static float assistBlend(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        int perception = data.getStatLevel(StatType.PERCEPTION);
        return (float) Math.min(1.0, 0.5 + perception / 200.0);
    }

    public static long markDurationMs(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        return data.isNodeUnlocked("shuriken_mark") ? 15000 : 10000;
    }

    public static boolean doubleThrow(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        return data.isNodeUnlocked("shuriken_double");
    }

    public static Vec3d aimAssist(ServerPlayerEntity player, Vec3d dir, double range) {
        double coneRad = Math.toRadians(assistConeDeg(player));
        Vec3d eye = player.getEyePos();
        Vec3d flat = dir.normalize();
        LivingEntity best = null;
        double bestAngle = Double.MAX_VALUE;
        for (LivingEntity e : player.getWorld().getEntitiesByClass(LivingEntity.class,
                player.getBoundingBox().expand(range), t -> t != player && t.isAlive())) {
            Vec3d to = e.getPos().add(0, e.getHeight() * 0.6, 0).subtract(eye);
            double dist = to.length();
            if (dist > range || dist < 0.5) continue;
            double angle = Math.acos(Math.max(-1, Math.min(1, flat.dotProduct(to.normalize()))));
            if (angle <= coneRad && angle < bestAngle) {
                bestAngle = angle;
                best = e;
            }
        }
        if (best == null) return dir;
        Vec3d toTarget = best.getPos().add(0, best.getHeight() * 0.6, 0).subtract(eye).normalize();
        return flat.lerp(toTarget, assistBlend(player)).normalize();
    }
}
'@
[System.IO.File]::WriteAllText($file, $code, $utf8)
Write-Host "[2] ThrowingHelper.java" -ForegroundColor Green

# === [3] ShurikenEntity.java ===
$file = "$src\entity\ShurikenEntity.java"
$code = @'
package com.example.shinobicore.entity;

import com.example.shinobicore.combat.MarkTracker;
import com.example.shinobicore.combat.ThrowingHelper;
import net.minecraft.entity.Entity;
import net.minecraft.entity.EntityType;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.data.DataTracker;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundEvents;
import net.minecraft.util.hit.BlockHitResult;
import net.minecraft.util.hit.HitResult;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.RaycastContext;
import net.minecraft.world.World;

import java.util.List;
import java.util.UUID;

public class ShurikenEntity extends Entity {
    private UUID ownerId;
    private float damage = 3f;
    private boolean stuck = false;
    private int age = 0;

    public ShurikenEntity(EntityType<?> type, World world) { super(type, world); }

    public ShurikenEntity(World world, LivingEntity owner, Vec3d velocity, float damage) {
        super(ModEntities.SHURIKEN, world);
        this.ownerId = owner.getUuid();
        this.damage = damage;
        this.setPosition(owner.getX(), owner.getEyeY() - 0.2, owner.getZ());
        this.setVelocity(velocity);
        this.velocityDirty = true;
    }

    @Override
    protected void initDataTracker() {}

    @Override
    public void tick() {
        super.tick();
        age++;
        if (stuck) {
            if (age > 400) discard();
            return;
        }
        if (age > 160) { discard(); return; }

        Vec3d vel = this.getVelocity();
        vel = new Vec3d(vel.x, vel.y - 0.035, vel.z);
        this.setVelocity(vel);

        Vec3d start = this.getPos();
        Vec3d end = start.add(vel);

        HitResult blockHit = this.getWorld().raycast(new RaycastContext(
                start, end, RaycastContext.ShapeType.COLLIDER, RaycastContext.FluidHandling.NONE, this));

        LivingEntity hitEntity = null;
        double closest = Double.MAX_VALUE;
        Box searchBox = this.getBoundingBox().stretch(vel).expand(0.15);
        for (Entity entity : this.getWorld().getOtherEntities(this, searchBox)) {
            if (entity instanceof LivingEntity living
                    && (ownerId == null || !living.getUuid().equals(ownerId))) {
                var opt = living.getBoundingBox().expand(0.3).raycast(start, end);
                if (opt.isPresent()) {
                    double d = start.squaredDistanceTo(opt.get());
                    if (d < closest) { closest = d; hitEntity = living; }
                }
            }
        }

        if (hitEntity != null) {
            float finalDmg = MarkTracker.boost(hitEntity, damage);
            hitEntity.damage(this.getDamageSources().mobProjectile(this, getOwner()), finalDmg);
            Entity owner = getOwner();
            if (owner instanceof ServerPlayerEntity sp) {
                MarkTracker.mark(hitEntity, ThrowingHelper.markDurationMs(sp));
            } else {
                MarkTracker.mark(hitEntity, 10000);
            }
            hitEntity.addStatusEffect(new StatusEffectInstance(StatusEffects.GLOWING, 100, 0, false, false));
            if (this.getWorld() instanceof ServerWorld sw) {
                sw.spawnParticles(ParticleTypes.CRIT, hitEntity.getX(), hitEntity.getY() + 1, hitEntity.getZ(),
                        8, 0.3, 0.3, 0.3, 0.05);
            }
            this.playSound(SoundEvents.ENTITY_ARROW_HIT, 0.8f, 1.2f);
            this.discard();
            return;
        }

        if (blockHit.getType() == HitResult.Type.BLOCK) {
            stuck = true;
            this.setVelocity(Vec3d.ZERO);
            this.playSound(SoundEvents.ENTITY_ARROW_HIT_GROUND, 0.5f, 1.4f);
            return;
        }

        this.setPosition(this.getX() + vel.x, this.getY() + vel.y, this.getZ() + vel.z);
        if (this.getWorld() instanceof ServerWorld sw && age % 2 == 0) {
            sw.spawnParticles(ParticleTypes.POOF, this.getX(), this.getY(), this.getZ(),
                    1, 0.02, 0.02, 0.02, 0.01);
        }
    }

    public Entity getOwner() {
        if (ownerId == null) return null;
        if (this.getWorld() instanceof ServerWorld sw) {
            return sw.getPlayerByUuid(ownerId);
        }
        return null;
    }

    public int getAge() { return age; }
    public boolean isStuck() { return stuck; }

    @Override
    protected void readCustomDataFromNbt(NbtCompound nbt) {
        damage = nbt.getFloat("Damage");
        if (nbt.containsUuid("OwnerUUID")) ownerId = nbt.getUuid("OwnerUUID");
    }

    @Override
    protected void writeCustomDataToNbt(NbtCompound nbt) {
        nbt.putFloat("Damage", damage);
        if (ownerId != null) nbt.putUuid("OwnerUUID", ownerId);
    }
}
'@
[System.IO.File]::WriteAllText($file, $code, $utf8)
Write-Host "[3] ShurikenEntity.java" -ForegroundColor Green

# === [4] ShurikenRenderer.java ===
$file = "$src\entity\ShurikenRenderer.java"
$code = @'
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

public class ShurikenRenderer extends EntityRenderer<ShurikenEntity> {
    private static final Identifier TEX = new Identifier("textures/misc/white.png");

    public ShurikenRenderer(EntityRendererFactory.Context ctx) { super(ctx); }

    @Override
    public void render(ShurikenEntity entity, float yaw, float tickDelta,
                       MatrixStack matrices, VertexConsumerProvider vc, int light) {
        super.render(entity, yaw, tickDelta, matrices, vc, light);
        matrices.push();
        matrices.translate(0, 0.25, 0);
        if (!entity.isStuck()) {
            float spin = (entity.getAge() + tickDelta) * 25f;
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(spin));
            matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(90));
        }
        VertexConsumer consumer = vc.getBuffer(RenderLayer.getEntityTranslucent(TEX));
        float s = 0.22f;
        float r = 0.75f, g = 0.75f, b = 0.78f, a = 1f;
        for (int q = 0; q < 2; q++) {
            matrices.push();
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(q * 90f));
            Matrix4f m = matrices.peek().getPositionMatrix();
            vertex(consumer, m, -s, 0, -s, r, g, b, a, light);
            vertex(consumer, m, -s, 0,  s, r, g, b, a, light);
            vertex(consumer, m,  s, 0,  s, r, g, b, a, light);
            vertex(consumer, m,  s, 0, -s, r, g, b, a, light);
            matrices.pop();
        }
        matrices.pop();
    }

    private void vertex(VertexConsumer c, Matrix4f m, float x, float y, float z,
                        float r, float g, float b, float a, int light) {
        c.vertex(m, x, y, z).color(r, g, b, a).texture(0, 0)
                .overlay(OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
    }

    @Override
    public Identifier getTexture(ShurikenEntity entity) { return TEX; }
}
'@
[System.IO.File]::WriteAllText($file, $code, $utf8)
Write-Host "[4] ShurikenRenderer.java" -ForegroundColor Green

# === [5] ThrowingWeaponItem.java ===
$file = "$src\item\ThrowingWeaponItem.java"
$code = @'
package com.example.shinobicore.item;

import com.example.shinobicore.combat.ThrowingHelper;
import com.example.shinobicore.entity.ShurikenEntity;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.item.Item;
import net.minecraft.item.ItemStack;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.sound.SoundEvents;
import net.minecraft.util.Hand;
import net.minecraft.util.TypedActionResult;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.World;

public class ThrowingWeaponItem extends Item {
    private final float damage;
    private final float speed;
    private final int cooldown;

    public ThrowingWeaponItem(Settings settings, float damage, float speed, int cooldown) {
        super(settings);
        this.damage = damage;
        this.speed = speed;
        this.cooldown = cooldown;
    }

    @Override
    public TypedActionResult<ItemStack> use(World world, PlayerEntity user, Hand hand) {
        ItemStack stack = user.getStackInHand(hand);
        if (!world.isClient && user instanceof ServerPlayerEntity sp) {
            Vec3d dir = ThrowingHelper.aimAssist(sp, user.getRotationVector(), 24.0);
            ShurikenEntity proj = new ShurikenEntity(world, user, dir.multiply(speed), damage);
            world.spawnEntity(proj);
            if (ThrowingHelper.doubleThrow(sp)) {
                Vec3d dir2 = rotate(dir, 4.0);
                ShurikenEntity proj2 = new ShurikenEntity(world, user, dir2.multiply(speed), damage);
                world.spawnEntity(proj2);
            }
            user.playSound(SoundEvents.ENTITY_ARROW_SHOOT, 0.8f, 1.4f);
            if (!user.getAbilities().creativeMode) stack.decrement(1);
            user.getItemCooldownManager().set(this, cooldown);
        }
        return TypedActionResult.success(stack, world.isClient());
    }

    private Vec3d rotate(Vec3d v, double deg) {
        double rad = Math.toRadians(deg);
        double cos = Math.cos(rad), sin = Math.sin(rad);
        return new Vec3d(v.x * cos - v.z * sin, v.y, v.x * sin + v.z * cos).normalize();
    }
}
'@
[System.IO.File]::WriteAllText($file, $code, $utf8)
Write-Host "[5] ThrowingWeaponItem.java" -ForegroundColor Green

# === [6] ModItems.java ===
$file = "$src\item\ModItems.java"
$code = @'
package com.example.shinobicore.item;

import com.example.shinobicore.ShinobiCore;
import net.minecraft.item.Item;
import net.minecraft.registry.Registries;
import net.minecraft.registry.Registry;
import net.minecraft.util.Identifier;

public class ModItems {
    public static final Item SHURIKEN = Registry.register(Registries.ITEM,
            new Identifier(ShinobiCore.MOD_ID, "shuriken"),
            new ThrowingWeaponItem(new Item.Settings().maxCount(16), 3f, 3.0f, 8));

    public static final Item KUNAI = Registry.register(Registries.ITEM,
            new Identifier(ShinobiCore.MOD_ID, "kunai"),
            new ThrowingWeaponItem(new Item.Settings().maxCount(16), 5f, 2.2f, 12));

    public static void register() {
        ShinobiCore.LOGGER.info("Registered shuriken/kunai items");
    }
}
'@
[System.IO.File]::WriteAllText($file, $code, $utf8)
Write-Host "[6] ModItems.java" -ForegroundColor Green

# === [7] IdlePoseSystem.java ===
$file = "$src\client\IdlePoseSystem.java"
$code = @'
package com.example.shinobicore.client;

import com.example.shinobicore.item.ModItems;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.client.render.entity.model.BipedEntityModel;
import net.minecraft.item.ItemStack;
import net.minecraft.item.SwordItem;
import net.minecraft.util.math.MathHelper;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

public class IdlePoseSystem {

    private static final Map<UUID, FidgetState> STATES = new HashMap<>();

    private static class FidgetState {
        long nextFidgetAt = 0;
        int fidget = -1;
        long fidgetStart = 0;
    }

    public static void apply(AbstractClientPlayerEntity player, BipedEntityModel<?> model,
                             float moveAmount, float animProgress) {
        if (moveAmount > 0.1f) return;

        float t = animProgress;
        float breath = MathHelper.sin(t * 0.07f) * 0.03f;

        if (ClientNinjaState.meditating) { applyMeditate(model, breath); return; }
        if (ChakraPhysicsClient.stickingToWall) { applyWallStick(model); return; }

        ItemStack main = player.getMainHandStack();
        boolean weapon = !main.isEmpty()
                && (main.getItem() instanceof SwordItem
                    || main.getItem() == ModItems.SHURIKEN
                    || main.getItem() == ModItems.KUNAI);

        boolean chakra = ClientNinjaState.chakraMode && ChakraHudRenderer.currentChakra > 0;

        if (weapon) applyWeaponStance(model, breath);
        else if (chakra) applyNinjaGuard(model, breath);
        else applyNormalIdle(model, breath, player);
    }

    private static void applyMeditate(BipedEntityModel<?> m, float breath) {
        m.rightArm.pitch = -0.9f + breath;
        m.leftArm.pitch = -0.9f + breath;
        m.rightArm.yaw = -0.5f;
        m.leftArm.yaw = 0.5f;
        m.head.pitch += 0.25f;
        m.body.pitch += 0.12f;
        m.rightLeg.yaw = 0.5f;
        m.leftLeg.yaw = -0.5f;
        m.rightLeg.pitch = -1.1f;
        m.leftLeg.pitch = -1.1f;
    }

    private static void applyWallStick(BipedEntityModel<?> m) {
        m.rightArm.pitch = -1.5f;
        m.leftArm.pitch = -1.5f;
        m.rightArm.yaw = -0.15f;
        m.leftArm.yaw = 0.15f;
        m.head.pitch -= 0.1f;
    }

    private static void applyWeaponStance(BipedEntityModel<?> m, float breath) {
        m.rightArm.pitch = -1.15f + breath;
        m.rightArm.yaw = -0.25f;
        m.leftArm.pitch = -0.75f + breath;
        m.leftArm.yaw = 0.45f;
        m.body.pitch += 0.10f;
        m.rightLeg.yaw = -0.25f;
        m.leftLeg.yaw = 0.25f;
        m.head.pitch -= 0.08f;
    }

    private static void applyNinjaGuard(BipedEntityModel<?> m, float breath) {
        m.rightArm.pitch = -0.95f + breath;
        m.rightArm.yaw = -0.40f;
        m.leftArm.pitch = -0.70f + breath;
        m.leftArm.yaw = 0.50f;
        m.body.pitch += 0.12f;
        m.rightLeg.yaw = -0.22f;
        m.leftLeg.yaw = 0.22f;
        m.rightLeg.pitch += 0.08f;
        m.leftLeg.pitch += 0.08f;
        m.head.pitch -= 0.10f;
    }

    private static void applyNormalIdle(BipedEntityModel<?> m, float breath,
                                        AbstractClientPlayerEntity player) {
        m.body.pitch += breath * 0.6f;
        m.rightArm.pitch += breath;
        m.leftArm.pitch += breath;

        FidgetState st = STATES.computeIfAbsent(player.getUuid(), u -> new FidgetState());
        long now = System.currentTimeMillis();
        if (st.fidget >= 0) {
            float p = (now - st.fidgetStart) / 2500f;
            if (p >= 1f) {
                st.fidget = -1;
                st.nextFidgetAt = now + 5000 + (long)(Math.random() * 7000);
            } else {
                float f = MathHelper.sin(p * (float) Math.PI);
                switch (st.fidget) {
                    case 0 -> m.head.yaw += f * 0.6f;
                    case 1 -> {
                        m.body.roll += f * 0.06f;
                        m.rightLeg.yaw -= f * 0.15f;
                        m.leftLeg.yaw += f * 0.15f;
                    }
                    case 2 -> {
                        m.rightArm.pitch += f * -1.6f;
                        m.rightArm.yaw += f * -0.5f;
                    }
                }
            }
        } else if (now >= st.nextFidgetAt) {
            st.fidget = (int)(Math.random() * 3);
            st.fidgetStart = now;
        }
    }
}
'@
[System.IO.File]::WriteAllText($file, $code, $utf8)
Write-Host "[7] IdlePoseSystem.java" -ForegroundColor Green

# === [8] ModEntities: SHURIKEN ===
$file = "$src\entity\ModEntities.java"
$marker = 'public static void register() {'
$insert = @'
public static final EntityType<ShurikenEntity> SHURIKEN = Registry.register(
            Registries.ENTITY_TYPE,
            new Identifier(ShinobiCore.MOD_ID, "shuriken"),
            FabricEntityTypeBuilder.<ShurikenEntity>create(SpawnGroup.MISC, ShurikenEntity::new)
                    .dimensions(EntityDimensions.fixed(0.25f, 0.25f))
                    .trackRangeChunks(16)
                    .trackedUpdateRate(1)
                    .build()
    );

    public static void register() {
'@
Patch $file $marker $insert "ModEntities: SHURIKEN entity"

# === [9] ShinobiCore: register items ===
$file = "$src\ShinobiCore.java"
Patch $file 'ModEntities.register();' 'ModEntities.register();
        ModItems.register();' "ShinobiCore: ModItems.register()"
Patch $file 'import com.example.shinobicore.entity.ModEntities;' 'import com.example.shinobicore.entity.ModEntities;
import com.example.shinobicore.item.ModItems;' "ShinobiCore: ModItems import"

# === [10] ShinobiCoreClient: renderer + meditating sync ===
$file = "$src\client\ShinobiCoreClient.java"
Patch $file 'EntityRendererRegistry.register(ModEntities.NINJA_PROJECTILE, NinjaProjectileRenderer::new);' 'EntityRendererRegistry.register(ModEntities.NINJA_PROJECTILE, NinjaProjectileRenderer::new);
        EntityRendererRegistry.register(ModEntities.SHURIKEN, ShurikenRenderer::new);' "ShinobiCoreClient: shuriken renderer"
Patch $file 'import com.example.shinobicore.entity.NinjaProjectileRenderer;' 'import com.example.shinobicore.entity.NinjaProjectileRenderer;
import com.example.shinobicore.entity.ShurikenRenderer;' "ShinobiCoreClient: renderer import"
Patch $file 'ChakraHudRenderer.exhausted = packet.exhausted();' 'ChakraHudRenderer.exhausted = packet.exhausted();
                ClientNinjaState.meditating = packet.meditating();' "ShinobiCoreClient: meditating sync"

# === [11] ClientNinjaState: meditating ===
$file = "$src\client\ClientNinjaState.java"
Patch $file 'public static boolean sensoryEnabled = true;' 'public static boolean sensoryEnabled = true;
    public static boolean meditating = false;' "ClientNinjaState: meditating"

# === [12] ChakraPhysicsClient: public sticking flag ===
$file = "$src\client\ChakraPhysicsClient.java"
Patch $file 'private static boolean wasStickingToWall = false;' 'private static boolean wasStickingToWall = false;
    public static boolean stickingToWall = false;' "ChakraPhysicsClient: stickingToWall field"
Patch $file 'wasStickingToWall = stickingNow;' 'wasStickingToWall = stickingNow;
            stickingToWall = stickingNow;' "ChakraPhysicsClient: update flag"

# === [13] Mixin: idle hook ===
$file = "$src\mixin\PlayerRenderAnimationMixin.java"
$marker = @'
        if (TaijutsuAnimations.isKicking(player)) {
            applyKickAnimation(player);
        }
    }
'@
$insert = @'
        if (TaijutsuAnimations.isKicking(player)) {
            applyKickAnimation(player);
        }
        // === IDLE POSE SYSTEM ===
        if (!TaijutsuAnimations.isAttacking(player) && !TaijutsuAnimations.isKicking(player)) {
            IdlePoseSystem.apply(player, (BipedEntityModel<?>) (Object) this, limbDistance, animationProgress);
        }
    }
'@
Patch $file $marker $insert "Mixin: idle hook"
Patch $file 'import com.example.shinobicore.client.combat.TaijutsuAnimations;' 'import com.example.shinobicore.client.combat.TaijutsuAnimations;
import com.example.shinobicore.client.IdlePoseSystem;' "Mixin: IdlePoseSystem import"

# === [14] Mark boost in behaviors ===
$file = "$src\jutsu\AoeBehavior.java"
Patch $file 'living.damage(player.getDamageSources().magic(), damage);' 'living.damage(player.getDamageSources().magic(), MarkTracker.boost(living, damage));' "AoeBehavior: mark boost"
Patch $file 'import com.example.shinobicore.stat.NinjaPlayerData;' 'import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.combat.MarkTracker;' "AoeBehavior: import"

$file = "$src\jutsu\MeleeBehavior.java"
Patch $file 'target.damage(player.getDamageSources().magic(), damage);' 'target.damage(player.getDamageSources().magic(), MarkTracker.boost(target, damage));' "MeleeBehavior: mark boost"
Patch $file 'import com.example.shinobicore.stat.NinjaPlayerData;' 'import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.combat.MarkTracker;' "MeleeBehavior: import"

$file = "$src\jutsu\DashBehavior.java"
Patch $file 'target.damage(player.getDamageSources().magic(), damage);' 'target.damage(player.getDamageSources().magic(), MarkTracker.boost(target, damage));' "DashBehavior: mark boost"
Patch $file 'import com.example.shinobicore.stat.NinjaPlayerData;' 'import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.combat.MarkTracker;' "DashBehavior: import"

$file = "$src\entity\NinjaProjectileEntity.java"
Patch $file 'hitEntity.damage(this.getDamageSources().magic(), damage);' 'hitEntity.damage(this.getDamageSources().magic(), MarkTracker.boost(hitEntity, damage));' "NinjaProjectileEntity: mark boost"
Patch $file 'import com.example.shinobicore.ShinobiCore;' 'import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.combat.MarkTracker;' "NinjaProjectileEntity: import"

# === [15] tree.json: shuriken branch + nodes ===
$file = "$res\data\shinobicore\skill_tree\tree.json"
$c = [System.IO.File]::ReadAllText($file, $utf8)
if (-not $c.Contains('"shuriken"')) {
    $c = $c.Replace('    "kekkei":    {"angle": 0,   "color": "#FF66CC", "label": "Kekkei Genkai", "hidden": true},',
        '    "shuriken":  {"angle": 0,   "color": "#BBBBBB", "label": "Shurikenjutsu"},
    "kekkei":    {"angle": 0,   "color": "#FF66CC", "label": "Kekkei Genkai", "hidden": true},')
    $endMarker = @'
  ]
}
'@
    $endNew = @'
    {"id":"shuriken_accuracy","branch":"shuriken","distance":1,"type":"passive","effect":"aim_cone","value":5,"spCost":4,"requires":[],"icon":"x","name":"Eagle Eye","description":"+5 deg shuriken aim assist"},
    {"id":"shuriken_mark","branch":"shuriken","distance":2,"type":"passive","effect":"mark_duration","value":5,"spCost":5,"requires":["shuriken_accuracy"],"icon":"x","name":"Cursed Mark","description":"Mark lasts 15s instead of 10s"},
    {"id":"shuriken_double","branch":"shuriken","distance":3,"type":"passive","effect":"double_throw","value":1,"spCost":7,"requires":["shuriken_mark"],"icon":"x","name":"Shadow Shuriken","description":"Throw a second shuriken"}
  ]
}
'@
    $c = $c.Replace($endMarker, $endNew)
    [System.IO.File]::WriteAllText($file, $c, $utf8)
    Write-Host "[15] tree.json: shuriken branch" -ForegroundColor Green
}

# === [16] SkillTreeScreen BASE_ORDER ===
$file = "$src\client\SkillTreeScreen.java"
Patch $file '"sensory", "space", "kekkei"' '"sensory", "space", "shuriken", "kekkei"' "SkillTreeScreen: shuriken column"

# === [17] Рецепты ===
$dir = "$res\data\shinobicore\recipes"
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
[System.IO.File]::WriteAllText("$dir\shuriken.json", @'
{
  "type": "minecraft:crafting_shaped",
  "pattern": ["n n", " n ", "n n"],
  "key": { "n": { "item": "minecraft:iron_nugget" } },
  "result": { "item": "shinobicore:shuriken", "count": 4 }
}
'@, $utf8)
[System.IO.File]::WriteAllText("$dir\kunai.json", @'
{
  "type": "minecraft:crafting_shaped",
  "pattern": ["i", "s"],
  "key": { "i": { "item": "minecraft:iron_ingot" }, "s": { "item": "minecraft:stick" } },
  "result": { "item": "shinobicore:kunai", "count": 2 }
}
'@, $utf8)
Write-Host "[17] recipes" -ForegroundColor Green

# === [18] Модели предметов ===
$dir = "$res\assets\shinobicore\models\item"
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
[System.IO.File]::WriteAllText("$dir\shuriken.json", @'
{ "parent": "item/generated", "textures": { "layer0": "shinobicore:item/shuriken" } }
'@, $utf8)
[System.IO.File]::WriteAllText("$dir\kunai.json", @'
{ "parent": "item/generated", "textures": { "layer0": "shinobicore:item/kunai" } }
'@, $utf8)
Write-Host "[18] item models" -ForegroundColor Green

# === [19] Текстуры программно (System.Drawing) ===
try {
    Add-Type -AssemblyName System.Drawing
    $dir = "$res\assets\shinobicore\textures\item"
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    # Сюрикен: 4-лучевая звезда
    $bmp = New-Object System.Drawing.Bitmap(16, 16)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::Transparent)
    $gray = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 190, 190, 200))
    $dark = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 60, 60, 70))
    $pts = @(
        [System.Drawing.Point]::new(8, 0), [System.Drawing.Point]::new(10, 6),
        [System.Drawing.Point]::new(16, 8), [System.Drawing.Point]::new(10, 10),
        [System.Drawing.Point]::new(8, 16), [System.Drawing.Point]::new(6, 10),
        [System.Drawing.Point]::new(0, 8), [System.Drawing.Point]::new(6, 6)
    )
    $g.FillPolygon($gray, $pts)
    $g.FillEllipse($dark, 6, 6, 4, 4)
    $bmp.Save("$dir\shuriken.png", [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()

    # Кунай: лезвие + рукоять
    $bmp = New-Object System.Drawing.Bitmap(16, 16)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::Transparent)
    $blade = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 210, 210, 220))
    $handle = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 110, 70, 30))
    $bladePts = @([System.Drawing.Point]::new(13, 0), [System.Drawing.Point]::new(16, 5), [System.Drawing.Point]::new(9, 9), [System.Drawing.Point]::new(7, 7))
    $g.FillPolygon($blade, $bladePts)
    $g.FillRectangle($handle, 4, 8, 4, 6)
    $g.FillEllipse($handle, 2, 13, 4, 3)
    $bmp.Save("$dir\kunai.png", [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    Write-Host "[19] textures generated" -ForegroundColor Green
} catch {
    Write-Host "[19] texture generation failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

# === [20] lang ===
$dir = "$res\assets\shinobicore\lang"
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
[System.IO.File]::WriteAllText("$dir\en_us.json", @'
{
  "item.shinobicore.shuriken": "Shuriken",
  "item.shinobicore.kunai": "Kunai",
  "key.shinobicore.skill_tree": "Skill Tree",
  "key.shinobicore.toggle_sensory": "Toggle Sensory",
  "key.categories.shinobicore": "Shinobi Core",
  "key.categories.shinobicore.combat": "Shinobi Core: Combat"
}
'@, $utf8)
Write-Host "[20] lang en_us" -ForegroundColor Green

Write-Host "`n=== COMPLETE ===" -ForegroundColor Cyan
Write-Host "Run: .\gradlew.bat build; .\gradlew.bat runClient" -ForegroundColor Yellow
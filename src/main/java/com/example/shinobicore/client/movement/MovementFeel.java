package com.example.shinobicore.client.movement;

import com.example.shinobicore.client.ClientNinjaStateHolder;
import com.example.shinobicore.client.parkour.util.ParkourSounds;
import com.example.shinobicore.config.ModConfig;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.particle.DustParticleEffect;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.util.math.MathHelper;
import net.minecraft.util.math.Vec3d;
import org.joml.Vector3f;

/**
 * Movement Pack (1.1.4): ощущение движения — обратная связь и кривые.
 *
 * Решает две главные жалобы:
 *   1. «бег по воде как на коньках»  -> разгон с кривой, покачивание (bob),
 *      шаги по воде: брызги + звук каждые ~1.1 блока, всплеск при касании;
 *   2. «бег по стене как ползание»   -> быстрый подъём (W) с циклом шагов,
 *      тихий подъём (Shift), пыль из-под ног, наклон камеры к стене.
 *
 * Плюс: отдача камеры при приземлении (dip), кольцо чакры при двойном
 * прыжке, след рывка, пыль при подкате, кольцо при заряженном прыжке.
 *
 * Все числовые параметры — в конфиге (секция movement), правятся без кода.
 * Класс КЛИЕНТСКИЙ: частицы и звуки локальные, на сервер ничего не шлёт.
 */
public final class MovementFeel {

    private MovementFeel() {}

    // --- состояние ---
    private static double waterStepDist = 0;
    private static double waterBobPhase = 0;
    private static float waterBobOffset = 0f;
    private static double climbStepDist = 0;
    private static float climbPhase = 0f;
    private static int climbRecentTicks = 0;
    private static double wallRunStepDist = 0;
    private static float wallRunPhase = 0f;
    private static float wallSide = 0f;         // -1 стена слева, +1 справа
    private static float wallSideSmooth = 0f;
    private static float cameraRollDeg = 0f;
    private static float cameraRollTarget = 0f;
    private static float cameraDip = 0f;
    private static boolean wasOnGround = true;
    private static double airMinVy = 0;
    private static boolean jumpFxArmed = false;

    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(MovementFeel::tick);
    }

    private static ModConfig.Movement cfg() {
        return ModConfig.instance.movement;
    }

    private static void tick(MinecraftClient client) {
        ClientPlayerEntity p = client.player;
        // плавные величины камеры живут независимо от игрока (затухают)
        cameraRollDeg = MathHelper.lerp(0.14f, cameraRollDeg, cameraRollTarget);
        cameraDip *= 0.82f;
        if (Math.abs(cameraDip) < 0.002f) cameraDip = 0f;
        waterBobOffset *= 0.86f;

        if (p == null || client.world == null) return;

        // --- детект приземления (для dip + пыли + звука) ---
        boolean grounded = p.isOnGround();
        if (!wasOnGround && grounded) {
            if (airMinVy < -0.55) onLanding(p, (float) airMinVy);
            airMinVy = 0;
        }
        if (!grounded) {
            airMinVy = Math.min(airMinVy, p.getVelocity().y);
        }
        wasOnGround = grounded;

        if (climbRecentTicks > 0) climbRecentTicks--;
    }

    // ==================================================================
    //  ВОДА
    // ==================================================================

    /**
     * Вызывается каждый тик из ChakraPhysicsClient, пока игрок стоит на воде.
     * Даёт разгон с кривой (ease-out), покачивание и события шагов.
     */
    public static void waterRunTick(ClientPlayerEntity p, boolean pressingForward, boolean sprinting) {
        ModConfig.Movement c = cfg();
        Vec3d v = p.getVelocity();
        double horiz = Math.hypot(v.x, v.z);

        // 1) мягкий разгон до целевой скорости (кривая ease-out: чем ближе к
        //    максимуму, тем меньше добавка — без «конькового» рывка)
        if (pressingForward && !p.input.sneaking) {
            double max = c.waterRunMaxSpeed;
            if (horiz < max - 0.001) {
                Vec3d lookFlat = new Vec3d(p.getRotationVector().x, 0, p.getRotationVector().z);
                if (lookFlat.lengthSquared() > 1e-6) {
                    lookFlat = lookFlat.normalize();
                    // ease-out: добавка падает квадратично к максимуму
                    double room = 1.0 - (horiz / max);
                    double add = c.waterRunAccel * room * room + c.waterRunAccel * 0.25 * room;
                    p.setVelocity(v.x + lookFlat.x * add, v.y, v.z + lookFlat.z * add);
                    p.velocityModified = true;
                    horiz = Math.hypot(p.getVelocity().x, p.getVelocity().z);
                }
            }
        }

        // 2) покачивание: фаза от пройденного расстояния (синхрон с шагами)
        double speedFactor = MathHelper.clamp(horiz / 0.28, 0.0, 1.4);
        waterBobPhase += horiz * 2.4;
        float bob = (float) (Math.sin(waterBobPhase) * c.waterBobAmplitude * speedFactor);
        waterBobOffset = bob;

        // 3) события шагов: брызги + звук каждые waterStepDistance блоков
        waterStepDist += horiz;
        if (waterStepDist >= c.waterStepDistance) {
            waterStepDist -= c.waterStepDistance;
            if (horiz > 0.06) waterStep(p);
        }
    }

    private static void waterStep(ClientPlayerEntity p) {
        Vec3d pos = p.getPos();
        Vector3f col = affinityColor();
        // брызги в точке ноги (слегка сбоку по фазе — «переступание»)
        double side = (Math.sin(waterBobPhase) >= 0) ? 0.18 : -0.18;
        Vec3d look = p.getRotationVector();
        Vec3d right = new Vec3d(-look.z, 0, look.x).normalize();
        double fx = pos.x + right.x * side;
        double fz = pos.z + right.z * side;
        cw(p).addParticle(ParticleTypes.SPLASH, fx, pos.y + 0.05, fz, 0.02, 0.10, 0.02);
        cw(p).addParticle(ParticleTypes.SPLASH, fx, pos.y + 0.05, fz, 0.05, 0.14, 0.05);
        cw(p).addParticle(ParticleTypes.BUBBLE_POP, fx, pos.y + 0.03, fz, 0.03, 0.05, 0.03);
        // чакра у стопы
        cw(p).addParticle(new DustParticleEffect(col, 0.7f), fx, pos.y + 0.08, fz, 0.01, 0.03, 0.01);
        // импульс покачивания на шаг
        waterBobOffset += 0.012f;
        ParkourSounds.playWaterStep();
    }

    /** Всплеск при первом касании воды после воздуха. */
    public static void waterTouchdown(ClientPlayerEntity p) {
        Vec3d pos = p.getPos();
        for (int i = 0; i < 12; i++) {
            double a = i * Math.PI * 2.0 / 12.0;
            cw(p).addParticle(ParticleTypes.SPLASH,
                    pos.x + Math.cos(a) * 0.3, pos.y + 0.06, pos.z + Math.sin(a) * 0.3,
                    Math.cos(a) * 0.08, 0.16, Math.sin(a) * 0.08);
        }
        cw(p).addParticle(ParticleTypes.SPLASH, pos.x, pos.y + 0.1, pos.z, 0.15, 0.05, 0.15);
        ParkourSounds.playWaterTouchdown();
        addCameraDip(0.05f);
    }

    // ==================================================================
    //  СТЕНА: ВЕРТИКАЛЬНЫЙ ПОДЪЁМ (W — быстрый забег, Shift — тихий)
    // ==================================================================

    /**
     * Вызывается из ChakraPhysicsClient каждый тик прилипания к стене.
     * Возвращает вертикальную скорость подъёма/спуска.
     */
    public static float climbTick(ClientPlayerEntity p, boolean sneaking, boolean pressingForward, Vec3d wallNormal) {
        ModConfig.Movement c = cfg();
        float vy;
        boolean silent = sneaking;
        if (sneaking) {
            vy = c.wallClimbSilentSpeed;      // тихий подъём (для стелса)
        } else if (pressingForward) {
            vy = c.wallClimbSpeed;            // быстрый забег как в аниме
        } else {
            vy = 0f;                          // висим
        }
        updateWallSide(p, wallNormal);
        if (vy > 0.001f) {
            climbRecentTicks = 3;
            climbPhase += vy * 5.2f;
            climbStepDist += vy;
            if (climbStepDist >= c.wallClimbStepDistance) {
                climbStepDist -= c.wallClimbStepDistance;
                climbStep(p, wallNormal, silent);
            }
        } else {
            climbPhase += 0.02f;  // лёгкое «дыхание» позы, пока висим
        }
        return vy;
    }

    private static void climbStep(ClientPlayerEntity p, Vec3d wallNormal, boolean silent) {
        Vec3d feet = p.getPos().add(wallNormal.multiply(0.25));
        // пыль у стены в точке ноги
        cw(p).addParticle(ParticleTypes.SMOKE, feet.x, feet.y + 0.1, feet.z, 0.02, 0.02, 0.02);
        if (!silent) {
            cw(p).addParticle(ParticleTypes.CRIT, feet.x, feet.y + 0.15, feet.z, 0.03, 0.04, 0.03);
            ParkourSounds.playClimbStep();
        }
        // лёгкий наклон камеры к стене и при подъёме
        cameraRollTarget = -wallSideSmooth * cfg().wallRunRollDeg * 0.5f;
    }

    public static boolean isWallClimbing() { return climbRecentTicks > 0; }
    public static float getClimbPhase() { return climbPhase; }

    // ==================================================================
    //  СТЕНА: ГОРИЗОНТАЛЬНЫЙ БЕГ (WallRunAction)
    // ==================================================================

    public static void wallRunTick(ClientPlayerEntity p, Vec3d wallNormal, double horizSpeed) {
        updateWallSide(p, wallNormal);
        wallRunPhase += (float) horizSpeed * 2.9f;
        wallRunStepDist += horizSpeed;
        float stepDist = 0.8f;
        if (wallRunStepDist >= stepDist) {
            wallRunStepDist -= stepDist;
            Vec3d feet = p.getPos().add(wallNormal.multiply(0.3)).add(0, -0.35, 0);
            cw(p).addParticle(ParticleTypes.SMOKE, feet.x, feet.y, feet.z, 0.03, 0.02, 0.03);
            cw(p).addParticle(new DustParticleEffect(affinityColor(), 0.6f), feet.x, feet.y, feet.z, 0.02, 0.02, 0.02);
            ParkourSounds.playWallRunStep();
        }
        // наклон камеры к стене
        cameraRollTarget = wallSideSmooth * cfg().wallRunRollDeg;
    }

    public static void wallRunEnd() {
        cameraRollTarget = 0f;
        wallRunStepDist = 0;
    }

    public static float getWallRunPhase() { return wallRunPhase; }

    private static void updateWallSide(ClientPlayerEntity p, Vec3d wallNormal) {
        if (wallNormal == null) { wallSide = 0f; return; }
        Vec3d look = p.getRotationVector();
        Vec3d right = new Vec3d(-look.z, 0, look.x);
        if (right.lengthSquared() < 1e-6) return;
        right = right.normalize();
        Vec3d toWall = wallNormal.multiply(-1); // от игрока к стене
        wallSide = (toWall.dotProduct(right) > 0) ? 1f : -1f;
        wallSideSmooth = MathHelper.lerp(0.25f, wallSideSmooth, wallSide);
    }

    /** -1 — стена слева, +1 — стена справа, 0 — неизвестно. */
    public static float getWallSide() { return wallSideSmooth; }

    // ==================================================================
    //  РАЗОВЫЕ СОБЫТИЯ
    // ==================================================================

    public static void onDoubleJump(ClientPlayerEntity p) {
        Vec3d pos = p.getPos();
        Vector3f col = affinityColor();
        // кольцо чакры под ногами
        for (int i = 0; i < 12; i++) {
            double a = i * Math.PI * 2.0 / 12.0;
            cw(p).addParticle(new DustParticleEffect(col, 0.9f),
                    pos.x + Math.cos(a) * 0.35, pos.y + 0.08, pos.z + Math.sin(a) * 0.35,
                    Math.cos(a) * 0.06, 0.02, Math.sin(a) * 0.06);
        }
        for (int i = 0; i < 4; i++) {
            cw(p).addParticle(ParticleTypes.SOUL_FIRE_FLAME,
                    pos.x + (Math.random() - 0.5) * 0.3, pos.y - 0.05, pos.z + (Math.random() - 0.5) * 0.3,
                    0, -0.04, 0);
        }
        ParkourSounds.playAirJump();
        addCameraDip(-0.05f);   // камера чуть «подпрыгивает»
    }

    public static void onWallJump(ClientPlayerEntity p, Vec3d wallNormal) {
        if (wallNormal == null) return;
        Vec3d at = p.getPos().add(wallNormal.multiply(-0.35)).add(0, 0.6, 0);
        for (int i = 0; i < 8; i++) {
            cw(p).addParticle(ParticleTypes.SMOKE, at.x, at.y + (Math.random() - 0.5) * 0.6, at.z,
                    wallNormal.x * -0.05, 0.02, wallNormal.z * -0.05);
        }
        cw(p).addParticle(ParticleTypes.CRIT, at.x, at.y, at.z, 0.08, 0.08, 0.08);
    }

    public static void onDodge(ClientPlayerEntity p, Vec3d dodgeDir) {
        Vec3d pos = p.getPos().add(0, 0.7, 0);
        Vector3f col = affinityColor();
        for (int i = 0; i < 8; i++) {
            double back = 0.25 + i * 0.11;
            cw(p).addParticle(new DustParticleEffect(col, 0.8f),
                    pos.x - dodgeDir.x * back, pos.y + (Math.random() - 0.5) * 0.4, pos.z - dodgeDir.z * back,
                    0, 0.01, 0);
        }
        addCameraDip(-0.035f);
    }

    public static void onSlideTick(ClientPlayerEntity p, int ticks) {
        if (ticks % 3 != 0) return;
        Vec3d v = p.getVelocity();
        Vec3d back = p.getPos().add(0, 0.05, 0).subtract(new Vec3d(v.x, 0, v.z).multiply(1.5));
        cw(p).addParticle(ParticleTypes.SMOKE, back.x, back.y, back.z, 0.02, 0.03, 0.02);
        cw(p).addParticle(ParticleTypes.CRIT, back.x, back.y + 0.05, back.z, 0.03, 0.02, 0.03);
    }

    public static void onChargedJumpRelease(ClientPlayerEntity p, float chargeRatio) {
        Vec3d pos = p.getPos();
        int n = 10 + (int) (chargeRatio * 10);
        Vector3f col = affinityColor();
        for (int i = 0; i < n; i++) {
            double a = i * Math.PI * 2.0 / n;
            double r = 0.4 + chargeRatio * 0.35;
            cw(p).addParticle(new DustParticleEffect(col, 1.1f),
                    pos.x + Math.cos(a) * r, pos.y + 0.06, pos.z + Math.sin(a) * r,
                    Math.cos(a) * 0.10, 0.03, Math.sin(a) * 0.10);
        }
        for (int i = 0; i < 5; i++) {
            cw(p).addParticle(ParticleTypes.END_ROD,
                    pos.x + (Math.random() - 0.5) * 0.4, pos.y + 0.1, pos.z + (Math.random() - 0.5) * 0.4,
                    0, 0.08, 0);
        }
        addCameraDip(0.04f + chargeRatio * 0.05f);
    }

    public static void onLedgeClimb(ClientPlayerEntity p, double ledgeY) {
        Vec3d pos = p.getPos();
        for (int i = 0; i < 6; i++) {
            cw(p).addParticle(ParticleTypes.SMOKE,
                    pos.x + (Math.random() - 0.5) * 0.5, ledgeY + 0.05, pos.z + (Math.random() - 0.5) * 0.5,
                    0.02, 0.03, 0.02);
        }
        cw(p).addParticle(ParticleTypes.CRIT, pos.x, ledgeY + 0.1, pos.z, 0.06, 0.03, 0.06);
    }

    private static void onLanding(ClientPlayerEntity p, float fallVy) {
        float strength = MathHelper.clamp(-fallVy, 0.55f, 3.0f);
        // просадка камеры
        addCameraDip(Math.min(cfg().landingDipMax, strength * 0.055f));
        // пылевое кольцо, масштаб от силы удара
        int n = (int) (6 + strength * 6);
        Vec3d pos = p.getPos();
        for (int i = 0; i < n; i++) {
            double a = i * Math.PI * 2.0 / n;
            double r = 0.3 + Math.random() * 0.2;
            cw(p).addParticle(ParticleTypes.SMOKE,
                    pos.x + Math.cos(a) * r, pos.y + 0.06, pos.z + Math.sin(a) * r,
                    Math.cos(a) * 0.05 * strength, 0.02, Math.sin(a) * 0.05 * strength);
        }
        if (strength > 1.0f) {
            ParkourSounds.playLandThud(strength);
        }
    }

    // ==================================================================
    //  КАМЕРА (потребляется CameraFxMixin)
    // ==================================================================

    public static float getCameraBob() { return waterBobOffset; }
    public static float getCameraRollDeg() { return cameraRollDeg; }
    public static float getCameraDip() { return -cameraDip; }

    public static void addCameraDip(float amount) {
        cameraDip = MathHelper.clamp(cameraDip + amount, -0.4f, 0.4f);
    }

    /** Сброс при смене мира/смерти. */
    public static void reset() {
        waterStepDist = 0; waterBobPhase = 0; waterBobOffset = 0;
        climbStepDist = 0; climbPhase = 0; climbRecentTicks = 0;
        wallRunStepDist = 0; wallRunPhase = 0;
        wallSide = 0; wallSideSmooth = 0;
        cameraRollDeg = 0; cameraRollTarget = 0; cameraDip = 0;
        wasOnGround = true; airMinVy = 0; jumpFxArmed = false;
    }

    /** Клиентский мир для частиц (Entity.getWorld() типизирован как World). */
    private static net.minecraft.client.world.ClientWorld cw(ClientPlayerEntity p) {
        return (net.minecraft.client.world.ClientWorld) p.getWorld();
    }

    private static Vector3f affinityColor() {
        String id = ClientNinjaStateHolder.get().getAffinityId();
        if (id == null) return new Vector3f(0.35f, 0.6f, 1.0f);
        return switch (id) {
            case "fire" -> new Vector3f(1.0f, 0.45f, 0.15f);
            case "water" -> new Vector3f(0.25f, 0.55f, 1.0f);
            case "wind" -> new Vector3f(0.55f, 1.0f, 0.7f);
            case "lightning" -> new Vector3f(1.0f, 1.0f, 0.35f);
            case "earth" -> new Vector3f(0.75f, 0.55f, 0.25f);
            default -> new Vector3f(0.35f, 0.6f, 1.0f);
        };
    }
}
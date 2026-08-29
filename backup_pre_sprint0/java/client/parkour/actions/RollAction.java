package com.example.shinobicore.client.parkour.actions;

import com.example.shinobicore.client.ChakraHudRenderer;
import com.example.shinobicore.client.parkour.ParkourManager;
import com.example.shinobicore.client.parkour.util.ParkourSounds;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.entity.EntityPose;
import net.minecraft.util.math.Vec3d;

public class RollAction implements ParkourAction {
    public static final String ID = "roll";

    private static final int ROLL_DURATION = 15;  // 0.75 сек
    private static final int INVULNERABILITY_TICKS = 9;  // 60% от длительности (Dark Souls)
    private static final float ROLL_IMPULSE = 0.4f;
    private static final float ROLL_BOOST_PER_TICK = 0.02f;

    private boolean active = false;
    private int rollTicks = 0;
    private Vec3d rollDirection = Vec3d.ZERO;
    private float startRollAngle = 0f;

    @Override
    public String getId() { return ID; }
    public void updateInput(ClientPlayerEntity player) {
        // Roll не требует edge detection как slide
        // Активируется сразу при нажатии Shift в воздухе
    }
    @Override
    public boolean canActivate(ClientPlayerEntity player, ParkourContext ctx) {
        if (player.isOnGround()) return false;
        if (!player.input.sneaking) return false;
        if (ChakraHudRenderer.currentChakra <= 0) return false;
        if (ChakraHudRenderer.exhausted) return false;
        if (ctx.isOnCooldown(ID)) return false;
        
        Vec3d horiz = new Vec3d(player.getVelocity().x, 0, player.getVelocity().z);
        return horiz.length() >= 0.15;  // нужна минимальная скорость
    }

    @Override
    public void activate(ClientPlayerEntity player, ParkourContext ctx) {
        active = true;
        rollTicks = 0;
        
        // Направление = вектор движения (не взгляд!)
        Vec3d horiz = new Vec3d(player.getVelocity().x, 0, player.getVelocity().z);
        rollDirection = horiz.normalize();
        
        // Начальный импульс
        player.addVelocity(rollDirection.x * ROLL_IMPULSE, 0, rollDirection.z * ROLL_IMPULSE);
        player.velocityModified = true;
        
        // Запоминаем угол для визуального эффекта
        startRollAngle = player.getPitch();
        
        // Меняем позу на плавание (визуально ниже)
        player.setPose(EntityPose.SWIMMING);
        
        ctx.resetActive(ID);
        ParkourSounds.playRoll();
    }

    @Override
    public void tick(ClientPlayerEntity player, ParkourContext ctx) {
        if (!active) return;
        
        rollTicks++;
        
        if (rollTicks > ROLL_DURATION || player.isOnGround()) {
            deactivate(player, ctx);
            return;
        }
        
        // Dark Souls i-frames: неуязвимость в первые 60% переката
        if (rollTicks <= INVULNERABILITY_TICKS) {
            player.timeUntilRegen = 5;  // неуязвимость
        }
        
        // Добавляем ускорение каждый тик (Dark Souls roll ускоряется)
        player.addVelocity(
            rollDirection.x * ROLL_BOOST_PER_TICK,
            0,
            rollDirection.z * ROLL_BOOST_PER_TICK
        );
        player.velocityModified = true;
        
        // Визуальный эффект: наклон камеры
        float progress = (float) rollTicks / ROLL_DURATION;
        float rollAngle = (float) Math.sin(progress * Math.PI) * 30f;  // наклон до 30°
        player.setPitch(startRollAngle + rollAngle);
    }

    @Override
    public void deactivate(ClientPlayerEntity player, ParkourContext ctx) {
        active = false;
        rollTicks = 0;
        player.setPose(EntityPose.STANDING);  // Возвращаем нормальную позу
        player.setPitch(startRollAngle);  // Возвращаем угол камеры
        ctx.setCooldown(ID, getCooldownTicks());
        ctx.clearActive(ID);
    }

    public boolean isActive() { return active; }

    @Override
    public int getCooldownTicks() { return 30; }  // 1.5 сек

    @Override
    public float getFatigueCost() { return 1.5f; }
}
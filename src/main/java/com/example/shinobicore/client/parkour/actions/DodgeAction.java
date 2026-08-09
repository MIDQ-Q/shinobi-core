package com.example.shinobicore.client.parkour.actions;

import com.example.shinobicore.client.ChakraHudRenderer;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.client.KeyBindings;
import com.example.shinobicore.client.parkour.util.ParkourSounds;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

public class DodgeAction implements ParkourAction {
    public static final String ID = "dodge";

    private static final int DODGE_DURATION = 8;  // 0.4 сек
    private static final int INVULNERABILITY_TICKS = 6;  // i-frames
    private static final float DODGE_IMPULSE = 1.2f;  // сила отскока

    private boolean active = false;
    private int dodgeTicks = 0;
    private Vec3d dodgeDirection = Vec3d.ZERO;

    @Override
    public String getId() { return ID; }

    @Override
    public boolean canActivate(ClientPlayerEntity player, ParkourContext ctx) {
        if (!ClientNinjaState.chakraMode) return false;
        if (ChakraHudRenderer.currentChakra <= 0) return false;
        if (ChakraHudRenderer.exhausted) return false;
        if (ctx.isOnCooldown(ID)) return false;
        
        // Проверяем нажатие клавиш dodge
        return KeyBindings.DODGE_LEFT.wasPressed() || KeyBindings.DODGE_RIGHT.wasPressed();
    }

    @Override
    public void activate(ClientPlayerEntity player, ParkourContext ctx) {
        active = true;
        dodgeTicks = 0;
        
        // Определяем направление (перпендикулярно взгляду)
        int direction = KeyBindings.DODGE_LEFT.wasPressed() ? -1 : 1;
        Vec3d look = player.getRotationVector();
        Vec3d right = new Vec3d(-look.z, 0, look.x).normalize();
        dodgeDirection = right.multiply(direction);
        
        // Импульс вбок
        player.addVelocity(dodgeDirection.x * DODGE_IMPULSE, 0.2, dodgeDirection.z * DODGE_IMPULSE);
        player.velocityModified = true;
        
        // Неуязвимость
        player.timeUntilRegen = INVULNERABILITY_TICKS;
        
        ctx.resetActive(ID);
        ParkourSounds.playRoll(); // Используем звук roll
    }

    @Override
    public void tick(ClientPlayerEntity player, ParkourContext ctx) {
        if (!active) return;
        
        dodgeTicks++;
        
        if (dodgeTicks > DODGE_DURATION) {
            deactivate(player, ctx);
            return;
        }
        
        // Поддерживаем неуязвимость
        if (dodgeTicks <= INVULNERABILITY_TICKS) {
            player.timeUntilRegen = INVULNERABILITY_TICKS - dodgeTicks;
        }
    }

    @Override
    public void deactivate(ClientPlayerEntity player, ParkourContext ctx) {
        active = false;
        dodgeTicks = 0;
        ctx.setCooldown(ID, getCooldownTicks());
        ctx.clearActive(ID);
    }

    public boolean isActive() { return active; }

    @Override
    public int getCooldownTicks() { return 20; }  // 1 сек

    @Override
    public float getFatigueCost() { return 2.0f; }
}
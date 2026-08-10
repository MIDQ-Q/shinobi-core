package com.example.shinobicore.client.parkour.actions;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.client.ChakraHudRenderer;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.client.KeyBindings;
import com.example.shinobicore.client.parkour.util.ParkourSounds;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

public class DodgeAction implements ParkourAction {
    public static final String ID = "dodge";

    private static final int DODGE_DURATION = 8;
    private static final int INVULNERABILITY_TICKS = 6;
    private static final float DODGE_IMPULSE = 1.2f;
    private static final long COOLDOWN_MS = 1000;

    private boolean active = false;
    private int dodgeTicks = 0;
    private int pendingDirection = 0;
    
    // ✅ Отслеживаем состояние клавиш КАЖДЫЙ тик (static чтобы работало всегда)
    private static boolean prevLeftDown = false;
    private static boolean prevRightDown = false;
    private static long lastDodgeTime = 0;

    @Override
    public String getId() { return ID; }

    @Override
    public boolean canActivate(ClientPlayerEntity player, ParkourContext ctx) {
        // ✅ Читаем текущее состояние клавиш
        boolean leftDown = KeyBindings.DODGE_LEFT.isPressed();
        boolean rightDown = KeyBindings.DODGE_RIGHT.isPressed();
        
        // ✅ Определяем НОВОЕ нажатие (переход false → true)
        boolean leftJustPressed = leftDown && !prevLeftDown;
        boolean rightJustPressed = rightDown && !prevRightDown;
        
        // ✅ ОБНОВЛЯЕМ предыдущее состояние КАЖДЫЙ тик (критично!)
        prevLeftDown = leftDown;
        prevRightDown = rightDown;
        
        // Если нет нового нажатия — выходим
        if (!leftJustPressed && !rightJustPressed) {
            return false;
        }
        
        // Если dodge уже активен — не активируем повторно
        if (active) return false;
        
        // Кулдаун
        long now = System.currentTimeMillis();
        if (now - lastDodgeTime < COOLDOWN_MS) {
            ShinobiCore.LOGGER.debug("[DODGE] Cooldown: {}ms remaining", COOLDOWN_MS - (now - lastDodgeTime));
            return false;
        }
        
        if (!ClientNinjaState.chakraMode) return false;
        if (ChakraHudRenderer.currentChakra <= 0) return false;
        if (ChakraHudRenderer.exhausted) return false;
        
        // Определяем направление
        if (leftJustPressed && !rightJustPressed) {
            pendingDirection = -1;
            ShinobiCore.LOGGER.debug("[DODGE] NEW PRESS: LEFT");
        } else if (rightJustPressed && !leftJustPressed) {
            pendingDirection = 1;
            ShinobiCore.LOGGER.debug("[DODGE] NEW PRESS: RIGHT");
        } else {
            pendingDirection = -1; // Обе нажаты → влево
            ShinobiCore.LOGGER.debug("[DODGE] NEW PRESS: BOTH → LEFT");
        }
        
        return true;
    }

    @Override
    public void activate(ClientPlayerEntity player, ParkourContext ctx) {
        active = true;
        dodgeTicks = 0;
        lastDodgeTime = System.currentTimeMillis();
        
        int direction = pendingDirection != 0 ? pendingDirection : 1;
        
        Vec3d look = player.getRotationVector();
        Vec3d right = new Vec3d(-look.z, 0, look.x).normalize();
        
        player.addVelocity(right.x * direction * DODGE_IMPULSE, 0.2, right.z * direction * DODGE_IMPULSE);
        player.velocityModified = true;
        player.timeUntilRegen = INVULNERABILITY_TICKS;
        
        ShinobiCore.LOGGER.debug("[DODGE] Activated: direction={} ({})", 
            direction, direction < 0 ? "LEFT" : "RIGHT");
        
        ctx.resetActive(ID);
        ParkourSounds.playRoll();
    }

    @Override
    public void tick(ClientPlayerEntity player, ParkourContext ctx) {
        if (!active) return;
        
        dodgeTicks++;
        
        if (dodgeTicks > DODGE_DURATION) {
            deactivate(player, ctx);
            return;
        }
        
        if (dodgeTicks <= INVULNERABILITY_TICKS) {
            player.timeUntilRegen = INVULNERABILITY_TICKS - dodgeTicks;
        }
    }

    @Override
    public void deactivate(ClientPlayerEntity player, ParkourContext ctx) {
        active = false;
        dodgeTicks = 0;
        pendingDirection = 0;
        ctx.clearActive(ID);
    }
    
    public boolean isActive() { return active; }

    @Override
    public int getCooldownTicks() { return 20; }

    @Override
    public float getFatigueCost() { return 2.0f; }
}
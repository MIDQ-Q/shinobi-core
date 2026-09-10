package com.example.shinobicore.client.parkour.actions;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.client.ChakraHudRenderer;
import com.example.shinobicore.client.KeyBindings;
import com.example.shinobicore.client.parkour.util.ParkourSounds;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;
import net.minecraft.client.MinecraftClient;
import net.minecraft.particle.ParticleTypes;
import com.example.shinobicore.client.ClientNinjaStateHolder;

public class DodgeAction implements ParkourAction {
    public static final String ID = "dodge";

    private static final int DODGE_DURATION = 8;
    private static final int INVULNERABILITY_TICKS = 6;
    private static final float DODGE_IMPULSE = 1.2f;
    private static final long COOLDOWN_MS = 1000;

    private boolean active = false;
    private int dodgeTicks = 0;
    private int pendingDirection = 0;
    
    // вњ… РћС‚СЃР»РµР¶РёРІР°РµРј СЃРѕСЃС‚РѕСЏРЅРёРµ РєР»Р°РІРёС€ РљРђР–Р”Р«Р™ С‚РёРє (static С‡С‚РѕР±С‹ СЂР°Р±РѕС‚Р°Р»Рѕ РІСЃРµРіРґР°)
    private static boolean prevLeftDown = false;
    private static boolean prevRightDown = false;
    private static long lastDodgeTime = 0;

    @Override
    public String getId() { return ID; }

    @Override
    public boolean canActivate(ClientPlayerEntity player, ParkourContext ctx) {
        // вњ… Р§РёС‚Р°РµРј С‚РµРєСѓС‰РµРµ СЃРѕСЃС‚РѕСЏРЅРёРµ РєР»Р°РІРёС€
        boolean leftDown = KeyBindings.DODGE_LEFT.isPressed();
        boolean rightDown = KeyBindings.DODGE_RIGHT.isPressed();
        
        // вњ… РћРїСЂРµРґРµР»СЏРµРј РќРћР’РћР• РЅР°Р¶Р°С‚РёРµ (РїРµСЂРµС…РѕРґ false в†’ true)
        boolean leftJustPressed = leftDown && !prevLeftDown;
        boolean rightJustPressed = rightDown && !prevRightDown;
        
        // вњ… РћР‘РќРћР’Р›РЇР•Рњ РїСЂРµРґС‹РґСѓС‰РµРµ СЃРѕСЃС‚РѕСЏРЅРёРµ РљРђР–Р”Р«Р™ С‚РёРє (РєСЂРёС‚РёС‡РЅРѕ!)
        prevLeftDown = leftDown;
        prevRightDown = rightDown;
        
        // Р•СЃР»Рё РЅРµС‚ РЅРѕРІРѕРіРѕ РЅР°Р¶Р°С‚РёСЏ вЂ” РІС‹С…РѕРґРёРј
        if (!leftJustPressed && !rightJustPressed) {
            return false;
        }
        
        // Р•СЃР»Рё dodge СѓР¶Рµ Р°РєС‚РёРІРµРЅ вЂ” РЅРµ Р°РєС‚РёРІРёСЂСѓРµРј РїРѕРІС‚РѕСЂРЅРѕ
        if (active) return false;
        
        // РљСѓР»РґР°СѓРЅ
        long now = System.currentTimeMillis();
        if (now - lastDodgeTime < COOLDOWN_MS) {
            ShinobiCore.LOGGER.debug("[DODGE] Cooldown: {}ms remaining", COOLDOWN_MS - (now - lastDodgeTime));
            return false;
        }
        
        if (!ClientNinjaStateHolder.get().isChakraMode()) return false;
        if (ChakraHudRenderer.currentChakra <= 0) return false;
        if (ChakraHudRenderer.exhausted) return false;
        
        // РћРїСЂРµРґРµР»СЏРµРј РЅР°РїСЂР°РІР»РµРЅРёРµ
        if (leftJustPressed && !rightJustPressed) {
            pendingDirection = -1;
            ShinobiCore.LOGGER.debug("[DODGE] NEW PRESS: LEFT");
        } else if (rightJustPressed && !leftJustPressed) {
            pendingDirection = 1;
            ShinobiCore.LOGGER.debug("[DODGE] NEW PRESS: RIGHT");
        } else {
            pendingDirection = -1; // РћР±Рµ РЅР°Р¶Р°С‚С‹ в†’ РІР»РµРІРѕ
            ShinobiCore.LOGGER.debug("[DODGE] NEW PRESS: BOTH в†’ LEFT");
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
        // Play dodge JSON animation
        com.example.shinobicore.client.anim.json.PlayerJsonAnimState.play(
            direction < 0 ? "dodge_left" : "dodge_right", true);
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

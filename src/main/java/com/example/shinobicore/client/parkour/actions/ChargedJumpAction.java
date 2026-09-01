package com.example.shinobicore.client.parkour.actions;

import com.example.shinobicore.client.ChakraHudRenderer;
import com.example.shinobicore.client.ChakraPhysicsClient;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.client.parkour.ParkourManager;
import com.example.shinobicore.client.parkour.util.ParkourSounds;
import com.example.shinobicore.stat.NinjaFormula;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;
import com.example.shinobicore.client.ClientNinjaStateHolder;

public class ChargedJumpAction implements ParkourAction {
    public static final String ID = "charged_jump";

    private static final int MAX_CHARGE_TICKS = 60;
    private static final int MIN_CHARGE_TICKS = 5;  // 0.25 сек до появления бара
    private static final float CHARGE_MULTIPLIER = 2.0f;

    private int chargeTicks = 0;
    private boolean charging = false;
    private boolean jumpPressed = false;

    @Override
    public String getId() { return ID; }

    @Override
    public boolean canActivate(ClientPlayerEntity player, ParkourContext ctx) {
        return false;
    }

    @Override
    public void activate(ClientPlayerEntity player, ParkourContext ctx) {
    }

    @Override
    public void tick(ClientPlayerEntity player, ParkourContext ctx) {
        if (!ClientNinjaStateHolder.get().isChakraMode() || ChakraHudRenderer.currentChakra <= 0 || ChakraHudRenderer.exhausted) {
            resetCharge();
            return;
        }

        boolean onGround = player.isOnGround() || ChakraPhysicsClient.standingOnWater;
        boolean jumping = player.input.jumping;

        if (onGround && jumping && !jumpPressed) {
            charging = true;
            chargeTicks = 0;
            jumpPressed = true;
        } else if (onGround && jumping && jumpPressed) {
            if (charging) {
                chargeTicks = Math.min(chargeTicks + 1, MAX_CHARGE_TICKS);
                if (chargeTicks >= MIN_CHARGE_TICKS && chargeTicks % 10 == 0) {
                    ParkourSounds.playChargeHum((float) chargeTicks / MAX_CHARGE_TICKS);
                }
            }
        } else if (onGround && !jumping && jumpPressed) {
            if (charging) {
                if (chargeTicks < MIN_CHARGE_TICKS) {
                    // Короткое нажатие — обычный прыжок с прокачкой
                    doVanillaJump(player);
                } else {
                    // Длинное нажатие — заряженный прыжок (x3 от базового + бонусы)
                    float chargeRatio = (float) chargeTicks / MAX_CHARGE_TICKS;
                    float chargeMultiplier = 1.0f + chargeRatio * CHARGE_MULTIPLIER;
                    
                    doVanillaJump(player);
                    
                    // Умножаем вертикальную скорость на множитель заряда
                    Vec3d v = player.getVelocity();
                    player.setVelocity(v.x, v.y * chargeMultiplier, v.z);
                    player.velocityModified = true;
                    
                    ParkourSounds.playChargedJump();
                    sendChargedJumpPacket(chargeRatio);
                }
                resetCharge();
            }
            jumpPressed = false;
        } else if (!onGround) {
            resetCharge();
            jumpPressed = false;
        }
    }

    /**
     * Ванильный прыжок с учётом jumpLevel и чакра-режима.
     * Повторяет логику ChakraPhysicsClient.applyJumpBoost().
     */
    private void doVanillaJump(ClientPlayerEntity player) {
        // Базовая вертикальная скорость ванильного прыжка
        player.setVelocity(player.getVelocity().x, 0.42, player.getVelocity().z);
        player.velocityModified = true;

        int jumpLevel = ClientNinjaStateHolder.get().getJumpLevel();
        boolean chakraOn = true;  // мы в чакра-режиме

        // === Горизонтальный буст (от jumpLevel) ===
        float horizMult = NinjaFormula.jumpHorizontalMultiplier(jumpLevel, chakraOn);
        if (horizMult > 1.0f) {
            Vec3d velocity = player.getVelocity();
            double horizSpeed = Math.sqrt(velocity.x * velocity.x + velocity.z * velocity.z);
            if (horizSpeed > 0.01) {
                double boost = (horizMult - 1.0) * horizSpeed;
                player.addVelocity(velocity.x / horizSpeed * boost, 0, velocity.z / horizSpeed * boost);
            }
        }

        // === Вертикальный буст (в чакра-режиме) ===
        float vertMult = NinjaFormula.jumpVerticalMultiplier(jumpLevel, true);
        if (vertMult > 1.0f) {
            player.addVelocity(0, 0.42 * (vertMult - 1.0), 0);
        }

        // === Спринт-буст (в чакра-режиме) ===
        if (player.isSprinting()) {
            player.addVelocity(0, 0.3, 0);
            Vec3d velocity = player.getVelocity();
            player.addVelocity(velocity.x * 0.5, 0, velocity.z * 0.5);
        }

        player.velocityModified = true;
    }

    @Override
    public void deactivate(ClientPlayerEntity player, ParkourContext ctx) {
        resetCharge();
    }

    public void resetCharge() {
        charging = false;
        chargeTicks = 0;
    }

    public int getChargeTicks() { return chargeTicks; }
    public float getChargeRatio() { return (float) chargeTicks / MAX_CHARGE_TICKS; }

    public boolean isCharging() { return charging && chargeTicks >= MIN_CHARGE_TICKS; }

    @Override
    public int getCooldownTicks() { return 0; }

    @Override
    public float getFatigueCost() { return 0f; }

    private void sendChargedJumpPacket(float chargeRatio) {
        float fatigue = chargeRatio * 2.0f;
        ParkourManager.sendChargedJumpFatigue(fatigue);
    }
}
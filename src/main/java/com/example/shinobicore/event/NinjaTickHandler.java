package com.example.shinobicore.event;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.config.ModConfig;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.stat.StatType;
import net.minecraft.entity.attribute.EntityAttributeModifier;
import net.minecraft.entity.attribute.EntityAttributes;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import net.minecraft.util.math.Vec3d;

import java.util.UUID;

public class NinjaTickHandler {

    private static int tickCounter = 0;
    private static final UUID SPEED_UUID = UUID.fromString("9e1a5b6c-7d8f-4a2b-9c3d-1e2f3a4b5c6d");
    private static final UUID SPRINT_UUID = UUID.fromString("8f7a6b5c-4d3e-2f1a-0b9c-8d7e6f5a4b3c");

    public static void onServerTick(MinecraftServer server) {
        // === КАЖДЫЙ ТИК: прыжки ===
        for (ServerPlayerEntity player : server.getPlayerManager().getPlayerList()) {
            NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();

            if (player.isOnGround()) {
                data.setWasOnGround(true);
            } else {
                if (data.wasOnGround()) {
                    applyJumpBoost(player, data);
                    data.setWasOnGround(false);
                }
            }

            // Спринт-бонус в чакра-режиме
            var speedAttr = player.getAttributeInstance(EntityAttributes.GENERIC_MOVEMENT_SPEED);
            if (speedAttr != null) {
                speedAttr.removeModifier(SPRINT_UUID);
                if (data.isChakraMode() && data.getCurrentChakra() > 0 && player.isSprinting()) {
                    speedAttr.addPersistentModifier(new EntityAttributeModifier(
                        SPRINT_UUID, "shinobicore_sprint", 0.5,
                        EntityAttributeModifier.Operation.MULTIPLY_BASE
                    ));
                }
            }
        }

        // === РАЗ В СЕКУНДУ ===
        tickCounter++;
        if (tickCounter < 20) return;
        tickCounter = 0;

        for (ServerPlayerEntity player : server.getPlayerManager().getPlayerList()) {
            NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();

            if (data.isMeditating() && !canMeditate(player, data)) {
                data.setMeditating(false);
            }

            float maxChakra = NinjaFormula.maxChakra(data);
            if (data.getCurrentChakra() < maxChakra) {
                float regen = NinjaFormula.regenPerSecond(data);
                if (data.isMeditating()) {
                    regen *= NinjaFormula.meditationRegenMultiplier();
                } else if (data.isChakraMode()) {
                    regen *= NinjaFormula.chakraModeRegenMultiplier();
                }
                data.setCurrentChakra(Math.min(data.getCurrentChakra() + regen, maxChakra));
            }

            if (data.getFatigue() > 0) {
                float decay = NinjaFormula.fatigueDecayPerSecond(data);
                if (data.isMeditating()) {
                    decay *= NinjaFormula.meditationFatigueDecayMultiplier();
                }
                data.setFatigue(Math.max(0, data.getFatigue() - decay));
            }

            if (data.isMeditating()) {
                boolean leveledReserve = NinjaFormula.grantReserveXp(data, NinjaFormula.meditationReserveXpPerSecond());
                boolean leveledControl = NinjaFormula.grantStatXp(data, StatType.CONTROL, NinjaFormula.meditationControlXpPerSecond());

                if (leveledReserve || leveledControl) {
                    ShinobiCore.sendChakraSync(player);
                    ShinobiCore.sendStatsSync(player);
                }

                int baseSlownessAmplifier = (int) ModConfig.instance.meditation.slownessBase;
                float controlReduction = data.getStatLevel(StatType.CONTROL) / 100f
                    * ModConfig.instance.meditation.slownessControlReduction;
                int finalAmplifier = Math.max(0, (int) (baseSlownessAmplifier - controlReduction));

                if (finalAmplifier > 0) {
                    player.addStatusEffect(new StatusEffectInstance(
                        StatusEffects.SLOWNESS, 40, finalAmplifier, false, false, true
                    ));
                }
            }

            if (data.isChakraMode()) {
                float drain = NinjaFormula.chakraModeDrainPerSecond(data);
                if (data.getCurrentChakra() >= drain) {
                    data.setCurrentChakra(data.getCurrentChakra() - drain);
                } else {
                    data.setChakraMode(false);
                    player.sendMessage(Text.literal("§cChakra depleted!"), false);
                }
            }

            double maxHp = NinjaFormula.maxHealth(data.getHpLevel());
            var hpAttr = player.getAttributeInstance(EntityAttributes.GENERIC_MAX_HEALTH);
            if (hpAttr != null) {
                hpAttr.setBaseValue(maxHp);
                if (player.getHealth() > maxHp) {
                    player.setHealth((float) maxHp);
                }
            }

            float speedMult = NinjaFormula.speedMultiplier(data.getSpeedLevel(), data.isChakraMode());
            var speedAttr2 = player.getAttributeInstance(EntityAttributes.GENERIC_MOVEMENT_SPEED);
            if (speedAttr2 != null) {
                speedAttr2.removeModifier(SPEED_UUID);
                if (speedMult != 1.0f) {
                    speedAttr2.addPersistentModifier(new EntityAttributeModifier(
                        SPEED_UUID, "shinobicore_speed", speedMult - 1.0,
                        EntityAttributeModifier.Operation.MULTIPLY_BASE
                    ));
                }
            }

            ShinobiCore.sendChakraSync(player);
            ShinobiCore.sendStatsSync(player);
            ShinobiCore.sendBodySync(player);
        }
    }

    private static void applyJumpBoost(ServerPlayerEntity player, NinjaPlayerData data) {
        float horizMult = NinjaFormula.jumpHorizontalMultiplier(data.getJumpLevel(), data.isChakraMode());
        if (horizMult <= 1.0f) return;

        Vec3d velocity = player.getVelocity();
        double horizSpeed = Math.sqrt(velocity.x * velocity.x + velocity.z * velocity.z);
        if (horizSpeed < 0.01) return;

        double boost = (horizMult - 1.0) * horizSpeed;
        player.addVelocity(velocity.x / horizSpeed * boost, 0, velocity.z / horizSpeed * boost);

        if (data.isChakraMode()) {
            float vertMult = NinjaFormula.jumpVerticalMultiplier(data.getJumpLevel(), true);
            if (vertMult > 1.0f) {
                player.addVelocity(0, 0.42 * (vertMult - 1.0), 0);
            }
            if (player.isSprinting()) {
                player.addVelocity(0, 0.3, 0);
                player.addVelocity(velocity.x * 0.5, 0, velocity.z * 0.5);
            }
        }

        player.velocityModified = true;
    }

    private static boolean canMeditate(ServerPlayerEntity player, NinjaPlayerData data) {
        if (data.isExhausted()) return false;
        if (!player.isOnGround()) return false;
        if (player.getHungerManager().getFoodLevel() < 6) return false;
        double dx = player.getX() - player.prevX;
        double dz = player.getZ() - player.prevZ;
        if (dx * dx + dz * dz > 0.01) return false;
        return true;
    }
}
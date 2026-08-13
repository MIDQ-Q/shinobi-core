$path = "E:\Games\mod\src\main\java\com\example\shinobicore\event\NinjaTickHandler.java"
$utf8 = New-Object System.Text.UTF8Encoding($false)

$content = @"
package com.example.shinobicore.event;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.config.ModConfig;
import com.example.shinobicore.jutsu.WallRemovalTask;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.stat.StatType;
import com.example.shinobicore.combat.KenjutsuStance;
import com.example.shinobicore.combat.MarkTracker;
import net.minecraft.entity.attribute.EntityAttributeModifier;
import net.minecraft.entity.attribute.EntityAttributes;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import java.util.UUID;
import com.example.shinobicore.jutsu.JutsuLogger;

public class NinjaTickHandler {
    private static int tickCounter = 0;
    private static final UUID SPEED_UUID = UUID.fromString("9e1a5b6c-7d8f-4a2b-9c3d-1e2f3a4b5c6d");
    private static final UUID SPRINT_UUID = UUID.fromString("8f7a6b5c-4d3e-2f1a-0b9c-8d7e6f5a4b3c");

    public static void onServerTick(MinecraftServer server) {
        for (ServerPlayerEntity player : server.getPlayerManager().getPlayerList()) {
            NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
            var speedAttr = player.getAttributeInstance(EntityAttributes.GENERIC_MOVEMENT_SPEED);
            if (speedAttr != null) {
                speedAttr.removeModifier(SPRINT_UUID);
                if (data.isChakraMode() && data.getCurrentChakra() > 0 && player.isSprinting()) {
                    speedAttr.addPersistentModifier(new EntityAttributeModifier(
                        SPRINT_UUID, "shinobicore_sprint", 0.5,
                        EntityAttributeModifier.Operation.MULTIPLY_BASE));
                }
            }
        }
        tickCounter++;
        if (tickCounter < 20) return;
        tickCounter = 0;

        MarkTracker.cleanupExpired();

        for (var world : server.getWorlds()) {
            WallRemovalTask.tick(world);
        }
        for (ServerPlayerEntity player : server.getPlayerManager().getPlayerList()) {
            NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
            if (data.isMeditating() && !canMeditate(player, data)) {
                data.setMeditating(false);
            }
            float maxChakra = NinjaFormula.maxChakra(data);
            if (data.getCurrentChakra() < maxChakra) {
                float regen = NinjaFormula.regenPerSecond(data);
                if (data.isMeditating()) regen *= NinjaFormula.meditationRegenMultiplier();
                if (data.isRasenganCharging()) {
                    data.setRasenganChargeTicks(data.getRasenganChargeTicks() + 1);
                    if (data.getRasenganChargeTicks() >= data.getRasenganChargeTarget()) {
                        data.setRasenganCharging(false);
                        data.setRasenganReady(true);
                        player.sendMessage(Text.literal("\u00a7b\u2726 Rasengan ready! Press LMB to strike!"), false);
                        ShinobiCore.sendRasenganSync(player);
                    }
                    if (data.getRasenganChargeTicks() % 5 == 0) {
                        ShinobiCore.sendRasenganSync(player);
                    }
                } else if (data.isChakraMode()) regen *= NinjaFormula.chakraModeRegenMultiplier();
                data.setCurrentChakra(Math.min(data.getCurrentChakra() + regen, maxChakra));
            }
            if (data.getFatigue() > 0) {
                float decay = NinjaFormula.fatigueDecayPerSecond(data);
                if (data.isMeditating()) decay *= NinjaFormula.meditationFatigueDecayMultiplier();
                data.setFatigue(Math.max(0, data.getFatigue() - decay));
            }
            if (data.isMeditating()) {
                NinjaFormula.grantReserveXp(data, NinjaFormula.meditationReserveXpPerSecond());
                NinjaFormula.grantStatXp(data, StatType.CONTROL, NinjaFormula.meditationControlXpPerSecond());
                int baseAmp = (int) ModConfig.instance.meditation.slownessBase;
                float red = data.getStatLevel(StatType.CONTROL) / 100f * ModConfig.instance.meditation.slownessControlReduction;
                int amp = Math.max(0, (int) (baseAmp - red));
                if (amp > 0) {
                    player.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, 40, amp, false, false, true));
                }
            }
            if (data.isChakraMode()) {
                float drain = NinjaFormula.chakraModeDrainPerSecond(data);
                if (data.getCurrentChakra() >= drain) {
                    data.setCurrentChakra(data.getCurrentChakra() - drain);
                } else {
                    data.setChakraMode(false);
                    ShinobiCore.sendBodySync(player);
                    player.sendMessage(Text.literal("\u00a7cChakra depleted!"), false);
                }
            }
            boolean seiganShield = data.isKatanaDeflectHeld()
                && KenjutsuStance.fromId(data.getKatanaStanceId()) == KenjutsuStance.SEIGAN;
            if (seiganShield) {
                player.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, 5, 2, false, false, false));
            }
            double maxHp = NinjaFormula.maxHealth(data.getHpLevel());
            var hpAttr = player.getAttributeInstance(EntityAttributes.GENERIC_MAX_HEALTH);
            if (hpAttr != null) {
                hpAttr.setBaseValue(maxHp);
                if (player.getHealth() > maxHp) player.setHealth((float) maxHp);
            }
            float speedMult = NinjaFormula.speedMultiplier(data.getSpeedLevel(), data.isChakraMode());
            var speedAttr = player.getAttributeInstance(EntityAttributes.GENERIC_MOVEMENT_SPEED);
            if (speedAttr != null) {
                speedAttr.removeModifier(SPEED_UUID);
                if (speedMult != 1.0f) {
                    speedAttr.addPersistentModifier(new EntityAttributeModifier(
                        SPEED_UUID, "shinobicore_speed", speedMult - 1.0,
                        EntityAttributeModifier.Operation.MULTIPLY_BASE));
                }
            }
            ShinobiCore.sendChakraSync(player);
            if (data.consumeStatsDirty()) {
                ShinobiCore.sendStatsSync(player);
            }
        }
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
"@

[System.IO.File]::WriteAllText($path, $content, $utf8)
Write-Host "[OK] NinjaTickHandler.java rewritten"
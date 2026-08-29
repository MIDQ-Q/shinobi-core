package com.example.shinobicore.event;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.config.ModConfig;
import com.example.shinobicore.jutsu.WallRemovalTask;
import com.example.shinobicore.jutsu.GenjutsuAuraEffect;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.stat.StatType;
import com.example.shinobicore.combat.KenjutsuStance;
import com.example.shinobicore.tree.TreePassives;
import com.example.shinobicore.network.ModPackets;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.mob.MobEntity;
import net.minecraft.network.PacketByteBuf;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import com.example.shinobicore.combat.MarkTracker;
import net.minecraft.entity.attribute.EntityAttributeModifier;
import net.minecraft.entity.attribute.EntityAttributes;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;
import net.minecraft.util.math.Vec3d;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import com.example.shinobicore.jutsu.JutsuLogger;

public class NinjaTickHandler {
    private static int tickCounter = 0;
    private static final UUID SPEED_UUID = UUID.fromString("9e1a5b6c-7d8f-4a2b-9c3d-1e2f3a4b5c6d");
    private static final UUID SPRINT_UUID = UUID.fromString("8f7a6b5c-4d3e-2f1a-0b9c-8d7e6f5a4b3c");

    // S13-03: Cached modifier templates
    private static EntityAttributeModifier cachedSprintModifier = null;

    public static void onServerTick(MinecraftServer server) {
        // === FAST PATH: Sprint modifier (every tick, but only for relevant players) ===
        for (ServerPlayerEntity player : server.getPlayerManager().getPlayerList()) {
            NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
            boolean shouldSprint = data.isChakraMode() && data.getCurrentChakra() > 0 && player.isSprinting();
            var speedAttr = player.getAttributeInstance(EntityAttributes.GENERIC_MOVEMENT_SPEED);
            if (speedAttr == null) continue;

            boolean hasSprintMod = speedAttr.getModifier(SPRINT_UUID) != null;
            if (shouldSprint && !hasSprintMod) {
                if (cachedSprintModifier == null) {
                    cachedSprintModifier = new EntityAttributeModifier(
                        SPRINT_UUID, "shinobicore_sprint", 0.5,
                        EntityAttributeModifier.Operation.MULTIPLY_BASE);
                }
                speedAttr.addPersistentModifier(cachedSprintModifier);
            } else if (!shouldSprint && hasSprintMod) {
                speedAttr.removeModifier(SPRINT_UUID);
            }
        }

        tickCounter++;
        if (tickCounter < 20) return;
        tickCounter = 0;

        MarkTracker.cleanupExpired();

        for (var world : server.getWorlds()) {
            WallRemovalTask.tick(world);
            if (world instanceof ServerWorld) GenjutsuAuraEffect.tick((ServerWorld) world);
        }

        // === SLOW PATH: Once per second logic ===
        for (ServerPlayerEntity player : server.getPlayerManager().getPlayerList()) {
            NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
            if (data.isMeditating() && !canMeditate(player, data)) {
                data.setMeditating(false);
            }

            // Chakra regen
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

            // Stamina regen
            if (data.getCurrentStamina() < data.getMaxStamina()) {
                float stRegen = ModConfig.instance.stamina.baseRegen;
                data.setCurrentStamina(data.getCurrentStamina() + stRegen);
            }
            if (player.isSprinting() && data.getCurrentStamina() > 0) {
                data.setCurrentStamina(data.getCurrentStamina() - ModConfig.instance.stamina.sprintCostPerSecond);
            }

            // Fatigue decay
            if (data.getFatigue() > 0) {
                float decay = NinjaFormula.fatigueDecayPerSecond(data);
                if (data.isMeditating()) decay *= NinjaFormula.meditationFatigueDecayMultiplier();
                data.setFatigue(Math.max(0, data.getFatigue() - decay));
            }

            // Meditation effects
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

            // Chakra mode drain
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

            // Seigan shield
            boolean seiganShield = data.isKatanaDeflectHeld()
                && KenjutsuStance.fromId(data.getKatanaStanceId()) == KenjutsuStance.SEIGAN;
            if (seiganShield) {
                player.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, 25, 2, false, false, false));
            }

            // Health attribute
            double maxHp = NinjaFormula.maxHealth(data.getHpLevel());
            var hpAttr = player.getAttributeInstance(EntityAttributes.GENERIC_MAX_HEALTH);
            if (hpAttr != null) {
                hpAttr.setBaseValue(maxHp);
                if (player.getHealth() > maxHp) player.setHealth((float) maxHp);
            }

            // Speed attribute
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

            // Chakra combo decay
            if (data.getChakraComboCounter() > 0) {
                long sinceLastHit = System.currentTimeMillis() - data.getLastChakraHitMs();
                if (sinceLastHit > 3000) {
                    data.resetChakraCombo();
                }
            }

            // Sensory component tick
            var sensoryComp = data.getSensoryComponent();
            if (sensoryComp != null) {
                sensoryComp.setTier(com.example.shinobicore.sensory.SensoryComponent.determineTier(data));
                sensoryComp.tick(player);
            }

            // Chakra altar regen (S13-03: optimized - no redundant modulo check)
            var altarPos = data.getBoundAltarPos();
            if (altarPos != null && player.getWorld() instanceof ServerWorld sw) {
                var be = sw.getBlockEntity(altarPos);
                if (be instanceof com.example.shinobicore.block.entity.ChakraAltarBlockEntity altar) {
                    float radius = altar.getRadius();
                    // S13-03: Use squared distance to avoid sqrt
                    double dx = player.getX() - (altarPos.getX() + 0.5);
                    double dy = player.getY() - (altarPos.getY() + 0.5);
                    double dz = player.getZ() - (altarPos.getZ() + 0.5);
                    double distSq = dx * dx + dy * dy + dz * dz;
                    if (distSq <= radius * radius) {
                        float bonusRegen = altar.getRegenMultiplier();
                        data.setCurrentChakra(Math.min(data.getCurrentChakra() + bonusRegen,
                            com.example.shinobicore.stat.NinjaFormula.maxChakra(data)));
                    }
                }
            }

            // Sharingan component tick
            var sharinganComp = data.getSharinganComponent();
            if (sharinganComp != null) {
                sharinganComp.tick(player);
            }

            // === S13-03: Optimized sensory and danger sense ===
            TreePassives.Bonuses b2 = TreePassives.collectServer(data);
            long worldTime = player.getWorld().getTime();

            // Sensory glow: every 10 ticks instead of 5 (effect lasts 40 ticks = 2 sec)
            if (b2.sensory && data.isSensoryEnabled() && (worldTime % 10 == 0)) {
                int radius = b2.sensoryRadius > 0 ? b2.sensoryRadius : 20;
                List<LivingEntity> targets = player.getWorld().getEntitiesByClass(LivingEntity.class,
                    player.getBoundingBox().expand(radius), e -> !(e instanceof ServerPlayerEntity));
                for (LivingEntity mob : targets) {
                    mob.addStatusEffect(new StatusEffectInstance(StatusEffects.GLOWING, 40, 0, false, false));
                }
            }

            // Danger sense: every 10 ticks instead of every tick
            if (b2.dangerSense && (worldTime % 10 == 0)) {
                boolean danger = false;
                List<LivingEntity> mobs = player.getWorld().getEntitiesByClass(LivingEntity.class,
                    player.getBoundingBox().expand(16), e -> e instanceof MobEntity);
                for (LivingEntity mob : mobs) {
                    if (((MobEntity) mob).getTarget() == player) { danger = true; break; }
                }
                if (danger != data.getLastDangerState()) {
                    data.setLastDangerState(danger);
                    PacketByteBuf dbuf = new PacketByteBuf(Unpooled.buffer());
                    dbuf.writeBoolean(danger);
                    ServerPlayNetworking.send(player, ModPackets.DANGER_SYNC_ID, dbuf);
                }
            }

            // Rasengan ready timer
            if (data.isRasenganReady()) {
                data.setRasenganReadyTicks(data.getRasenganReadyTicks() + 20);
                if (data.getRasenganReadyTicks() >= 600) {
                    data.setRasenganReady(false);
                    data.setRasenganReadyTicks(0);
                    player.sendMessage(Text.literal("\u00a77Rasengan dissipated..."), false);
                    ShinobiCore.sendRasenganSync(player);
                }
            } else {
                data.setRasenganReadyTicks(0);
            }

            // Passive XP drift
            NinjaFormula.grantPassiveXp(data);
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
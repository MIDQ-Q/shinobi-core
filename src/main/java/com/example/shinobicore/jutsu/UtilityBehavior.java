package com.example.shinobicore.jutsu;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.entity.effect.StatusEffect;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;
import net.minecraft.util.math.Vec3d;

public class UtilityBehavior implements JutsuBehavior {

    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        String effect = params.has("effect") ? params.get("effect").getAsString() : "heal";
        int amplifier = params.has("amplifier") ? params.get("amplifier").getAsInt() : 0;
        int duration = params.has("duration") ? params.get("duration").getAsInt() : 200;
        boolean showParticles = !params.has("showParticles") || params.get("showParticles").getAsBoolean();

        if (!(player.getWorld() instanceof ServerWorld serverWorld)) return;

        Vec3d center = player.getPos().add(0, player.getHeight() / 2.0, 0);

        switch (effect) {
            case "heal" -> {
                float healAmount = params.has("healAmount") ? params.get("healAmount").getAsFloat() : 6.0f;
                float actualHeal = Math.min(healAmount, player.getMaxHealth() - player.getHealth());
                player.heal(actualHeal);

                spawnParticles(serverWorld, center, ParticleTypes.HAPPY_VILLAGER, 20);
                JutsuLogger.logBehavior("utility",
                        String.format("HEAL: player=%s, amount=%.1f, actual=%.1f",
                                player.getName().getString(), healAmount, actualHeal));
            }

            case "chakra_heal" -> {
                float chakraAmount = params.has("chakraAmount") ? params.get("chakraAmount").getAsFloat() : 30.0f;
                float maxChakra = com.example.shinobicore.stat.NinjaFormula.maxChakra(data);
                float actualRestore = Math.min(chakraAmount, maxChakra - data.getCurrentChakra());
                data.setCurrentChakra(data.getCurrentChakra() + actualRestore);

                spawnParticles(serverWorld, center, ParticleTypes.ENCHANT, 15);
                JutsuLogger.logBehavior("utility",
                        String.format("CHAKRA_HEAL: player=%s, amount=%.1f, actual=%.1f",
                                player.getName().getString(), chakraAmount, actualRestore));
            }

            case "regen" -> {
                player.addStatusEffect(new StatusEffectInstance(
                        StatusEffects.REGENERATION, duration, amplifier, false, showParticles));

                spawnParticles(serverWorld, center, ParticleTypes.HAPPY_VILLAGER, 12);
                JutsuLogger.logBehavior("utility",
                        String.format("REGEN: player=%s, amp=%d, dur=%d",
                                player.getName().getString(), amplifier, duration));
            }

            case "speed" -> {
                player.addStatusEffect(new StatusEffectInstance(
                        StatusEffects.SPEED, duration, amplifier, false, showParticles));

                spawnParticles(serverWorld, center, ParticleTypes.ENCHANT, 10);
                JutsuLogger.logBehavior("utility",
                        String.format("SPEED: player=%s, amp=%d, dur=%d",
                                player.getName().getString(), amplifier, duration));
            }

            case "strength" -> {
                player.addStatusEffect(new StatusEffectInstance(
                        StatusEffects.STRENGTH, duration, amplifier, false, showParticles));

                spawnParticles(serverWorld, center, ParticleTypes.ENCHANT, 10);
                JutsuLogger.logBehavior("utility",
                        String.format("STRENGTH: player=%s, amp=%d, dur=%d",
                                player.getName().getString(), amplifier, duration));
            }

            case "resistance" -> {
                player.addStatusEffect(new StatusEffectInstance(
                        StatusEffects.RESISTANCE, duration, amplifier, false, showParticles));

                spawnParticles(serverWorld, center, ParticleTypes.ENCHANT, 10);
                JutsuLogger.logBehavior("utility",
                        String.format("RESISTANCE: player=%s, amp=%d, dur=%d",
                                player.getName().getString(), amplifier, duration));
            }

            case "clear" -> {
                int removed = 0;
                removed += removeIfPresent(player, StatusEffects.POISON);
                removed += removeIfPresent(player, StatusEffects.WITHER);
                removed += removeIfPresent(player, StatusEffects.SLOWNESS);
                removed += removeIfPresent(player, StatusEffects.WEAKNESS);
                removed += removeIfPresent(player, StatusEffects.BLINDNESS);
                removed += removeIfPresent(player, StatusEffects.NAUSEA);
                removed += removeIfPresent(player, StatusEffects.HUNGER);
                removed += removeIfPresent(player, StatusEffects.MINING_FATIGUE);
                removed += removeIfPresent(player, StatusEffects.LEVITATION);

                spawnParticles(serverWorld, center, ParticleTypes.CLOUD, 25);
                JutsuLogger.logBehavior("utility",
                        String.format("CLEAR: player=%s, removed=%d effects",
                                player.getName().getString(), removed));

                if (removed > 0) {
                    player.sendMessage(Text.literal("§aCleared " + removed + " negative effect(s)!"), false);
                } else {
                    player.sendMessage(Text.literal("§7No negative effects to clear."), false);
                }
            }

            default -> {
                player.sendMessage(Text.literal("§cUnknown utility effect: " + effect), false);
                JutsuLogger.logBehavior("utility", "UNKNOWN effect: " + effect);
            }
        }
    }

    private int removeIfPresent(ServerPlayerEntity player, StatusEffect effect) {
        if (player.hasStatusEffect(effect)) {
            player.removeStatusEffect(effect);
            return 1;
        }
        return 0;
    }

    private void spawnParticles(ServerWorld world, Vec3d center,
                                 net.minecraft.particle.ParticleEffect particle, int count) {
        for (int i = 0; i < count; i++) {
            double angle = (i / (double) count) * Math.PI * 2;
            double r = 0.5 + Math.random() * 0.3;
            double x = center.x + Math.cos(angle) * r;
            double z = center.z + Math.sin(angle) * r;
            double y = center.y + (Math.random() - 0.5) * 1.0;

            world.spawnParticles(particle, x, y, z, 1,
                    (Math.random() - 0.5) * 0.1,
                    Math.random() * 0.1,
                    (Math.random() - 0.5) * 0.1,
                    0.05);
        }
    }
}
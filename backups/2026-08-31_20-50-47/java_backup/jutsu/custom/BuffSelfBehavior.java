package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
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

public class BuffSelfBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        String eff = params.has("effect") ? params.get("effect").getAsString() : "speed";
        int amp = params.has("amplifier") ? params.get("amplifier").getAsInt() : 0;
        int dur = params.has("duration") ? params.get("duration").getAsInt() : 400;
        boolean particles = !params.has("showParticles") || params.get("showParticles").getAsBoolean();
        StatusEffect se = parse(eff);
        if (se == null) {
            player.sendMessage(Text.literal("\u00a7cUnknown buff effect: " + eff), false);
            return;
        }
        player.addStatusEffect(new StatusEffectInstance(se, dur, amp, false, particles));
        Vec3d c = player.getPos().add(0, 1, 0);
        for (int i = 0; i < 30; i++) {
            double a = (i / 30.0) * Math.PI * 2;
            world.spawnParticles(ParticleTypes.ENCHANT,
                    c.x + Math.cos(a) * 0.8, c.y, c.z + Math.sin(a) * 0.8,
                    1, 0, 0.1, 0, 0.05);
        }
        JutsuLogger.logBehavior("buff_self", "effect=" + eff + " amp=" + amp + " dur=" + dur);
    }
    private StatusEffect parse(String id) {
        return switch (id) {
            case "speed" -> StatusEffects.SPEED;
            case "strength" -> StatusEffects.STRENGTH;
            case "resistance" -> StatusEffects.RESISTANCE;
            case "regeneration" -> StatusEffects.REGENERATION;
            case "haste" -> StatusEffects.HASTE;
            case "jump_boost" -> StatusEffects.JUMP_BOOST;
            case "absorption" -> StatusEffects.ABSORPTION;
            case "fire_resistance" -> StatusEffects.FIRE_RESISTANCE;
            case "invisibility" -> StatusEffects.INVISIBILITY;
            default -> null;
        };
    }
}
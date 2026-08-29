package com.example.shinobicore.jutsu.behavior;
import com.example.shinobicore.progression.JutsuCastNotifier;

import com.example.shinobicore.jutsu.data.JutsuDefinition;
import com.example.shinobicore.util.EffectHelper;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.JsonHelper;
import net.minecraft.util.math.Box;

import java.util.List;

/**
 * Applies mental debuffs (blindness/slowness) to enemies in range.
 * HLD: Section 2.2
 */
public class GenjutsuBehavior implements JutsuBehavior {

    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, JsonObject params, float damage) {
        JutsuCastNotifier.fire(player, "genjutsu", "genjutsu");

        float range = JsonHelper.getFloat(params, "range", 16.0f);
        int duration = JsonHelper.getInt(params, "duration", 60);

        Box box = player.getBoundingBox().expand(range);
        List<Entity> targets = player.getWorld().getOtherEntities(player, box);

        for (Entity e : targets) {
            if (!(e instanceof LivingEntity le)) {
                continue;
            }
            le.addStatusEffect(new StatusEffectInstance(StatusEffects.BLINDNESS, duration, 0));
            le.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, duration, 1));
            EffectHelper.applyAll(le, def);

            for (int i = 0; i < 6; i++) {
                le.getWorld().addParticle(ParticleTypes.ENCHANT,
                    le.getX(), le.getY() + 1.0, le.getZ(), 0.0, 0.2, 0.0);
            }
        }
    }
}
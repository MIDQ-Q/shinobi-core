package com.example.shinobicore.jutsu.behavior;
import com.example.shinobicore.progression.JutsuCastNotifier;

import com.example.shinobicore.jutsu.data.JutsuDefinition;
import com.example.shinobicore.util.EffectHelper;
import com.example.shinobicore.util.ParticleHelper;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.JsonHelper;

/**
 * Self-targeted buffs, heals and utility effects.
 * HLD: Section 2.2, 2.9
 * Yarn 1.20.1: extinguish() to remove fire.
 */
public class UtilityBehavior implements JutsuBehavior {

    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, JsonObject params, float damage) {
        JutsuCastNotifier.fire(player, "utility", "ninjutsu");

        if (params.has("effects") && params.get("effects").isJsonArray()) {
            for (JsonElement el : params.getAsJsonArray("effects")) {
                if (el.isJsonObject()) {
                    EffectHelper.apply(player, el.getAsJsonObject());
                }
            }
        }

        String particle = JsonHelper.getString(params, "particle", "enchant");
        for (int i = 0; i < 16; i++) {
            player.getWorld().addParticle(
                ParticleHelper.get(particle),
                player.getX(), player.getY() + 1.0, player.getZ(),
                (player.getRandom().nextFloat() - 0.5f) * 0.5,
                player.getRandom().nextFloat() * 0.4,
                (player.getRandom().nextFloat() - 0.5f) * 0.5
            );
        }

        if (JsonHelper.getBoolean(params, "extinguish", false)) {
            player.extinguish();
            player.getWorld().addParticle(ParticleTypes.SPLASH,
                player.getX(), player.getY() + 1.0, player.getZ(), 0.0, 0.2, 0.0);
        }
    }
}
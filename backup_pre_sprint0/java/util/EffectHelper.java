package com.example.shinobicore.util;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.jutsu.data.JutsuDefinition;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffect;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.registry.Registries;
import net.minecraft.util.Identifier;
import net.minecraft.util.JsonHelper;

/**
 * Applies JSON-defined effects to living entities.
 * HLD: Section 2.9 (status effects array)
 * Yarn 1.20.1: setOnFireFor(int seconds)
 */
public final class EffectHelper {

    private EffectHelper() {}

    public static void apply(LivingEntity target, JsonObject effect) {
        String type = JsonHelper.getString(effect, "type", "status");

        if (type.equals("heal")) {
            float amount = JsonHelper.getFloat(effect, "amount", 4.0f);
            target.heal(amount);
            return;
        }

        if (type.equals("burn")) {
            int seconds = JsonHelper.getInt(effect, "duration", 3);
            target.setOnFireFor(seconds);
            return;
        }

        String id = JsonHelper.getString(effect, "id", "slowness");
        int duration = JsonHelper.getInt(effect, "duration", 100);
        int amplifier = JsonHelper.getInt(effect, "amplifier", 0);

        StatusEffect se = Registries.STATUS_EFFECT.get(new Identifier(id));
        if (se == null) {
            ShinobiCore.LOGGER.warn("[WARN] Unknown status effect id: {}", id);
            return;
        }
        target.addStatusEffect(new StatusEffectInstance(se, duration, amplifier));
    }

    /**
     * Apply all effects from def.params().effects array.
     */
    public static void applyAll(LivingEntity target, JutsuDefinition def) {
        JsonObject params = def.params();
        if (!params.has("effects")) {
            return;
        }
        if (!params.get("effects").isJsonArray()) {
            return;
        }
        for (JsonElement el : params.getAsJsonArray("effects")) {
            if (el.isJsonObject()) {
                apply(target, el.getAsJsonObject());
            }
        }
    }
}
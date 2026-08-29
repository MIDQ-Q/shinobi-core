package com.example.shinobicore.jutsu.behavior;

import com.example.shinobicore.jutsu.data.JutsuDefinition;
import com.google.gson.JsonObject;
import net.minecraft.server.network.ServerPlayerEntity;

/**
 * Behavior contract for jutsu casting.
 * HLD: Section 2.1 - raw JsonObject params, no POJO classes.
 */
public interface JutsuBehavior {

    /**
     * Execute the jutsu behavior on the server.
     *
     * @param player caster
     * @param def    parsed jutsu definition
     * @param params raw params object from JSON
     * @param damage final damage after NinjaFormula multipliers
     */
    void cast(ServerPlayerEntity player, JutsuDefinition def, JsonObject params, float damage);
}
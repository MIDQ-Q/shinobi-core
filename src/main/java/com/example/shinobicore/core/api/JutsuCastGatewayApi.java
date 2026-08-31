package com.example.shinobicore.core.api;

import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import java.util.List;

public interface JutsuCastGatewayApi {
    boolean tryCast(LivingEntity caster, String jutsuId, Entity target);
    boolean isJutsuAvailable(String jutsuId);
    List<String> getJutsuByRank(String rank);
}
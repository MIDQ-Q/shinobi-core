package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.stat.StatType;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;
import net.minecraft.util.hit.EntityHitResult;
import net.minecraft.util.hit.HitResult;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.RaycastContext;

public class GenjutsuBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float range = params.has("range") ? params.get("range").getAsFloat() : 16f;
        int slownessDur = params.has("slownessDuration") ? params.get("slownessDuration").getAsInt() : 100;
        int weaknessDur = params.has("weaknessDuration") ? params.get("weaknessDuration").getAsInt() : 100;
        int nauseaDur = params.has("nauseaDuration") ? params.get("nauseaDuration").getAsInt() : 120;
        int blindnessDur = params.has("blindnessDuration") ? params.get("blindnessDuration").getAsInt() : 80;
        int genLevel = data.getStatLevel(StatType.GENJUTSU);
        float ampScale = 1f + genLevel / 50f;
        Vec3d eye = player.getEyePos();
        Vec3d look = player.getRotationVector();
        Vec3d end = eye.add(look.multiply(range));
        HitResult hit = world.raycast(new RaycastContext(eye, end,
                RaycastContext.ShapeType.OUTLINE, RaycastContext.FluidHandling.NONE, player));
        LivingEntity target = null;
        if (hit.getType() == HitResult.Type.ENTITY && hit instanceof EntityHitResult ehr) {
            Entity e = ehr.getEntity();
            if (e instanceof LivingEntity le && !e.equals(player)) target = le;
        }
        if (target == null) {
            player.sendMessage(Text.literal("\u00a7cNo target hit!"), false);
            return;
        }
        int slAmp = Math.min(4, (int)(1 * ampScale));
        int wkAmp = Math.min(3, (int)(1 * ampScale));
        target.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, slownessDur, slAmp, false, true));
        target.addStatusEffect(new StatusEffectInstance(StatusEffects.WEAKNESS, weaknessDur, wkAmp, false, true));
        target.addStatusEffect(new StatusEffectInstance(StatusEffects.NAUSEA, nauseaDur, 0, false, true));
        if (blindnessDur > 0) {
            target.addStatusEffect(new StatusEffectInstance(StatusEffects.BLINDNESS, blindnessDur, 0, false, true));
        }
        if (damage > 0) target.damage(player.getDamageSources().magic(), damage);
        JutsuLogger.logBehavior("genjutsu", "target=" + target.getName().getString() + " gen=" + genLevel);
    }
}
package com.example.shinobicore.ai;

import com.example.shinobicore.jutsu.core.FormDefinition;
import com.example.shinobicore.jutsu.executor.CastContext;
import com.example.shinobicore.jutsu.executor.Combat;
import com.example.shinobicore.jutsu.executor.VerificationLogger;
import net.minecraft.entity.LivingEntity;

public class SummonSystem {

    public static void register(CastContext ctx, FormDefinition form, LivingEntity e) {
        AiBrain b = new AiBrain(e, ctx.caster.getUuid());
        b.behavior = form.getString("behavior", "fight_for_caster");
        b.lifetime = form.getInt("lifetime", 1200);
        b.level = ctx.level;
        String js = form.getString("jutsus", "");
        for (String s : js.split(",")) {
            if (!s.trim().isEmpty()) b.jutsus.add(s.trim());
        }
        b.meleeDamage = 4f + ctx.level;
        b.explodeDamage = Combat.baseDamageOf(ctx.jutsu, ctx.damageScale);
        b.explodeRadius = 3f;

        if (AiSystem.countForOwner(b.owner) >= 8) {
            AiSystem.removeOldestForOwner(b.owner);
        }
        AiSystem.add(b);
        VerificationLogger.log("SUMMON", "entity=" + e.getType() + " behavior=" + b.behavior + " jutsus=" + b.jutsus);
    }
}
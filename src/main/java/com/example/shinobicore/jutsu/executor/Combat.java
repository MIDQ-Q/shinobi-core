package com.example.shinobicore.jutsu.executor;

import com.example.shinobicore.jutsu.core.EffectDefinition;
import com.example.shinobicore.jutsu.core.JutsuDefinition;
import com.example.shinobicore.jutsu.core.PropertyDefinition;
import com.example.shinobicore.jutsu.enums.EffectType;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import java.util.HashSet;
import java.util.Set;
import java.util.UUID;

public class Combat {

    public static float baseDamageOf(JutsuDefinition j, double scale) {
        for (EffectDefinition e : j.getEffects()) {
            if (e.getType() == EffectType.DAMAGE) {
                return (float) (e.getDouble("amount", e.getDouble("dps", 4)) * scale);
            }
        }
        return (float) (4 * scale);
    }

    public static void applyDamage(CastContext ctx, LivingEntity target, float amount) {
        PropertyDefinition exec = ctx.prop("execute_bonus");
        if (exec != null && target.getMaxHealth() > 0) {
            double hpPct = (target.getHealth() / target.getMaxHealth()) * 100.0;
            if (hpPct < exec.getDouble("threshold", 30)) {
                amount *= (float) (1.0 + exec.getDouble("bonus", 50) / 100.0);
            }
        }
        amount = (float) (amount * StatusSystem.vulnerabilityMult(target));
        VerificationLogger.logHit(ctx.caster, target, "DAMAGE", amount);
        target.damage(target.getDamageSources().magic(), amount);

        PropertyDefinition ls = ctx.prop("lifesteal");
        if (ls != null && ctx.caster.isAlive()) {
            float healAmt = amount * (float) (ls.getDouble("percent", 20) / 100.0);
            VerificationLogger.log("LIFESTEAL", "heal=" + healAmt);
            if (ctx.caster.getHealth() >= ctx.caster.getMaxHealth()) {
                ctx.caster.addStatusEffect(new StatusEffectInstance(StatusEffects.ABSORPTION, 100,
                        Math.max(0, (int) (healAmt / 4) - 1), false, false, false));
            } else {
                ctx.caster.heal(healAmt);
            }
        }

        PropertyDefinition cd = ctx.prop("chakra_drain_on_hit");
        if (cd != null) {
            int amt = cd.getInt("amount", 10);
            if (target instanceof ServerPlayerEntity tp) {
                NinjaPlayerData td = ((NinjaDataHolder) tp).shinobicore_getData();
                td.setCurrentChakra(Math.max(0, td.getCurrentChakra() - amt));
            }
            if (ctx.caster instanceof ServerPlayerEntity sp) {
                NinjaPlayerData cd2 = ((NinjaDataHolder) sp).shinobicore_getData();
                cd2.setCurrentChakra(cd2.getCurrentChakra() + amt);
            }
        }
    }

    public static LivingEntity nearestEnemy(ServerWorld world, LivingEntity caster, Vec3d pos, double range, Set<UUID> exclude) {
        LivingEntity best = null;
        double bd = range;
        for (Object o : world.getOtherEntities(caster, new Box(pos, pos).expand(range))) {
            if (!(o instanceof LivingEntity e) || !e.isAlive() || e.equals(caster)) continue;
            if (exclude != null && exclude.contains(e.getUuid())) continue;
            double d = e.getPos().distanceTo(pos);
            if (d < bd) { bd = d; best = e; }
        }
        return best;
    }

    public static void chain(CastContext ctx, LivingEntity first, PropertyDefinition prop) {
        int count = prop.getInt("count", 3);
        double range = prop.getDouble("range", 4);
        double falloff = prop.getDouble("falloff", 0.2);
        ServerWorld world = ctx.world();
        LivingEntity current = first;
        double mult = 1.0 - falloff;
        Set<UUID> chained = new HashSet<>();
        chained.add(first.getUuid());
        for (int i = 0; i < count; i++) {
            LivingEntity next = nearestEnemy(world, ctx.caster, current.getPos(), range, chained);
            if (next == null || !ctx.markHit(next)) break;
            chained.add(next.getUuid());
            applyDamage(ctx, next, (float) (baseDamageOf(ctx.jutsu, ctx.damageScale) * mult));
            Vec3d a = current.getPos().add(0, 1, 0), b = next.getPos().add(0, 1, 0);
            for (int t = 0; t < 6; t++) {
                Vec3d p = a.lerp(b, t / 6.0);
                world.spawnParticles(ParticleTypes.ELECTRIC_SPARK, p.x, p.y, p.z, 2, 0.1, 0.1, 0.1, 0.05);
            }
            current = next;
            mult *= (1.0 - falloff);
        }
    }
}
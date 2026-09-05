package com.example.shinobicore.ai;

import com.example.shinobicore.jutsu.enums.ElementType;
import com.example.shinobicore.jutsu.executor.Fx;
import com.example.shinobicore.jutsu.executor.VerificationLogger;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.damage.DamageSource;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;

public class EnemyCombat {

    /** Returns false if the hit was negated (dodge / kawarimi). */
    public static boolean onDamaged(AiBrain b, DamageSource source, float amount) {
        if (!(source.getAttacker() instanceof LivingEntity attacker)) return true;
        var rnd = b.entity.getRandom();
        ServerWorld world = (ServerWorld) b.entity.getWorld();

        // 1) Dodge: chance scales with level
        if (b.cdOk("dodge", 30) && rnd.nextFloat() < b.dodgeChance) {
            Vec3d side = b.entity.getPos().subtract(attacker.getPos());
            Vec3d perp = new Vec3d(-side.z, 0, side.x).normalize();
            if (rnd.nextBoolean()) perp = perp.multiply(-1);
            b.entity.addVelocity(perp.x * 0.6, 0.25, perp.z * 0.6);
            b.entity.velocityModified = true;
            Fx.elementBurst(world, b.entity.getPos().add(0, 1, 0), ElementType.WIND, 6);
            VerificationLogger.log("AI_DODGE", b.entity.getName().getString() + " dodged (lvl " + b.level + ")");
            return false;
        }

        // 2) Kawarimi: safe teleport behind attacker + counter
        if (b.cdOk("kawarimi", 240) && rnd.nextFloat() < 0.15f) {
            Vec3d base = attacker.getPos().add(attacker.getRotationVector().multiply(-1.5));
            Vec3d spot = null;
            for (int i = 0; i < 6 && spot == null; i++) {
                double a = i * Math.PI / 3.0;
                Vec3d cand = base.add(Math.cos(a) * 0.6, 0, Math.sin(a) * 0.6);
                BlockPos bp = BlockPos.ofFloored(cand);
                if (!world.getBlockState(bp).isSolidBlock(world, bp)
                        && !world.getBlockState(bp.up()).isSolidBlock(world, bp.up())) {
                    spot = cand;
                }
            }
            if (spot == null) spot = base.add(0, 1.0, 0);

            Fx.elementBurst(world, b.entity.getPos().add(0, 1, 0), ElementType.YIN, 15);
            b.entity.teleport(spot.x, spot.y + 0.1, spot.z, false);
            Fx.elementBurst(world, b.entity.getPos().add(0, 1, 0), ElementType.YIN, 15);
            b.navCd = 0;
            b.stuck = 0;
            b.target = attacker;
            b.setState(AiStates.ROOT); // immediately resume combat, don't wait for strike animation
            VerificationLogger.log("KAWARIMI", b.entity.getName().getString() + " substituted behind " + attacker.getName().getString());
            return false;
        }

        // 3) Smoke bomb at low HP
        if (b.entity.getHealth() - amount < b.entity.getMaxHealth() * 0.25f && b.cdOk("smoke", 99999)) {
            b.setState(AiStates.flee());
            return true;
        }
        return true;
    }
}
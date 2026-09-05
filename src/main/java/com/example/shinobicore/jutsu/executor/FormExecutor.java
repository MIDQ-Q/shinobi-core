package com.example.shinobicore.jutsu.executor;

import com.example.shinobicore.jutsu.core.EffectDefinition;
import com.example.shinobicore.jutsu.core.FormDefinition;
import com.example.shinobicore.jutsu.enums.EffectType;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.registry.Registries;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.Vec3d;
import net.minecraft.entity.EntityType;
import java.util.Optional;

public class FormExecutor {
    public static void executeForm(CastContext ctx) {
        FormDefinition form = ctx.jutsu.getForm();
        switch (form.getType()) {
            case POINT -> executePoint(ctx, form);
            case PROJECTILE -> executeProjectile(ctx, form);
            case BEAM -> BeamSystem.start(ctx, form);
            case DASH -> DashSystem.start(ctx, form);
            case HANDHELD -> HandheldSystem.start(ctx);
            case ZONE -> ZoneSystem.start(ctx, form);
            case CONSTRUCT -> ConstructSystem.start(ctx, form);
            case SUMMON -> executeSummon(ctx, form);
            default -> ctx.sendMsg(Text.literal("\u00a7eForm '" + form.getType().getId() + "' coming soon"), false);
        }
        JutsuSoundHelper.playCastSound(ctx.caster, ctx.jutsu);
        JutsuAnimationHelper.playCastAnimation(ctx.caster, ctx.jutsu);
    }

    private static void executePoint(CastContext ctx, FormDefinition form) {
        String mode = form.getString("targetMode", "self");
        double range = form.getDouble("range", 3.0);
        LivingEntity target;
        if (mode.equals("self")) {
            target = ctx.caster;
        } else if (ctx.caster instanceof ServerPlayerEntity sp) {
            target = Targeting.lookEntity(sp, range);
        } else {
            // AI caster: simple cone search forward
            target = Combat.nearestEnemy(ctx.world(), ctx.caster, ctx.caster.getPos(), range, null);
        }

        if (target != null) {
            ctx.markHit(target);
            EffectExecutor.applyEffects(ctx, target);
            HitProperties.apply(ctx, target.getPos());
            Fx.elementBurst(ctx.world(), target.getPos().add(0, 1, 0), ctx.jutsu.getElement(), 20);
        } else if (mode.equals("raycast_point")) {
            net.minecraft.util.hit.HitResult hit = ctx.caster.raycast(range, 0.0f, false);
            Vec3d center = hit.getPos();
            boolean any = false;
            for (EffectDefinition eff : ctx.effects) {
                if (eff.getType() == EffectType.WORLD) { WorldEffectExecutor.applyWorld(ctx, eff, center); any = true; }
            }
            if (any) { Fx.elementBurst(ctx.world(), center, ctx.jutsu.getElement(), 20); VerificationLogger.log("WORLD_POINT", "at " + center); }
        }
    }

    private static void executeProjectile(CastContext ctx, FormDefinition form) {
        if (ctx.hasProp("orbiting")) {
            var o = ctx.prop("orbiting");
            OrbitingSystem.start(ctx, o.getDouble("radius", 2), o.getInt("count", 4), form.getInt("lifetime", 100));
            return;
        }
        int count = form.getInt("count", 1);
        double spread = form.getDouble("spread", 0);
        Vec3d dir = ctx.caster.getRotationVector();
        for (int i = 0; i < Math.max(1, count); i++) {
            double angle = count <= 1 ? 0 : (-spread / 2.0 + spread * i / Math.max(1, count - 1.0)) * Math.PI / 180.0;
            Vec3d d = angle == 0 ? dir : rotY(dir, angle);
            ProjectileSystem.spawn(ctx, d);
        }
    }

    private static Vec3d rotY(Vec3d v, double a) {
        double c = Math.cos(a), s = Math.sin(a);
        return new Vec3d(v.x * c - v.z * s, v.y, v.x * s + v.z * c);
    }

    private static void executeSummon(CastContext ctx, FormDefinition form) {
        String entityType = form.getString("entityType", "minecraft:wolf");
        int count = form.getInt("count", 1);
        Optional<EntityType<?>> type = Registries.ENTITY_TYPE.getOrEmpty(new Identifier(entityType));
        if (type.isEmpty()) { ctx.sendMsg(Text.literal("\u00a7cUnknown entity: " + entityType), false); return; }
        ServerWorld world = ctx.world();
        for (int i = 0; i < count; i++) {
            Entity e = type.get().create(world);
            if (e == null) continue;
            double angle = (i * 2.0 * Math.PI) / Math.max(1, count);
            e.setPosition(ctx.caster.getPos().add(Math.cos(angle) * 2.0, 0, Math.sin(angle) * 2.0));
            world.spawnEntity(e);
            if (e instanceof LivingEntity le) com.example.shinobicore.ai.SummonSystem.register(ctx, form, le);
        }
        Fx.elementBurst(world, ctx.caster.getPos().add(0, 1, 0), ctx.jutsu.getElement(), 25);
    }
}
package com.example.shinobicore.jutsu.executor;

import com.example.shinobicore.jutsu.core.FormDefinition;
import com.example.shinobicore.jutsu.core.JutsuDefinition;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.registry.Registries;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;
import net.minecraft.util.Identifier;
import java.util.Optional;
import net.minecraft.entity.EntityType;

public class FormExecutor {

    public static void executeForm(ServerPlayerEntity player, JutsuDefinition jutsu) {
        FormDefinition form = jutsu.getForm();
        switch (form.getType()) {
            case POINT -> executePoint(player, jutsu, form);
            case PROJECTILE -> executeProjectile(player, jutsu, form);
            case DASH -> DashSystem.start(player, jutsu, form);
            case HANDHELD -> HandheldSystem.start(player, jutsu);
            case ZONE -> ZoneSystem.start(player, jutsu, form);
            case SUMMON -> executeSummon(player, jutsu, form);
            default -> player.sendMessage(
                Text.literal("\u00a7eForm '" + form.getType().getId() + "' coming soon"), false);
        }
        Fx.castSound(player, jutsu);
    }

    private static void executePoint(ServerPlayerEntity player, JutsuDefinition jutsu, FormDefinition form) {
        String mode = form.getString("targetMode", "self");
        double range = form.getDouble("range", 3.0);
        LivingEntity target;
        if (mode.equals("self")) {
            target = player;
        } else {
            target = Targeting.lookEntity(player, range);
        }
        if (target != null) {
            EffectExecutor.applyEffects(player, jutsu, target);
            HitProperties.apply(player.getServerWorld(), player, jutsu, target.getPos());
            Fx.elementBurst(player.getServerWorld(), target.getPos().add(0, 1, 0), jutsu.getElement(), 20);
        } else {
            player.sendMessage(Text.literal("\u00a7cNo target in range"), false);
        }
    }

    private static void executeProjectile(ServerPlayerEntity player, JutsuDefinition jutsu, FormDefinition form) {
        double speed = form.getDouble("speed", 1.4);
        double gravity = form.getDouble("gravity", 0.02);
        int lifetime = form.getInt("lifetime", 80);
        double size = form.getDouble("size", 0.5);
        boolean piercing = jutsu.hasProperty("piercing");
        ProjectileSystem.spawn(player, jutsu, player.getRotationVector(), speed, gravity, lifetime, size, piercing);
    }

    private static void executeSummon(ServerPlayerEntity player, JutsuDefinition jutsu, FormDefinition form) {
        String entityType = form.getString("entityType", "minecraft:wolf");
        int count = form.getInt("count", 1);
        Optional<EntityType<?>> type = Registries.ENTITY_TYPE.getOrEmpty(new Identifier(entityType));
        if (type.isEmpty()) {
            player.sendMessage(Text.literal("\u00a7cUnknown entity: " + entityType), false);
            return;
        }
        ServerWorld world = player.getServerWorld();
        for (int i = 0; i < count; i++) {
            Entity e = type.get().create(world);
            if (e == null) continue;
            double angle = (i * 2.0 * Math.PI) / Math.max(1, count);
            e.setPosition(player.getPos().add(Math.cos(angle) * 2.0, 0, Math.sin(angle) * 2.0));
            world.spawnEntity(e);
        }
        Fx.elementBurst(world, player.getPos().add(0, 1, 0), jutsu.getElement(), 25);
    }
}
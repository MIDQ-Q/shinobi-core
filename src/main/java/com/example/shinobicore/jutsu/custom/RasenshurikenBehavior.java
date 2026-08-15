package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.entity.RasenshurikenEntity;
import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;
import net.minecraft.text.Text;
import net.minecraft.util.math.Vec3d;

public class RasenshurikenBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;

        // Создаём сущность расенсюрикена НАД ГОЛОВОЙ
        RasenshurikenEntity shurikenEntity = new RasenshurikenEntity(world, player, damage);
        world.spawnEntity(shurikenEntity);
        player.sendMessage(Text.literal("\u00a7b\u2726 Rasenshuriken ready! Right-click to throw!"), true);
        world.playSound(null, player.getBlockPos(), SoundEvents.BLOCK_BEACON_AMBIENT,
                SoundCategory.PLAYERS, 2.0f, 1.5f);

        // Частицы зарядки
        TickScheduler.schedule(world, 1, 2, 30, w -> {
            Vec3d above = player.getPos().add(0, player.getHeight() + 0.8, 0);
            float rot = w.getTime() * 0.3f;
            for (int i = 0; i < 12; i++) {
                double a = rot + (i / 12.0) * Math.PI * 2;
                double r = 0.6 + (i % 3) * 0.2;
                w.spawnParticles(ParticleTypes.CLOUD,
                        above.x + Math.cos(a) * r,
                        above.y + Math.sin(a * 2) * 0.2,
                        above.z + Math.sin(a) * r,
                        2, 0.04, 0.04, 0.04, 0.02);
            }
        });

        JutsuLogger.logBehavior("rasenshuriken",
            String.format("SPAWNED above head: player=%s, damage=%.1f",
            player.getName().getString(), damage));
    }
}
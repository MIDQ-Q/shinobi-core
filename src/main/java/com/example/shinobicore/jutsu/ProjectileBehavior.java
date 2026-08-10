package com.example.shinobicore.jutsu;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.entity.NinjaProjectileEntity;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.math.Vec3d;

public class ProjectileBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data, JsonObject params, float damage) {
        float speed = params.has("speed") ? params.get("speed").getAsFloat() : 1.5f;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 1.0f;
        String particle = params.has("particle") ? params.get("particle").getAsString() : "flame";
        int lifetime = params.has("lifetime") ? params.get("lifetime").getAsInt() : 100;
        boolean hasGravity = params.has("gravity") && params.get("gravity").getAsBoolean();
        int pierceCount = params.has("pierce") ? params.get("pierce").getAsInt() : 0;
        int bounceCount = params.has("bounce") ? params.get("bounce").getAsInt() : 0;
        int projectileCount = params.has("count") ? params.get("count").getAsInt() : 1;
        float spread = params.has("spread") ? params.get("spread").getAsFloat() : 0f;

        Vec3d baseDir = player.getRotationVector().normalize();

        // === ЛОГИРОВАНИЕ: начало каста ===
        ShinobiCore.LOGGER.info("[PROJECTILE-BEHAVIOR] Cast: speed={}, radius={}, particle={}, lifetime={}, gravity={}, pierce={}, bounce={}, count={}, spread={}",
                speed, radius, particle, lifetime, hasGravity, pierceCount, bounceCount, projectileCount, spread);
        ShinobiCore.LOGGER.info("[PROJECTILE-BEHAVIOR] Player pos: ({}, {}, {}), lookDir: ({}, {}, {})",
                String.format("%.2f", player.getX()),
                String.format("%.2f", player.getY()),
                String.format("%.2f", player.getZ()),
                String.format("%.2f", baseDir.x),
                String.format("%.2f", baseDir.y),
                String.format("%.2f", baseDir.z));

        for (int i = 0; i < projectileCount; i++) {
            Vec3d dir = baseDir;

            // Разброс для нескольких снарядов
            if (projectileCount > 1 && spread > 0) {
                float angle = (float) ((i - (projectileCount - 1) / 2.0) * spread * Math.PI / 180.0);
                double cos = Math.cos(angle);
                double sin = Math.sin(angle);
                dir = new Vec3d(
                        baseDir.x * cos - baseDir.z * sin,
                        baseDir.y,
                        baseDir.x * sin + baseDir.z * cos
                ).normalize();
            }

            Vec3d velocity = dir.multiply(speed);
            
            // === ИСПРАВЛЕНО: спавн на 3 блока впереди игрока (было 2) ===
            Vec3d spawnOffset = dir.multiply(3.0);
            double spawnX = player.getX() + spawnOffset.x;
            double spawnY = player.getEyeY() - 0.2 + spawnOffset.y;
            double spawnZ = player.getZ() + spawnOffset.z;
            
            // === ЛОГИРОВАНИЕ: позиция спавна ===
            ShinobiCore.LOGGER.info("[PROJECTILE-BEHAVIOR] Spawn offset: ({}, {}, {}), final pos: ({}, {}, {})",
                    String.format("%.2f", spawnOffset.x),
                    String.format("%.2f", spawnOffset.y),
                    String.format("%.2f", spawnOffset.z),
                    String.format("%.2f", spawnX),
                    String.format("%.2f", spawnY),
                    String.format("%.2f", spawnZ));
            
            NinjaProjectileEntity projectile = new NinjaProjectileEntity(
                    player.getWorld(), player, velocity, damage, radius, particle, lifetime
            );
            projectile.setPosition(spawnX, spawnY, spawnZ);

            // Устанавливаем дополнительные параметры
            projectile.setHasGravity(hasGravity);
            projectile.setPierceCount(pierceCount);
            projectile.setBounceCount(bounceCount);

            player.getWorld().spawnEntity(projectile);
            
            ShinobiCore.LOGGER.info("[PROJECTILE-BEHAVIOR] Entity spawned, id={}", projectile.getId());
        }
    }
}
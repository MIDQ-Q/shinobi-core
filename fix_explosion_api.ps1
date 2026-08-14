$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$f = "E:\Games\mod\src\main\java\com\example\shinobicore\jutsu\custom\ExplodingProjectileBehavior.java"

$code = @'
package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.entity.projectile.FireballEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;

public class ExplodingProjectileBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float speed = params.has("speed") ? params.get("speed").getAsFloat() : 1.8f;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 4f;
        Vec3d eye = player.getEyePos();
        Vec3d look = player.getRotationVector();
        FireballEntity fb = new FireballEntity(world, player, look.x, look.y, look.z, 0);
        fb.setPosition(eye.x, eye.y, eye.z);
        fb.setVelocity(look.x * speed, look.y * speed, look.z * speed, 0.1f, 0.1f);
        world.spawnEntity(fb);
        TickScheduler.schedule(world, 1, 2, 40, w -> {
            if (fb.isRemoved() || fb.horizontalCollision || fb.verticalCollision) {
                Vec3d pos = fb.getPos();
                w.createExplosion(fb, pos.x, pos.y, pos.z, radius, false, net.minecraft.world.explosion.Explosion.DestructionType.DESTROY);
                fb.discard();
            }
        });
        JutsuLogger.logBehavior("exploding_projectile", "radius=" + radius);
    }
}
'@

[System.IO.File]::WriteAllText($f, $code, $utf8)
Write-Host "[OK] ExplodingProjectileBehavior: simplified createExplosion"
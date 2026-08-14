$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main\java\com\example\shinobicore"

function Write-File($p, $c) {
    $dir = [System.IO.Path]::GetDirectoryName($p)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] $p"
}

# 1. Standard ProjectileBehavior (Все базовые elemental bullets: Fire, Water, Wind, Earth)
Write-File "$base\jutsu\ProjectileBehavior.java" @'
package com.example.shinobicore.jutsu;

import com.example.shinobicore.entity.NinjaProjectileEntity;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;

public class ProjectileBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        
        float speed = params.has("speed") ? params.get("speed").getAsFloat() : 2.0f;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 1.0f;
        String particle = params.has("particle") ? params.get("particle").getAsString() : "flame";
        if ("none".equals(particle)) particle = "wind";
        int lifetime = params.has("lifetime") ? params.get("lifetime").getAsInt() : 80;
        boolean gravity = params.has("gravity") && params.get("gravity").getAsBoolean();
        int pierce = params.has("pierce") ? params.get("pierce").getAsInt() : 0;
        int count = params.has("count") ? params.get("count").getAsInt() : 1;
        float spread = params.has("spread") ? params.get("spread").getAsFloat() : 0f;

        Vec3d eye = player.getEyePos();
        Vec3d look = player.getRotationVector();

        for (int i = 0; i < count; i++) {
            Vec3d dir = look;
            if (count > 1 && spread > 0) {
                double angle = (i - (count - 1) / 2.0) * spread;
                double rad = Math.toRadians(angle);
                double cos = Math.cos(rad), sin = Math.sin(rad);
                dir = new Vec3d(dir.x * cos - dir.z * sin, dir.y, dir.x * sin + dir.z * cos).normalize();
            }
            
            NinjaProjectileEntity proj = new NinjaProjectileEntity(
                world, player, dir.multiply(speed), damage, radius, particle, lifetime
            );
            proj.setPosition(eye.x, eye.y - 0.2, eye.z);
            proj.setHasGravity(gravity);
            proj.setPierceCount(pierce);
            world.spawnEntity(proj);
        }
    }
}
'@

# 2. RasenshurikenBehavior (Теперь это массивная 3D сфера!)
Write-File "$base\jutsu\custom\RasenshurikenBehavior.java" @'
package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.entity.NinjaProjectileEntity;
import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
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
        
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 8f;
        int chargeTicks = params.has("chargeTicks") ? params.get("chargeTicks").getAsInt() : 60;
        
        player.sendMessage(Text.literal("\u00a7bRasenshuriken charging..."), true);
        world.playSound(null, player.getBlockPos(), SoundEvents.BLOCK_BEACON_AMBIENT, SoundCategory.PLAYERS, 2.0f, 1.5f);
        
        TickScheduler.schedule(world, 1, 2, chargeTicks / 2, w -> {
            Vec3d hand = player.getEyePos().add(player.getRotationVector().multiply(0.8)).add(0, -0.3, 0);
            w.spawnParticles(ParticleTypes.CLOUD, hand.x, hand.y, hand.z, 15, 0.3, 0.3, 0.3, 0.05);
            w.spawnParticles(ParticleTypes.END_ROD, hand.x, hand.y, hand.z, 5, 0.1, 0.1, 0.1, 0.02);
        });
        
        TickScheduler.schedule(world, chargeTicks + 1, chargeTicks + 1, 1, w -> {
            player.sendMessage(Text.literal("\u00a7aRASENSHURIKEN!"), true);
            world.playSound(null, player.getBlockPos(), SoundEvents.ENTITY_ENDER_DRAGON_GROWL, SoundCategory.PLAYERS, 2.0f, 1.2f);
            
            Vec3d eye = player.getEyePos();
            Vec3d look = player.getRotationVector();
            
            NinjaProjectileEntity proj = new NinjaProjectileEntity(
                world, player, look.multiply(2.5), damage, radius, "wind", 80
            );
            proj.setPosition(eye.x + look.x, eye.y - 0.2, eye.z + look.z);
            proj.setHasGravity(false);
            proj.setPierceCount(20); // Пробивает всё насквозь и взрывается в конце
            world.spawnEntity(proj);
        });
    }
}
'@

# 3. ExplodingProjectileBehavior (Огненные шары)
Write-File "$base\jutsu\custom\ExplodingProjectileBehavior.java" @'
package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.entity.NinjaProjectileEntity;
import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
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
        
        NinjaProjectileEntity proj = new NinjaProjectileEntity(
            world, player, look.multiply(speed), damage, radius, "fire", 100
        );
        proj.setPosition(eye.x, eye.y - 0.2, eye.z);
        proj.setHasGravity(true);
        world.spawnEntity(proj);
    }
}
'@

# 4. HomingProjectileBehavior (Самонаведение)
Write-File "$base\jutsu\custom\HomingProjectileBehavior.java" @'
package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.entity.NinjaProjectileEntity;
import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;

public class HomingProjectileBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        
        int count = params.has("count") ? params.get("count").getAsInt() : 12;
        float speed = params.has("speed") ? params.get("speed").getAsFloat() : 2.0f;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 1.0f;
        
        Vec3d eye = player.getEyePos();
        Vec3d look = player.getRotationVector();
        
        for (int i = 0; i < count; i++) {
            Vec3d dir = look.add((Math.random() - 0.5) * 0.5, (Math.random() - 0.5) * 0.5, (Math.random() - 0.5) * 0.5).normalize();
            NinjaProjectileEntity proj = new NinjaProjectileEntity(
                world, player, dir.multiply(speed), damage, radius, "fire", 80
            );
            proj.setPosition(eye.x, eye.y - 0.2, eye.z);
            proj.setPierceCount(1);
            world.spawnEntity(proj);
        }
    }
}
'@

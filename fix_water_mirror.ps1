$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$f = "E:\Games\mod\src\main\java\com\example\shinobicore\jutsu\custom\ImprovedWaterMirrorBehavior.java"

$code = @'
package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.jutsu.WallRemovalTask;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.block.Blocks;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import java.util.ArrayList;
import java.util.List;

public class ImprovedWaterMirrorBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float range = params.has("range") ? params.get("range").getAsFloat() : 8f;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 5f;
        int lifetime = params.has("lifetime") ? params.get("lifetime").getAsInt() : 200;
        Vec3d center = player.getPos().add(player.getRotationVector().multiply(range));
        BlockPos c = BlockPos.ofFloored(center);
        List<BlockPos> placed = new ArrayList<>();
        int r = (int) radius;
        for (int dx = -r; dx <= r; dx++) {
            for (int dz = -r; dz <= r; dz++) {
                if (dx * dx + dz * dz > r * r) continue;
                BlockPos p = c.add(dx, 0, dz);
                if (world.getBlockState(p).isAir()) {
                    world.setBlockState(p, Blocks.WATER.getDefaultState(), 3);
                    placed.add(p);
                }
            }
        }
        if (!placed.isEmpty()) WallRemovalTask.schedule(world, placed, lifetime);
        for (Entity e : world.getOtherEntities(player, new Box(center, center).expand(radius))) {
            if (e instanceof LivingEntity living && !living.equals(player)) {
                living.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, lifetime, 2, false, false));
            }
        }
        JutsuLogger.logBehavior("improved_water_mirror", "placed=" + placed.size() + " radius=" + radius);
    }
}
'@

[System.IO.File]::WriteAllText($f, $code, $utf8)
Write-Host "[OK] ImprovedWaterMirrorBehavior: fixed Entity -> LivingEntity loop"
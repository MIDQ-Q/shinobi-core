$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main"
function Write-File($p, $c) { [System.IO.File]::WriteAllText($p, $c, $utf8); Write-Host "[OK] $p" }

# ============ 1. MobEntityAccessor ============
Write-File "$base\java\com\example\shinobicore\mixin\MobEntityAccessor.java" @'
package com.example.shinobicore.mixin;

import net.minecraft.entity.ai.goal.GoalSelector;
import net.minecraft.entity.mob.MobEntity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.gen.Accessor;

@Mixin(MobEntity.class)
public interface MobEntityAccessor {
    @Accessor("targetSelector")
    GoalSelector shinobicore$getTargetSelector();

    @Accessor("goalSelector")
    GoalSelector shinobicore$getGoalSelector();
}
'@

# ============ 2. Register accessor in mixins.json ============
$mx = "E:\Games\mod\src\main\resources\shinobicore.mixins.json"
$mc = [System.IO.File]::ReadAllText($mx, $utf8)
if (-not $mc.Contains("MobEntityAccessor")) {
    $mc = $mc.Replace('"client": [', '"client": [
    "MobEntityAccessor",')
    [System.IO.File]::WriteAllText($mx, $mc, $utf8)
    Write-Host "[OK] mixins.json: MobEntityAccessor added"
}

# ============ 3. SummonBehavior rewrite with accessor ============
Write-File "$base\java\com\example\shinobicore\jutsu\custom\SummonBehavior.java" @'
package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.mixin.MobEntityAccessor;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.EntityType;
import net.minecraft.entity.ai.goal.ActiveTargetGoal;
import net.minecraft.entity.mob.Hostile;
import net.minecraft.entity.mob.MobEntity;
import net.minecraft.entity.passive.WolfEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.registry.Registries;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.Vec3d;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

public class SummonBehavior implements JutsuBehavior {
    private static final Map<UUID, List<Long>> SUMMON_TIMES = new HashMap<>();
    private static final long LIFETIME_MS = 120000;

    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        String entityId = params.has("entity") ? params.get("entity").getAsString() : "minecraft:wolf";
        int count = params.has("count") ? params.get("count").getAsInt() : 1;

        long now = System.currentTimeMillis();
        List<Long> times = SUMMON_TIMES.computeIfAbsent(player.getUuid(), k -> new ArrayList<>());
        times.removeIf(t -> now - t > LIFETIME_MS);
        if (times.size() >= 2) {
            player.sendMessage(Text.literal("\u00a7cMax 2 summons active! Wait for them to dissipate."), false);
            return;
        }

        EntityType<?> type = Registries.ENTITY_TYPE.getOrEmpty(new Identifier(entityId)).orElse(null);
        if (type == null) {
            player.sendMessage(Text.literal("\u00a7cUnknown summon: " + entityId), false);
            return;
        }
        Vec3d basePos = player.getPos();
        for (int i = 0; i < count; i++) {
            Entity entity = type.create(world);
            if (entity == null) continue;
            double angle = Math.random() * Math.PI * 2;
            double r = 1.5 + Math.random();
            entity.setPosition(basePos.x + Math.cos(angle) * r, basePos.y, basePos.z + Math.sin(angle) * r);
            world.spawnEntity(entity);

            if (entity instanceof WolfEntity wolf) {
                wolf.setOwner(player);
                wolf.setTamed(true);
            }
            if (entity instanceof MobEntity mob) {
                var acc = (MobEntityAccessor) mob;
                var ts = acc.shinobicore$getTargetSelector();
                ts.clear(g -> true);
                ActiveTargetGoal<MobEntity> goal = new ActiveTargetGoal<>(mob, MobEntity.class, 10, true, true,
                    t -> (t instanceof Hostile) && !t.equals(player) && !(t instanceof WolfEntity));
                ts.add(1, goal);
            }

            times.add(now);
            final Entity summon = entity;
            TickScheduler.schedule(world, 2400, 2400, 1, w -> {
                if (!summon.isRemoved()) {
                    for (int p = 0; p < 15; p++) {
                        w.spawnParticles(ParticleTypes.POOF,
                            summon.getX(), summon.getY() + Math.random(), summon.getZ(), 1, 0.3, 0.3, 0.3, 0.02);
                    }
                    summon.discard();
                }
            });
        }
        JutsuLogger.logBehavior("summon", "entity=" + entityId + " count=" + count);
    }
}
'@

Write-Host "=== SUMMON FIX DONE ==="
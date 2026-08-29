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
import net.minecraft.entity.mob.MobEntity;
import net.minecraft.entity.mob.Monster;
import net.minecraft.entity.passive.WolfEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;
import net.minecraft.util.math.Vec3d;
public class ShadowCloneBehavior implements JutsuBehavior {
@Override
public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
JsonObject params, float damage) {
if (!(player.getWorld() instanceof ServerWorld world)) return;
int count = params.has("count") ? params.get("count").getAsInt() : 3;
int duration = params.has("duration") ? params.get("duration").getAsInt() : 400;
for (int i = 0; i < count; i++) {
double angle = (i / (double) count) * Math.PI * 2;
double x = player.getX() + Math.cos(angle) * 2;
double z = player.getZ() + Math.sin(angle) * 2;
WolfEntity clone = EntityType.WOLF.create(world);
if (clone == null) continue;
clone.setPosition(x, player.getY(), z);
clone.setOwner(player);
clone.setTamed(true);
clone.setCustomName(Text.literal("Shadow Clone"));
clone.setCustomNameVisible(true);
world.spawnEntity(clone);
world.spawnParticles(ParticleTypes.POOF, x, player.getY() + 1, z, 10, 0.5, 0.5, 0.5, 0.1);
final Entity summon = clone;
TickScheduler.schedule(world, duration, duration, 1, w -> {
if (!summon.isRemoved()) {
w.spawnParticles(ParticleTypes.POOF, summon.getX(), summon.getY() + 1, summon.getZ(), 10, 0.5, 0.5, 0.5, 0.1);
summon.discard();
}
});
}
player.sendMessage(Text.literal("\u00a77Shadow Clone Jutsu! " + count + " clones created."), true);
JutsuLogger.logBehavior("shadow_clone", "count=" + count + " duration=" + duration);
}
}
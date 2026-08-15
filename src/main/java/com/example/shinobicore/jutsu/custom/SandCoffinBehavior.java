package com.example.shinobicore.jutsu.custom;
import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;
import net.minecraft.text.Text;
import net.minecraft.util.math.Vec3d;
public class SandCoffinBehavior implements JutsuBehavior {
@Override
public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
JsonObject params, float damage) {
if (!(player.getWorld() instanceof ServerWorld world)) return;
float range = params.has("range") ? params.get("range").getAsFloat() : 15f;
LivingEntity target = null;
double closestDist = Double.MAX_VALUE;
for (Entity e : world.getOtherEntities(player, player.getBoundingBox().expand(range))) {
if (e instanceof LivingEntity liv && !liv.equals(player)) {
double d = liv.getPos().distanceTo(player.getPos());
if (d < closestDist) {
closestDist = d;
target = liv;
}
}
}
if (target == null) {
player.sendMessage(Text.literal("\u00a7cNo target in range!"), false);
return;
}
final LivingEntity finalTarget = target;
finalTarget.addStatusEffect(new StatusEffectInstance(StatusEffects.LEVITATION, 60, 2, false, false));
finalTarget.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, 60, 255, false, false));
finalTarget.addStatusEffect(new StatusEffectInstance(StatusEffects.MINING_FATIGUE, 60, 255, false, false));
world.playSound(null, player.getBlockPos(), SoundEvents.BLOCK_SAND_PLACE, SoundCategory.PLAYERS, 1.5f, 0.8f);
player.sendMessage(Text.literal("\u00a76Sand Coffin!"), true);
TickScheduler.schedule(world, 1, 5, 12, w -> {
Vec3d pos = finalTarget.getPos();
w.spawnParticles(ParticleTypes.POOF, pos.x, pos.y + 1, pos.z, 15, 1, 1, 1, 0.1);
w.spawnParticles(ParticleTypes.FALLING_NECTAR, pos.x, pos.y + 1.5, pos.z, 5, 0.5, 0.5, 0.5, 0.05);
});
TickScheduler.schedule(world, 60, 60, 1, w -> {
Vec3d pos = finalTarget.getPos();
finalTarget.damage(player.getDamageSources().magic(), damage);
Vec3d kb = finalTarget.getPos().subtract(player.getPos()).normalize().multiply(2.0);
finalTarget.addVelocity(kb.x, 0.5, kb.z);
finalTarget.velocityModified = true;
w.spawnParticles(ParticleTypes.EXPLOSION, pos.x, pos.y + 1, pos.z, 5, 0.5, 0.5, 0.5, 0.05);
w.playSound(null, finalTarget.getBlockPos(), SoundEvents.ENTITY_GENERIC_EXPLODE, SoundCategory.PLAYERS, 1.0f, 1.0f);
});
JutsuLogger.logBehavior("sand_coffin", "target=" + target.getName().getString());
}
}
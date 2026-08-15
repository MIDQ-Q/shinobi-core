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
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
public class ChidoriBehavior implements JutsuBehavior {
@Override
public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
JsonObject params, float damage) {
if (!(player.getWorld() instanceof ServerWorld world)) return;
float dashDistance = params.has("dashDistance") ? params.get("dashDistance").getAsFloat() : 8f;
float hitRadius = params.has("hitRadius") ? params.get("hitRadius").getAsFloat() : 2f;
Vec3d look = player.getRotationVector();
Vec3d startPos = player.getPos();
player.addVelocity(look.x * 2, 0.1, look.z * 2);
player.velocityModified = true;
world.spawnParticles(ParticleTypes.ELECTRIC_SPARK, startPos.x, startPos.y + 1, startPos.z, 30, 1, 1, 1, 0.2);
world.playSound(null, player.getBlockPos(), SoundEvents.ENTITY_LIGHTNING_BOLT_THUNDER, SoundCategory.PLAYERS, 1.5f, 1.0f);
player.addStatusEffect(new StatusEffectInstance(StatusEffects.SPEED, 40, 2, false, false));
TickScheduler.schedule(world, 2, 2, 8, w -> {
Vec3d currentPos = player.getPos();
for (Entity e : w.getOtherEntities(player, new Box(currentPos, currentPos).expand(hitRadius))) {
if (e instanceof LivingEntity liv && !liv.equals(player)) {
liv.damage(player.getDamageSources().magic(), damage * 0.3f);
liv.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, 40, 2, false, false));
Vec3d kb = liv.getPos().subtract(player.getPos()).normalize().multiply(0.5);
liv.addVelocity(kb.x, 0.3, kb.z);
liv.velocityModified = true;
}
}
w.spawnParticles(ParticleTypes.ELECTRIC_SPARK, currentPos.x, currentPos.y + 1, currentPos.z, 8, 0.5, 0.5, 0.5, 0.1);
});
TickScheduler.schedule(world, 20, 20, 1, w -> {
Vec3d endPos = player.getPos();
for (Entity e : w.getOtherEntities(player, new Box(endPos, endPos).expand(hitRadius * 1.5))) {
if (e instanceof LivingEntity liv && !liv.equals(player)) {
liv.damage(player.getDamageSources().magic(), damage * 0.5f);
}
}
w.spawnParticles(ParticleTypes.FLASH, endPos.x, endPos.y + 1, endPos.z, 3, 0.5, 0.5, 0.5, 0.05);
});
JutsuLogger.logBehavior("chidori", "dash=" + dashDistance + " hitRadius=" + hitRadius);
}
}
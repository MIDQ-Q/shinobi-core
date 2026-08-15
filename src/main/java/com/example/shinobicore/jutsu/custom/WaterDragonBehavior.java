package com.example.shinobicore.jutsu.custom;
import com.example.shinobicore.entity.NinjaProjectileEntity;
import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
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
public class WaterDragonBehavior implements JutsuBehavior {
@Override
public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
JsonObject params, float damage) {
if (!(player.getWorld() instanceof ServerWorld world)) return;
float speed = params.has("speed") ? params.get("speed").getAsFloat() : 1.4f;
float radius = params.has("radius") ? params.get("radius").getAsFloat() : 4f;
int lifetime = params.has("lifetime") ? params.get("lifetime").getAsInt() : 100;
Vec3d eye = player.getEyePos();
Vec3d look = player.getRotationVector();
NinjaProjectileEntity proj = new NinjaProjectileEntity(
world, player, look.multiply(speed), damage, radius, "water", "water_dragon", lifetime
);
proj.setPosition(eye.x, eye.y - 0.2, eye.z);
proj.setHasGravity(false);
proj.setPierceCount(3);
world.spawnEntity(proj);
world.playSound(null, player.getBlockPos(), SoundEvents.ENTITY_GENERIC_SPLASH, SoundCategory.PLAYERS, 2.0f, 0.8f);
TickScheduler.schedule(world, 1, 3, 25, w -> {
if (!proj.isRemoved()) {
w.spawnParticles(ParticleTypes.FALLING_WATER, proj.getX(), proj.getY(), proj.getZ(), 4, 0.5, 0.5, 0.5, 0.1);
w.spawnParticles(ParticleTypes.BUBBLE_POP, proj.getX(), proj.getY() + 0.3, proj.getZ(), 2, 0.3, 0.3, 0.3, 0.02);
for (var e : w.getOtherEntities(player, new Box(proj.getPos(), proj.getPos()).expand(2.5))) {
if (e instanceof LivingEntity liv && !liv.equals(player)) {
liv.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, 40, 1, false, false));
}
}
}
});
JutsuLogger.logBehavior("water_dragon", "speed=" + speed + " radius=" + radius);
}
}
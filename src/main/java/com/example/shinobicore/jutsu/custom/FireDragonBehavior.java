package com.example.shinobicore.jutsu.custom;
import com.example.shinobicore.entity.NinjaProjectileEntity;
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
import net.minecraft.util.math.Vec3d;
public class FireDragonBehavior implements JutsuBehavior {
@Override
public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
JsonObject params, float damage) {
if (!(player.getWorld() instanceof ServerWorld world)) return;
float speed = params.has("speed") ? params.get("speed").getAsFloat() : 1.5f;
float radius = params.has("radius") ? params.get("radius").getAsFloat() : 4f;
int lifetime = params.has("lifetime") ? params.get("lifetime").getAsInt() : 80;
Vec3d eye = player.getEyePos();
Vec3d look = player.getRotationVector();
NinjaProjectileEntity proj = new NinjaProjectileEntity(
world, player, look.multiply(speed), damage, radius, "flame", "fire_dragon", lifetime
);
proj.setPosition(eye.x, eye.y - 0.2, eye.z);
proj.setHasGravity(false);
proj.setPierceCount(5);
world.spawnEntity(proj);
world.playSound(null, player.getBlockPos(), SoundEvents.ENTITY_ENDER_DRAGON_GROWL, SoundCategory.PLAYERS, 1.5f, 1.2f);
TickScheduler.schedule(world, 1, 2, 20, w -> {
if (!proj.isRemoved()) {
w.spawnParticles(ParticleTypes.FLAME, proj.getX(), proj.getY(), proj.getZ(), 5, 0.5, 0.5, 0.5, 0.1);
w.spawnParticles(ParticleTypes.LARGE_SMOKE, proj.getX(), proj.getY() + 0.5, proj.getZ(), 2, 0.3, 0.3, 0.3, 0.02);
}
});
JutsuLogger.logBehavior("fire_dragon", "speed=" + speed + " radius=" + radius);
}
}
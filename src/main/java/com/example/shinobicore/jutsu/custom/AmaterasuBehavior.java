package com.example.shinobicore.jutsu.custom;
import com.example.shinobicore.entity.NinjaProjectileEntity;
import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
public class AmaterasuBehavior implements JutsuBehavior {
@Override
public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
JsonObject params, float damage) {
if (!(player.getWorld() instanceof ServerWorld world)) return;
// S5-06 FIX: Require Sharingan
if (data.getActiveDojutsu() == null || !data.getActiveDojutsu().equals("sharingan")) {
player.sendMessage(net.minecraft.text.Text.literal("В§cRequires Sharingan!"), false);
return;
}
float speed = params.has("speed") ? params.get("speed").getAsFloat() : 2.0f;
float radius = params.has("radius") ? params.get("radius").getAsFloat() : 2f;
int lifetime = params.has("lifetime") ? params.get("lifetime").getAsInt() : 120;
Vec3d eye = player.getEyePos();
Vec3d look = player.getRotationVector();
// Triple damage for Amaterasu
float amaterasuDamage = damage * 3.0f;
NinjaProjectileEntity proj = new NinjaProjectileEntity(
world, player, look.multiply(speed), amaterasuDamage, radius, "smoke", "amaterasu", lifetime
);
proj.setPosition(eye.x, eye.y - 0.2, eye.z);
proj.setHasGravity(false);
world.spawnEntity(proj);
world.playSound(null, player.getBlockPos(), SoundEvents.ENTITY_BLAZE_SHOOT, SoundCategory.PLAYERS, 1.5f, 0.6f);
TickScheduler.schedule(world, 1, 3, 15, w -> {
if (!proj.isRemoved()) {
w.spawnParticles(ParticleTypes.SMOKE, proj.getX(), proj.getY(), proj.getZ(), 4, 0.3, 0.3, 0.3, 0.05);
w.spawnParticles(ParticleTypes.LARGE_SMOKE, proj.getX(), proj.getY(), proj.getZ(), 2, 0.2, 0.2, 0.2, 0.03);
}
});
JutsuLogger.logBehavior("amaterasu", "speed=" + speed + " radius=" + radius);
}
}
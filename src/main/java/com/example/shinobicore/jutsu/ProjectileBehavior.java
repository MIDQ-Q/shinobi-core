package com.example.shinobicore.jutsu;
import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.entity.NinjaProjectileEntity;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.math.Vec3d;
public class ProjectileBehavior implements JutsuBehavior {
@Override
public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data, JsonObject params, float damage) {
float speed = params.has("speed") ? params.get("speed").getAsFloat() : 1.5f;
float radius = params.has("radius") ? params.get("radius").getAsFloat() : 1.0f;
String particle = params.has("particle") ? params.get("particle").getAsString() : "flame";
String model = params.has("model") ? params.get("model").getAsString() : "sphere";
int lifetime = params.has("lifetime") ? params.get("lifetime").getAsInt() : 100;
boolean hasGravity = params.has("gravity") && params.get("gravity").getAsBoolean();
int pierceCount = params.has("pierce") ? params.get("pierce").getAsInt() : 0;
int bounceCount = params.has("bounce") ? params.get("bounce").getAsInt() : 0;
int projectileCount = params.has("count") ? params.get("count").getAsInt() : 1;
float spread = params.has("spread") ? params.get("spread").getAsFloat() : 0f;
Vec3d baseDir = player.getRotationVector().normalize();
for (int i = 0; i < projectileCount; i++) {
Vec3d dir = baseDir;
if (projectileCount > 1 && spread > 0) {
float angle = (float) ((i - (projectileCount - 1) / 2.0) * spread * Math.PI / 180.0);
double cos = Math.cos(angle);
double sin = Math.sin(angle);
dir = new Vec3d(baseDir.x * cos - baseDir.z * sin, baseDir.y, baseDir.x * sin + baseDir.z * cos).normalize();
}
Vec3d velocity = dir.multiply(speed);
Vec3d spawnOffset = dir.multiply(2.0);
double spawnX = player.getX() + spawnOffset.x;
double spawnY = player.getEyeY() - 0.2 + spawnOffset.y;
double spawnZ = player.getZ() + spawnOffset.z;
NinjaProjectileEntity projectile = new NinjaProjectileEntity(
player.getWorld(), player, velocity, damage, radius, particle, model, lifetime
);
projectile.setPosition(spawnX, spawnY, spawnZ);
projectile.setHasGravity(hasGravity);
projectile.setPierceCount(pierceCount);
projectile.setBounceCount(bounceCount);
player.getWorld().spawnEntity(projectile);
}
}
}
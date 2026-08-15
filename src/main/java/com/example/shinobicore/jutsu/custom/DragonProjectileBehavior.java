package com.example.shinobicore.jutsu.custom;
import com.example.shinobicore.entity.NinjaProjectileEntity;
import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;
public class DragonProjectileBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data, JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float speed = params.has("speed") ? params.get("speed").getAsFloat() : 1.5f;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 3.0f;
        String model = params.has("model") ? params.get("model").getAsString() : "water_dragon";
        String particle = params.has("particle") ? params.get("particle").getAsString() : "water";
        Vec3d eye = player.getEyePos();
        Vec3d look = player.getRotationVector();
        NinjaProjectileEntity proj = new NinjaProjectileEntity(world, player, look.multiply(speed), damage, radius, particle, model, 120);
        proj.setPosition(eye.x, eye.y, eye.z);
        proj.setPierceCount(2);
        world.spawnEntity(proj);
    }
}
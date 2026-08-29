package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.entity.NinjaProjectileEntity;
import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;

/**
 * Wind Release: Sickle Weasel Technique
 * Creates a spinning wind projectile that flies forward in an arc pattern
 */
public class SickleWeaselBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data, JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        
        float speed = params.has("speed") ? params.get("speed").getAsFloat() : 2.4f;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 1.0f;
        int pierce = params.has("pierce") ? params.get("pierce").getAsInt() : 2;
        int lifetime = params.has("lifetime") ? params.get("lifetime").getAsInt() : 60;
        
        Vec3d eye = player.getEyePos();
        Vec3d look = player.getRotationVector();
        
        // Create the sickle projectile with shuriken model
        NinjaProjectileEntity proj = new NinjaProjectileEntity(world, player, look.multiply(speed), damage, radius, "wind", "shuriken", lifetime);
        proj.setPosition(eye.x, eye.y, eye.z);
        proj.setPierceCount(pierce);
        
        // Add slight upward angle for arc trajectory
        Vec3d velocity = new Vec3d(look.x, look.y + 0.15, look.z).normalize().multiply(speed);
        proj.setVelocity(velocity);
        proj.velocityDirty = true;
        
        world.spawnEntity(proj);
    }
}

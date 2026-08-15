package com.example.shinobicore.jutsu.custom;
import com.example.shinobicore.entity.NinjaProjectileEntity;
import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;
public class BladeProjectileBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data, JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float speed = params.has("speed") ? params.get("speed").getAsFloat() : 2.5f;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 2.0f;
        Vec3d eye = player.getEyePos();
        Vec3d look = player.getRotationVector();
        NinjaProjectileEntity proj = new NinjaProjectileEntity(world, player, look.multiply(speed), damage, radius, "wind", "blade", 80);
        proj.setPosition(eye.x, eye.y, eye.z);
        proj.setPierceCount(10);
        proj.setBounceCount(2);
        world.spawnEntity(proj);
        TickScheduler.schedule(world, 30, 30, 1, w -> {
            if (!proj.isRemoved()) {
                Vec3d toPlayer = player.getPos().add(0, 1, 0).subtract(proj.getPos()).normalize();
                proj.setVelocity(toPlayer.multiply(speed * 1.2));
                proj.velocityDirty = true;
            }
        });
    }
}
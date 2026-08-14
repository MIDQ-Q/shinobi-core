package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.ElementType;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.EntityType;
import net.minecraft.entity.LightningEntity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;

public class KirinBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        boolean rain = world.isRaining();
        boolean fire = data.isNatureUnlocked(ElementType.FIRE);
        if (!rain && !fire) {
            player.sendMessage(Text.literal("\u00a7cKirin requires rain or an unlocked Fire nature!"), false);
            return;
        }
        float range = params.has("range") ? params.get("range").getAsFloat() : 16f;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 6f;
        int bolts = params.has("bolts") ? params.get("bolts").getAsInt() : 5;
        Vec3d center = player.getPos().add(player.getRotationVector().multiply(range));
        for (int i = 0; i < bolts; i++) {
            double ox = (Math.random() - 0.5) * radius;
            double oz = (Math.random() - 0.5) * radius;
            LightningEntity bolt = EntityType.LIGHTNING_BOLT.create(world);
            if (bolt != null) {
                bolt.setPosition(center.x + ox, world.getTopY(), center.z + oz);
                world.spawnEntity(bolt);
            }
        }
        for (Entity entity : world.getOtherEntities(player, new Box(center, center).expand(radius))) {
            if (entity instanceof LivingEntity living && !living.equals(player)) {
                living.damage(player.getDamageSources().magic(), damage);
            }
        }
        JutsuLogger.logBehavior("kirin", "player=" + player.getName().getString() + " bolts=" + bolts);
    }
}
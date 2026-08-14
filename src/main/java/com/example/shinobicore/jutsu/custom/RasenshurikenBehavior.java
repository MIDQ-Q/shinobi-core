package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.entity.NinjaProjectileEntity;
import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;
import net.minecraft.text.Text;
import net.minecraft.util.math.Vec3d;

public class RasenshurikenBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 8f;
        int chargeTicks = params.has("chargeTicks") ? params.get("chargeTicks").getAsInt() : 60;
        
        player.sendMessage(Text.literal("\u00a7bRasenshuriken charging..."), true);
        world.playSound(null, player.getBlockPos(), SoundEvents.BLOCK_BEACON_AMBIENT, SoundCategory.PLAYERS, 2.0f, 1.5f);
        
        TickScheduler.schedule(world, 1, 2, chargeTicks / 2, w -> {
            Vec3d hand = player.getEyePos().add(player.getRotationVector().multiply(0.8)).add(0, -0.3, 0);
            w.spawnParticles(ParticleTypes.CLOUD, hand.x, hand.y, hand.z, 15, 0.3, 0.3, 0.3, 0.05);
            w.spawnParticles(ParticleTypes.END_ROD, hand.x, hand.y, hand.z, 5, 0.1, 0.1, 0.1, 0.02);
        });
        
        TickScheduler.schedule(world, chargeTicks + 1, chargeTicks + 1, 1, w -> {
            player.sendMessage(Text.literal("\u00a7aRASENSHURIKEN!"), true);
            world.playSound(null, player.getBlockPos(), SoundEvents.ENTITY_ENDER_DRAGON_GROWL, SoundCategory.PLAYERS, 2.0f, 1.2f);
            
            Vec3d eye = player.getEyePos();
            Vec3d look = player.getRotationVector();
            
            NinjaProjectileEntity proj = new NinjaProjectileEntity(
                world, player, look.multiply(2.5), damage, radius, "wind", "default", 80
            );
            proj.setPosition(eye.x + look.x, eye.y - 0.2, eye.z + look.z);
            proj.setHasGravity(false);
            proj.setPierceCount(20); // РџСЂРѕР±РёРІР°РµС‚ РІСЃС‘ РЅР°СЃРєРІРѕР·СЊ Рё РІР·СЂС‹РІР°РµС‚СЃСЏ РІ РєРѕРЅС†Рµ
            world.spawnEntity(proj);
        });
    }
}
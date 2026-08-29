package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.jutsu.WallRemovalTask;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.block.Blocks;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;
import net.minecraft.text.Text;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;
import java.util.ArrayList;
import java.util.List;

public class IceMirrorBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float range = params.has("range") ? params.get("range").getAsFloat() : 15f;
        int lifetime = params.has("lifetime") ? params.get("lifetime").getAsInt() : 200;

        Vec3d startPos = player.getPos();
        Vec3d endPos = startPos.add(player.getRotationVector().multiply(range));

        // Build portal A (around player)
        List<BlockPos> portalA = buildMirror(world, startPos);
        // Build portal B (at target)
        List<BlockPos> portalB = buildMirror(world, endPos);

        if (portalA.isEmpty() || portalB.isEmpty()) {
            player.sendMessage(Text.literal("\u00a7cCannot create ice mirror - no space"), false);
            return;
        }

        WallRemovalTask.schedule(world, portalA, lifetime);
        WallRemovalTask.schedule(world, portalB, lifetime);

        // Sound + particles
        world.playSound(null, BlockPos.ofFloored(startPos), SoundEvents.BLOCK_GLASS_BREAK, SoundCategory.PLAYERS, 1.5f, 0.8f);
        world.playSound(null, BlockPos.ofFloored(endPos), SoundEvents.BLOCK_GLASS_BREAK, SoundCategory.PLAYERS, 1.5f, 0.8f);

        for (int i = 0; i < 40; i++) {
            double a = (i / 40.0) * Math.PI * 2;
            world.spawnParticles(ParticleTypes.END_ROD,
                startPos.x + Math.cos(a) * 1.5, startPos.y + 1 + Math.random(), startPos.z + Math.sin(a) * 1.5,
                2, 0.1, 0.2, 0.1, 0.03);
            world.spawnParticles(ParticleTypes.END_ROD,
                endPos.x + Math.cos(a) * 1.5, endPos.y + 1 + Math.random(), endPos.z + Math.sin(a) * 1.5,
                2, 0.1, 0.2, 0.1, 0.03);
        }

        // Teleport player to target portal
        player.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOW_FALLING, 60, 0, false, false));
        player.teleport(endPos.x, endPos.y, endPos.z);
        player.sendMessage(Text.literal("\u00a7b*Ice Mirror Teleport*"), true);

        JutsuLogger.logBehavior("ice_mirror", "range=" + range);
    }

    private List<BlockPos> buildMirror(ServerWorld world, Vec3d center) {
        BlockPos c = BlockPos.ofFloored(center);
        List<BlockPos> placed = new ArrayList<>();
        // Mirror frame: 3x3 ring of ICE + PACKED_ICE center
        int[][] offsets = {
            {-1, 0, -1}, {0, 0, -1}, {1, 0, -1},
            {-1, 0, 0},              {1, 0, 0},
            {-1, 0, 1},  {0, 0, 1},  {1, 0, 1},
            {0, 1, -1}, {0, 2, -1},
            {0, 1, 1},  {0, 2, 1},
            {-1, 1, 0}, {-1, 2, 0},
            {1, 1, 0},  {1, 2, 0},
            {0, 3, 0}
        };
        for (int[] off : offsets) {
            BlockPos p = c.add(off[0], off[1], off[2]);
            if (world.getBlockState(p).isAir()) {
                world.setBlockState(p, Blocks.PACKED_ICE.getDefaultState(), 3);
                placed.add(p);
            }
        }
        return placed;
    }
}
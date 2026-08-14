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

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Substitution Jutsu (Kawarimi).
 *
 * FIX (Phase G2.5): cooldown used to be a single static long shared by ALL players.
 * In multiplayer, one player's cast put the jutsu on cooldown for everyone.
 * Cooldown is now stored per-player UUID.
 */
public class SubstitutionBehavior implements JutsuBehavior {

    private static final Map<UUID, Long> LAST_USE_MS = new HashMap<>();
    private static final long COOLDOWN_MS = 10000;

    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;

        long now = System.currentTimeMillis();

        // Cheap cleanup of stale entries
        LAST_USE_MS.entrySet().removeIf(e -> now - e.getValue() > COOLDOWN_MS * 6);

        long last = LAST_USE_MS.getOrDefault(player.getUuid(), 0L);
        long since = now - last;
        if (since < COOLDOWN_MS) {
            player.sendMessage(Text.literal("\u00a7cSubstitution on cooldown: " + ((COOLDOWN_MS - since) / 1000) + "s"), false);
            return;
        }
        LAST_USE_MS.put(player.getUuid(), now);

        float teleportDistance = params.has("distance") ? params.get("distance").getAsFloat() : 8f;
        int invisDuration = params.has("invisDuration") ? params.get("invisDuration").getAsInt() : 40;

        Vec3d oldPos = player.getPos();
        Vec3d dir = player.getRotationVector().multiply(-1).normalize();
        Vec3d newPos = oldPos.add(dir.multiply(teleportDistance));

        // Particles at old position
        for (int i = 0; i < 30; i++) {
            world.spawnParticles(ParticleTypes.SMOKE,
                    oldPos.x + (Math.random() - 0.5) * 1.5, oldPos.y + Math.random() * 1.8, oldPos.z + (Math.random() - 0.5) * 1.5,
                    1, 0.1, 0.1, 0.1, 0.05);
            world.spawnParticles(ParticleTypes.LARGE_SMOKE,
                    oldPos.x + (Math.random() - 0.5) * 1.0, oldPos.y + Math.random() * 1.5, oldPos.z + (Math.random() - 0.5) * 1.0,
                    1, 0.05, 0.05, 0.05, 0.02);
        }

        // Place log at old position
        BlockPos logPos = BlockPos.ofFloored(oldPos);
        if (world.getBlockState(logPos).isAir()) {
            world.setBlockState(logPos, Blocks.OAK_LOG.getDefaultState(), 3);
            WallRemovalTask.schedule(world, List.of(logPos), 60);
        }

        world.playSound(null, BlockPos.ofFloored(oldPos), SoundEvents.ENTITY_ENDERMAN_TELEPORT, SoundCategory.PLAYERS, 1.0f, 1.0f);

        player.teleport(newPos.x, newPos.y, newPos.z);
        player.addStatusEffect(new StatusEffectInstance(StatusEffects.INVISIBILITY, invisDuration, 0, false, false));
        player.addStatusEffect(new StatusEffectInstance(StatusEffects.SPEED, invisDuration, 2, false, false));
        player.sendMessage(Text.literal("\u00a77*Substitution!*"), true);

        JutsuLogger.logBehavior("substitution", "player=" + player.getName().getString() + " dist=" + teleportDistance);
    }
}
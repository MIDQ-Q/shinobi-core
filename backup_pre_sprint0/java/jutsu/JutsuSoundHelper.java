package com.example.shinobicore.jutsu;

import com.example.shinobicore.stat.ElementType;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;
import net.minecraft.util.math.BlockPos;

public class JutsuSoundHelper {
    public static void playCastSound(ServerPlayerEntity player, JutsuDefinition def) {
        ServerWorld world = (ServerWorld) player.getWorld();
        BlockPos pos = player.getBlockPos();

        if (def.hasNature()) {
            playNatureCastSound(world, pos, def.nature(), def.baseDamage());
            return;
        }

        String type = def.type();
        String category = def.category();

        if (def.id().contains("rasengan")) {
            world.playSound(null, pos, SoundEvents.BLOCK_BEACON_POWER_SELECT, SoundCategory.PLAYERS, 1.5f, 0.8f);
        } else if (def.id().contains("rasenshuriken")) {
            world.playSound(null, pos, SoundEvents.ENTITY_ENDER_DRAGON_GROWL, SoundCategory.PLAYERS, 2.0f, 1.2f);
        } else if ("dash".equals(type) || "shunshin".equals(type)) {
            world.playSound(null, pos, SoundEvents.ENTITY_ENDERMAN_TELEPORT, SoundCategory.PLAYERS, 0.8f, 1.5f);
        } else if ("genjutsu".equals(category)) {
            world.playSound(null, pos, SoundEvents.ENTITY_WITCH_AMBIENT, SoundCategory.PLAYERS, 0.8f, 0.5f);
        } else if ("medical".equals(category)) {
            world.playSound(null, pos, SoundEvents.ENTITY_EXPERIENCE_ORB_PICKUP, SoundCategory.PLAYERS, 0.8f, 1.5f);
        } else if ("melee".equals(type)) {
            world.playSound(null, pos, SoundEvents.ENTITY_PLAYER_ATTACK_STRONG, SoundCategory.PLAYERS, 1.0f, 0.9f);
        } else {
            world.playSound(null, pos, SoundEvents.ENTITY_PLAYER_ATTACK_SWEEP, SoundCategory.PLAYERS, 0.6f, 1.0f);
        }
    }

    private static void playNatureCastSound(ServerWorld world, BlockPos pos, ElementType nature, float damage) {
        float volume = Math.min(2.0f, 0.6f + damage * 0.03f);
        switch (nature) {
            case FIRE -> {
                world.playSound(null, pos, SoundEvents.ENTITY_BLAZE_SHOOT, SoundCategory.PLAYERS, volume, 0.8f);
                if (damage > 15) world.playSound(null, pos, SoundEvents.ITEM_FIRECHARGE_USE, SoundCategory.PLAYERS, volume * 0.5f, 0.6f);
            }
            case WATER -> {
                world.playSound(null, pos, SoundEvents.ENTITY_DOLPHIN_SPLASH, SoundCategory.PLAYERS, volume, 0.9f);
                if (damage > 12) world.playSound(null, pos, SoundEvents.ENTITY_PLAYER_SPLASH_HIGH_SPEED, SoundCategory.PLAYERS, volume * 0.4f, 0.7f);
            }
            case WIND -> {
                world.playSound(null, pos, SoundEvents.ENTITY_PLAYER_ATTACK_SWEEP, SoundCategory.PLAYERS, volume, 0.7f);
                if (damage > 12) world.playSound(null, pos, SoundEvents.ENTITY_PHANTOM_FLAP, SoundCategory.PLAYERS, volume * 0.3f, 0.5f);
            }
            case LIGHTNING -> {
                world.playSound(null, pos, SoundEvents.ENTITY_LIGHTNING_BOLT_IMPACT, SoundCategory.PLAYERS, volume * 0.6f, 1.3f);
                if (damage > 15) world.playSound(null, pos, SoundEvents.BLOCK_BEEHIVE_WORK, SoundCategory.PLAYERS, volume * 0.4f, 2.0f);
            }
            case EARTH -> {
                world.playSound(null, pos, SoundEvents.BLOCK_STONE_BREAK, SoundCategory.PLAYERS, volume, 0.6f);
                if (damage > 10) world.playSound(null, pos, SoundEvents.BLOCK_GRAVEL_BREAK, SoundCategory.PLAYERS, volume * 0.5f, 0.5f);
            }
        }
    }

    public static void playChargeStartSound(ServerPlayerEntity player, JutsuDefinition def) {
        ServerWorld world = (ServerWorld) player.getWorld();
        BlockPos pos = player.getBlockPos();
        if (def.id().contains("rasengan")) {
            world.playSound(null, pos, SoundEvents.BLOCK_BEACON_AMBIENT, SoundCategory.PLAYERS, 0.5f, 0.8f);
        } else if (def.id().contains("rasenshuriken")) {
            world.playSound(null, pos, SoundEvents.BLOCK_BEACON_AMBIENT, SoundCategory.PLAYERS, 0.8f, 0.6f);
            world.playSound(null, pos, SoundEvents.ENTITY_PLAYER_ATTACK_SWEEP, SoundCategory.PLAYERS, 0.3f, 0.4f);
        } else {
            world.playSound(null, pos, SoundEvents.BLOCK_PORTAL_AMBIENT, SoundCategory.PLAYERS, 0.3f, 0.8f);
        }
    }

    public static void playChargeReadySound(ServerPlayerEntity player, JutsuDefinition def) {
        ServerWorld world = (ServerWorld) player.getWorld();
        BlockPos pos = player.getBlockPos();
        if (def.id().contains("rasengan")) {
            world.playSound(null, pos, SoundEvents.BLOCK_BEACON_POWER_SELECT, SoundCategory.PLAYERS, 1.5f, 1.2f);
        } else if (def.id().contains("rasenshuriken")) {
            world.playSound(null, pos, SoundEvents.ENTITY_ENDER_DRAGON_GROWL, SoundCategory.PLAYERS, 1.5f, 1.0f);
        } else {
            world.playSound(null, pos, SoundEvents.ENTITY_EXPERIENCE_ORB_PICKUP, SoundCategory.PLAYERS, 1.0f, 0.5f);
        }
    }

    public static void playRasenganStrikeSound(ServerPlayerEntity player) {
        ServerWorld world = (ServerWorld) player.getWorld();
        BlockPos pos = player.getBlockPos();
        world.playSound(null, pos, SoundEvents.ENTITY_GENERIC_EXPLODE, SoundCategory.PLAYERS, 1.5f, 1.2f);
        world.playSound(null, pos, SoundEvents.ENTITY_PLAYER_ATTACK_CRIT, SoundCategory.PLAYERS, 1.0f, 0.6f);
    }

    public static void playRasenshurikenThrowSound(ServerPlayerEntity player) {
        ServerWorld world = (ServerWorld) player.getWorld();
        BlockPos pos = player.getBlockPos();
        world.playSound(null, pos, SoundEvents.ENTITY_ENDER_DRAGON_GROWL, SoundCategory.PLAYERS, 2.0f, 1.2f);
        world.playSound(null, pos, SoundEvents.ENTITY_PLAYER_ATTACK_SWEEP, SoundCategory.PLAYERS, 1.0f, 0.5f);
    }

    public static void playSubstitutionSound(ServerPlayerEntity player) {
        ServerWorld world = (ServerWorld) player.getWorld();
        BlockPos pos = player.getBlockPos();
        world.playSound(null, pos, SoundEvents.ENTITY_ENDERMAN_TELEPORT, SoundCategory.PLAYERS, 1.0f, 1.0f);
        world.playSound(null, pos, SoundEvents.ENTITY_GENERIC_EXTINGUISH_FIRE, SoundCategory.PLAYERS, 0.5f, 1.5f);
    }

    public static void playKatanaDeflectSound(ServerPlayerEntity player) {
        ServerWorld world = (ServerWorld) player.getWorld();
        BlockPos pos = player.getBlockPos();
        world.playSound(null, pos, SoundEvents.ITEM_SHIELD_BLOCK, SoundCategory.PLAYERS, 0.8f, 1.5f);
        world.playSound(null, pos, SoundEvents.BLOCK_ANVIL_LAND, SoundCategory.PLAYERS, 0.3f, 2.0f);
    }
}
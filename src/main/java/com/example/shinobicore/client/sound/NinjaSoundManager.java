package com.example.shinobicore.client.sound;

import com.example.shinobicore.ShinobiCore;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvent;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.World;

/**
 * S5-06: Central sound manager for all ninja-related sounds.
 * Categories: cast, charge, shot, hit, explosion, element loops,
 * clone dispersion, kawarimi, enemy telegraphs.
 * Uses pitch variation for uniqueness without separate audio files.
 */
public class NinjaSoundManager {

    public enum SoundType {
        CAST, CHARGE, SHOT, HIT, EXPLOSION, LOOP, DISPERSE, KAWARIMI, TELEGRAPH
    }

    // Sound events (defined in sounds.json)
    public static final SoundEvent CAST_START = SoundEvent.of(new Identifier("shinobicore", "cast_start"));
    public static final SoundEvent CAST_COMPLETE = SoundEvent.of(new Identifier("shinobicore", "cast_complete"));
    public static final SoundEvent CHARGE_LOOP = SoundEvent.of(new Identifier("shinobicore", "charge_loop"));
    public static final SoundEvent CHARGE_READY = SoundEvent.of(new Identifier("shinobicore", "charge_ready"));
    public static final SoundEvent SHOT_FIRE = SoundEvent.of(new Identifier("shinobicore", "shot_fire"));
    public static final SoundEvent SHOT_WATER = SoundEvent.of(new Identifier("shinobicore", "shot_water"));
    public static final SoundEvent SHOT_WIND = SoundEvent.of(new Identifier("shinobicore", "shot_wind"));
    public static final SoundEvent SHOT_LIGHTNING = SoundEvent.of(new Identifier("shinobicore", "shot_lightning"));
    public static final SoundEvent SHOT_EARTH = SoundEvent.of(new Identifier("shinobicore", "shot_earth"));
    public static final SoundEvent HIT_IMPACT = SoundEvent.of(new Identifier("shinobicore", "hit_impact"));
    public static final SoundEvent EXPLOSION_SMALL = SoundEvent.of(new Identifier("shinobicore", "explosion_small"));
    public static final SoundEvent EXPLOSION_LARGE = SoundEvent.of(new Identifier("shinobicore", "explosion_large"));
    public static final SoundEvent CLONE_DISPERSE = SoundEvent.of(new Identifier("shinobicore", "clone_disperse"));
    public static final SoundEvent KAWARIMI = SoundEvent.of(new Identifier("shinobicore", "kawarimi"));
    public static final SoundEvent TELEGRAPH_MELEE = SoundEvent.of(new Identifier("shinobicore", "telegraph_melee"));
    public static final SoundEvent TELEGRAPH_RANGED = SoundEvent.of(new Identifier("shinobicore", "telegraph_ranged"));

    /**
     * Play sound with pitch variation for uniqueness.
     */
    public static void play(ClientPlayerEntity player, SoundEvent sound,
                            SoundType type, float volume, float basePitch) {
        if (player == null) return;
        float pitch = basePitch + getVariation(type);
        try {
            player.playSound(sound, getCategory(type), volume, pitch);
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("[SOUND] Play failed: {}", e.getMessage());
        }
    }

    /**
     * Play sound at world position with distance attenuation.
     */
    public static void playAt(World world, Vec3d pos, SoundEvent sound,
                              SoundType type, float volume, float basePitch) {
        float pitch = basePitch + getVariation(type);
        try {
            world.playSound(null, pos.x, pos.y, pos.z, sound, getCategory(type), volume, pitch);
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("[SOUND] Positioned play failed: {}", e.getMessage());
        }
    }

    /**
     * Get element-specific shot sound.
     */
    public static SoundEvent getElementShot(String element) {
        if (element == null) return SHOT_FIRE;
        return switch (element) {
            case "water" -> SHOT_WATER;
            case "wind" -> SHOT_WIND;
            case "lightning" -> SHOT_LIGHTNING;
            case "earth" -> SHOT_EARTH;
            default -> SHOT_FIRE;
        };
    }

    private static float getVariation(SoundType type) {
        float r = (float) Math.random();
        return switch (type) {
            case CAST -> (r - 0.5f) * 0.2f;
            case CHARGE -> (r - 0.5f) * 0.1f;
            case SHOT -> (r - 0.5f) * 0.3f;
            case HIT -> (r - 0.5f) * 0.4f;
            case EXPLOSION -> (r - 0.5f) * 0.15f;
            case LOOP -> 0f;
            case DISPERSE -> (r - 0.5f) * 0.3f;
            case KAWARIMI -> (r - 0.5f) * 0.2f;
            case TELEGRAPH -> (r - 0.5f) * 0.25f;
        };
    }

    private static SoundCategory getCategory(SoundType type) {
        return switch (type) {
            case TELEGRAPH -> SoundCategory.HOSTILE;
            case LOOP -> SoundCategory.AMBIENT;
            default -> SoundCategory.PLAYERS;
        };
    }
}
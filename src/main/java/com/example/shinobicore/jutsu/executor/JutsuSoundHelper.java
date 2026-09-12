package com.example.shinobicore.jutsu.executor;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.jutsu.core.JutsuDefinition;
import com.example.shinobicore.jutsu.core.SoundDefinition;
import com.example.shinobicore.jutsu.enums.ElementType;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvent;
import net.minecraft.sound.SoundEvents;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.Vec3d;

public class JutsuSoundHelper {
    public static void playCastSound(LivingEntity caster, JutsuDefinition jutsu) {
        play(caster.getWorld(), caster.getPos(), resolve(jutsu, "cast"), SoundCategory.PLAYERS, 1.0f, 1.0f);
    }
    public static void playImpactSound(ServerWorld world, Vec3d pos, JutsuDefinition jutsu) {
        play(world, pos, resolve(jutsu, "hit"), SoundCategory.PLAYERS, 1.0f, 1.0f);
    }
    private static SoundEvent resolve(JutsuDefinition j, String phase) {
        // Part 3 (WS-4): если у техники задано поле "sound", берём звук из него.
        // На момент применения ни один файл техники поля "sound" не содержит,
        // поэтому ветка является no-op и прежнее поведение сохранено полностью.
        SoundDefinition sd = j.getSound();
        if (sd != null) {
            String custom = null;
            if ("cast".equals(phase))      custom = sd.getCast();
            else if ("hit".equals(phase))  custom = sd.getHit();
            else if ("loop".equals(phase)) custom = sd.getLoop();
            else if ("end".equals(phase))  custom = sd.getEnd();
            if (custom != null && !custom.isEmpty()) {
                Identifier cid = Identifier.tryParse(custom);
                if (cid != null) return SoundEvent.of(cid);
            }
        }
        ElementType el = j.getElement();
        SoundEvent base = SoundEvents.ENTITY_PLAYER_ATTACK_SWEEP;
        if (el != null) switch (el) {
            case FIRE -> base = SoundEvents.ITEM_FIRECHARGE_USE;
            case WATER -> base = SoundEvents.ENTITY_GENERIC_SPLASH;
            case LIGHTNING -> base = SoundEvents.ENTITY_LIGHTNING_BOLT_THUNDER;
            case EARTH -> base = SoundEvents.BLOCK_STONE_HIT;
            case WIND -> base = SoundEvents.ENTITY_PLAYER_ATTACK_SWEEP;
            default -> {}
        }
        return base;
    }
    private static void play(net.minecraft.world.World w, Vec3d p, SoundEvent e, SoundCategory c, float v, float pitch) {
        w.playSound(null, p.x, p.y, p.z, e, c, v, pitch);
    }
}
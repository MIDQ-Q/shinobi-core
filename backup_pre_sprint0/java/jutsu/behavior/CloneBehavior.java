package com.example.shinobicore.jutsu.behavior;
import com.example.shinobicore.progression.JutsuCastNotifier;

import com.example.shinobicore.entity.CloneEntity;
import com.example.shinobicore.entity.ModEntities;
import com.example.shinobicore.jutsu.data.JutsuDefinition;
import com.google.gson.JsonObject;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;

/**
 * Summons a static shadow clone decoy next to the caster.
 * HLD: Blueprint (static decoy clones)
 */
public class CloneBehavior implements JutsuBehavior {

    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, JsonObject params, float damage) {
        JutsuCastNotifier.fire(player, "clone", "chakraControl");

        if (!(player.getWorld() instanceof ServerWorld world)) return;

        Vec3d look = player.getRotationVector();
        Vec3d spawn = player.getPos().add(look.x * 1.5, 0.0, look.z * 1.5);

        CloneEntity clone = ModEntities.CLONE.create(world);
        if (clone == null) return;

        clone.setPosition(spawn.x, spawn.y, spawn.z);
        clone.setOwner(player.getUuid());
        world.spawnEntity(clone);
    }
}
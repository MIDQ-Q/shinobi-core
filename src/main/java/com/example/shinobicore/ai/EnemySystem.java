package com.example.shinobicore.ai;

import net.minecraft.entity.attribute.EntityAttributeModifier;
import net.minecraft.entity.attribute.EntityAttributes;
import net.minecraft.entity.mob.MobEntity;

import java.util.UUID;

public class EnemySystem {

    /**
     * Balance (level 1 = dangerous but fair, level 15 = elite):
     *  HP:        20 * (1 + level * 0.15) -> 23 / 50 / 65
     *  speed:     +1%/lvl (cap 1.25)
     *  dodge:     5% + 2.5%/lvl (cap 40%)
     *  melee:     2 + 0.5/lvl
     *  jutsu:     45% + 4%/lvl (cap 120%)
     */
    public static void register(MobEntity mob, int level) {
        AiBrain b = new AiBrain(mob, null);
        b.behavior = "enemy";
        b.level = level;
        b.home = mob.getPos();
        b.speedMult = Math.min(1.25f, 1.0f + level * 0.01f);
        b.dodgeChance = Math.min(0.40f, 0.05f + level * 0.025f);
        b.meleeDamage = 2f + level * 0.5f;
        b.castScale = Math.min(1.20f, 0.45f + level * 0.04f);
        b.personality = mob.getRandom().nextBoolean() ? 0 : 1;
        b.jutsus.add("shinobicore:fire_release_great_fireball");
        AiSystem.add(b);

        // Level-scaled HP modifier: +15% per level
        double hpMult = 1.0 + level * 0.15;
        EntityAttributeModifier hpMod = new EntityAttributeModifier(
                UUID.fromString("a1b2c3d4-e5f6-7890-abcd-ef1234567890"),
                "Ninja level HP",
                hpMult - 1.0,
                EntityAttributeModifier.Operation.MULTIPLY_BASE);
        var hpAttr = mob.getAttributeInstance(EntityAttributes.GENERIC_MAX_HEALTH);
        if (hpAttr != null) {
            hpAttr.removeModifier(hpMod.getId());
            hpAttr.addTemporaryModifier(hpMod);
            mob.setHealth(mob.getMaxHealth()); // fill to new max
        }

        // Level-scaled speed modifier: +1% per level (stacks with speedMult at runtime)
        double speedMult = Math.min(1.25, 1.0 + level * 0.01);
        EntityAttributeModifier spMod = new EntityAttributeModifier(
                UUID.fromString("b2c3d4e5-f6a7-8901-bcde-f12345678901"),
                "Ninja level speed",
                speedMult - 1.0,
                EntityAttributeModifier.Operation.MULTIPLY_BASE);
        var spAttr = mob.getAttributeInstance(EntityAttributes.GENERIC_MOVEMENT_SPEED);
        if (spAttr != null) {
            spAttr.removeModifier(spMod.getId());
            spAttr.addTemporaryModifier(spMod);
        }
    }
}
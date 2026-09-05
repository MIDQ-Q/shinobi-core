package com.example.shinobicore.jutsu.executor;

import com.example.shinobicore.jutsu.core.JutsuDefinition;
import net.minecraft.entity.LivingEntity;
import net.minecraft.util.Hand;

public class JutsuAnimationHelper {
    public static void playCastAnimation(LivingEntity caster, JutsuDefinition jutsu) {
        if (caster == null) return;
        caster.swingHand(Hand.MAIN_HAND, true);
    }
}
package com.example.shinobicore.ai;

import net.minecraft.entity.EntityType;
import net.minecraft.entity.ai.goal.GoalSelector;
import net.minecraft.entity.passive.WolfEntity;
import net.minecraft.world.World;

import java.util.Collection;
import java.util.Map;

public class SummonCloneEntity extends WolfEntity {

    public SummonCloneEntity(EntityType<? extends WolfEntity> entityType, World world) {
        super(entityType, world);
        clearGoals(this.goalSelector);
        clearGoals(this.targetSelector);
        this.setPersistent();
    }

    /**
     * GoalSelector in 1.20.1 has no no-arg clear(); wipe the internal
     * goal collection reflectively so the FSM has full control.
     */
    private static void clearGoals(GoalSelector selector) {
        if (selector == null) return;
        for (String fieldName : new String[]{"goals", "tasks"}) {
            try {
                java.lang.reflect.Field f = GoalSelector.class.getDeclaredField(fieldName);
                f.setAccessible(true);
                Object v = f.get(selector);
                if (v instanceof Collection<?> col) { col.clear(); return; }
                if (v instanceof Map<?, ?> map) { map.clear(); return; }
            } catch (NoSuchFieldException ignored) {
            } catch (Throwable ignored) { }
        }
    }
}
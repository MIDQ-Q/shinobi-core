package com.example.shinobicore.modules.combat.component;

import dev.onyxstudios.cca.api.v3.component.ComponentKey;
import dev.onyxstudios.cca.api.v3.component.ComponentRegistry;
import dev.onyxstudios.cca.api.v3.entity.EntityComponentFactoryRegistry;
import dev.onyxstudios.cca.api.v3.entity.EntityComponentInitializer;
import dev.onyxstudios.cca.api.v3.entity.RespawnCopyStrategy;
import net.minecraft.util.Identifier;

public final class CombatComponentKey implements EntityComponentInitializer {
    public static final Identifier ID = new Identifier("shinobicore", "combat");
    public static final ComponentKey<CombatComponent> KEY = 
            ComponentRegistry.getOrCreate(ID, CombatComponent.class);

    @Override
    public void registerEntityComponentFactories(EntityComponentFactoryRegistry registry) {
        registry.registerForPlayers(KEY, player -> new CombatComponentImpl(), RespawnCopyStrategy.ALWAYS_COPY);
    }

    public static void register() {
        // Static initialization triggers registry
    }
}
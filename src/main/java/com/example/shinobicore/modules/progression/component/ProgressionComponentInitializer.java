package com.example.shinobicore.modules.progression.component;

import dev.onyxstudios.cca.api.v3.component.ComponentKey;
import dev.onyxstudios.cca.api.v3.component.ComponentRegistry;
import dev.onyxstudios.cca.api.v3.entity.EntityComponentFactoryRegistry;
import dev.onyxstudios.cca.api.v3.entity.EntityComponentInitializer;
import dev.onyxstudios.cca.api.v3.entity.RespawnCopyStrategy;
import net.minecraft.util.Identifier;

public class ProgressionComponentInitializer implements EntityComponentInitializer {
    public static final ComponentKey<ProgressionComponent> PROGRESSION = 
        ComponentRegistry.getOrCreate(new Identifier("shinobicore", "progression"), ProgressionComponent.class);

    @Override
    public void registerEntityComponentFactories(EntityComponentFactoryRegistry registry) {
        registry.registerForPlayers(PROGRESSION, player -> new ProgressionComponentImpl(), RespawnCopyStrategy.ALWAYS_COPY);
    }
}
package com.example.shinobicore.progression;

import dev.onyxstudios.cca.api.v3.component.ComponentKey;
import dev.onyxstudios.cca.api.v3.component.ComponentRegistry;
import dev.onyxstudios.cca.api.v3.entity.EntityComponentInitializer;
import dev.onyxstudios.cca.api.v3.entity.EntityComponentFactoryRegistry;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.util.Identifier;

/**
 * Cardinal Components entrypoint. Registers all ShinobiCore components.
 * Must be declared in fabric.mod.json under "entrypoints.cardinal-components".
 * HLD Section 10 (Progression System).
 */
public class ShinobiComponents implements EntityComponentInitializer {

    public static final ComponentKey<PlayerProgressionComponent> PROGRESSION =
        ComponentRegistry.getOrCreate(
            new Identifier("shinobicore", "progression"),
            PlayerProgressionComponent.class
        );

    @Override
    public void registerEntityComponentFactories(EntityComponentFactoryRegistry registry) {
        // Correct CCA 5.2.2 API: registerFor(Class, ComponentKey, Function)
        registry.registerFor(
            PlayerEntity.class,
            PROGRESSION,
            PlayerProgressionComponentImpl::new
        );
    }
}
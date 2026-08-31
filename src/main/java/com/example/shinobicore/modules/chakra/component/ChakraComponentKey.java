package com.example.shinobicore.modules.chakra.component;

import com.example.shinobicore.api.chakra.IChakraComponent;
import dev.onyxstudios.cca.api.v3.component.ComponentKey;
import dev.onyxstudios.cca.api.v3.component.ComponentRegistry;
import dev.onyxstudios.cca.api.v3.entity.EntityComponentFactoryRegistry;
import dev.onyxstudios.cca.api.v3.entity.EntityComponentInitializer;
import dev.onyxstudios.cca.api.v3.entity.RespawnCopyStrategy;
import net.minecraft.util.Identifier;

public final class ChakraComponentKey implements EntityComponentInitializer {
    public static final ComponentKey<IChakraComponent> KEY =
        ComponentRegistry.getOrCreate(
            new Identifier("shinobicore", "chakra"),
            IChakraComponent.class
        );

    public static IChakraComponent get(net.minecraft.entity.player.PlayerEntity player) {
        return KEY.getNullable(player);
    }

    @Override
    public void registerEntityComponentFactories(EntityComponentFactoryRegistry registry) {
        registry.registerForPlayers(KEY, p -> new ChakraComponentImpl(), RespawnCopyStrategy.ALWAYS_COPY);
    }
}
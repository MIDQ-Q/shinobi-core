package com.example.shinobicore.modules.clans.component;

import com.example.shinobicore.modules.clans.ClansModule;
import dev.onyxstudios.cca.api.v3.component.ComponentKey;
import dev.onyxstudios.cca.api.v3.component.ComponentRegistry;
import dev.onyxstudios.cca.api.v3.entity.EntityComponentFactoryRegistry;
import dev.onyxstudios.cca.api.v3.entity.EntityComponentInitializer;
import dev.onyxstudios.cca.api.v3.entity.RespawnCopyStrategy;
import net.minecraft.util.Identifier;

public final class ClanComponentInitializer implements EntityComponentInitializer {
    public static final ComponentKey<ClanComponent> CLAN = ComponentRegistry.getOrCreate(
        new Identifier("shinobicore", "clan"), ClanComponent.class
    );

    @Override
    public void registerEntityComponentFactories(EntityComponentFactoryRegistry registry) {
        registry.registerForPlayers(CLAN, player -> new ClanComponent(), RespawnCopyStrategy.ALWAYS_COPY);
    }
}
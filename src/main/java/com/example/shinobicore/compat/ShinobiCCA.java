package com.example.shinobicore.compat;
import dev.onyxstudios.cca.api.v3.entity.EntityComponentFactoryRegistry;
import dev.onyxstudios.cca.api.v3.entity.EntityComponentInitializer;
import dev.onyxstudios.cca.api.v3.entity.RespawnCopyStrategy;
import com.example.shinobicore.stealth.StealthComponent;
import com.example.shinobicore.stealth.StealthComponentImpl;
import com.example.shinobicore.faction.ReputationComponent;
import com.example.shinobicore.faction.ReputationComponentImpl;
public class ShinobiCCA implements EntityComponentInitializer {
    @Override
    public void registerEntityComponentFactories(EntityComponentFactoryRegistry registry) {
        registry.registerForPlayers(StealthComponent.KEY, player -> new StealthComponentImpl(), RespawnCopyStrategy.ALWAYS_COPY);
        registry.registerForPlayers(ReputationComponent.KEY, player -> new ReputationComponentImpl(), RespawnCopyStrategy.ALWAYS_COPY);
    }
}
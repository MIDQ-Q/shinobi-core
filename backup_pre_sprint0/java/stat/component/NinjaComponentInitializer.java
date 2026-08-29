package com.example.shinobicore.stat.component;

import com.example.shinobicore.stat.component.impl.ChakraComponentImpl;
import com.example.shinobicore.stat.component.impl.ClanComponentImpl;
import com.example.shinobicore.stat.component.impl.CombatComponentImpl;
import com.example.shinobicore.stat.component.impl.DojutsuComponentImpl;
import com.example.shinobicore.stat.component.impl.JutsuComponentImpl;
import com.example.shinobicore.stat.component.impl.StatsComponentImpl;
import dev.onyxstudios.cca.api.v3.entity.EntityComponentFactoryRegistry;
import dev.onyxstudios.cca.api.v3.entity.EntityComponentInitializer;
import dev.onyxstudios.cca.api.v3.entity.RespawnCopyStrategy;

/**
 * CCA entity component initializer.
 * Must be registered in fabric.mod.json entrypoints.
 * HLD: Section 1.1
 */
public class NinjaComponentInitializer implements EntityComponentInitializer {
    @Override
    public void registerEntityComponentFactories(EntityComponentFactoryRegistry registry) {
        registry.registerForPlayers(NinjaComponents.CHAKRA,
            player -> new ChakraComponentImpl(), RespawnCopyStrategy.ALWAYS_COPY);
        registry.registerForPlayers(NinjaComponents.STATS,
            player -> new StatsComponentImpl(), RespawnCopyStrategy.ALWAYS_COPY);
        registry.registerForPlayers(NinjaComponents.CLAN,
            player -> new ClanComponentImpl(), RespawnCopyStrategy.ALWAYS_COPY);
        registry.registerForPlayers(NinjaComponents.JUTSU,
            player -> new JutsuComponentImpl(), RespawnCopyStrategy.ALWAYS_COPY);
        registry.registerForPlayers(NinjaComponents.DOJUTSU,
            player -> new DojutsuComponentImpl(), RespawnCopyStrategy.ALWAYS_COPY);
        registry.registerForPlayers(NinjaComponents.PARKOUR,
                player -> new com.example.shinobicore.stat.component.impl.ParkourComponentImpl(), RespawnCopyStrategy.ALWAYS_COPY);
        registry.registerForPlayers(NinjaComponents.COMBAT,
            player -> new CombatComponentImpl(), RespawnCopyStrategy.ALWAYS_COPY);
    }
}
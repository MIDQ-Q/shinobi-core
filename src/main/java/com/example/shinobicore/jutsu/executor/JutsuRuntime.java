package com.example.shinobicore.jutsu.executor;

import com.example.shinobicore.ShinobiCore;
import net.fabricmc.fabric.api.entity.event.v1.ServerLivingEntityEvents;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.minecraft.server.network.ServerPlayerEntity;

public class JutsuRuntime {

    public static void register() {
        ServerTickEvents.END_SERVER_TICK.register(server -> {
            ProjectileSystem.tick(server);
            HandheldSystem.tick(server);
            DashSystem.tick(server);
            ZoneSystem.tick(server);
            StatusSystem.tick(server);
        });

        // HandheldSystem hook: called from LivingEntityDamageMixin or via manual integration
        // ServerLivingEntityEvents.AFTER_DAMAGE does not exist in Fabric API 1.20.1
        // The hook is invoked via LivingEntityDamageMixin -> HandheldSystem.onPlayerHit()

        ShinobiCore.LOGGER.info("[JutsuRuntime] v2 executors registered");
    }
}
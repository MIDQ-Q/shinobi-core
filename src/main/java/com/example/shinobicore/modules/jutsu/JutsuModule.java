package com.example.shinobicore.modules.jutsu;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.jutsu.executor.*;
import com.example.shinobicore.jutsu.loader.JutsuLoader;
import com.example.shinobicore.jutsu.registry.JutsuRegistry;
import com.example.shinobicore.modules.jutsu.cooldown.JutsuCooldownService;
import com.example.shinobicore.modules.jutsu.requirement.JutsuRequirementService;
import com.example.shinobicore.modules.jutsu.client.JutsuClientController;
import com.example.shinobicore.modules.jutsu.network.JutsuPackets;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;

/**
 * Sprint 6: Unified entry point for the Jutsu subsystem.
 * Wires together existing JutsuCaster, CooldownSystem, ActivationSystem
 * with new CooldownService, RequirementService, ClientController.
 */
public final class JutsuModule {
    public static final String ID = "jutsu";
    private static boolean initialized = false;

    private JutsuModule() {}

    public static void init() {
        if (initialized) return;
        initialized = true;

        JutsuCooldownService.init();
        JutsuRequirementService.init();
        JutsuPackets.registerServer();

        ServerTickEvents.END_SERVER_TICK.register(JutsuModule::serverTick);

        ShinobiCore.LOGGER.info("[JutsuModule] Initialized. {} jutsu loaded.", JutsuRegistry.size());
    }

    public static void initClient() {
        JutsuClientController.init();
        JutsuPackets.registerClient();
        ShinobiCore.LOGGER.info("[JutsuModule] Client initialized.");
    }

    private static void serverTick(MinecraftServer server) {
        JutsuCooldownService.tick();
        CooldownSystem.tick();
        ActivationSystem.tick(server);
        ProjectileSystem.tick(server);
        BeamSystem.tick(server);
        DashSystem.tick(server);
        ZoneSystem.tick(server);
        ConstructSystem.tick(server);
        HandheldSystem.tick(server);
        DelayedExplosionSystem.tick(server);
        StatusSystem.tick(server);
        TempBlockSystem.tick(server);
        StickSystem.tick(server);
        OrbitingSystem.tick(server);
        com.example.shinobicore.ai.AiSystem.tick(server);

        for (ServerPlayerEntity p : server.getPlayerManager().getPlayerList()) {
            com.example.shinobicore.combat.CastingServerState.tickPlayer(p);
        }
    }
}
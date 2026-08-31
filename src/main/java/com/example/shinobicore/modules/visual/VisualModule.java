package com.example.shinobicore.modules.visual;

import com.example.shinobicore.modules.visual.listener.*;

import com.example.shinobicore.core.view.CoreViews;

import com.example.shinobicore.core.event.CoreEvents;

import net.minecraft.client.MinecraftClient;

import net.fabricmc.fabric.api.client.rendering.v1.WorldRenderEvents;

import net.fabricmc.fabric.api.client.rendering.v1.HudRenderCallback;

import com.example.shinobicore.core.service.CoreServices;

import com.example.shinobicore.core.api.ChakraApi;



import com.example.shinobicore.core.api.ClientAwareModule;
import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.visual.aura.AuraRenderer;
import com.example.shinobicore.modules.visual.aura.AuraService;
import com.example.shinobicore.modules.visual.camera.CameraShakeService;
import com.example.shinobicore.modules.visual.command.VisualClientCommands;
import com.example.shinobicore.modules.visual.config.VisualConfig;
import com.example.shinobicore.modules.visual.culling.EffectCullingService;
import com.example.shinobicore.modules.visual.listener.CombatVisualListener;
import com.example.shinobicore.modules.visual.listener.EnemyVisualListener;
import com.example.shinobicore.modules.visual.listener.JutsuVisualListener;
import com.example.shinobicore.modules.visual.listener.MovementVisualListener;
import com.example.shinobicore.modules.visual.listener.ProgressionVisualListener;
import com.example.shinobicore.modules.visual.particle.ParticleService;
import com.example.shinobicore.modules.visual.pool.ParticlePool;
import com.example.shinobicore.modules.visual.pool.TrailPool;
import com.example.shinobicore.modules.visual.render.VisualRenderDispatcher;
import com.example.shinobicore.modules.visual.screen.ScreenFlashRenderer;
import com.example.shinobicore.modules.visual.screen.ScreenFlashService;
import com.example.shinobicore.modules.visual.stub.StubEvents;
import com.example.shinobicore.modules.visual.trail.TrailService;
import com.example.shinobicore.modules.visual.util.EffectRateLimiter;
import com.example.shinobicore.modules.visual.view.VisualViewConsumer;
import com.google.gson.JsonObject;
import com.mojang.brigadier.arguments.StringArgumentType;
import net.fabricmc.fabric.api.client.command.v2.ClientCommandManager;
import net.fabricmc.fabric.api.client.command.v2.ClientCommandRegistrationCallback;

public class VisualModule implements ClientAwareModule {
    public static final String ID = "visual";

    @Override public String id() { return ID; }

    @Override
    public void onEnable(ModuleContext ctx) {
        JsonObject rawConfig = ctx.configs().readModuleConfig(ID);
        VisualConfig.load(rawConfig);

        if (!VisualConfig.get().enabled) {
            ShinobiLogger.module(ID, "Visual module disabled by config.");
            return;
        }

        ParticlePool.init(VisualConfig.get().particles.poolSize);
        TrailPool.init(VisualConfig.get().trails.poolSize);

        ParticleService.init();
        TrailService.init();
        CameraShakeService.init();
        ScreenFlashService.init();
        AuraService.init();
        EffectCullingService.init(VisualConfig.get().culling.distance);
        EffectRateLimiter.init(VisualConfig.get().particles.cooldownMs);

        ShinobiLogger.module(ID, "Visual module enabled. Pools & Services initialized.");
    }

    @Override
    public void registerEvents(ModuleContext ctx) {
        // Jutsu events
        CoreEvents.subscribe(StubEvents.JutsuCastStartedEvent.class, JutsuVisualListener::onCastStarted);
        CoreEvents.subscribe(StubEvents.JutsuCastFinishedEvent.class, e -> {
            ScreenFlashService.flash(0xFF4499FF, 8);
        });

        // Combat events
        CoreEvents.subscribe(StubEvents.CombatHitEvent.class, CombatVisualListener::onHit);
        CoreEvents.subscribe(StubEvents.CombatBlockedEvent.class, e -> {
            ScreenFlashService.flash(0xFF4444FF, 4);
        });
        CoreEvents.subscribe(StubEvents.CombatParriedEvent.class, e -> {
            ScreenFlashService.flash(0xFFFFD700, 5);
        });

        // Movement events
        CoreEvents.subscribe(StubEvents.WaterWalkStartedEvent.class, MovementVisualListener::onWaterWalkStarted);
        CoreEvents.subscribe(StubEvents.WallRunStartedEvent.class, MovementVisualListener::onWallRunStarted);
        CoreEvents.subscribe(StubEvents.SlideStartedEvent.class, MovementVisualListener::onSlideStarted);
        CoreEvents.subscribe(StubEvents.RollStartedEvent.class, MovementVisualListener::onRollStarted);
        CoreEvents.subscribe(StubEvents.DodgeEvent.class, MovementVisualListener::onDodge);

        // Progression events
        CoreEvents.subscribe(StubEvents.LevelChangedEvent.class, ProgressionVisualListener::onLevelUp);
        CoreEvents.subscribe(StubEvents.XpGainedEvent.class, ProgressionVisualListener::onXpGained);

        // Chakra/Aura events
        CoreEvents.subscribe(StubEvents.ChakraModeEnabledEvent.class, AuraService::onChakraModeEnabled);
        CoreEvents.subscribe(StubEvents.ChakraModeDisabledEvent.class, AuraService::onChakraModeDisabled);

        // Enemy events
        CoreEvents.subscribe(StubEvents.EnemyStateChangedEvent.class, EnemyVisualListener::onEnemyStateChanged);
    }

    @Override
    public void onClientInit(ModuleContext ctx) {
        if (!VisualConfig.get().enabled) return;

        VisualRenderDispatcher.register();
        ScreenFlashRenderer.register();
        AuraRenderer.register();

        ClientCommandRegistrationCallback.EVENT.register((dispatcher, registryAccess) -> {
            dispatcher.register(ClientCommandManager.literal("shinobicore")
                .then(ClientCommandManager.literal("visual")
                    .then(ClientCommandManager.literal("test").executes(c -> {
                        VisualClientCommands.executeTest(c.getSource()); return 1;
                    }))
                    .then(ClientCommandManager.literal("info").executes(c -> {
                        VisualClientCommands.executeInfo(c.getSource()); return 1;
                    }))
                    .then(ClientCommandManager.literal("clear").executes(c -> {
                        VisualClientCommands.executeClear(c.getSource()); return 1;
                    }))
                    .then(ClientCommandManager.literal("debug").executes(c -> {
                        VisualClientCommands.executeDebug(c.getSource()); return 1;
                    }))
                    .then(ClientCommandManager.literal("flash").executes(c -> {
                        VisualClientCommands.executeFlash(c.getSource()); return 1;
                    }))
                    .then(ClientCommandManager.literal("aura").executes(c -> {
                        VisualClientCommands.executeAura(c.getSource()); return 1;
                    }))
                    .then(ClientCommandManager.literal("preset")
                        .then(ClientCommandManager.argument("name", StringArgumentType.word())
                            .executes(c -> {
                                VisualClientCommands.executePreset(c.getSource(), StringArgumentType.getString(c, "name"));
                                return 1;
                            })
                        )
                    )
                )
            );
        });

        ShinobiLogger.module(ID, "Visual renderers and client commands registered.");
    }

    @Override
    public void onClientTick(ModuleContext ctx) {
        if (!VisualConfig.get().enabled) return;

        VisualViewConsumer.pollViews();
        ParticleService.tick();
        TrailService.tick();
        CameraShakeService.tick();
        ScreenFlashService.tick();
        AuraService.tick();
        EffectRateLimiter.tick();

        // O(1) Particle cleanup
        for (int i = 0; i < ParticlePool.getActiveCount(); i++) {
            ParticlePool.PooledParticle p = ParticlePool.get(i);
            p.age++;
            // Apply velocity
            p.x += p.vx;
            p.y += p.vy;
            p.z += p.vz;
            p.vy -= 0.002f; // gravity
            if (p.isExpired()) {
                ParticlePool.releaseAt(i);
                i--;
            }
        }
    }
}
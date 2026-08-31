package com.example.shinobicore.modules.movement;


import com.example.shinobicore.core.view.CoreViews;

import com.example.shinobicore.core.api.ClientAwareModule;
import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.event.CoreEvents;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.movement.commands.MovementCommands;
import com.example.shinobicore.modules.movement.config.MovementConfig;
import com.example.shinobicore.modules.movement.network.MovementPackets;
import com.example.shinobicore.modules.movement.server.MovementServerMirror;
import com.example.shinobicore.modules.movement.view.MovementVisualView;
import com.example.shinobicore.modules.movement.view.MovementVisualViewImpl;
import com.example.shinobicore.modules.movement.client.ClientMovementController;
import com.example.shinobicore.modules.movement.client.input.MovementKeyBindings;
import com.mojang.brigadier.CommandDispatcher;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.command.ServerCommandSource;

public class MovementModule implements ClientAwareModule {
    public static final String ID = "movement";

    @Override public String id() { return ID; }

    @Override
    public void onEnable(ModuleContext ctx) {
        MovementConfig.load(ctx.configs().readModuleConfig(ID));
        MovementServerMirror.init();
        MovementPackets.registerServer();
        ShinobiLogger.module(ID, "Movement module enabled.");
    }

    @Override
    public void registerEvents(ModuleContext ctx) {
        CoreEvents events = new CoreEvents(); // Static singleton
        
        // Stop parkour if chakra mode is disabled globally
        CoreEvents.subscribe(com.example.shinobicore.core.event.ChakraModeDisabledEvent.class, e -> {
            MovementServerMirror.forceStopParkour(e.player());
        });

        // CRITICAL: Cleanup static maps on player leave/death to prevent memory leaks (TZ 11)
        CoreEvents.subscribe(com.example.shinobicore.core.event.PlayerLeaveEvent.class, e -> {
            MovementServerMirror.cleanupPlayer(e.player().getUuid());
        });
        
        CoreEvents.subscribe(com.example.shinobicore.core.event.PlayerDiedEvent.class, e -> {
            MovementServerMirror.cleanupPlayer(e.player().getUuid());
        });
    }

    @Override
    public void registerViews(ModuleContext ctx) {
        CoreViews.register(MovementVisualView.class, player -> 
            java.util.Optional.of(new MovementVisualViewImpl(player)));
    }

    @Override
    public void registerCommands(ModuleContext ctx, CommandDispatcher<ServerCommandSource> d) {
        MovementCommands.register(d);
    }

    @Override
    public void onClientInit(ModuleContext ctx) {
        MovementKeyBindings.register();
        ClientMovementController.init(new CoreEvents());
        MovementPackets.registerClient();
    }

    @Override
    public void onClientTick(ModuleContext ctx) {
        ClientMovementController.tick();
    }

    @Override
    public void onServerTick(ModuleContext ctx, MinecraftServer server) {
        MovementServerMirror.tick(server);
    }
}
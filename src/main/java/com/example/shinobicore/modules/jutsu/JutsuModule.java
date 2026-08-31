package com.example.shinobicore.modules.jutsu;

import com.example.shinobicore.core.event.CoreEvents;
import com.example.shinobicore.core.view.CoreViews;

import com.example.shinobicore.core.api.ClientAwareModule;
import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.core.service.CoreServices;
import com.example.shinobicore.modules.jutsu.behavior.BehaviorRegistry;
import com.example.shinobicore.modules.jutsu.cast.JutsuCastService;
import com.example.shinobicore.modules.jutsu.client.JutsuClientController;
import com.example.shinobicore.modules.jutsu.client.JutsuKeyBindings;
import com.example.shinobicore.modules.jutsu.command.JutsuCommands;
import com.example.shinobicore.modules.jutsu.config.JutsuConfig;
import com.example.shinobicore.modules.jutsu.cooldown.JutsuCooldownService;
import com.example.shinobicore.modules.jutsu.data.JutsuJsonValidator;
import com.example.shinobicore.modules.jutsu.data.JutsuLoader;
import com.example.shinobicore.modules.jutsu.data.JutsuRegistry;
import com.example.shinobicore.modules.jutsu.gateway.JutsuCastGatewayImpl;
import com.example.shinobicore.modules.jutsu.network.JutsuPackets;
import com.example.shinobicore.modules.jutsu.requirement.JutsuRequirementService;
import com.example.shinobicore.modules.jutsu.view.JutsuVisualView;
import com.example.shinobicore.modules.jutsu.view.JutsuVisualViewImpl;
import com.mojang.brigadier.CommandDispatcher;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.command.ServerCommandSource;

public class JutsuModule implements ClientAwareModule {
    public static final String ID = "jutsu";

    @Override public String id() { return ID; }

    @Override
    public void onRegister(ModuleContext ctx) {
        ShinobiLogger.module(ID, "Registering Jutsu components...");
    }

    @Override
    public void onEnable(ModuleContext ctx) {
        ShinobiLogger.module(ID, "Enabling Jutsu module...");
        
        // 1. Load Config
        JutsuConfig.load(ctx.configs().readModuleConfig(ID));
        ShinobiLogger.module(ID, "Config loaded. Slots: " + JutsuConfig.get().slotCount);

        // 2. Register Behaviors BEFORE loading definitions
        BehaviorRegistry.registerDefaults();
        
        // 3. Load & Validate JSON
        JutsuLoader.load();
        JutsuJsonValidator.validateAll(); 
        
        // 4. Register Gateway for AI
        CoreServices.register(JutsuCastGatewayImpl.class, new JutsuCastGatewayImpl());
        
        // 5. Init Services
        JutsuCooldownService.init();
        JutsuRequirementService.init();
        
        // 6. Register Network
        JutsuPackets.registerServer();
        
        ShinobiLogger.module(ID, "Loaded " + JutsuRegistry.size() + " jutsu definitions. Module fully operational.");
    }

    @Override
    public void registerViews(ModuleContext ctx) {
        CoreViews.register(JutsuVisualView.class, player -> {
            return java.util.Optional.of(new JutsuVisualViewImpl(player));
        });
        ShinobiLogger.module(ID, "JutsuVisualView registered for HUD/Visual modules.");
    }

    @Override
    public void registerEvents(ModuleContext ctx) {
        // Subscribe to core events for interrupts and cleanup
        // Note: If core events (PlayerDiedEvent, etc.) are not yet compiled in Sprint 1, 
        // this block will be commented out until Sprint 2 provides them.
        /*
        CoreEvents.subscribe(com.example.shinobicore.core.event.PlayerDiedEvent.class, e -> {
            JutsuCastService.instance().cancelAll(e.player());
            JutsuCooldownService.resetAll(e.player());
        });
        */
    }

    @Override
    public void onDisable(ModuleContext ctx) {
        ShinobiLogger.module(ID, "Jutsu module disabled.");
    }

    @Override
    public void registerCommands(ModuleContext ctx, CommandDispatcher<ServerCommandSource> dispatcher) {
        JutsuCommands.register(dispatcher);
    }

    @Override
    public void onServerTick(ModuleContext ctx, MinecraftServer server) {
        JutsuCastService.instance().serverTick(server);
        JutsuCooldownService.serverTick(server);
    }
    
    @Override
    public void onClientInit(ModuleContext ctx) {
        JutsuKeyBindings.register();
        JutsuClientController.init();
        JutsuPackets.registerClient();
    }

    @Override
    public void onClientTick(ModuleContext ctx) {
        JutsuClientController.tick();
    }
}
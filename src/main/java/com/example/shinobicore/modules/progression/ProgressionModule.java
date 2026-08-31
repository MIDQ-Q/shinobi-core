package com.example.shinobicore.modules.progression;

import com.example.shinobicore.modules.progression.event.*;

import com.example.shinobicore.core.view.CoreViews;

import com.example.shinobicore.core.event.CoreEvents;
import com.example.shinobicore.core.api.ClientAwareModule;
import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.progression.client.ProgressionKeyBindings;
import com.example.shinobicore.modules.progression.client.ProgressionInputHandler;
import com.example.shinobicore.modules.progression.commands.ProgressionCommands;
import com.example.shinobicore.modules.progression.component.ProgressionComponentKey;
import com.example.shinobicore.modules.progression.config.ProgressionConfig;
import com.example.shinobicore.modules.progression.data.ProgressionDataLoader;
import com.example.shinobicore.modules.progression.data.ProgressionJsonValidator;
import com.example.shinobicore.modules.progression.network.AttunementAttemptPacket;
import com.example.shinobicore.modules.progression.network.ProgressionActionPacket;
import com.example.shinobicore.modules.progression.network.ProgressionStateSyncPacket;
import com.example.shinobicore.modules.progression.service.AttunementService;
import com.example.shinobicore.modules.progression.service.BodyStatService;
import com.example.shinobicore.modules.progression.service.JutsuMasteryService;
import com.example.shinobicore.modules.progression.service.LevelService;
import com.example.shinobicore.modules.progression.service.ReputationService;
import com.example.shinobicore.modules.progression.service.SpService;
import com.example.shinobicore.modules.progression.service.StatService;
import com.example.shinobicore.modules.progression.service.XpSourceService;
import com.example.shinobicore.modules.progression.view.ProgressionVisualView;
import com.example.shinobicore.modules.progression.view.ProgressionVisualViewImpl;
import com.google.gson.JsonObject;
import com.mojang.brigadier.CommandDispatcher;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.command.ServerCommandSource;

import java.util.Optional;

public class ProgressionModule implements ClientAwareModule {
    public static final String ID = "progression";

    @Override public String id() { return ID; }

    @Override
    public void onRegister(ModuleContext ctx) {
        ProgressionComponentKey.register();
        ShinobiLogger.module(ID, "Progression component registered");
    }

    @Override
    public void onEnable(ModuleContext ctx) {
        JsonObject rawConfig = ctx.configs().readModuleConfig(ID);
        ProgressionConfig.get().load(rawConfig);

        ProgressionDataLoader.loadTree();
        ProgressionDataLoader.loadAttunement();
        ProgressionJsonValidator.validateTree();

        SpService.init(new CoreEvents());
        LevelService.init(new CoreEvents());
        StatService.init(new CoreEvents());
        BodyStatService.init(new CoreEvents());
        XpSourceService.init();
        JutsuMasteryService.init(new CoreEvents());
        AttunementService.init(new CoreEvents());
        ReputationService.init(new CoreEvents());

        ProgressionActionPacket.registerServer();
        AttunementAttemptPacket.registerServer();

        ShinobiLogger.module(ID, "Progression module enabled");
    }

    @Override
    public void registerViews(ModuleContext ctx) {
        CoreViews.register(ProgressionVisualView.class,
            player -> Optional.of(new ProgressionVisualViewImpl(player)));
    }

    @Override
    public void registerCommands(ModuleContext ctx, CommandDispatcher<ServerCommandSource> dispatcher) {
        ProgressionCommands.register(dispatcher);
    }

    @Override
    public void onClientInit(ModuleContext ctx) {
        ProgressionKeyBindings.register();
        ProgressionInputHandler.init();
        ProgressionStateSyncPacket.registerClient();
        ShinobiLogger.module(ID, "Progression client initialized");
    }

    @Override
    public void onServerTick(ModuleContext ctx, MinecraftServer server) {
    }
}
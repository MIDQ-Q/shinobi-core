package com.example.shinobicore.modules.clans;

import com.example.shinobicore.core.event.CoreEvents;
import com.example.shinobicore.core.view.CoreViews;
import com.example.shinobicore.core.api.ClientAwareModule;
import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.clans.client.ClansKeyBindings;
import com.example.shinobicore.modules.clans.component.ClanComponentKey;
import com.example.shinobicore.modules.clans.config.ClansConfig;
import com.example.shinobicore.modules.clans.data.ClanLoader;
import com.example.shinobicore.modules.clans.data.ClanJsonValidator;
import com.example.shinobicore.modules.clans.event.ClanChangedEvent;
import com.example.shinobicore.modules.clans.event.ClanJutsuLockedEvent;
import com.example.shinobicore.modules.clans.event.ClanJutsuUnlockedEvent;
import com.example.shinobicore.modules.clans.event.ClanSelectedEvent;
import com.example.shinobicore.modules.clans.event.DojutsuHookAppliedEvent;
import com.example.shinobicore.modules.clans.event.FormulaCalculationEvent;
import com.example.shinobicore.modules.clans.event.ReputationChangedEvent;
import com.example.shinobicore.core.event.PlayerJoinEvent;
import com.example.shinobicore.core.event.PlayerRespawnedEvent;
import com.example.shinobicore.core.event.PlayerChangedDimensionEvent;
import com.example.shinobicore.modules.clans.network.ClansPackets;
import com.example.shinobicore.modules.clans.service.*;
import com.example.shinobicore.modules.clans.view.ClanVisualView;
import com.example.shinobicore.modules.clans.view.ClanVisualViewImpl;
import com.mojang.brigadier.CommandDispatcher;
import net.minecraft.server.command.ServerCommandSource;
import java.util.Optional;
public class ClansModule implements ClientAwareModule {
    public static final String ID = "clans";
    @Override public String id() { return ID; }
    @Override public void onRegister(ModuleContext ctx) { ClanComponentKey.register(); }
    @Override
    public void onEnable(ModuleContext ctx) {
        ClansConfig.load(ctx.configs().readModuleConfig(ID));
        ShinobiLogger.module(ID, "Loading clan definitions...");
        ClanLoader.load();
        ClanJsonValidator.validateAll();
        ClanService.init(); ClanModifierService.init(); ClanJutsuGateService.init();
        ReputationService.init(); DojutsuHookService.init();
        ClansPackets.registerServer();
        ShinobiLogger.module(ID, "Clans module enabled. Loaded: " + ClanLoader.getLoadedCount() + " clans.");
    }
    @Override
    public void registerEvents(ModuleContext ctx) {
        CoreEvents.subscribe(FormulaCalculationEvent.class, ClanModifierService::applyModifiers);
        // Auto-sync on player lifecycle events (Sprint 2 core events)
        CoreEvents.subscribe(com.example.shinobicore.core.event.PlayerJoinEvent.class, e -> ClanService.syncToClient(e.player()));
        CoreEvents.subscribe(com.example.shinobicore.core.event.PlayerRespawnedEvent.class, e -> ClanService.syncToClient(e.player()));
        CoreEvents.subscribe(com.example.shinobicore.core.event.PlayerChangedDimensionEvent.class, e -> ClanService.syncToClient(e.player()));
        // Auto-unlock dojutsu when clan is set
        CoreEvents.subscribe(ClanSelectedEvent.class, e -> DojutsuHookService.applyHook(e.player(), e.clanId()));
    }
    @Override
    public void registerViews(ModuleContext ctx) {
        CoreViews.register(ClanVisualView.class, player -> Optional.of(new ClanVisualViewImpl(player)));
    }
    @Override
    public void registerCommands(ModuleContext ctx, CommandDispatcher<ServerCommandSource> dispatcher) {
        ClanCommands.register(dispatcher);
    }
    @Override
    public void onClientInit(ModuleContext ctx) {
        ClansKeyBindings.register();
        ClansPackets.registerClient();
    }
    @Override
    public void onClientTick(ModuleContext ctx) {
        // Future: Handle OPEN_CLAN_MENU key press here
    }
}
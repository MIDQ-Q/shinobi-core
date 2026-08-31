package com.example.shinobicore.modules.combat;

import com.example.shinobicore.core.event.CoreEvents;
import com.example.shinobicore.core.view.CoreViews;

import com.example.shinobicore.core.api.ClientAwareModule;
import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.event.*;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.core.module.ModuleManager;
import com.example.shinobicore.modules.combat.command.CombatCommands;
import com.example.shinobicore.modules.combat.compat.BetterCombatAdapter;
import com.example.shinobicore.modules.combat.compat.CombatCompatibilityChecker;
import com.example.shinobicore.modules.combat.compat.PlayerAnimatorAdapter;
import com.example.shinobicore.modules.combat.config.CombatConfig;
import com.example.shinobicore.modules.combat.component.CombatComponentKey;
import com.example.shinobicore.modules.combat.input.CombatInputHandler;
import com.example.shinobicore.modules.combat.input.CombatKeyBindings;
import com.example.shinobicore.modules.combat.network.CombatPackets;
import com.example.shinobicore.modules.combat.render.SheathFeatureRenderer;
import com.example.shinobicore.modules.combat.service.*;
import com.example.shinobicore.modules.combat.view.CombatVisualView;
import com.example.shinobicore.modules.combat.view.CombatVisualViewImpl;
import com.mojang.brigadier.CommandDispatcher;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.command.ServerCommandSource;

public class CombatModule implements ClientAwareModule {
    public static final String ID = "combat";

    @Override public String id() { return ID; }

    @Override
    public void onRegister(ModuleContext ctx) {
        CombatComponentKey.register();
        ShinobiLogger.module(ID, "Combat component key registered");
    }

    @Override
    public void onEnable(ModuleContext ctx) {
        if (!CombatCompatibilityChecker.isBetterCombatOk()) {
            ShinobiLogger.error(ID, "Better Combat is REQUIRED but not detected. Disabling module.", null);
            CoreEvents.publish(new ModuleDisabledEvent(ID, "Missing required mod: bettercombat"));
            ModuleManager.disable(ID, "Missing Better Combat");
            return;
        }

        CombatConfig.load(ctx.configs().readModuleConfig(ID));
        BetterCombatAdapter.init();
        PlayerAnimatorAdapter.init();
        
        StanceService.init(ctx);
        BlockService.init(ctx);
        ParryService.init(ctx);
        SheathService.init(ctx);
        ProjectileDeflectService.init(ctx);
        ComboTracker.init(ctx);
        DamageInterceptionService.init(ctx);
        ThrowableService.init(ctx);
        KickService.init(ctx);
        QuickWeaponSlotService.init(ctx);
        UnarmedCombatService.init(ctx);
        ImbueService.init(ctx);

        CombatPackets.registerServer();
        ShinobiLogger.module(ID, "Combat module enabled successfully");
    }

    @Override
    public void registerEvents(ModuleContext ctx) {
        CoreEvents.subscribe(com.example.shinobicore.core.event.PlayerDiedEvent.class, e -> {
            var comp = CombatComponentKey.KEY.getNullable(e.player());
            if (comp != null) {
                comp.setStance(com.example.shinobicore.modules.combat.common.Stance.NONE);
                comp.setBlocking(false);
                comp.setParrying(false);
                comp.resetCombo();
                comp.setSheathed(false);
            }
        });
        CoreEvents.subscribe(com.example.shinobicore.core.event.PlayerRespawnedEvent.class, e -> {
            // Reset to default handled by CCA RespawnCopyStrategy, but explicit reset is safe
        });
    }

    @Override
    public void registerViews(ModuleContext ctx) {
        CoreViews.register(CombatVisualView.class, player ->
            java.util.Optional.of(new CombatVisualViewImpl(player)));
    }

    @Override
    public void registerCommands(ModuleContext ctx, CommandDispatcher<ServerCommandSource> dispatcher) {
        CombatCommands.register(dispatcher);
    }

    @Override
    public void onClientInit(ModuleContext ctx) {
        CombatKeyBindings.register();
        CombatPackets.registerClient();
        // SheathFeatureRenderer already registered via callback
        ShinobiLogger.module(ID, "Combat client initialized");
    }

    @Override
    public void onClientTick(ModuleContext ctx) {
        CombatInputHandler.tick();
    }

    @Override
    public void onServerTick(ModuleContext ctx, MinecraftServer server) {
        BlockService.serverTick(server);
        ParryService.serverTick(server);
        ProjectileDeflectService.serverTick(server);
        ComboTracker.serverTick(server);
    }
}
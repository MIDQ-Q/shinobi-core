package com.example.shinobicore.modules.chakra;

import com.example.shinobicore.core.api.ClientAwareModule;
import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.core.service.CoreServices;
import com.example.shinobicore.api.chakra.ChakraApi;
import com.example.shinobicore.modules.chakra.component.ChakraComponentKey;
import com.example.shinobicore.modules.chakra.service.ChakraApiImpl;
import com.mojang.brigadier.CommandDispatcher;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;

public final class ChakraModule implements ClientAwareModule {
    public static final String ID = "chakra";

    @Override public String id() { return ID; }

    @Override
    public void onRegister(ModuleContext ctx) {
        ShinobiLogger.module(ID, "Chakra module registered");
    }

    @Override
    public void onEnable(ModuleContext ctx) {
        CoreServices.register(ChakraApi.class, new ChakraApiImpl());

        ServerTickEvents.END_SERVER_TICK.register(server -> {
            for (ServerPlayerEntity p : server.getPlayerManager().getPlayerList()) {
                var comp = ChakraComponentKey.get(p);
                if (comp == null) continue;
                if (comp.isChakraModeActive()) {
                    comp.trySpend(0.5);
                } else if (!comp.isExhausted()) {
                    comp.regenerate(1.0);
                }
            }
        });

        ShinobiLogger.module(ID, "Chakra module enabled. API registered.");
    }

    @Override
    public void registerCommands(ModuleContext ctx, CommandDispatcher<ServerCommandSource> d) {
        d.register(CommandManager.literal("shinobicore")
            .then(CommandManager.literal("chakra")
                .then(CommandManager.literal("toggle").executes(c -> {
                    var p = c.getSource().getPlayer();
                    if (p == null) return 0;
                    new ChakraApiImpl().toggleChakraMode(p);
                    var comp = ChakraComponentKey.get(p);
                    if (comp == null) return 0;
                    c.getSource().sendFeedback(
                        () -> Text.literal("[Chakra] Mode: " + (comp.isChakraModeActive() ? "ON" : "OFF")
                            + " | " + (int)comp.getCurrent() + "/" + (int)comp.getMax()),
                        false);
                    return 1;
                }))
                .then(CommandManager.literal("info").executes(c -> {
                    var p = c.getSource().getPlayer();
                    if (p == null) return 0;
                    var comp = ChakraComponentKey.get(p);
                    if (comp == null) return 0;
                    c.getSource().sendFeedback(
                        () -> Text.literal(String.format("[Chakra] %.0f/%.0f | Mode: %s | Exhausted: %s",
                            comp.getCurrent(), comp.getMax(),
                            comp.isChakraModeActive(), comp.isExhausted())),
                        false);
                    return 1;
                }))
                .then(CommandManager.literal("fill")
                    .requires(s -> s.hasPermissionLevel(2))
                    .executes(c -> {
                        var p = c.getSource().getPlayer();
                        if (p == null) return 0;
                        var comp = ChakraComponentKey.get(p);
                    if (comp == null) return 0;
                        comp.setCurrent(comp.getMax());
                        comp.setExhausted(false);
                        c.getSource().sendFeedback(
                            () -> Text.literal("[Chakra] Filled!"), false);
                        return 1;
                    }))
            )
        );
    }

    @Override
    public void onClientInit(ModuleContext ctx) {
        // Client init handled by ChakraClientModule
    }
}
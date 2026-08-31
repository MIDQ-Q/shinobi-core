package com.example.shinobicore;
import com.example.shinobicore.core.command.CoreCommands;
import com.example.shinobicore.core.compat.CompatibilityChecker;
import com.example.shinobicore.core.config.ModuleConfigLoader;
import com.example.shinobicore.core.event.CoreEvents;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.core.module.ModuleManager;
import com.example.shinobicore.core.view.CoreViews;
import com.example.shinobicore.core.api.ModuleContext;
import net.fabricmc.api.ModInitializer;
import net.fabricmc.fabric.api.command.v2.CommandRegistrationCallback;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerLifecycleEvents;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;

public class ShinobiCoreMod implements ModInitializer {
    private static final ModuleConfigLoader CONFIGS = new ModuleConfigLoader();
    @Override
    public void onInitialize() {
        ShinobiLogger.init();
        ShinobiLogger.core("ShinobiCore 4.0.0 starting");
        CompatibilityChecker.check();
        ModuleManager.init(CONFIGS);
        ModuleManager.loadAll();
        CommandRegistrationCallback.EVENT.register((dispatcher, registryAccess, environment) -> {
            CoreCommands.register(dispatcher);
            for (var entry : ModuleManager.all()) {
                if (entry.state().name().equals("ENABLED")) {
                    try {
                        ModuleContext ctx = new ModuleContext(entry.module().id(), CONFIGS);
                        entry.module().registerCommands(ctx, dispatcher);
                    } catch (Throwable t) {
                        ModuleManager.disable(entry.module().id(), "Command registration failed: " + t.getMessage());
                    }
                }
            }
        });
        ServerLifecycleEvents.SERVER_STARTING.register(ModuleManager::serverStarting);
        ServerLifecycleEvents.SERVER_STOPPED.register(ModuleManager::serverStopping);
        ServerTickEvents.END_SERVER_TICK.register(ModuleManager::serverTick);
    }
}
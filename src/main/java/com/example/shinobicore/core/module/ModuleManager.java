package com.example.shinobicore.core.module;
import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.api.ShinobiModule;
import com.example.shinobicore.core.api.ClientAwareModule;
import com.example.shinobicore.core.event.CoreEvents;
import com.example.shinobicore.core.view.CoreViews;
import com.example.shinobicore.core.config.ModuleConfigLoader;
import com.example.shinobicore.core.log.ShinobiLogger;
import net.fabricmc.loader.api.FabricLoader;
import net.fabricmc.loader.api.entrypoint.EntrypointContainer;
import net.minecraft.server.MinecraftServer;
import java.util.Collection;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

public final class ModuleManager {
    private static final Map<String, ModuleEntry> MODULES = new LinkedHashMap<>();
    private static ModuleConfigLoader configs;
    private ModuleManager() {}

    public static void init(ModuleConfigLoader configsIn) {
        configs = configsIn;
    }

    public static void loadAll() {
        List<EntrypointContainer<ShinobiModule>> containers =
                FabricLoader.getInstance().getEntrypointContainers("shinobicore:module", ShinobiModule.class);
        for (EntrypointContainer<ShinobiModule> container : containers) {
            loadOne(container);
        }
        ShinobiLogger.core("Loaded modules: " + MODULES.size());
    }

    private static void loadOne(EntrypointContainer<ShinobiModule> container) {
        String provider = container.getProvider().getMetadata().getId();
        ShinobiModule module = null;
        try {
            module = container.getEntrypoint();
            String id = module.id();
            if (MODULES.containsKey(id)) {
                ShinobiLogger.error("core", "Duplicate module id: " + id + " from provider: " + provider, null);
                return;
            }
            ModuleContext ctx = new ModuleContext(id, configs);
            module.onRegister(ctx);
            module.registerEvents(ctx);
            module.registerViews(ctx);
            boolean enabled = configs.isModuleEnabled(id);
            ModuleEntry entry = new ModuleEntry(module, provider);
            if (!enabled) {
                entry.setState(ModuleState.DISABLED);
                MODULES.put(id, entry);
                ShinobiLogger.module(id, "Module disabled by config");
                return;
            }
            module.onEnable(ctx);
            MODULES.put(id, entry);
            ShinobiLogger.module(id, "Module enabled");
        } catch (Throwable t) {
            String id = (module != null) ? module.id() : "unknown";
            ShinobiLogger.error("core", "Failed to load module: " + id, t);
            if (module != null) {
                ModuleEntry entry = new ModuleEntry(module, provider);
                entry.fail(String.valueOf(t.getMessage()));
                MODULES.put(module.id(), entry);
            }
        }
    }

    public static void initClient() {
        for (ModuleEntry entry : MODULES.values()) {
            if (entry.state() != ModuleState.ENABLED) continue;
            if (!(entry.module() instanceof ClientAwareModule clientModule)) continue;
            try {
                ModuleContext ctx = contextFor(entry.module());
                clientModule.onClientInit(ctx);
            } catch (Throwable t) {
                disable(entry.module().id(), "Client init failed: " + t.getMessage());
            }
        }
    }

    public static void serverStarting(MinecraftServer server) {
        for (ModuleEntry entry : MODULES.values()) {
            if (entry.state() != ModuleState.ENABLED) continue;
            try {
                ModuleContext ctx = contextFor(entry.module());
                entry.module().onServerStarting(ctx, server);
            } catch (Throwable t) {
                disable(entry.module().id(), "Server starting failed: " + t.getMessage());
            }
        }
    }

    public static void serverStopping(MinecraftServer server) {
        for (ModuleEntry entry : MODULES.values()) {
            if (entry.state() != ModuleState.ENABLED) continue;
            try {
                ModuleContext ctx = contextFor(entry.module());
                entry.module().onServerStopping(ctx, server);
            } catch (Throwable t) {
                ShinobiLogger.error(entry.module().id(), "Server stopping failed", t);
            }
        }
    }

    public static void serverTick(MinecraftServer server) {
        for (ModuleEntry entry : MODULES.values()) {
            if (entry.state() != ModuleState.ENABLED) continue;
            try {
                ModuleContext ctx = contextFor(entry.module());
                entry.module().onServerTick(ctx, server);
            } catch (Throwable t) {
                disable(entry.module().id(), "Server tick failed: " + t.getMessage());
            }
        }
    }

    public static void clientTick() {
        for (ModuleEntry entry : MODULES.values()) {
            if (entry.state() != ModuleState.ENABLED) continue;
            if (!(entry.module() instanceof ClientAwareModule clientModule)) continue;
            try {
                ModuleContext ctx = contextFor(entry.module());
                clientModule.onClientTick(ctx);
            } catch (Throwable t) {
                disable(entry.module().id(), "Client tick failed: " + t.getMessage());
            }
        }
    }

    public static void disable(String moduleId, String reason) {
        ModuleEntry entry = MODULES.get(moduleId);
        if (entry == null) return;
        if (entry.state() == ModuleState.ENABLED) {
            try {
                ModuleContext ctx = contextFor(entry.module());
                entry.module().onDisable(ctx);
            } catch (Throwable ignored) {}
        }
        entry.setState(ModuleState.DISABLED);
        ShinobiLogger.error(moduleId, "Module disabled: " + reason, null);
    }

    public static Collection<ModuleEntry> all() { return MODULES.values(); }
    public static Optional<ModuleEntry> get(String id) { return Optional.ofNullable(MODULES.get(id)); }
    private static ModuleContext contextFor(ShinobiModule module) {
        return new ModuleContext(module.id(), configs);
    }
}
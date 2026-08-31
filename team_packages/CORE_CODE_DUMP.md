# SHINOBICORE 4.0.0 - CORE CODE DUMP

Generated: 2026-08-30 16:00:22
This file contains the complete source code of the ShinobiCore kernel.
Teams must use this code as the foundation. Do NOT modify core files.

---

## FILE: src\main\java\com\example\shinobicore\ShinobiCoreMod.java

```java
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
    private static final CoreEvents EVENTS = new CoreEvents();
    private static final CoreViews VIEWS = new CoreViews();
    private static final ModuleConfigLoader CONFIGS = new ModuleConfigLoader();
    @Override
    public void onInitialize() {
        ShinobiLogger.init();
        ShinobiLogger.core("ShinobiCore 4.0.0 starting");
        CompatibilityChecker.check();
        ModuleManager.init(EVENTS, VIEWS, CONFIGS);
        ModuleManager.loadAll();
        CommandRegistrationCallback.EVENT.register((dispatcher, registryAccess, environment) -> {
            CoreCommands.register(dispatcher);
            for (var entry : ModuleManager.all()) {
                if (entry.state().name().equals("ENABLED")) {
                    try {
                        ModuleContext ctx = new ModuleContext(entry.module().id(), EVENTS, VIEWS, CONFIGS);
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
```

## FILE: src\main\java\com\example\shinobicore\ShinobiCoreClient.java

```java
package com.example.shinobicore;
import com.example.shinobicore.core.module.ModuleManager;
import net.fabricmc.api.ClientModInitializer;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
public class ShinobiCoreClient implements ClientModInitializer {
    @Override
    public void onInitializeClient() {
        ModuleManager.initClient();
        ClientTickEvents.END_CLIENT_TICK.register(client -> ModuleManager.clientTick());
    }
}
```

## FILE: src\main\java\com\example\shinobicore\core\api\ShinobiModule.java

```java
package com.example.shinobicore.core.api;
import com.mojang.brigadier.CommandDispatcher;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.command.ServerCommandSource;
public interface ShinobiModule {
    String id();
    default void onRegister(ModuleContext ctx) {}
    default void onEnable(ModuleContext ctx) {}
    default void onDisable(ModuleContext ctx) {}
    default void registerEvents(ModuleContext ctx) {}
    default void registerViews(ModuleContext ctx) {}
    default void registerCommands(ModuleContext ctx, CommandDispatcher<ServerCommandSource> dispatcher) {}
    default void onServerStarting(ModuleContext ctx, MinecraftServer server) {}
    default void onServerStopping(ModuleContext ctx, MinecraftServer server) {}
    default void onServerTick(ModuleContext ctx, MinecraftServer server) {}
}
```

## FILE: src\main\java\com\example\shinobicore\core\api\ClientAwareModule.java

```java
package com.example.shinobicore.core.api;
public interface ClientAwareModule extends ShinobiModule {
    default void onClientInit(ModuleContext ctx) {}
    default void onClientTick(ModuleContext ctx) {}
}
```

## FILE: src\main\java\com\example\shinobicore\core\api\ModuleContext.java

```java
package com.example.shinobicore.core.api;
import com.example.shinobicore.core.event.CoreEvents;
import com.example.shinobicore.core.view.CoreViews;
import com.example.shinobicore.core.config.ModuleConfigLoader;
public final class ModuleContext {
    private final String moduleId;
    private final CoreEvents events;
    private final CoreViews views;
    private final ModuleConfigLoader configs;
    public ModuleContext(String moduleId, CoreEvents events, CoreViews views, ModuleConfigLoader configs) {
        this.moduleId = moduleId;
        this.events = events;
        this.views = views;
        this.configs = configs;
    }
    public String moduleId() { return moduleId; }
    public CoreEvents events() { return events; }
    public CoreViews views() { return views; }
    public ModuleConfigLoader configs() { return configs; }
}
```

## FILE: src\main\java\com\example\shinobicore\core\module\ModuleState.java

```java
package com.example.shinobicore.core.module;
public enum ModuleState { ENABLED, DISABLED, FAILED }
```

## FILE: src\main\java\com\example\shinobicore\core\module\ModuleEntry.java

```java
package com.example.shinobicore.core.module;
import com.example.shinobicore.core.api.ShinobiModule;
public final class ModuleEntry {
    private final ShinobiModule module;
    private final String provider;
    private ModuleState state;
    private String failReason;
    public ModuleEntry(ShinobiModule module, String provider) {
        this.module = module;
        this.provider = provider;
        this.state = ModuleState.ENABLED;
        this.failReason = "";
    }
    public ShinobiModule module() { return module; }
    public String provider() { return provider; }
    public ModuleState state() { return state; }
    public String failReason() { return failReason; }
    public void setState(ModuleState state) { this.state = state; }
    public void fail(String reason) { this.state = ModuleState.FAILED; this.failReason = reason; }
}
```

## FILE: src\main\java\com\example\shinobicore\core\module\ModuleManager.java

```java
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
    private static CoreEvents events;
    private static CoreViews views;
    private static ModuleConfigLoader configs;
    private ModuleManager() {}

    public static void init(CoreEvents eventsIn, CoreViews viewsIn, ModuleConfigLoader configsIn) {
        events = eventsIn;
        views = viewsIn;
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
            ModuleContext ctx = new ModuleContext(id, events, views, configs);
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
        return new ModuleContext(module.id(), events, views, configs);
    }
}
```

## FILE: src\main\java\com\example\shinobicore\core\event\CoreEvents.java

```java
package com.example.shinobicore.core.event;
import com.example.shinobicore.core.log.ShinobiLogger;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.function.Consumer;
public final class CoreEvents {
    private final Map<Class<?>, CopyOnWriteArrayList<Consumer<?>>> listeners = new ConcurrentHashMap<>();
    public <T> void subscribe(Class<T> type, Consumer<T> listener) {
        listeners.computeIfAbsent(type, k -> new CopyOnWriteArrayList<>()).add(listener);
    }
    @SuppressWarnings("unchecked")
    public <T> void publish(T event) {
        CopyOnWriteArrayList<Consumer<?>> list = listeners.get(event.getClass());
        if (list == null || list.isEmpty()) return;
        for (Consumer<?> raw : list) {
            try { ((Consumer<T>) raw).accept(event); }
            catch (Throwable t) {
                ShinobiLogger.error("core", "Event listener failed for: " + event.getClass().getSimpleName(), t);
            }
        }
    }
}
```

## FILE: src\main\java\com\example\shinobicore\core\view\CoreViews.java

```java
package com.example.shinobicore.core.view;
import com.example.shinobicore.core.log.ShinobiLogger;
import net.minecraft.entity.player.PlayerEntity;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
public final class CoreViews {
    @FunctionalInterface
    public interface ViewFactory<T> { Optional<T> create(PlayerEntity player); }
    private final Map<Class<?>, ViewFactory<?>> factories = new ConcurrentHashMap<>();
    public <T> void register(Class<T> type, ViewFactory<T> factory) { factories.put(type, factory); }
    @SuppressWarnings("unchecked")
    public <T> Optional<T> get(PlayerEntity player, Class<T> type) {
        ViewFactory<?> raw = factories.get(type);
        if (raw == null) return Optional.empty();
        try { return ((ViewFactory<T>) raw).create(player); }
        catch (Throwable t) {
            ShinobiLogger.error("core", "View factory failed: " + type.getSimpleName(), t);
            return Optional.empty();
        }
    }
}
```

## FILE: src\main\java\com\example\shinobicore\core\service\CoreServices.java

```java
package com.example.shinobicore.core.service;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
public final class CoreServices {
    private static final Map<Class<?>, Object> SERVICES = new ConcurrentHashMap<>();
    private CoreServices() {}
    public static <T> void register(Class<T> type, T service) { SERVICES.put(type, service); }
    public static <T> Optional<T> get(Class<T> type) {
        Object value = SERVICES.get(type);
        if (value == null) return Optional.empty();
        return Optional.ofNullable(type.cast(value));
    }
    public static <T> T require(Class<T> type) {
        return get(type).orElseThrow(() -> new IllegalStateException("Core service not registered: " + type.getSimpleName()));
    }
}
```

## FILE: src\main\java\com\example\shinobicore\core\log\ShinobiLogger.java

```java
package com.example.shinobicore.core.log;
import net.fabricmc.loader.api.FabricLoader;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import java.io.IOException;
import java.io.PrintWriter;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
public final class ShinobiLogger {
    private static final Logger SLF4J = LoggerFactory.getLogger("ShinobiCore");
    private static final DateTimeFormatter FMT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
    private static Path logDir;
    private static final int MAX_ROTATION = 3;
    private ShinobiLogger() {}
    public static void init() {
        try {
            logDir = FabricLoader.getInstance().getGameDir().resolve("logs").resolve("shinobicore");
            Files.createDirectories(logDir);
        } catch (Throwable t) {
            SLF4J.error("Failed to init log dir", t);
        }
    }
    public static void core(String message) {
        SLF4J.info("[CORE] {}", message);
        appendRotated("core", "[CORE] " + message);
    }
    public static void module(String moduleId, String message) {
        SLF4J.info("[{}] {}", moduleId, message);
        appendRotated(moduleId, "[" + moduleId + "] " + message);
    }
    public static void error(String moduleId, String message, Throwable t) {
        if (t == null) SLF4J.error("[{}] {}", moduleId, message);
        else SLF4J.error("[{}] {}", moduleId, message, t);
        String text = "[" + moduleId + "] ERROR: " + message;
        if (t != null) text += " -> " + t.getClass().getSimpleName() + ": " + t.getMessage();
        appendRotated(moduleId, text);
    }
    public static void info(String message) { SLF4J.info(message); }
    private static void appendRotated(String type, String line) {
        if (logDir == null) return;
        try {
            rotate(type);
            Path current = logDir.resolve(type + "-1.log");
            String stamp = LocalDateTime.now().format(FMT);
            Files.writeString(current, "[" + stamp + "] " + line + System.lineSeparator(),
                    StandardOpenOption.CREATE, StandardOpenOption.APPEND);
        } catch (IOException ignored) {}
    }
    private static void rotate(String type) throws IOException {
        for (int i = MAX_ROTATION; i >= 1; i--) {
            Path p = logDir.resolve(type + "-" + i + ".log");
            if (i == MAX_ROTATION) {
                Files.deleteIfExists(p);
            } else {
                Path next = logDir.resolve(type + "-" + (i + 1) + ".log");
                if (Files.exists(p)) Files.move(p, next, java.nio.file.StandardCopyOption.REPLACE_EXISTING);
            }
        }
    }
}
```

## FILE: src\main\java\com\example\shinobicore\core\config\ModuleConfigLoader.java

```java
package com.example.shinobicore.core.config;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import net.fabricmc.loader.api.FabricLoader;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
public final class ModuleConfigLoader {
    private static final Gson GSON = new GsonBuilder().setPrettyPrinting().create();
    private final Path rootDir;
    public ModuleConfigLoader() {
        this.rootDir = FabricLoader.getInstance().getConfigDir().resolve("shinobicore").resolve("modules");
        try { Files.createDirectories(rootDir); } catch (IOException t) { ShinobiLogger.error("core", "Failed to create config dir", t); }
    }
    public boolean isModuleEnabled(String moduleId) {
        Path file = rootDir.resolve(moduleId + ".json");
        if (!Files.exists(file)) {
            writeDefault(file);
            return true;
        }
        try {
            String raw = Files.readString(file);
            JsonObject obj = JsonParser.parseString(raw).getAsJsonObject();
            if (obj.has("enabled")) return obj.get("enabled").getAsBoolean();
            return true;
        } catch (Throwable t) {
            ShinobiLogger.error(moduleId, "Failed to read config, using default enabled=true", t);
            return true;
        }
    }
    public JsonObject readModuleConfig(String moduleId) {
        Path file = rootDir.resolve(moduleId + ".json");
        if (!Files.exists(file)) { writeDefault(file); return new JsonObject(); }
        try {
            return JsonParser.parseString(Files.readString(file)).getAsJsonObject();
        } catch (Throwable t) {
            ShinobiLogger.error(moduleId, "Failed to parse config", t);
            return new JsonObject();
        }
    }
    private void writeDefault(Path file) {
        try {
            JsonObject obj = new JsonObject();
            obj.addProperty("enabled", true);
            obj.addProperty("debug", false);
            Files.writeString(file, GSON.toJson(obj));
        } catch (IOException t) {
            ShinobiLogger.error("core", "Failed to write default config: " + file, t);
        }
    }
}
```

## FILE: src\main\java\com\example\shinobicore\core\command\CoreCommands.java

```java
package com.example.shinobicore.core.command;

import com.example.shinobicore.core.module.ModuleEntry;
import com.example.shinobicore.core.module.ModuleManager;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.context.CommandContext;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.text.Text;
import net.minecraft.util.Formatting;

public final class CoreCommands {
    private CoreCommands() {}

    public static void register(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(CommandManager.literal("shinobicore")
                .then(CommandManager.literal("systems").executes(CoreCommands::cmdSystems))
                .then(CommandManager.literal("modules")
                        .then(CommandManager.literal("list").executes(CoreCommands::cmdModulesList)))
                .then(CommandManager.literal("version").executes(ctx -> {
                    ctx.getSource().sendFeedback(() -> Text.literal("ShinobiCore 4.0.0").formatted(Formatting.GOLD), false);
                    return 1;
                }))
        );
    }

    private static int cmdSystems(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource src = ctx.getSource();
        src.sendFeedback(() -> Text.literal("=== ShinobiCore Systems ===").formatted(Formatting.GOLD), false);
        for (ModuleEntry e : ModuleManager.all()) {
            Formatting f = Formatting.WHITE;
            switch (e.state()) {
                case ENABLED:  f = Formatting.GREEN; break;
                case DISABLED: f = Formatting.YELLOW; break;
                case FAILED:   f = Formatting.RED; break;
            }
            final Formatting ff = f;
            final String line = e.module().id() + " [" + e.provider() + "] -> " + e.state()
                    + (e.failReason().isEmpty() ? "" : " (" + e.failReason() + ")");
            src.sendFeedback(() -> Text.literal(line).formatted(ff), false);
        }
        return 1;
    }

    private static int cmdModulesList(CommandContext<ServerCommandSource> ctx) {
        return cmdSystems(ctx);
    }
}
```

## FILE: src\main\java\com\example\shinobicore\core\compat\CompatibilityChecker.java

```java
package com.example.shinobicore.core.compat;
import com.example.shinobicore.core.log.ShinobiLogger;
import net.fabricmc.loader.api.FabricLoader;
public final class CompatibilityChecker {
    private CompatibilityChecker() {}
    public static void check() {
        String[] required = { "fabric-api", "cardinal-components-base", "cardinal-components-entity" };
        String[] optional = { "bettercombat", "player-animator", "geckolib", "cloth-config" };
        for (String id : required) {
            if (!FabricLoader.getInstance().isModLoaded(id)) {
                ShinobiLogger.error("core", "MISSING REQUIRED MOD: " + id, null);
            } else {
                ShinobiLogger.core("Required mod present: " + id);
            }
        }
        for (String id : optional) {
            if (FabricLoader.getInstance().isModLoaded(id)) {
                ShinobiLogger.core("Optional mod present: " + id);
            } else {
                ShinobiLogger.core("Optional mod absent: " + id);
            }
        }
    }
}
```

## FILE: src\main\java\com\example\shinobicore\modules\example\ExampleModule.java

```java
package com.example.shinobicore.modules.example;
import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.api.ShinobiModule;
import com.example.shinobicore.core.log.ShinobiLogger;
public class ExampleModule implements ShinobiModule {
    @Override public String id() { return "example"; }
    @Override public void onEnable(ModuleContext ctx) {
        ShinobiLogger.module(id(), "Example module enabled");
    }
    @Override public void onDisable(ModuleContext ctx) {
        ShinobiLogger.module(id(), "Example module disabled");
    }
}
```

## FILE: src\main\resources\fabric.mod.json

```json
{
    "schemaVersion":  1,
    "id":  "shinobicore",
    "version": "4.0.0",
    "name": "ShinobiCore",
    "description": "Modular shinobi framework - 4.0.0 architecture rewrite",
    "authors":  [
                    "ShinobiCore Team"
                ],
    "contact":  {

                },
    "license":  "MIT",
    "icon":  "assets/shinobicore/icon.png",
    "environment":  "*",
      "entrypoints": {
    "main": [
      "com.example.shinobicore.ShinobiCoreMod"
    ],
    "client": [
      "com.example.shinobicore.ShinobiCoreClient"
    ],
    "shinobicore:module": [
      "com.example.shinobicore.modules.example.ExampleModule"
    ]
  },
    "mixins":  [
                   "shinobicore.mixins.json"
               ],
    "depends":  {
                    "fabricloader":  "\u003e=0.14.21",
                    "minecraft":  "~1.20.1",
                    "java":  "\u003e=17",
                    "fabric-api":  "*",
                    "cardinal-components-base":  "\u003e=5.2.0",
                    "cardinal-components-entity":  "\u003e=5.2.0"
                },
    "recommends":  {
                       "bettercombat":  "\u003e=1.9.0",
                       "geckolib":  "\u003e=4.4.0",
                       "cloth-config":  "\u003e=11.0.0"
                   },
    "custom":  {
                   "cardinal-components":  [
                                               "shinobicore:chakra",
                                               "shinobicore:stats",
                                               "shinobicore:clan",
                                               "shinobicore:jutsu",
                                               "shinobicore:dojutsu",
                                               "shinobicore:parkour",
                                               "shinobicore:combat"
                                           ]
               }
}

```

## FILE: src\main\resources\shinobicore.mixins.json

```json
{
  "required": true,
  "package": "com.example.shinobicore.mixin",
  "compatibilityLevel": "JAVA_17",
  "mixins": [],
  "client": [],
  "injectors": {
    "defaultRequire": 1
  }
}
```

## FILE: gradle.properties

```text
# === FABRIC CORE ===
org.gradle.jvmargs=-Xmx3G
org.gradle.parallel=true
minecraft_version=1.20.1
yarn_mappings=1.20.1+build.10
loader_version=0.16.9
fabric_version=0.92.3+1.20.1

# === MOD INFO ===
mod_version=4.0.0
maven_group=com.example
archives_base_name=shinobicore

# === LIBRARIES (Maven) ===
cca_version=5.2.2
cloth_config_version=11.1.106
geckolib_version=4.4.9
mixin_extras_version=0.4.1
```

---

## DUMP STATISTICS
Total files: 19
Total lines: 620

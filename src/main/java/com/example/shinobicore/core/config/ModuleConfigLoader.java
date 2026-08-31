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
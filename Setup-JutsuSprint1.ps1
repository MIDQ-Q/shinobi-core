# Setup-JutsuSprint1.ps1
# Мастер-скрипт для создания Loader, Cast и Slots модуля Jutsu (Sprint 1, Step 2)
# Требует запуска из корневой директории мода (где находится build.gradle)

$ErrorActionPreference = "Stop"
$rootPath = Get-Location

Write-Host "=== ShinobiCore: Jutsu Module Sprint 1 Setup ===" -ForegroundColor Cyan

# 1. Создание структуры директорий
$dirs = @(
    "src\main\resources\data\shinobicore\jutsu",
    "src\main\java\com\example\shinobicore\modules\jutsu",
    "src\main\java\com\example\shinobicore\modules\jutsu\data",
    "src\main\java\com\example\shinobicore\modules\jutsu\cast",
    "src\main\java\com\example\shinobicore\modules\jutsu\slot"
)

foreach ($dir in $dirs) {
    $fullPath = Join-Path $rootPath $dir
    if (!(Test-Path $fullPath)) {
        New-Item -ItemType Directory -Force -Path $fullPath | Out-Null
        Write-Host "[OK] Created directory: $dir" -ForegroundColor Green
    } else {
        Write-Host "[SKIP] Directory already exists: $dir" -ForegroundColor Yellow
    }
}

# 2. Функция для безопасной записи файлов (UTF-8 без BOM, критично для Fabric)
function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText((Join-Path $rootPath $Path), $Content, $utf8NoBom)
    Write-Host "[OK] Written: $Path" -ForegroundColor Green
}

# 3. Создание JSON файлов техник
Write-Host "`n--- Creating JSON Definitions ---" -ForegroundColor Cyan

$testProjectileJson = @'
{
  "id": "shinobicore:test_projectile",
  "name": "Test Fireball",
  "element": "fire",
  "behavior": "projectile",
  "baseCost": 10.0,
  "cooldownTicks": 40,
  "prepareTicks": 5,
  "chargeTicks": 15,
  "releaseTicks": 5,
  "maxChargeMultiplier": 1.5,
  "requirements": {
    "minPlayerLevel": 1,
    "elements": [],
    "stats": {},
    "clanJutsu": false,
    "treeNode": null,
    "scroll": null,
    "dojutsu": null
  },
  "behaviorData": {
    "projectileSpeed": 1.5,
    "projectileDamage": 4.0,
    "projectileGravity": 0.02,
    "projectileLifetimeTicks": 60,
    "impactRadius": 1.5,
    "fireTicksOnHit": 0
  },
  "scaling": {
    "damagePerLevel": 0.5,
    "costReductionPerLevel": 0.01,
    "cooldownReductionPerLevel": 1
  },
  "visual": {
    "castHandSeals": ["tiger"],
    "particleColor": "#FF4500",
    "soundCast": "",
    "soundImpact": ""
  }
}
'@
Write-Utf8NoBom "src\main\resources\data\shinobicore\jutsu\test_projectile.json" $testProjectileJson

$testDashJson = @'
{
  "id": "shinobicore:test_dash",
  "name": "Test Dash",
  "element": "none",
  "behavior": "dash",
  "baseCost": 5.0,
  "cooldownTicks": 20,
  "prepareTicks": 0,
  "chargeTicks": 0,
  "releaseTicks": 1,
  "maxChargeMultiplier": 1.0,
  "requirements": {
    "minPlayerLevel": 1,
    "elements": [],
    "stats": {},
    "clanJutsu": false,
    "treeNode": null,
    "scroll": null,
    "dojutsu": null
  },
  "behaviorData": {
    "dashDistance": 5.0,
    "iFramesTicks": 4
  },
  "scaling": {
    "damagePerLevel": 0.0,
    "costReductionPerLevel": 0.0,
    "cooldownReductionPerLevel": 1
  },
  "visual": {
    "castHandSeals": [],
    "particleColor": "#FFFFFF",
    "soundCast": "",
    "soundImpact": ""
  }
}
'@
Write-Utf8NoBom "src\main\resources\data\shinobicore\jutsu\test_dash.json" $testDashJson

# 4. Создание Java файлов (Data)
Write-Host "`n--- Creating Java Classes (Data) ---" -ForegroundColor Cyan

$jutsuElementJava = @'
package com.example.shinobicore.modules.jutsu.data;

public enum JutsuElement {
    FIRE, WATER, WIND, LIGHTNING, EARTH, NONE;

    public static JutsuElement fromString(String s) {
        if (s == null || s.isEmpty()) return NONE;
        try {
            return valueOf(s.toUpperCase());
        } catch (Exception e) {
            return NONE;
        }
    }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\data\JutsuElement.java" $jutsuElementJava

$jutsuDefinitionJava = @'
package com.example.shinobicore.modules.jutsu.data;

import com.google.gson.JsonObject;
import java.util.List;
import java.util.Map;

public record JutsuDefinition(
    String id,
    String name,
    JutsuElement element,
    String behaviorId,
    float baseCost,
    int cooldownTicks,
    int prepareTicks,
    int chargeTicks,
    int releaseTicks,
    float maxChargeMultiplier,
    Requirements requirements,
    JsonObject behaviorData,
    Scaling scaling,
    VisualData visual
) {
    public record Requirements(
        int minPlayerLevel,
        List<String> elements,
        Map<String, Integer> stats,
        boolean clanJutsu,
        String treeNode,
        String scroll,
        String dojutsu
    ) {}

    public record Scaling(
        float damagePerLevel,
        float costReductionPerLevel,
        int cooldownReductionPerLevel
    ) {}

    public record VisualData(
        List<String> castHandSeals,
        String particleColor,
        String soundCast,
        String soundImpact
    ) {}
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\data\JutsuDefinition.java" $jutsuDefinitionJava

$jutsuRegistryJava = @'
package com.example.shinobicore.modules.jutsu.data;

import com.example.shinobicore.core.log.ShinobiLogger;
import java.util.Collection;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

public final class JutsuRegistry {
    private static final Map<String, JutsuDefinition> JUTSU_MAP = new ConcurrentHashMap<>();

    public static void register(JutsuDefinition def) {
        if (def == null || def.id() == null) return;
        if (JUTSU_MAP.containsKey(def.id())) {
            ShinobiLogger.error("jutsu", "Duplicate jutsu id ignored: " + def.id(), null);
            return;
        }
        JUTSU_MAP.put(def.id(), def);
    }

    public static Optional<JutsuDefinition> get(String id) {
        return Optional.ofNullable(JUTSU_MAP.get(id));
    }

    public static Collection<JutsuDefinition> all() {
        return JUTSU_MAP.values();
    }

    public static int size() {
        return JUTSU_MAP.size();
    }
    
    public static void clear() {
        JUTSU_MAP.clear();
    }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\data\JutsuRegistry.java" $jutsuRegistryJava

$jutsuLoaderJava = @'
package com.example.shinobicore.modules.jutsu.data;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import net.fabricmc.loader.api.FabricLoader;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;

public final class JutsuLoader {
    private static final Gson GSON = new GsonBuilder().setPrettyPrinting().create();

    public static void load() {
        JutsuRegistry.clear();
        Path jutsuDir = FabricLoader.getInstance().getModContainer("shinobicore")
                .flatMap(c -> c.findPath("data/shinobicore/jutsu"))
                .orElseThrow(() -> new RuntimeException("Cannot find jutsu data path"));

        if (!Files.isDirectory(jutsuDir)) {
            ShinobiLogger.module("jutsu", "Jutsu data directory not found. Skipping load.");
            return;
        }

        int loadedCount = 0;
        int errorCount = 0;

        try (var stream = Files.walk(jutsuDir)) {
            stream.filter(Files::isRegularFile)
                  .filter(p -> p.toString().endsWith(".json"))
                  .forEach(path -> {
                      try {
                          String json = Files.readString(path);
                          JsonObject obj = JsonParser.parseString(json).getAsJsonObject();
                          JutsuDefinition def = parseDefinition(obj);
                          if (def != null) {
                              JutsuRegistry.register(def);
                              loadedCount++;
                          }
                      } catch (Exception e) {
                          errorCount++;
                          ShinobiLogger.error("jutsu", "Failed to load jutsu from: " + path.getFileName(), e);
                      }
                  });
        } catch (IOException e) {
            ShinobiLogger.error("jutsu", "Failed to read jutsu directory", e);
        }

        ShinobiLogger.module("jutsu", String.format("Loaded %d jutsu definitions. Errors: %d", loadedCount, errorCount));
    }

    private static JutsuDefinition parseDefinition(JsonObject obj) {
        try {
            String id = obj.has("id") ? obj.get("id").getAsString() : "unknown";
            String name = obj.has("name") ? obj.get("name").getAsString() : "Unnamed";
            String elementStr = obj.has("element") ? obj.get("element").getAsString() : "none";
            JutsuElement element = JutsuElement.fromString(elementStr);
            String behaviorId = obj.has("behavior") ? obj.get("behavior").getAsString() : "utility";
            
            float baseCost = obj.has("baseCost") ? obj.get("baseCost").getAsFloat() : 0.0f;
            int cooldownTicks = obj.has("cooldownTicks") ? obj.get("cooldownTicks").getAsInt() : 0;
            int prepareTicks = obj.has("prepareTicks") ? obj.get("prepareTicks").getAsInt() : 0;
            int chargeTicks = obj.has("chargeTicks") ? obj.get("chargeTicks").getAsInt() : 0;
            int releaseTicks = obj.has("releaseTicks") ? obj.get("releaseTicks").getAsInt() : 1;
            float maxChargeMultiplier = obj.has("maxChargeMultiplier") ? obj.get("maxChargeMultiplier").getAsFloat() : 1.0f;

            JutsuDefinition.Requirements req = parseRequirements(obj.getAsJsonObject("requirements"));
            JsonObject behaviorData = obj.has("behaviorData") ? obj.getAsJsonObject("behaviorData") : new JsonObject();
            JutsuDefinition.Scaling scaling = parseScaling(obj.getAsJsonObject("scaling"));
            JutsuDefinition.VisualData visual = parseVisual(obj.getAsJsonObject("visual"));

            return new JutsuDefinition(id, name, element, behaviorId, baseCost, cooldownTicks, 
                    prepareTicks, chargeTicks, releaseTicks, maxChargeMultiplier, req, behaviorData, scaling, visual);
        } catch (Exception e) {
            ShinobiLogger.error("jutsu", "Malformed jutsu definition skipped", e);
            return null;
        }
    }

    private static JutsuDefinition.Requirements parseRequirements(JsonObject obj) {
        if (obj == null) return new JutsuDefinition.Requirements(1, List.of(), Map.of(), false, null, null, null);
        int minLvl = obj.has("minPlayerLevel") ? obj.get("minPlayerLevel").getAsInt() : 1;
        boolean clan = obj.has("clanJutsu") && obj.get("clanJutsu").getAsBoolean();
        return new JutsuDefinition.Requirements(minLvl, List.of(), Map.of(), clan, null, null, null);
    }

    private static JutsuDefinition.Scaling parseScaling(JsonObject obj) {
        if (obj == null) return new JutsuDefinition.Scaling(0.0f, 0.0f, 0);
        float dmg = obj.has("damagePerLevel") ? obj.get("damagePerLevel").getAsFloat() : 0.0f;
        float cost = obj.has("costReductionPerLevel") ? obj.get("costReductionPerLevel").getAsFloat() : 0.0f;
        int cd = obj.has("cooldownReductionPerLevel") ? obj.get("cooldownReductionPerLevel").getAsInt() : 0;
        return new JutsuDefinition.Scaling(dmg, cost, cd);
    }

    private static JutsuDefinition.VisualData parseVisual(JsonObject obj) {
        if (obj == null) return new JutsuDefinition.VisualData(List.of(), "#FFFFFF", "", "");
        return new JutsuDefinition.VisualData(List.of(), "#FFFFFF", "", "");
    }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\data\JutsuLoader.java" $jutsuLoaderJava

$jutsuJsonValidatorJava = @'
package com.example.shinobicore.modules.jutsu.data;

import com.example.shinobicore.core.log.ShinobiLogger;

public final class JutsuJsonValidator {
    private static int errorCount = 0;

    public static void validateAll() {
        errorCount = 0;
        for (JutsuDefinition def : JutsuRegistry.all()) {
            validate(def);
        }
        if (errorCount > 0) {
            ShinobiLogger.error("jutsu", "Validation completed with " + errorCount + " errors. Check logs.", null);
        } else {
            ShinobiLogger.module("jutsu", "All " + JutsuRegistry.size() + " jutsu validated successfully.");
        }
    }

    private static void validate(JutsuDefinition def) {
        if (def.baseCost() < 0) error(def, "baseCost cannot be negative");
        if (def.cooldownTicks() < 0) error(def, "cooldownTicks cannot be negative");
        if (def.maxChargeMultiplier() < 1.0f) error(def, "maxChargeMultiplier must be >= 1.0");
        if (def.id() == null || def.id().isEmpty()) error(def, "id is missing or empty");
    }

    private static void error(JutsuDefinition def, String msg) {
        ShinobiLogger.error("jutsu", "Validation error in [" + def.id() + "]: " + msg, null);
        errorCount++;
    }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\data\JutsuJsonValidator.java" $jutsuJsonValidatorJava

# 5. Создание Java файлов (Cast)
Write-Host "`n--- Creating Java Classes (Cast) ---" -ForegroundColor Cyan

$castPhaseJava = @'
package com.example.shinobicore.modules.jutsu.cast;

public enum CastPhase {
    IDLE, PREPARE, CHARGE, RELEASE, COOLDOWN
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\cast\CastPhase.java" $castPhaseJava

$jutsuCastSessionJava = @'
package com.example.shinobicore.modules.jutsu.cast;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.core.service.CoreServices;
import com.example.shinobicore.modules.jutsu.data.JutsuDefinition;
import com.example.shinobicore.modules.jutsu.data.JutsuRegistry;
import net.minecraft.server.network.ServerPlayerEntity;

import java.util.UUID;

public final class JutsuCastSession {
    private final UUID playerId;
    private final String jutsuId;
    private final JutsuDefinition def;
    private final int slot;
    
    private CastPhase phase = CastPhase.PREPARE;
    private int ticksInPhase = 0;
    private float chargeMultiplier = 1.0f;
    private boolean isHoldingCast = true;
    private String queuedJutsuId = null;

    public JutsuCastSession(UUID playerId, String jutsuId, int slot) {
        this.playerId = playerId;
        this.jutsuId = jutsuId;
        this.slot = slot;
        this.def = JutsuRegistry.get(jutsuId).orElseThrow();
    }

    public void tick(ServerPlayerEntity player) {
        if (player == null || player.isDead()) {
            cancel("player_dead");
            return;
        }

        ticksInPhase++;
        switch (phase) {
            case PREPARE -> {
                if (ticksInPhase >= def.prepareTicks()) {
                    phase = CastPhase.CHARGE;
                    ticksInPhase = 0;
                }
            }
            case CHARGE -> {
                if (!isHoldingCast || ticksInPhase >= def.chargeTicks()) {
                    phase = CastPhase.RELEASE;
                    ticksInPhase = 0;
                } else {
                    chargeMultiplier = 1.0f + ((float) ticksInPhase / def.chargeTicks()) * (def.maxChargeMultiplier() - 1.0f);
                }
            }
            case RELEASE -> {
                if (ticksInPhase == 1) {
                    executeRelease(player);
                }
                if (ticksInPhase >= def.releaseTicks()) {
                    phase = CastPhase.COOLDOWN;
                    ticksInPhase = 0;
                }
            }
            case COOLDOWN -> {
                if (ticksInPhase >= def.cooldownTicks()) {
                    finish(player);
                }
            }
        }
    }

    private void executeRelease(ServerPlayerEntity player) {
        CoreServices.get(com.example.shinobicore.core.api.ChakraApi.class).ifPresentOrElse(chakra -> {
            float cost = def.baseCost() * chargeMultiplier;
            if (!chakra.trySpend(player, cost)) {
                cancel("insufficient_chakra_at_release");
            } else {
                // TODO: Вызов Behavior.onRelease() и публикация JutsuCastFinishedEvent
            }
        }, () -> {
            ShinobiLogger.module("jutsu", "ChakraApi missing, allowing cast for testing (graceful degradation).");
        });
    }

    public void cancel(String reason) {
        phase = CastPhase.IDLE;
        ShinobiLogger.module("jutsu", "Cast cancelled for " + playerId + ". Reason: " + reason);
    }

    private void finish(ServerPlayerEntity player) {
        phase = CastPhase.IDLE;
        if (queuedJutsuId != null) {
            JutsuCastService.instance().requestCast(player, queuedJutsuId, slot);
        }
    }

    public void setHoldingCast(boolean holding) { this.isHoldingCast = holding; }
    public CastPhase getPhase() { return phase; }
    public boolean isFinished() { return phase == CastPhase.IDLE; }
    public void queueNext(String nextJutsuId) { this.queuedJutsuId = nextJutsuId; }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\cast\JutsuCastSession.java" $jutsuCastSessionJava

$jutsuCastServiceJava = @'
package com.example.shinobicore.modules.jutsu.cast;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.jutsu.data.JutsuRegistry;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

public final class JutsuCastService {
    private static final JutsuCastService INSTANCE = new JutsuCastService();
    private final Map<UUID, JutsuCastSession> activeSessions = new ConcurrentHashMap<>();

    public static JutsuCastService instance() { return INSTANCE; }

    public void requestCast(ServerPlayerEntity player, String jutsuId, int slot) {
        if (!JutsuRegistry.get(jutsuId).isPresent()) {
            ShinobiLogger.error("jutsu", "Attempted to cast unknown jutsu: " + jutsuId, null);
            return;
        }

        UUID uuid = player.getUuid();
        JutsuCastSession current = activeSessions.get(uuid);

        if (current != null && !current.isFinished()) {
            current.queueNext(jutsuId);
            ShinobiLogger.module("jutsu", "Queued jutsu " + jutsuId + " for player " + uuid);
            return;
        }

        // TODO: Здесь вызвать JutsuRequirementService.check() перед созданием сессии
        
        JutsuCastSession newSession = new JutsuCastSession(uuid, jutsuId, slot);
        activeSessions.put(uuid, newSession);
        ShinobiLogger.module("jutsu", "Started cast: " + jutsuId + " for player " + uuid);
    }

    public void serverTick(MinecraftServer server) {
        activeSessions.entrySet().removeIf(entry -> {
            ServerPlayerEntity player = server.getPlayerManager().getPlayer(entry.getKey());
            if (player == null) return true; // Игрок вышел, удаляем сессию (защита от утечек)

            JutsuCastSession session = entry.getValue();
            session.tick(player);
            
            return session.isFinished(); // Удаляем из мапы, если сессия завершена
        });
    }

    public void cancelAll(ServerPlayerEntity player) {
        JutsuCastSession session = activeSessions.remove(player.getUuid());
        if (session != null) {
            session.cancel("external_interrupt");
        }
    }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\cast\JutsuCastService.java" $jutsuCastServiceJava

# 6. Создание Java файлов (Slot)
Write-Host "`n--- Creating Java Classes (Slot) ---" -ForegroundColor Cyan

$jutsuLoadoutJava = @'
package com.example.shinobicore.modules.jutsu.slot;

public record JutsuLoadout(
    String slot0, // A
    String slot1, // B
    String slot2, // C
    int selectedSlot // 0, 1, or 2
) {
    public static JutsuLoadout DEFAULT = new JutsuLoadout(
        "shinobicore:test_projectile", 
        "shinobicore:test_dash", 
        null, 
        0
    );

    public String getSlot(int index) {
        return switch (index) {
            case 0 -> slot0;
            case 1 -> slot1;
            case 2 -> slot2;
            default -> null;
        };
    }

    public JutsuLoadout withSlot(int index, String jutsuId) {
        return switch (index) {
            case 0 -> new JutsuLoadout(jutsuId, slot1, slot2, selectedSlot);
            case 1 -> new JutsuLoadout(slot0, jutsuId, slot2, selectedSlot);
            case 2 -> new JutsuLoadout(slot0, slot1, jutsuId, selectedSlot);
            default -> this;
        };
    }

    public JutsuLoadout withSelected(int index) {
        return new JutsuLoadout(slot0, slot1, slot2, index);
    }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\slot\JutsuLoadout.java" $jutsuLoadoutJava

$jutsuSlotServiceJava = @'
package com.example.shinobicore.modules.jutsu.slot;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.core.service.CoreServices;
import com.example.shinobicore.modules.jutsu.data.JutsuRegistry;
import net.minecraft.server.network.ServerPlayerEntity;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

public final class JutsuSlotService {
    private static final Map<UUID, JutsuLoadout> playerLoadouts = new ConcurrentHashMap<>();

    public static JutsuLoadout getLoadout(ServerPlayerEntity player) {
        return playerLoadouts.computeIfAbsent(player.getUuid(), uuid -> JutsuLoadout.DEFAULT);
    }

    public static void selectSlot(ServerPlayerEntity player, int slotIndex) {
        if (slotIndex < 0 || slotIndex > 2) return;
        UUID uuid = player.getUuid();
        JutsuLoadout current = getLoadout(player);
        playerLoadouts.put(uuid, current.withSelected(slotIndex));
        ShinobiLogger.module("jutsu", "Player " + uuid + " selected slot " + slotIndex);
    }

    public static void cycleSlot(ServerPlayerEntity player) {
        UUID uuid = player.getUuid();
        JutsuLoadout current = getLoadout(player);
        int nextSlot = (current.selectedSlot() + 1) % 3;
        playerLoadouts.put(uuid, current.withSelected(nextSlot));
    }

    public static boolean assignJutsu(ServerPlayerEntity player, int slotIndex, String jutsuId) {
        if (slotIndex < 0 || slotIndex > 2) return false;
        
        boolean isLearned = true; 
        var progOpt = CoreServices.get(com.example.shinobicore.core.api.ProgressionApi.class);
        if (progOpt.isPresent() && jutsuId != null) {
            // TODO: isLearned = progOpt.get().isNodeUnlocked(player, jutsuId);
        }

        if (!isLearned) {
            ShinobiLogger.module("jutsu", "Player " + player.getUuid() + " tried to assign unlearned jutsu: " + jutsuId);
            return false;
        }

        if (jutsuId != null && !JutsuRegistry.get(jutsuId).isPresent()) {
            ShinobiLogger.error("jutsu", "Attempted to assign unknown jutsu: " + jutsuId, null);
            return false;
        }

        UUID uuid = player.getUuid();
        JutsuLoadout current = getLoadout(player);
        playerLoadouts.put(uuid, current.withSlot(slotIndex, jutsuId));
        ShinobiLogger.module("jutsu", "Assigned " + jutsuId + " to slot " + slotIndex + " for player " + uuid);
        return true;
    }

    public static void resetToDefaults(ServerPlayerEntity player) {
        playerLoadouts.put(player.getUuid(), JutsuLoadout.DEFAULT);
    }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\slot\JutsuSlotService.java" $jutsuSlotServiceJava

# 7. Обновление JutsuModule.java
Write-Host "`n--- Updating JutsuModule.java ---" -ForegroundColor Cyan

$jutsuModuleJava = @'
package com.example.shinobicore.modules.jutsu;

import com.example.shinobicore.core.api.ClientAwareModule;
import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.jutsu.cast.JutsuCastService;
import com.example.shinobicore.modules.jutsu.data.JutsuJsonValidator;
import com.example.shinobicore.modules.jutsu.data.JutsuLoader;
import com.example.shinobicore.modules.jutsu.data.JutsuRegistry;
import com.mojang.brigadier.CommandDispatcher;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.command.ServerCommandSource;

public class JutsuModule implements ClientAwareModule {
    public static final String ID = "jutsu";

    @Override
    public String id() { return ID; }

    @Override
    public void onRegister(ModuleContext ctx) {
        ShinobiLogger.module(ID, "Registering Jutsu components...");
        // JutsuComponentKey.register(); // Раскомментируем на этапе CCA
    }

    @Override
    public void onEnable(ModuleContext ctx) {
        ShinobiLogger.module(ID, "Enabling Jutsu module...");
        
        // 1. Загружаем JSON
        JutsuLoader.load();
        
        // 2. Валидируем (без краша!)
        JutsuJsonValidator.validateAll(); 
        
        ShinobiLogger.module(ID, "Loaded " + JutsuRegistry.size() + " jutsu definitions.");
    }

    @Override
    public void onDisable(ModuleContext ctx) {
        ShinobiLogger.module(ID, "Jutsu module disabled.");
    }

    @Override
    public void registerCommands(ModuleContext ctx, CommandDispatcher<ServerCommandSource> dispatcher) {
        // JutsuCommands.register(dispatcher);
    }

    @Override
    public void onServerTick(ModuleContext ctx, MinecraftServer server) {
        JutsuCastService.instance().serverTick(server);
        // JutsuCooldownService.serverTick(server); // Добавим позже
    }
    
    @Override
    public void onClientInit(ModuleContext ctx) {
        // JutsuKeyBindings.register();
    }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\JutsuModule.java" $jutsuModuleJava

Write-Host "`n=== Setup Complete! ===" -ForegroundColor Green
Write-Host "Next step: Run '.\gradlew.bat build' to verify compilation." -ForegroundColor Yellow
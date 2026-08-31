# Setup-JutsuSprint4-Integration.ps1
# Мастер-скрипт для интеграции Jutsu с ядром (Gateway, Views, Events, Config, Stubs)
# Требует запуска из корневой директории мода (где находится build.gradle)

$ErrorActionPreference = "Stop"
$rootPath = Get-Location

Write-Host "=== ShinobiCore: Jutsu Module Sprint 4 (Integration) Setup ===" -ForegroundColor Cyan

# 1. Создание структуры директорий
$dirs = @(
    "src\main\java\com\example\shinobicore\modules\jutsu\config",
    "src\main\java\com\example\shinobicore\modules\jutsu\gateway",
    "src\main\java\com\example\shinobicore\modules\jutsu\view",
    "src\main\java\com\example\shinobicore\modules\jutsu\event"
)

foreach ($dir in $dirs) {
    $fullPath = Join-Path $rootPath $dir
    if (!(Test-Path $fullPath)) {
        New-Item -ItemType Directory -Force -Path $fullPath | Out-Null
        Write-Host "[OK] Created directory: $dir" -ForegroundColor Green
    }
}

# 2. Функция для безопасной записи файлов (UTF-8 без BOM)
function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText((Join-Path $rootPath $Path), $Content, $utf8NoBom)
    Write-Host "[OK] Written: $Path" -ForegroundColor Green
}

# 3. Config
Write-Host "`n--- Creating Config ---" -ForegroundColor Cyan

$jutsuConfigJava = @'
package com.example.shinobicore.modules.jutsu.config;

import com.google.gson.JsonObject;

public final class JutsuConfig {
    private static JutsuConfig INSTANCE;

    public final boolean enabled;
    public final boolean debug;
    public final int slotCount;
    public final int castQueueSize;
    public final float interruptOnDamageChance;
    public final boolean interruptOnMovement;
    public final float partialRefundOnCancel;
    public final int minCooldownTicks;
    public final int maxJutsuLevel;

    private JutsuConfig(JsonObject json) {
        this.enabled = getBool(json, "enabled", true);
        this.debug = getBool(json, "debug", false);
        
        JsonObject slots = getObj(json, "slots");
        this.slotCount = getInt(slots, "count", 3);
        
        JsonObject cast = getObj(json, "cast");
        this.castQueueSize = getInt(cast, "queueSize", 1);
        this.interruptOnDamageChance = getFloat(cast, "interruptOnDamageChance", 0.5f);
        this.interruptOnMovement = getBool(cast, "interruptOnMovement", true);
        this.partialRefundOnCancel = getFloat(cast, "partialRefundOnCancel", 0.3f);
        
        JsonObject cooldown = getObj(json, "cooldown");
        this.minCooldownTicks = getInt(cooldown, "minCooldownTicks", 1);
        
        JsonObject levels = getObj(json, "levels");
        this.maxJutsuLevel = getInt(levels, "maxLevel", 10);
    }

    public static void load(JsonObject json) {
        INSTANCE = new JutsuConfig(json);
    }

    public static JutsuConfig get() {
        if (INSTANCE == null) load(new JsonObject()); // Fallback to defaults
        return INSTANCE;
    }

    private static boolean getBool(JsonObject o, String k, boolean def) { return o != null && o.has(k) ? o.get(k).getAsBoolean() : def; }
    private static int getInt(JsonObject o, String k, int def) { return o != null && o.has(k) ? o.get(k).getAsInt() : def; }
    private static float getFloat(JsonObject o, String k, float def) { return o != null && o.has(k) ? o.get(k).getAsFloat() : def; }
    private static JsonObject getObj(JsonObject o, String k) { return o != null && o.has(k) ? o.getAsJsonObject(k) : new JsonObject(); }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\config\JutsuConfig.java" $jutsuConfigJava

# 4. Events
Write-Host "`n--- Creating Events ---" -ForegroundColor Cyan

$jutsuEventsJava = @'
package com.example.shinobicore.modules.jutsu.event;

import net.minecraft.server.network.ServerPlayerEntity;

public final class JutsuEvents {
    public record JutsuCastStartedEvent(ServerPlayerEntity caster, String jutsuId, int slot) {}
    public record JutsuCastFinishedEvent(ServerPlayerEntity caster, String jutsuId, boolean success) {}
    public record JutsuCastCancelledEvent(ServerPlayerEntity caster, String jutsuId, String reason) {}
    public record JutsuCooldownChangedEvent(ServerPlayerEntity player, String jutsuId, int remainingTicks) {}
    public record JutsuSlotChangedEvent(ServerPlayerEntity player, int slot, String jutsuId) {}
    
    private JutsuEvents() {}
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\event\JutsuEvents.java" $jutsuEventsJava

# 5. Gateway (For AI)
Write-Host "`n--- Creating Gateway ---" -ForegroundColor Cyan

$jutsuCastGatewayImplJava = @'
package com.example.shinobicore.modules.jutsu.gateway;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.jutsu.cast.JutsuCastService;
import com.example.shinobicore.modules.jutsu.data.JutsuDefinition;
import com.example.shinobicore.modules.jutsu.data.JutsuRegistry;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.network.ServerPlayerEntity;

import java.util.List;

public final class JutsuCastGatewayImpl {
    
    public boolean tryCast(LivingEntity caster, String jutsuId, Entity target) {
        JutsuDefinition def = JutsuRegistry.get(jutsuId).orElse(null);
        if (def == null) {
            ShinobiLogger.module("jutsu", "Gateway: unknown jutsu " + jutsuId);
            return false;
        }
        
        // For non-player casters (enemies), we bypass loadout/slot logic
        // and go straight to the cast service. 
        // Note: Full AI support requires extending JutsuCastService to accept LivingEntity instead of just ServerPlayerEntity.
        if (caster instanceof ServerPlayerEntity player) {
            JutsuCastService.instance().requestCast(player, jutsuId, 0, System.currentTimeMillis(), caster.getYaw(), caster.getPitch());
            return true;
        }
        
        ShinobiLogger.module("jutsu", "Gateway: AI casting for non-player entities is a Sprint 2 feature.");
        return false;
    }

    public boolean isJutsuAvailable(String jutsuId) {
        return JutsuRegistry.get(jutsuId).isPresent();
    }

    public List<String> getJutsuByRank(String rank) {
        return JutsuRegistry.all().stream()
                .map(JutsuDefinition::id)
                .toList();
    }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\gateway\JutsuCastGatewayImpl.java" $jutsuCastGatewayImplJava

# 6. Views (For HUD/Visual)
Write-Host "`n--- Creating Views ---" -ForegroundColor Cyan

$jutsuVisualViewJava = @'
package com.example.shinobicore.modules.jutsu.view;

import com.example.shinobicore.modules.jutsu.cast.CastPhase;

public interface JutsuVisualView {
    boolean isCasting();
    float getCastProgress();
    CastPhase getCurrentPhase();
    String getCurrentJutsuId();
    boolean isCharging();
    boolean isQueued();
    String getQueuedJutsuId();
    
    String getSlotJutsuId(int slot);
    int getSelectedSlot();
    int getSlotCount();
    
    int getCooldownTicks(String jutsuId);
    int getMaxCooldownTicks(String jutsuId);
    float getCooldownProgress(String jutsuId);
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\view\JutsuVisualView.java" $jutsuVisualViewJava

$jutsuVisualViewImplJava = @'
package com.example.shinobicore.modules.jutsu.view;

import com.example.shinobicore.modules.jutsu.cast.CastPhase;
import com.example.shinobicore.modules.jutsu.cast.JutsuCastService;
import com.example.shinobicore.modules.jutsu.cooldown.JutsuCooldownService;
import com.example.shinobicore.modules.jutsu.slot.JutsuLoadout;
import com.example.shinobicore.modules.jutsu.slot.JutsuSlotService;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.server.network.ServerPlayerEntity;

import java.util.UUID;

public final class JutsuVisualViewImpl implements JutsuVisualView {
    private final ServerPlayerEntity player;
    private final UUID uuid;

    public JutsuVisualViewImpl(PlayerEntity player) {
        this.player = (ServerPlayerEntity) player;
        this.uuid = player.getUuid();
    }

    @Override public boolean isCasting() { return false; /* TODO: Read from CastService active sessions */ }
    @Override public float getCastProgress() { return 0.0f; }
    @Override public CastPhase getCurrentPhase() { return CastPhase.IDLE; }
    @Override public String getCurrentJutsuId() { return ""; }
    @Override public boolean isCharging() { return getCurrentPhase() == CastPhase.CHARGE; }
    @Override public boolean isQueued() { return false; }
    @Override public String getQueuedJutsuId() { return null; }

    @Override
    public String getSlotJutsuId(int slot) {
        return JutsuSlotService.getLoadout(player).getSlot(slot);
    }

    @Override
    public int getSelectedSlot() {
        return JutsuSlotService.getLoadout(player).selectedSlot();
    }

    @Override
    public int getSlotCount() {
        return 3; // From config
    }

    @Override
    public int getCooldownTicks(String jutsuId) {
        return JutsuCooldownService.getRemainingTicks(uuid, jutsuId);
    }

    @Override
    public int getMaxCooldownTicks(String jutsuId) {
        // Simplified: would need to read from JutsuDefinition
        return 0; 
    }

    @Override
    public float getCooldownProgress(String jutsuId) {
        int max = getMaxCooldownTicks(jutsuId);
        if (max <= 0) return 0.0f;
        return 1.0f - ((float) getCooldownTicks(jutsuId) / max);
    }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\view\JutsuVisualViewImpl.java" $jutsuVisualViewImplJava

# 7. Stub Behaviors (To pass validation)
Write-Host "`n--- Creating Stub Behaviors ---" -ForegroundColor Cyan

$stubBehaviors = @("AoeBehavior", "WallBehavior", "GenjutsuBehavior", "UtilityBehavior", "MeleeBufferBehavior")
$stubIds = @("aoe", "wall", "genjutsu", "utility", "melee_buffer")

for ($i = 0; $i -lt $stubBehaviors.Count; $i++) {
    $className = $stubBehaviors[$i]
    $behaviorId = $stubIds[$i]
    
    $code = @"
package com.example.shinobicore.modules.jutsu.behavior;

import com.example.shinobicore.core.log.ShinobiLogger;

public final class $className implements JutsuBehavior {
    public static final String ID = "$behaviorId";

    @Override public String id() { return ID; }

    @Override
    public void onRelease(BehaviorContext ctx) {
        ShinobiLogger.module("jutsu", "Stub behavior '$behaviorId' triggered for " + ctx.jutsuId());
        // TODO: Implement actual logic in Sprint 2
    }
}
"@
    Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\behavior\$className.java" $code
}

# 8. Update BehaviorRegistry to include stubs
Write-Host "`n--- Updating BehaviorRegistry ---" -ForegroundColor Cyan

$behaviorRegistryUpdatedJava = @'
package com.example.shinobicore.modules.jutsu.behavior;

import com.example.shinobicore.core.log.ShinobiLogger;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

public final class BehaviorRegistry {
    private static final Map<String, JutsuBehavior> BEHAVIORS = new ConcurrentHashMap<>();

    public static void register(JutsuBehavior behavior) {
        if (behavior != null && behavior.id() != null) {
            BEHAVIORS.put(behavior.id(), behavior);
        }
    }

    public static Optional<JutsuBehavior> get(String id) {
        return Optional.ofNullable(BEHAVIORS.get(id));
    }

    public static boolean isRegistered(String id) {
        return BEHAVIORS.containsKey(id);
    }

    public static void registerDefaults() {
        register(new ProjectileBehavior());
        register(new DashBehavior());
        register(new AoeBehavior());
        register(new WallBehavior());
        register(new GenjutsuBehavior());
        register(new UtilityBehavior());
        register(new MeleeBufferBehavior());
        ShinobiLogger.module("jutsu", "All 7 default behaviors registered.");
    }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\behavior\BehaviorRegistry.java" $behaviorRegistryUpdatedJava

# 9. Update JutsuModule to wire everything together
Write-Host "`n--- Updating JutsuModule.java ---" -ForegroundColor Cyan

$jutsuModuleFinalJava = @'
package com.example.shinobicore.modules.jutsu;

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
        ctx.views().register(JutsuVisualView.class, player -> {
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
        ctx.events().subscribe(com.example.shinobicore.core.event.PlayerDiedEvent.class, e -> {
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
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\JutsuModule.java" $jutsuModuleFinalJava

Write-Host "`n=== Setup Complete! ===" -ForegroundColor Green
Write-Host "Next step: Run '.\gradlew.bat build' to verify compilation." -ForegroundColor Yellow
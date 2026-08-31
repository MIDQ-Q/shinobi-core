# Setup-JutsuFoundation.ps1
# Мастер-скрипт для создания базовой структуры модуля Jutsu (Sprint 1, Step 1)
# Требует запуска из корневой директории мода (где находится build.gradle)

$ErrorActionPreference = "Stop"
$rootPath = Get-Location

Write-Host "=== ShinobiCore: Jutsu Module Foundation Setup ===" -ForegroundColor Cyan

# 1. Создание структуры директорий
$dirs = @(
    "src\main\resources\data\shinobicore\jutsu",
    "src\main\java\com\example\shinobicore\modules\jutsu\data"
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

# 2. Функция для безопасной записи файлов (UTF-8 без BOM)
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

# 4. Создание Java файлов
Write-Host "`n--- Creating Java Classes ---" -ForegroundColor Cyan

$jutsuModuleJava = @'
package com.example.shinobicore.modules.jutsu;

import com.example.shinobicore.core.api.ClientAwareModule;
import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.log.ShinobiLogger;
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
        // JutsuJsonValidator.validateAll(); 
        
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
        // JutsuCastService.serverTick(server);
        // JutsuCooldownService.serverTick(server);
    }
    
    @Override
    public void onClientInit(ModuleContext ctx) {
        // JutsuKeyBindings.register();
    }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\JutsuModule.java" $jutsuModuleJava

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

Write-Host "`n=== Setup Complete! ===" -ForegroundColor Green
Write-Host "Next step: Register JutsuModule in fabric.mod.json" -ForegroundColor Yellow
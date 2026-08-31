$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding $false
$root = 'E:\Games\mod'
$srcBase = Join-Path $root 'src\main\java\com\example\shinobicore'

function Write-File($path, $content) {
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $content, $utf8)
    Write-Host " [OK] $([System.IO.Path]::GetFileName($path))" -ForegroundColor Green
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ' FIXING STATIC API MISMATCH' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ''

# ============================================================
# 1. Rewrite core/event/CoreEvents.java as STATIC singleton
# ============================================================
Write-Host '[1/6] Rewriting CoreEvents as static singleton' -ForegroundColor Yellow
$coreEventsImpl = @'
package com.example.shinobicore.core.event;

import com.example.shinobicore.core.log.ShinobiLogger;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.function.Consumer;

/**
 * Global event bus. Static singleton - modules call CoreEvents.publish(...) directly.
 */
public final class CoreEvents {

    private static final Map<Class<?>, CopyOnWriteArrayList<Consumer<?>>> LISTENERS =
            new ConcurrentHashMap<>();

    private CoreEvents() {}

    public static <T> void subscribe(Class<T> type, Consumer<T> listener) {
        LISTENERS
                .computeIfAbsent(type, k -> new CopyOnWriteArrayList<>())
                .add(listener);
    }

    @SuppressWarnings("unchecked")
    public static <T> void publish(T event) {
        CopyOnWriteArrayList<Consumer<?>> list = LISTENERS.get(event.getClass());
        if (list == null || list.isEmpty()) {
            return;
        }

        for (Consumer<?> raw : list) {
            try {
                ((Consumer<T>) raw).accept(event);
            } catch (Throwable t) {
                ShinobiLogger.error(
                        "core",
                        "Event listener failed for event: " + event.getClass().getSimpleName(),
                        t
                );
            }
        }
    }
}
'@
Write-File (Join-Path $srcBase 'core\event\CoreEvents.java') $coreEventsImpl

# ============================================================
# 2. Rewrite core/view/CoreViews.java as STATIC singleton
# ============================================================
Write-Host '[2/6] Rewriting CoreViews as static singleton' -ForegroundColor Yellow
$coreViewsImpl = @'
package com.example.shinobicore.core.view;

import com.example.shinobicore.core.log.ShinobiLogger;
import net.minecraft.entity.player.PlayerEntity;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Global view registry. Static singleton - modules call CoreViews.get(player, Type) directly.
 */
public final class CoreViews {

    @FunctionalInterface
    public interface ViewFactory<T> {
        Optional<T> create(PlayerEntity player);
    }

    private static final Map<Class<?>, ViewFactory<?>> FACTORIES = new ConcurrentHashMap<>();

    private CoreViews() {}

    public static <T> void register(Class<T> type, ViewFactory<T> factory) {
        FACTORIES.put(type, factory);
    }

    @SuppressWarnings("unchecked")
    public static <T> Optional<T> get(PlayerEntity player, Class<T> type) {
        ViewFactory<?> raw = FACTORIES.get(type);
        if (raw == null) {
            return Optional.empty();
        }

        try {
            return ((ViewFactory<T>) raw).create(player);
        } catch (Throwable t) {
            ShinobiLogger.error("core", "View factory failed: " + type.getSimpleName(), t);
            return Optional.empty();
        }
    }
}
'@
Write-File (Join-Path $srcBase 'core\view\CoreViews.java') $coreViewsImpl

# ============================================================
# 3. Simplify core/api/CoreEvents.java to static delegator
# ============================================================
Write-Host '[3/6] Simplifying core/api/CoreEvents alias' -ForegroundColor Yellow
$coreEventsAlias = @'
package com.example.shinobicore.core.api;

import java.util.function.Consumer;

/**
 * Convenience alias in core.api. Delegates to core.event.CoreEvents.
 * Use either import - both work identically.
 */
public final class CoreEvents {
    private CoreEvents() {}

    public static <T> void subscribe(Class<T> type, Consumer<T> listener) {
        com.example.shinobicore.core.event.CoreEvents.subscribe(type, listener);
    }

    public static <T> void publish(T event) {
        com.example.shinobicore.core.event.CoreEvents.publish(event);
    }
}
'@
Write-File (Join-Path $srcBase 'core\api\CoreEvents.java') $coreEventsAlias

# ============================================================
# 4. Simplify core/api/CoreViews.java alias (create new)
# ============================================================
Write-Host '[4/6] Creating core/api/CoreViews alias' -ForegroundColor Yellow
$coreViewsAlias = @'
package com.example.shinobicore.core.api;

import net.minecraft.entity.player.PlayerEntity;
import java.util.Optional;

/**
 * Convenience alias in core.api. Delegates to core.view.CoreViews.
 */
public final class CoreViews {
    private CoreViews() {}

    public static <T> void register(Class<T> type, com.example.shinobicore.core.view.CoreViews.ViewFactory<T> factory) {
        com.example.shinobicore.core.view.CoreViews.register(type, factory);
    }

    public static <T> Optional<T> get(PlayerEntity player, Class<T> type) {
        return com.example.shinobicore.core.view.CoreViews.get(player, type);
    }
}
'@
Write-File (Join-Path $srcBase 'core\api\CoreViews.java') $coreViewsAlias

# ============================================================
# 5. Update ModuleManager to not need instance CoreEvents/CoreViews
# ============================================================
Write-Host '[5/6] Updating ModuleManager for static APIs' -ForegroundColor Yellow
$moduleManagerPath = Join-Path $srcBase 'core\module\ModuleManager.java'
if (Test-Path $moduleManagerPath) {
    $content = [System.IO.File]::ReadAllText($moduleManagerPath, [System.Text.Encoding]::UTF8)
    $content = $content.Replace("`r`n", "`n")

    # Remove instance fields for events/views and use static calls
    $content = $content -replace 'private static CoreEvents events;\s*', ''
    $content = $content -replace 'private static CoreViews views;\s*', ''
    $content = $content -replace 'events = eventsIn;\s*', ''
    $content = $content -replace 'views = viewsIn;\s*', ''

    # Update init signature to not require events/views params
    $content = $content -replace 'public static void init\(\s*CoreEvents eventsIn,\s*CoreViews viewsIn,\s*ModuleConfigLoader configsIn\s*\)', 'public static void init(ModuleConfigLoader configsIn)'

    # Update contextFor to not pass events/views
    $content = $content -replace 'new ModuleContext\(module\.id\(\), events, views, configs\)', 'new ModuleContext(module.id(), configs)'
    $content = $content -replace 'new ModuleContext\(id, events, views, configs\)', 'new ModuleContext(id, configs)'

    [System.IO.File]::WriteAllText($moduleManagerPath, $content, $utf8)
    Write-Host " [OK] ModuleManager.java updated" -ForegroundColor Green
} else {
    Write-Host " [WARN] ModuleManager.java not found" -ForegroundColor Yellow
}

# ============================================================
# 6. Update ModuleContext to not hold events/views
# ============================================================
Write-Host '[6/6] Updating ModuleContext' -ForegroundColor Yellow
$moduleContextPath = Join-Path $srcBase 'core\api\ModuleContext.java'
$moduleContextContent = @'
package com.example.shinobicore.core.api;

import com.example.shinobicore.core.config.ModuleConfigLoader;

public final class ModuleContext {

    private final String moduleId;
    private final ModuleConfigLoader configs;

    public ModuleContext(String moduleId, ModuleConfigLoader configs) {
        this.moduleId = moduleId;
        this.configs = configs;
    }

    public String moduleId() {
        return moduleId;
    }

    public ModuleConfigLoader configs() {
        return configs;
    }
}
'@
Write-File $moduleContextPath $moduleContextContent

# ============================================================
# 7. Update ShinobiCoreMod.java to use new static APIs
# ============================================================
Write-Host ''
Write-Host '[BONUS] Updating ShinobiCoreMod.java' -ForegroundColor Yellow
$mainModPath = Join-Path $srcBase 'ShinobiCoreMod.java'
if (Test-Path $mainModPath) {
    $content = [System.IO.File]::ReadAllText($mainModPath, [System.Text.Encoding]::UTF8)
    $content = $content.Replace("`r`n", "`n")

    # Remove EVENTS and VIEWS static fields
    $content = $content -replace 'private static final CoreEvents EVENTS = new CoreEvents\(\);\s*', ''
    $content = $content -replace 'private static final CoreViews VIEWS = new CoreViews\(\);\s*', ''

    # Update ModuleManager.init call
    $content = $content -replace 'ModuleManager\.init\(EVENTS, VIEWS, CONFIGS\)', 'ModuleManager.init(CONFIGS)'

    # Update ModuleContext creation in command registration
    $content = $content -replace 'new ModuleContext\(entry\.module\(\)\.id\(\), EVENTS, VIEWS, CONFIGS\)', 'new ModuleContext(entry.module().id(), CONFIGS)'

    [System.IO.File]::WriteAllText($mainModPath, $content, $utf8)
    Write-Host " [OK] ShinobiCoreMod.java updated" -ForegroundColor Green
} else {
    Write-Host " [WARN] ShinobiCoreMod.java not found" -ForegroundColor Yellow
}

# ============================================================
# BUILD
# ============================================================
Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ' RUNNING BUILD' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ''

Push-Location $root
try {
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = & '.\gradlew.bat' build 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP

    Write-Host ''
    if ($exitCode -eq 0) {
        Write-Host '============================================================' -ForegroundColor Green
        Write-Host ' [PASS] BUILD SUCCESSFUL!' -ForegroundColor Green
        Write-Host '============================================================' -ForegroundColor Green
        Write-Host ''
        Write-Host 'Static API mismatch is now fixed.' -ForegroundColor White
        Write-Host 'Run: .\gradlew.bat runClient' -ForegroundColor Yellow
    } else {
        Write-Host '============================================================' -ForegroundColor Red
        Write-Host ' [FAIL] BUILD FAILED' -ForegroundColor Red
        Write-Host '============================================================' -ForegroundColor Red
        Write-Host ''
        Write-Host 'Remaining errors:' -ForegroundColor Yellow
        $out | Where-Object { $_ -match 'error:' -and $_ -notmatch 'Env.CLIENT' } | Select-Object -First 30 | ForEach-Object {
            Write-Host " $_" -ForegroundColor Red
        }
    }
} finally {
    Pop-Location
}
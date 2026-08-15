$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main\java\com\example\shinobicore"

function Write-File($p, $c) {
    $dir = [System.IO.Path]::GetDirectoryName($p)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] $p"
}

Write-Host "=== ИСПРАВЛЕНИЕ КРИТИЧЕСКИХ БАГОВ РЕНДЕРА И КРАША ===" -ForegroundColor Cyan

# ==========================================
# 1. TickScheduler (Fix ConcurrentModificationException)
# ==========================================
Write-File "$base\util\TickScheduler.java" @'
package com.example.shinobicore.util;

import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.minecraft.server.world.ServerWorld;

import java.util.ArrayList;
import java.util.List;
import java.util.function.Consumer;

public class TickScheduler {
    private static final List<Task> TASKS = new ArrayList<>();
    private static boolean registered = false;

    public static void register() {
        if (registered) return;
        registered = true;
        ServerTickEvents.START_WORLD_TICK.register(world -> {
            List<Task> currentTasks;
            synchronized (TASKS) {
                // Делаем снапшот списка и очищаем оригинал, чтобы избежать ConcurrentModificationException
                currentTasks = new ArrayList<>(TASKS);
                TASKS.clear();
            }
            
            List<Task> toKeep = new ArrayList<>();
            for (Task t : currentTasks) {
                if (t.world != world) {
                    toKeep.add(t);
                    continue;
                }
                t.delay--;
                if (t.delay > 0) {
                    toKeep.add(t);
                    continue;
                }
                t.delay = t.interval;
                try { 
                    t.action.accept(world); 
                } catch (Exception ignored) {}
                t.count--;
                if (t.count > 0) {
                    toKeep.add(t);
                }
            }
            synchronized (TASKS) {
                TASKS.addAll(toKeep);
            }
        });
    }

    public static void schedule(ServerWorld world, int delay, int interval, int count, Consumer<ServerWorld> action) {
        register();
        synchronized (TASKS) {
            TASKS.add(new Task(world, delay, interval, count, action));
        }
    }

    private static class Task {
        final ServerWorld world;
        int delay;
        final int interval;
        int count;
        final Consumer<ServerWorld> action;

        Task(ServerWorld w, int d, int i, int c, Consumer<ServerWorld> a) {
            world = w; delay = d; interval = i; count = c; action = a;
        }
    }
}
'@

# ==========================================
# 2. Fix getOwner() in all entities (3D models invisible fix)
# ==========================================
$entities = @(
    "$base\entity\RasenganHandEntity.java",
    "$base\entity\RasenshurikenEntity.java",
    "$base\entity\NinjaProjectileEntity.java",
    "$base\entity\ShurikenEntity.java"
)

foreach ($e in $entities) {
    if (Test-Path $e) {
        $c = [System.IO.File]::ReadAllText($e, $utf8)
        # Regex для поиска сломанного getOwner(), который возвращал null на клиенте
        $pattern = 'if\s*\(\s*this\.getWorld\(\)\s*instanceof\s*ServerWorld\s+\w+\s*\)\s*return\s+\w+\.getPlayerByUuid\(ownerId\);\s*return\s*null;'
        $replacement = 'return this.getWorld().getPlayerByUuid(ownerId);'
        
        if ([regex]::IsMatch($c, $pattern)) {
            $c = [regex]::Replace($c, $pattern, $replacement)
            [System.IO.File]::WriteAllText($e, $c, $utf8)
            Write-Host "[OK] Fixed getOwner() (Client-side discard fix) in $([System.IO.Path]::GetFileName($e))" -ForegroundColor Green
        } else {
            Write-Host "[SKIP] getOwner() already fixed or different format in $([System.IO.Path]::GetFileName($e))" -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  КРИТИЧЕСКИЕ ИСПРАВЛЕНИЯ ПРИМЕНЕНЫ                       ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "Почему не работали:" -ForegroundColor Yellow
Write-Host "1. 3D модели не появлялись: метод getOwner() на клиенте возвращал null,"
Write-Host "   из-за чего сущности (Расенган в руке, Расенсюрикен) удаляли себя (discard)"
Write-Host "   в первом же тике на клиенте. Теперь они корректно находят игрока."
Write-Host "2. Краш сервера (ConcurrentModificationException): TickScheduler"
Write-Host "   изменял список задач во время итерации. Теперь используется безопасное копирование."
Write-Host ""
Write-Host "Запускайте:" -ForegroundColor Cyan
Write-Host ".\gradlew.bat build" -ForegroundColor White
Write-Host ".\gradlew.bat runClient" -ForegroundColor White
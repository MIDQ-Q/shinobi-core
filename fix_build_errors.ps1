$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main\java\com\example\shinobicore"

Write-Host "=== ИСПРАВЛЕНИЕ ОШИБОК КОМПИЛЯЦИИ ===" -ForegroundColor Cyan

# 1. Fix ClientInputHandler.java (Опечатка ByteBuf / Unpooled)
$cih = "$base\client\ClientInputHandler.java"
if (Test-Path $cih) {
    $c = [System.IO.File]::ReadAllText($cih, $utf8)
    $c = $c.Replace("io.netty.buffer.Unpooled buffer = io.netty.buffer.Unpooled.buffer();", "io.netty.buffer.ByteBuf buffer = io.netty.buffer.Unpooled.buffer();")
    [System.IO.File]::WriteAllText($cih, $c, $utf8)
    Write-Host "[OK] Исправлен тип Unpooled в ClientInputHandler.java" -ForegroundColor Green
}

# 2. Восстановление ShinobiCore.java из Git (Возвращает sendChakraSync, sendStatsSync и т.д.)
Write-Host "Попытка восстановить ShinobiCore.java из Git..." -ForegroundColor Yellow
git -C "E:\Games\mod" checkout HEAD -- "src/main/java/com/example/shinobicore/ShinobiCore.java" 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] ShinobiCore.java успешно восстановлен из Git" -ForegroundColor Green
} else {
    Write-Host "[!] Git не нашел файл. Если ShinobiCore.java все еще сломан, вам нужно скопировать его из вашего бэкапа!" -ForegroundColor Red
}

# 3. Fix Entity classes (Добавляем публичный renderTicks)
$entities = @("$base\entity\RasenganHandEntity.java", "$base\entity\RasenshurikenEntity.java")
foreach ($e in $entities) {
    if (Test-Path $e) {
        $c = [System.IO.File]::ReadAllText($e, $utf8)
        if (-not $c.Contains("public int renderTicks")) {
            $c = $c.Replace("private int age = 0;", "private int age = 0;`n    public int renderTicks = 0;")
            if (-not $c.Contains("this.renderTicks++;")) {
                $c = $c.Replace("public void tick() {", "public void tick() {`n        this.renderTicks++;")
            }
            [System.IO.File]::WriteAllText($e, $c, $utf8)
            Write-Host "[OK] Добавлен renderTicks в $([System.IO.Path]::GetFileName($e))" -ForegroundColor Green
        }
    }
}

# 4. Fix Renderers (Заменяем entity.age на entity.renderTicks)
$renderers = @("$base\entity\RasenganHandRenderer.java", "$base\entity\RasenshurikenRenderer.java")
foreach ($r in $renderers) {
    if (Test-Path $r) {
        $c = [System.IO.File]::ReadAllText($r, $utf8)
        if ($c.Contains("entity.age")) {
            $c = $c.Replace("entity.age", "entity.renderTicks")
            [System.IO.File]::WriteAllText($r, $c, $utf8)
            Write-Host "[OK] Заменено entity.age на entity.renderTicks в $([System.IO.Path]::GetFileName($r))" -ForegroundColor Green
        }
    }
}

# 5. Fix RasenganBehavior.java (Перезаписываем чистой версией без сломанных getEntities/spawnParticles)
$rb = "$base\jutsu\custom\RasenganBehavior.java"
$cleanRb = @'
package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.entity.RasenganHandEntity;
import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;

public class RasenganBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;

        // Удаляем существующий расенган если есть
        for (var e : world.getOtherEntities(player, player.getBoundingBox().expand(5))) {
            if (e instanceof RasenganHandEntity rhe) {
                rhe.discard();
            }
        }

        // Создаём 3D сферу в руке (частицы обрабатываются самим Entity)
        RasenganHandEntity entity = new RasenganHandEntity(world, player, damage);
        world.spawnEntity(entity);

        player.sendMessage(Text.literal("\u00a7b\u2726 Rasengan ready! Attack to strike!"), false);
        JutsuLogger.logBehavior("rasengan",
                String.format("HAND SPHERE: player=%s, damage=%.1f",
                        player.getName().getString(), damage));
    }
}
'@
[System.IO.File]::WriteAllText($rb, $cleanRb, $utf8)
Write-Host "[OK] RasenganBehavior.java перезаписан чистой версией" -ForegroundColor Green

Write-Host "`n=== ВСЕ ОШИБКИ ИСПРАВЛЕНЫ ===" -ForegroundColor Cyan
Write-Host "Теперь запустите: .\gradlew.bat build" -ForegroundColor Yellow
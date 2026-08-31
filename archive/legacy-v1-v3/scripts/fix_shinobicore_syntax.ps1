$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$file = "E:\Games\mod\src\main\java\com\example\shinobicore\ShinobiCore.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)

# 1. Удаляем "заблудившиеся" хендлеры, где бы они ни находились (используем Regex)
$c = $c -replace '(?s)// === RASENSHURIKEN THROW HANDLER ===.*?// === RASENGAN STRIKE HANDLER ===.*?\}\);[ \t\r\n]*', ''
$c = $c -replace '(?s)// === RASENGAN STRIKE HANDLER ===.*?\}\);[ \t\r\n]*', ''
$c = $c -replace '(?s)// === RASENSHURIKEN THROW HANDLER ===.*?\}\);[ \t\r\n]*', ''

# 2. Чистый код хендлеров
$handlers = @'

        // === RASENSHURIKEN THROW HANDLER ===
        ServerPlayNetworking.registerGlobalReceiver(ModPackets.THROW_RASENSHURIKEN_ID,
            (server, player, handler, buf, responseSender) -> {
                server.execute(() -> {
                    for (var e : player.getWorld().getOtherEntities(player, player.getBoundingBox().expand(3))) {
                        if (e instanceof RasenshurikenEntity rs && !rs.isLaunched()) {
                            Vec3d dir = player.getRotationVector();
                            rs.launch(dir);
                            ShinobiCore.LOGGER.info("[SERVER] Rasenshuriken launched by {}", player.getName().getString());
                            break;
                        }
                    }
                });
            });

        // === RASENGAN STRIKE HANDLER ===
        ServerPlayNetworking.registerGlobalReceiver(ModPackets.RASENGAN_STRIKE_ID,
            (server, player, handler, buf, responseSender) -> {
                server.execute(() -> {
                    RasenganHandEntity rasengan = null;
                    for (var e : player.getWorld().getOtherEntities(player, player.getBoundingBox().expand(3))) {
                        if (e instanceof RasenganHandEntity rg) {
                            rasengan = rg;
                            break;
                        }
                    }
                    if (rasengan != null) {
                        float damage = rasengan.getDamage();
                        Vec3d look = player.getRotationVector();
                        Vec3d strikeCenter = player.getPos().add(look.multiply(1.5)).add(0, 0.5, 0);
                        float radius = 2.5f;
                        for (var e : player.getWorld().getOtherEntities(player, new net.minecraft.util.math.Box(strikeCenter, strikeCenter).expand(radius))) {
                            if (e instanceof net.minecraft.entity.LivingEntity liv) {
                                liv.damage(player.getDamageSources().magic(), damage);
                                Vec3d kb = liv.getPos().subtract(player.getPos()).normalize().multiply(2.0);
                                liv.addVelocity(kb.x, 0.5, kb.z);
                                liv.velocityModified = true;
                            }
                        }
                        if (player.getWorld() instanceof net.minecraft.server.world.ServerWorld sw) {
                            for (int i = 0; i < 40; i++) {
                                double a = (i / 40.0) * Math.PI * 2;
                                double r = radius * Math.random();
                                sw.spawnParticles(net.minecraft.particle.ParticleTypes.CLOUD, strikeCenter.x + Math.cos(a) * r, strikeCenter.y + Math.random() * 1.5, strikeCenter.z + Math.sin(a) * r, 3, 0.1, 0.1, 0.1, 0.05);
                            }
                            sw.spawnParticles(net.minecraft.particle.ParticleTypes.EXPLOSION, strikeCenter.x, strikeCenter.y, strikeCenter.z, 2, 0.3, 0.3, 0.3, 0.02);
                            sw.playSound(null, player.getBlockPos(), net.minecraft.sound.SoundEvents.ENTITY_GENERIC_EXPLODE, net.minecraft.sound.SoundCategory.PLAYERS, 1.5f, 1.2f);
                        }
                        rasengan.discard();
                        ShinobiCore.LOGGER.info("[SERVER] Rasengan strike by {}", player.getName().getString());
                    }
                });
            });
'@

# 3. Находим метод onInitialize() и аккуратно вставляем код ПЕРЕД его закрывающей скобкой
$onInitIdx = $c.IndexOf("public void onInitialize()")
if ($onInitIdx -lt 0) { $onInitIdx = $c.IndexOf("public void onInitializeServer()") }

if ($onInitIdx -ge 0) {
    $openBrace = $c.IndexOf("{", $onInitIdx)
    $braceCount = 1
    $idx = $openBrace + 1
    # Считаем скобки, чтобы найти точное место конца метода
    while ($braceCount -gt 0 -and $idx -lt $c.Length) {
        if ($c[$idx] -eq '{') { $braceCount++ }
        elseif ($c[$idx] -eq '}') { $braceCount-- }
        $idx++
    }
    $insertIdx = $idx - 1
    $c = $c.Insert($insertIdx, $handlers)
    Write-Host "[OK] Хендлеры успешно перемещены внутрь onInitialize()!"
} else {
    Write-Host "[!] Метод onInitialize() не найден."
}

# 4. Гарантируем наличие нужных импортов
$requiredImports = @(
    "import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;",
    "import net.minecraft.util.math.Vec3d;",
    "import com.example.shinobicore.entity.RasenshurikenEntity;",
    "import com.example.shinobicore.entity.RasenganHandEntity;"
)
foreach ($imp in $requiredImports) {
    if (-not $c.Contains($imp)) {
        $c = $c.Replace("package com.example.shinobicore;", "package com.example.shinobicore;`n$imp")
    }
}

[System.IO.File]::WriteAllText($file, $c, $utf8)
Write-Host "`n=== СИНТАКСИС ИСПРАВЛЕН ==="
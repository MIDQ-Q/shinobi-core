$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main"

function Write-File($p, $c) {
    $dir = [System.IO.Path]::GetDirectoryName($p)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] $p" -ForegroundColor Green
}

Write-Host "=== ПРИМЕНЕНИЕ ФИНАЛЬНОГО ФИКСА RASENGAN + RASENSHURIKEN ===" -ForegroundColor Cyan

# ============ 1. RasenshurikenBehavior (Сервер: Зарядка -> Спавн сущности) ============
Write-File "$base\java\com\example\shinobicore\jutsu\custom\RasenshurikenBehavior.java" @'
package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.entity.RasenshurikenEntity;
import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;
import net.minecraft.text.Text;
import net.minecraft.util.math.Vec3d;

public class RasenshurikenBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;

        player.sendMessage(Text.literal("§bЗарядка Расенсюрикена..."), true);
        world.playSound(null, player.getBlockPos(), SoundEvents.BLOCK_BEACON_AMBIENT, SoundCategory.PLAYERS, 2.0f, 1.5f);

        // Фаза 1: Зарядка (60 тиков = 3 секунды)
        TickScheduler.schedule(world, 1, 2, 30, w -> {
            Vec3d above = player.getPos().add(0, player.getHeight() + 0.8, 0);
            float rot = w.getTime() * 0.3f;
            for (int i = 0; i < 12; i++) {
                double a = rot + (i / 12.0) * Math.PI * 2;
                double r = 0.6 + (i % 3) * 0.2;
                w.spawnParticles(ParticleTypes.CLOUD,
                    above.x + Math.cos(a) * r, above.y + Math.sin(a * 2) * 0.2, above.z + Math.sin(a) * r,
                    2, 0.04, 0.04, 0.04, 0.02);
            }
        });

        // Фаза 2: Спавн сущности над головой (после зарядки)
        TickScheduler.schedule(world, 61, 61, 1, w -> {
            player.sendMessage(Text.literal("§a✦ Расенсюрикен готов! ПКМ для броска!"), true);
            world.playSound(null, player.getBlockPos(), SoundEvents.BLOCK_BEACON_POWER_SELECT, SoundCategory.PLAYERS, 2.0f, 1.2f);
            
            RasenshurikenEntity entity = new RasenshurikenEntity(world, player, damage);
            world.spawnEntity(entity);
        });
    }
}
'@

# ============ 2. RasenganBehavior (Сервер: Зарядка -> Спавн сферы в руке) ============
Write-File "$base\java\com\example\shinobicore\jutsu\custom\RasenganBehavior.java" @'
package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.entity.RasenganHandEntity;
import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;
import net.minecraft.text.Text;
import net.minecraft.util.math.Vec3d;

public class RasenganBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;

        // Удаляем старый расенган если есть
        for (var e : world.getEntities()) {
            if (e instanceof RasenganHandEntity rhe && rhe.getOwner() == player) rhe.discard();
        }

        player.sendMessage(Text.literal("§bФормирование Расенгана..."), true);
        world.playSound(null, player.getBlockPos(), SoundEvents.ENTITY_PLAYER_ATTACK_SWEEP, SoundCategory.PLAYERS, 1.5f, 1.8f);

        // Фаза 1: Зарядка (40 тиков = 2 секунды)
        TickScheduler.schedule(world, 1, 2, 20, w -> {
            Vec3d hand = player.getEyePos().add(player.getRotationVector().multiply(0.6)).add(0, -0.2, 0);
            for (int i = 0; i < 8; i++) {
                w.spawnParticles(ParticleTypes.SOUL_FIRE_FLAME,
                    hand.x + (Math.random() - 0.5) * 0.3, hand.y + (Math.random() - 0.5) * 0.3, hand.z + (Math.random() - 0.5) * 0.3,
                    1, 0, 0.03, 0);
            }
        });

        // Фаза 2: Спавн сферы в руке
        TickScheduler.schedule(world, 41, 41, 1, w -> {
            player.sendMessage(Text.literal("§a✦ Расенган готов! ЛКМ для удара!"), false);
            world.playSound(null, player.getBlockPos(), SoundEvents.BLOCK_BEACON_ACTIVATE, SoundCategory.PLAYERS, 1.5f, 1.2f);
            
            RasenganHandEntity entity = new RasenganHandEntity(world, player, damage);
            world.spawnEntity(entity);
        });
    }
}
'@

# ============ 3. ClientInputHandler (Надежное обнаружение сущностей) ============
$cihPath = "$base\java\com\example\shinobicore\client\ClientInputHandler.java"
$cih = [System.IO.File]::ReadAllText($cihPath, $utf8)

$rmbLmbCode = @'
        // === RMB: throw rasenshuriken (Надежный поиск по всему миру) ===
        boolean rmbDown = client.options.useKey.isPressed();
        if (rmbDown && !prevRmbDown) {
            boolean hasRs = false;
            if (client.world != null && client.player != null) {
                for (var e : client.world.getEntities()) {
                    if (e instanceof com.example.shinobicore.entity.RasenshurikenEntity rs && 
                        rs.getOwner() == client.player && !rs.isLaunched()) {
                        hasRs = true;
                        break;
                    }
                }
            }
            if (hasRs) {
                io.netty.buffer.Unpooled buffer = io.netty.buffer.Unpooled.buffer();
                net.minecraft.network.PacketByteBuf buf = new net.minecraft.network.PacketByteBuf(buffer);
                net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking.send(com.example.shinobicore.network.ModPackets.THROW_RASENSHURIKEN_ID, buf);
            }
        }
        prevRmbDown = rmbDown;

        // === LMB: rasengan strike ===
        boolean lmbDown = client.options.attackKey.isPressed();
        if (lmbDown && !prevLmbDown) {
            boolean hasRg = false;
            if (client.world != null && client.player != null) {
                for (var e : client.world.getEntities()) {
                    if (e instanceof com.example.shinobicore.entity.RasenganHandEntity rg && rg.getOwner() == client.player) {
                        hasRg = true;
                        break;
                    }
                }
            }
            if (hasRg) {
                io.netty.buffer.Unpooled buffer = io.netty.buffer.Unpooled.buffer();
                net.minecraft.network.PacketByteBuf buf = new net.minecraft.network.PacketByteBuf(buffer);
                net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking.send(com.example.shinobicore.network.ModPackets.RASENGAN_STRIKE_ID, buf);
            }
        }
        prevLmbDown = lmbDown;
'@

# Заменяем старую логику или добавляем новую перед CRAWL
if ($cih -match "KeyBindings\.CRAWL\.wasPressed") {
    $cih = $cih -replace '(?s)// === RMB: throw rasenshuriken.*?prevLmbDown = lmbDown;', $rmbLmbCode
} else {
    $cih = $cih -replace '(if \(KeyBindings\.CRAWL\.wasPressed\(\)\))', ($rmbLmbCode + "`n        `$1")
}
[System.IO.File]::WriteAllText($cihPath, $cih, $utf8)
Write-Host "[OK] ClientInputHandler updated" -ForegroundColor Green

# ============ 4. ShinobiCore (Серверные обработчики пакетов) ============
$scPath = "$base\java\com\example\shinobicore\ShinobiCore.java"
$sc = [System.IO.File]::ReadAllText($scPath, $utf8)

$serverHandlers = @'

        // === RASENSHURIKEN THROW HANDLER ===
        net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking.registerGlobalReceiver(
            com.example.shinobicore.network.ModPackets.THROW_RASENSHURIKEN_ID,
            (server, player, handler, buf, responseSender) -> {
                server.execute(() -> {
                    for (var e : player.getWorld().getEntities()) {
                        if (e instanceof com.example.shinobicore.entity.RasenshurikenEntity rs && 
                            rs.getOwner() == player && !rs.isLaunched()) {
                            rs.launch(player.getRotationVector());
                            break;
                        }
                    }
                });
            });

        // === RASENGAN STRIKE HANDLER ===
        net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking.registerGlobalReceiver(
            com.example.shinobicore.network.ModPackets.RASENGAN_STRIKE_ID,
            (server, player, handler, buf, responseSender) -> {
                server.execute(() -> {
                    com.example.shinobicore.entity.RasenganHandEntity rasengan = null;
                    for (var e : player.getWorld().getEntities()) {
                        if (e instanceof com.example.shinobicore.entity.RasenganHandEntity rg && rg.getOwner() == player) {
                            rasengan = rg;
                            break;
                        }
                    }
                    if (rasengan != null) {
                        float damage = rasengan.getDamage();
                        net.minecraft.util.math.Vec3d look = player.getRotationVector();
                        net.minecraft.util.math.Vec3d strikeCenter = player.getPos().add(look.multiply(1.5)).add(0, 0.5, 0);
                        float radius = 3.0f;
                        for (var e : player.getWorld().getOtherEntities(player, new net.minecraft.util.math.Box(strikeCenter, strikeCenter).expand(radius))) {
                            if (e instanceof net.minecraft.entity.LivingEntity liv) {
                                liv.damage(player.getDamageSources().magic(), damage);
                                net.minecraft.util.math.Vec3d kb = liv.getPos().subtract(player.getPos()).normalize().multiply(2.0);
                                liv.addVelocity(kb.x, 0.5, kb.z);
                                liv.velocityModified = true;
                            }
                        }
                        if (player.getWorld() instanceof net.minecraft.server.world.ServerWorld sw) {
                            sw.spawnParticles(net.minecraft.particle.ParticleTypes.EXPLOSION_EMITTER, strikeCenter.x, strikeCenter.y, strikeCenter.z, 1, 0, 0, 0, 0);
                            sw.playSound(null, player.getBlockPos(), net.minecraft.sound.SoundEvents.ENTITY_GENERIC_EXPLODE, net.minecraft.sound.SoundCategory.PLAYERS, 1.5f, 1.2f);
                        }
                        rasengan.discard();
                    }
                });
            });
'@

if (-not $sc.Contains("THROW_RASENSHURIKEN_ID")) {
    # Вставляем перед последней закрывающей скобкой класса
    $lastBrace = $sc.LastIndexOf("}")
    $sc = $sc.Insert($lastBrace, $serverHandlers)
    [System.IO.File]::WriteAllText($scPath, $sc, $utf8)
    Write-Host "[OK] ShinobiCore server handlers added" -ForegroundColor Green
}

# ============ 5. 3D Renderers (Исправление невидимых моделей) ============
Write-File "$base\java\com\example\shinobicore\entity\RasenshurikenRenderer.java" @'
package com.example.shinobicore.entity;

import net.minecraft.client.render.OverlayTexture;
import net.minecraft.client.render.RenderLayer;
import net.minecraft.client.render.VertexConsumer;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.render.entity.EntityRenderer;
import net.minecraft.client.render.entity.EntityRendererFactory;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.RotationAxis;
import org.joml.Matrix4f;

public class RasenshurikenRenderer extends EntityRenderer<RasenshurikenEntity> {
    private static final Identifier TEX = new Identifier("textures/misc/white.png");

    public RasenshurikenRenderer(EntityRendererFactory.Context ctx) { super(ctx); }

    @Override
    public void render(RasenshurikenEntity entity, float yaw, float tickDelta, MatrixStack matrices, VertexConsumerProvider vc, int light) {
        super.render(entity, yaw, tickDelta, matrices, vc, light);
        matrices.push();
        
        float rotation = (entity.age + tickDelta) * 15f;
        matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(rotation));
        
        VertexConsumer consumer = vc.getBuffer(RenderLayer.getEntityTranslucentCull(TEX));
        
        // 4 Лезвия
        for (int i = 0; i < 4; i++) {
            matrices.push();
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(i * 90));
            Matrix4f m = matrices.peek().getPositionMatrix();
            emitQuad(consumer, m, 0, 0.05f, 0, 1.5f, 0.05f, -0.3f, 1.5f, 0.05f, 0.3f, 0, 0.05f, 0, 0.3f, 0.6f, 1.0f, 0.9f, light);
            emitQuad(consumer, m, 0, -0.05f, 0, 1.5f, -0.05f, 0.3f, 1.5f, -0.05f, -0.3f, 0, -0.05f, 0, 0.2f, 0.4f, 0.9f, 0.8f, light);
            matrices.pop();
        }
        
        // Центральная сфера (упрощенная)
        renderSphere(matrices, vc, 0.35f, 0.2f, 0.5f, 1.0f, 0.95f, light);
        matrices.pop();
    }

    private void renderSphere(MatrixStack matrices, VertexConsumerProvider vc, float radius, float r, float g, float b, float a, int light) {
        VertexConsumer consumer = vc.getBuffer(RenderLayer.getEntityTranslucentCull(TEX));
        float half = radius;
        for (int i = 0; i < 3; i++) {
            float angle = i * 60f;
            matrices.push();
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(angle));
            Matrix4f m = matrices.peek().getPositionMatrix();
            emitQuad(consumer, m, -half, -half, 0, half, -half, 0, half, half, 0, -half, half, 0, r, g, b, a, light);
            matrices.pop();
        }
    }

    private void emitQuad(VertexConsumer consumer, Matrix4f matrix, float x1, float y1, float z1, float x2, float y2, float z2, float x3, float y3, float z3, float x4, float y4, float z4, float r, float g, float b, float a, int light) {
        vertex(consumer, matrix, x1, y1, z1, 0, 1, r, g, b, a, light);
        vertex(consumer, matrix, x2, y2, z2, 1, 1, r, g, b, a, light);
        vertex(consumer, matrix, x3, y3, z3, 1, 0, r, g, b, a, light);
        vertex(consumer, matrix, x4, y4, z4, 0, 0, r, g, b, a, light);
        // Задняя сторона (чтобы не исчезало)
        vertex(consumer, matrix, x4, y4, z4, 0, 0, r, g, b, a, light);
        vertex(consumer, matrix, x3, y3, z3, 1, 0, r, g, b, a, light);
        vertex(consumer, matrix, x2, y2, z2, 1, 1, r, g, b, a, light);
        vertex(consumer, matrix, x1, y1, z1, 0, 1, r, g, b, a, light);
    }

    private void vertex(VertexConsumer consumer, Matrix4f matrix, float x, float y, float z, float u, float v, float r, float g, float b, float a, int light) {
        consumer.vertex(matrix, x, y, z).color(r, g, b, a).texture(u, v).overlay(OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
    }

    @Override
    public Identifier getTexture(RasenshurikenEntity entity) { return TEX; }
}
'@

Write-File "$base\java\com\example\shinobicore\entity\RasenganHandRenderer.java" @'
package com.example.shinobicore.entity;

import net.minecraft.client.render.OverlayTexture;
import net.minecraft.client.render.RenderLayer;
import net.minecraft.client.render.VertexConsumer;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.render.entity.EntityRenderer;
import net.minecraft.client.render.entity.EntityRendererFactory;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.RotationAxis;
import org.joml.Matrix4f;

public class RasenganHandRenderer extends EntityRenderer<RasenganHandEntity> {
    private static final Identifier TEX = new Identifier("textures/misc/white.png");

    public RasenganHandRenderer(EntityRendererFactory.Context ctx) { super(ctx); }

    @Override
    public void render(RasenganHandEntity entity, float yaw, float tickDelta, MatrixStack matrices, VertexConsumerProvider vc, int light) {
        super.render(entity, yaw, tickDelta, matrices, vc, light);
        matrices.push();
        
        float pulse = 0.9f + 0.1f * (float) Math.sin((entity.age + tickDelta) * 0.15);
        matrices.scale(pulse, pulse, pulse);
        
        float rotation = (entity.age + tickDelta) * 8f;
        matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(rotation));
        
        VertexConsumer consumer = vc.getBuffer(RenderLayer.getEntityTranslucentCull(TEX));
        
        // Ядро
        renderSphere(matrices, vc, 0.2f, 0.3f, 0.6f, 1.0f, 0.95f, light);
        // Оболочка
        renderSphere(matrices, vc, 0.3f, 0.2f, 0.4f, 0.9f, 0.5f, light);
        
        matrices.pop();
    }

    private void renderSphere(MatrixStack matrices, VertexConsumerProvider vc, float radius, float r, float g, float b, float a, int light) {
        VertexConsumer consumer = vc.getBuffer(RenderLayer.getEntityTranslucentCull(TEX));
        float half = radius;
        for (int i = 0; i < 3; i++) {
            float angle = i * 60f;
            matrices.push();
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(angle));
            Matrix4f m = matrices.peek().getPositionMatrix();
            emitQuad(consumer, m, -half, -half, 0, half, -half, 0, half, half, 0, -half, half, 0, r, g, b, a, light);
            matrices.pop();
        }
        matrices.push();
        matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(90));
        Matrix4f mH = matrices.peek().getPositionMatrix();
        emitQuad(consumer, mH, -half, -half, 0, half, -half, 0, half, half, 0, -half, half, 0, r, g, b, a, light);
        matrices.pop();
    }

    private void emitQuad(VertexConsumer consumer, Matrix4f matrix, float x1, float y1, float z1, float x2, float y2, float z2, float x3, float y3, float z3, float x4, float y4, float z4, float r, float g, float b, float a, int light) {
        vertex(consumer, matrix, x1, y1, z1, 0, 1, r, g, b, a, light);
        vertex(consumer, matrix, x2, y2, z2, 1, 1, r, g, b, a, light);
        vertex(consumer, matrix, x3, y3, z3, 1, 0, r, g, b, a, light);
        vertex(consumer, matrix, x4, y4, z4, 0, 0, r, g, b, a, light);
        vertex(consumer, matrix, x4, y4, z4, 0, 0, r, g, b, a, light);
        vertex(consumer, matrix, x3, y3, z3, 1, 0, r, g, b, a, light);
        vertex(consumer, matrix, x2, y2, z2, 1, 1, r, g, b, a, light);
        vertex(consumer, matrix, x1, y1, z1, 0, 1, r, g, b, a, light);
    }

    private void vertex(VertexConsumer consumer, Matrix4f matrix, float x, float y, float z, float u, float v, float r, float g, float b, float a, int light) {
        consumer.vertex(matrix, x, y, z).color(r, g, b, a).texture(u, v).overlay(OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
    }

    @Override
    public Identifier getTexture(RasenganHandEntity entity) { return TEX; }
}
'@

Write-Host "`n=== ВСЕ ИСПРАВЛЕНИЯ ПРИМЕНЕНЫ ===" -ForegroundColor Yellow
Write-Host "Запустите: .\gradlew.bat build" -ForegroundColor White
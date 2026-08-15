$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$baseJava = "E:\Games\mod\src\main\java\com\example\shinobicore"
$renderDir = "$baseJava\client\render"

# Гарантируем наличие папки render
if (-not (Test-Path $renderDir)) { New-Item -ItemType Directory -Path $renderDir -Force | Out-Null }

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  ИСПРАВЛЕНИЕ ОШИБОК FeatureRenderer (Context & Generics)" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# =========================================================
# 1. BackKatanaRenderer.java
# =========================================================
Write-Host "[1/3] Создание/Обновление BackKatanaRenderer.java..." -ForegroundColor Yellow
$backKatanaPath = "$renderDir\BackKatanaRenderer.java"

$backKatanaCode = @"
package com.example.shinobicore.client.render;

import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.client.render.OverlayTexture;
import net.minecraft.client.render.RenderLayer;
import net.minecraft.client.render.VertexConsumer;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.render.entity.feature.FeatureRenderer;
import net.minecraft.client.render.entity.feature.FeatureRendererContext;
import net.minecraft.client.render.entity.model.PlayerEntityModel;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.RotationAxis;
import org.joml.Matrix4f;

public class BackKatanaRenderer extends FeatureRenderer<AbstractClientPlayerEntity, PlayerEntityModel<AbstractClientPlayerEntity>> {

    private static final Identifier TEX = new Identifier("textures/misc/white.png");

    // Конструктор принимает Context (сам рендерер), а не Model
    public BackKatanaRenderer(FeatureRendererContext<AbstractClientPlayerEntity, PlayerEntityModel<AbstractClientPlayerEntity>> context) {
        super(context);
    }

    @Override
    public void render(
            MatrixStack matrices, 
            VertexConsumerProvider vertexConsumers, 
            int light, 
            AbstractClientPlayerEntity entity, 
            float limbAngle, float limbDistance, float tickDelta, 
            float animationProgress, float headYaw, float headPitch) {
        
        // Пример условия: рендерим только если в инвентаре есть катана
        boolean hasKatana = false;
        for (int i = 0; i < entity.getInventory().size(); i++) {
            if (entity.getInventory().getStack(i).getItem() instanceof com.example.shinobicore.item.KatanaItem) {
                hasKatana = true;
                break;
            }
        }
        if (!hasKatana) return;

        matrices.push();
        
        // Привязываемся к кости торса (body)
        this.getContextModel().body.rotate(matrices);
        
        // Смещаем за спину и поворачиваем
        matrices.translate(0.0f, 0.15f, 0.25f);
        matrices.multiply(RotationAxis.POSITIVE_Z.rotationDegrees(-40.0f));
        matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(180.0f));
        matrices.scale(0.65f, 0.65f, 0.65f);

        VertexConsumer vc = vertexConsumers.getBuffer(RenderLayer.getEntityTranslucent(TEX));
        
        // Лезвие
        drawCuboid(matrices, vc, light, -0.05f, -0.9f, -0.05f, 0.1f, 1.3f, 0.1f, 0.85f, 0.87f, 0.90f);
        // Рукоять
        drawCuboid(matrices, vc, light, -0.04f, 0.4f, -0.04f, 0.08f, 0.4f, 0.08f, 0.25f, 0.18f, 0.12f);

        matrices.pop();
    }

    private void drawCuboid(MatrixStack matrices, VertexConsumer vc, int light,
                            float x, float y, float z, float w, float h, float d,
                            float r, float g, float b) {
        Matrix4f m = matrices.peek().getPositionMatrix();
        float x2 = x + w, y2 = y + h, z2 = z + d;
        addQuad(vc, m, x, y, z2, x2, y, z2, x2, y2, z2, x, y2, z2, r, g, b, light);
        addQuad(vc, m, x2, y, z, x, y, z, x, y2, z, x2, y2, z, r, g, b, light);
        addQuad(vc, m, x, y, z, x, y, z2, x, y2, z2, x, y2, z, r, g, b, light);
        addQuad(vc, m, x2, y, z2, x2, y, z, x2, y2, z, x2, y2, z2, r, g, b, light);
    }

    private void addQuad(VertexConsumer vc, Matrix4f m,
                         float x1, float y1, float z1, float x2, float y2, float z2,
                         float x3, float y3, float z3, float x4, float y4, float z4,
                         float r, float g, float b, int light) {
        v(vc, m, x1, y1, z1, r, g, b, light); v(vc, m, x2, y2, z2, r, g, b, light);
        v(vc, m, x3, y3, z3, r, g, b, light); v(vc, m, x4, y4, z4, r, g, b, light);
    }

    private void v(VertexConsumer vc, Matrix4f m, float x, float y, float z,
                   float r, float g, float b, int light) {
        vc.vertex(m, x, y, z).color(r, g, b, 1.0f).texture(0, 0)
                .overlay(OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
    }
}
"@
[System.IO.File]::WriteAllText($backKatanaPath, $backKatanaCode, $utf8)
Write-Host "  [OK] BackKatanaRenderer.java сохранен." -ForegroundColor Green

# =========================================================
# 2. NarutoArmorRenderer.java
# =========================================================
Write-Host "[2/3] Создание/Обновление NarutoArmorRenderer.java..." -ForegroundColor Yellow
$narutoArmorPath = "$renderDir\NarutoArmorRenderer.java"

$narutoArmorCode = @"
package com.example.shinobicore.client.render;

import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.client.render.OverlayTexture;
import net.minecraft.client.render.RenderLayer;
import net.minecraft.client.render.VertexConsumer;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.render.entity.feature.FeatureRenderer;
import net.minecraft.client.render.entity.feature.FeatureRendererContext;
import net.minecraft.client.render.entity.model.PlayerEntityModel;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.Identifier;
import org.joml.Matrix4f;

public class NarutoArmorRenderer extends FeatureRenderer<AbstractClientPlayerEntity, PlayerEntityModel<AbstractClientPlayerEntity>> {

    private static final Identifier TEX = new Identifier("textures/misc/white.png");

    public NarutoArmorRenderer(FeatureRendererContext<AbstractClientPlayerEntity, PlayerEntityModel<AbstractClientPlayerEntity>> context) {
        super(context);
    }

    @Override
    public void render(
            MatrixStack matrices, 
            VertexConsumerProvider vertexConsumers, 
            int light, 
            AbstractClientPlayerEntity entity, 
            float limbAngle, float limbDistance, float tickDelta, 
            float animationProgress, float headYaw, float headPitch) {
        
        // Здесь можно добавить проверку на наличие баффа или предмета
        // if (!entity.hasStatusEffect(...)) return;

        matrices.push();
        this.getContextModel().body.rotate(matrices);
        
        // Рендерим жилет/накидку поверх торса
        matrices.translate(0.0f, 0.0f, -0.15f);
        matrices.scale(1.05f, 1.05f, 1.05f);

        VertexConsumer vc = vertexConsumers.getBuffer(RenderLayer.getEntityTranslucent(TEX));
        
        // Пластинка за спиной (Хаори)
        drawCuboid(matrices, vc, light, -0.4f, -0.6f, -0.1f, 0.8f, 1.2f, 0.05f, 0.8f, 0.2f, 0.2f);

        matrices.pop();
    }

    private void drawCuboid(MatrixStack matrices, VertexConsumer vc, int light,
                            float x, float y, float z, float w, float h, float d,
                            float r, float g, float b) {
        Matrix4f m = matrices.peek().getPositionMatrix();
        float x2 = x + w, y2 = y + h, z2 = z + d;
        addQuad(vc, m, x, y, z2, x2, y, z2, x2, y2, z2, x, y2, z2, r, g, b, light);
        addQuad(vc, m, x2, y, z, x, y, z, x, y2, z, x2, y2, z, r, g, b, light);
        addQuad(vc, m, x, y, z, x, y, z2, x, y2, z2, x, y2, z, r, g, b, light);
        addQuad(vc, m, x2, y, z2, x2, y, z, x2, y2, z, x2, y2, z2, r, g, b, light);
    }

    private void addQuad(VertexConsumer vc, Matrix4f m,
                         float x1, float y1, float z1, float x2, float y2, float z2,
                         float x3, float y3, float z3, float x4, float y4, float z4,
                         float r, float g, float b, int light) {
        v(vc, m, x1, y1, z1, r, g, b, light); v(vc, m, x2, y2, z2, r, g, b, light);
        v(vc, m, x3, y3, z3, r, g, b, light); v(vc, m, x4, y4, z4, r, g, b, light);
    }

    private void v(VertexConsumer vc, Matrix4f m, float x, float y, float z,
                   float r, float g, float b, int light) {
        vc.vertex(m, x, y, z).color(r, g, b, 1.0f).texture(0, 0)
                .overlay(OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
    }
}
"@
[System.IO.File]::WriteAllText($narutoArmorPath, $narutoArmorCode, $utf8)
Write-Host "  [OK] NarutoArmorRenderer.java сохранен." -ForegroundColor Green

# =========================================================
# 3. Патчим ShinobiCoreClient.java
# =========================================================
Write-Host "[3/3] Патчинг ShinobiCoreClient.java (Регистрация)..." -ForegroundColor Yellow
$sccPath = "$baseJava\client\ShinobiCoreClient.java"

if (Test-Path $sccPath) {
    $content = [System.IO.File]::ReadAllText($sccPath, $utf8)
    
    # 1. Добавляем импорт, если его нет
    $importCallback = "import net.fabricmc.fabric.api.client.rendering.v1.LivingEntityFeatureRendererRegistrationCallback;"
    if (-not $content.Contains($importCallback)) {
        $content = $content.Replace(
            "import net.fabricmc.fabric.api.client.rendering.v1.EntityRendererRegistry;", 
            "import net.fabricmc.fabric.api.client.rendering.v1.EntityRendererRegistry;`n$importCallback"
        )
    }

    # 2. Удаляем старые сломанные регистрации (если они есть в коде)
    # Ищем строки, где передавалось .getModel() или старые варианты
    $content = $content -replace '(?m).*?registrationHelper\.register\(new BackKatanaRenderer.*?;\s*', ''
    $content = $content -replace '(?m).*?registrationHelper\.register\(new NarutoArmorRenderer.*?;\s*', ''

    # 3. Внедряем правильный блок регистрации
    $correctBlock = @"
        // === РЕГИСТРАЦИЯ КАСТОМНЫХ РЕНДЕРЕРОВ ИГРОКА (FeatureRenderers) ===
        LivingEntityFeatureRendererRegistrationCallback.EVENT.register((entityType, entityRenderer, registrationHelper, context) -> {
            if (entityRenderer instanceof net.minecraft.client.render.entity.PlayerEntityRenderer playerRenderer) {
                registrationHelper.register(new com.example.shinobicore.client.render.BackKatanaRenderer(playerRenderer));
                registrationHelper.register(new com.example.shinobicore.client.render.NarutoArmorRenderer(playerRenderer));
            }
        });
"@

    if (-not $content.Contains("LivingEntityFeatureRendererRegistrationCallback.EVENT.register")) {
        # Внедряем перед BuiltinItemRendererRegistry (или EntityRendererRegistry, если первого нет)
        if ($content.Contains("BuiltinItemRendererRegistry.INSTANCE.register")) {
            $content = $content.Replace("BuiltinItemRendererRegistry.INSTANCE.register", "$correctBlock`n`n        BuiltinItemRendererRegistry.INSTANCE.register")
        } elseif ($content.Contains("EntityRendererRegistry.register")) {
            $content = $content.Replace("EntityRendererRegistry.register", "$correctBlock`n`n        EntityRendererRegistry.register")
        } else {
            # Фоллбэк: в самый конец onInitializeClient
            $content = $content -replace '(\s*}\s*)$', "`n$correctBlock`$1"
        }
    }

    [System.IO.File]::WriteAllText($sccPath, $content, $utf8)
    Write-Host "  [OK] ShinobiCoreClient.java обновлен." -ForegroundColor Green
} else {
    Write-Host "  [ERROR] ShinobiCoreClient.java не найден!" -ForegroundColor Red
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "  ГОТОВО! Ошибки дженериков и контекста исправлены." -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Следующий шаг: Запустите сборку" -ForegroundColor Cyan
Write-Host ".\gradlew.bat build" -ForegroundColor White
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main\java\com\example\shinobicore\entity"

# ВНИМАНИЕ: Внутри here-строки @' ... '@ НЕЛЬЗЯ использовать одиночные кавычки (')!
# Используем только двойные (") для строк в Java.
$rendererCode = @'
package com.example.shinobicore.entity;

import net.minecraft.client.render.OverlayTexture;
import net.minecraft.client.render.RenderLayer;
import net.minecraft.client.render.VertexConsumer;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.render.entity.EntityRenderer;
import net.minecraft.client.render.entity.EntityRendererFactory;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.MathHelper;
import net.minecraft.util.math.RotationAxis;
import org.joml.Matrix4f;

public class NinjaProjectileRenderer extends EntityRenderer<NinjaProjectileEntity> {
    private static final Identifier WHITE_TEXTURE = new Identifier("textures/misc/white.png");

    public NinjaProjectileRenderer(EntityRendererFactory.Context ctx) {
        super(ctx);
    }

    @Override
    public void render(NinjaProjectileEntity entity, float yaw, float tickDelta,
                       MatrixStack matrices, VertexConsumerProvider vertexConsumers, int light) {
        super.render(entity, yaw, tickDelta, matrices, vertexConsumers, light);
        
        float radius = entity.getRadius() * 0.25f;
        if (radius < 0.1f) radius = 0.1f;
        String particle = entity.getParticleType();
        
        int innerColor = getInnerColor(particle);
        int outerColor = getOuterColor(particle);
        
        matrices.push();
        matrices.translate(0, entity.getHeight() / 2.0, 0);
        
        // Динамическое вращение снаряда в полете
        float age = entity.age + tickDelta;
        matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(age * 15.0f));
        matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(age * 10.0f));

        // 1. Внутреннее ядро (непрозрачное/плотное)
        renderUVSphere(matrices, vertexConsumers, radius, innerColor, light, false);
        
        // 2. Внешнее свечение (чуть больше, полупрозрачное)
        renderUVSphere(matrices, vertexConsumers, radius * 1.4f, outerColor, light, true);
        
        matrices.pop();
    }

    private int getInnerColor(String particle) {
        return switch (particle) {
            case "fire" -> 0xFFFF5500;      // Оранжево-красный
            case "water" -> 0xFF2288FF;     // Синий
            case "lightning" -> 0xFFFFFF44; // Желтый
            case "wind" -> 0xFFCCFFCC;      // Светло-зеленый/белый
            case "earth" -> 0xFF996633;     // Коричневый
            case "smoke" -> 0xFF888888;     // Серый
            default -> 0xFFFF5500;
        };
    }

    private int getOuterColor(String particle) {
        return switch (particle) {
            case "fire" -> 0x88FF2200;      // Полупрозрачный красный
            case "water" -> 0x880044FF;     // Полупрозрачный синий
            case "lightning" -> 0x88FFFF00; // Полупрозрачный желтый
            case "wind" -> 0x88AAFFAA;
            case "earth" -> 0x88553311;
            case "smoke" -> 0x88444444;
            default -> 0x88FF2200;
        };
    }

    /**
     * Генерирует процедурную 3D UV-сферу
     */
    private void renderUVSphere(MatrixStack matrices, VertexConsumerProvider vc, 
                                float size, int color, int light, boolean isGlow) {
        Identifier texture = WHITE_TEXTURE;
        RenderLayer layer = isGlow ? RenderLayer.getEntityTranslucentCull(texture) : RenderLayer.getEntityTranslucent(texture);
        VertexConsumer consumer = vc.getBuffer(layer);
        
        float r = ((color >> 16) & 0xFF) / 255f;
        float g = ((color >> 8) & 0xFF) / 255f;
        float b = (color & 0xFF) / 255f;
        float a = ((color >> 24) & 0xFF) / 255f;
        
        Matrix4f m = matrices.peek().getPositionMatrix();
        
        int stacks = 10;  // Вертикальные сегменты
        int slices = 14;  // Горизонтальные сегменты
        
        for (int i = 0; i < stacks; i++) {
            float theta1 = (float) i / stacks * MathHelper.PI;
            float theta2 = (float) (i + 1) / stacks * MathHelper.PI;
            
            for (int j = 0; j < slices; j++) {
                float phi1 = (float) j / slices * MathHelper.PI * 2;
                float phi2 = (float) (j + 1) / slices * MathHelper.PI * 2;
                
                // 4 вершины квада
                float x1 = size * MathHelper.sin(theta1) * MathHelper.cos(phi1);
                float y1 = size * MathHelper.cos(theta1);
                float z1 = size * MathHelper.sin(theta1) * MathHelper.sin(phi1);
                
                float x2 = size * MathHelper.sin(theta1) * MathHelper.cos(phi2);
                float y2 = size * MathHelper.cos(theta1);
                float z2 = size * MathHelper.sin(theta1) * MathHelper.sin(phi2);
                
                float x3 = size * MathHelper.sin(theta2) * MathHelper.cos(phi2);
                float y3 = size * MathHelper.cos(theta2);
                float z3 = size * MathHelper.sin(theta2) * MathHelper.sin(phi2);
                
                float x4 = size * MathHelper.sin(theta2) * MathHelper.cos(phi1);
                float y4 = size * MathHelper.cos(theta2);
                float z4 = size * MathHelper.sin(theta2) * MathHelper.sin(phi1);
                
                // Нормали для сферы совпадают с.normalized() координатами
                float nx1 = MathHelper.sin(theta1) * MathHelper.cos(phi1);
                float ny1 = MathHelper.cos(theta1);
                float nz1 = MathHelper.sin(theta1) * MathHelper.sin(phi1);
                
                // Рисуем два треугольника (квад)
                vertex(consumer, m, x1, y1, z1, nx1, ny1, nz1, r, g, b, a, light);
                vertex(consumer, m, x2, y2, z2, nx1, ny1, nz1, r, g, b, a, light);
                vertex(consumer, m, x3, y3, z3, nx1, ny1, nz1, r, g, b, a, light);
                
                vertex(consumer, m, x1, y1, z1, nx1, ny1, nz1, r, g, b, a, light);
                vertex(consumer, m, x3, y3, z3, nx1, ny1, nz1, r, g, b, a, light);
                vertex(consumer, m, x4, y4, z4, nx1, ny1, nz1, r, g, b, a, light);
            }
        }
    }

    private void vertex(VertexConsumer consumer, Matrix4f matrix, 
                        float x, float y, float z, 
                        float nx, float ny, float nz,
                        float r, float g, float b, float a, int light) {
        consumer.vertex(matrix, x, y, z)
                .color(r, g, b, a)
                .texture(0, 0)
                .overlay(OverlayTexture.DEFAULT_UV)
                .light(light)
                .normal(nx, ny, nz)
                .next();
    }

    @Override
    public Identifier getTexture(NinjaProjectileEntity entity) {
        return WHITE_TEXTURE;
    }
}
'@

# Записываем файл
[System.IO.File]::WriteAllText("$base\NinjaProjectileRenderer.java", $rendererCode, $utf8)
Write-Host "=====================================================================" -ForegroundColor Green
Write-Host "[OK] NinjaProjectileRenderer.java обновлен! Теперь это настоящая 3D-сфера." -ForegroundColor Green
Write-Host "=====================================================================" -ForegroundColor Green
Write-Host "Run .\gradlew.bat runClient to see the new 3D projectiles in-game."
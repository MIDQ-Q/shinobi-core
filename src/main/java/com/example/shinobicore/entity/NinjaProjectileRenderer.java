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

public class NinjaProjectileRenderer extends EntityRenderer<NinjaProjectileEntity> {
    private static final Identifier WHITE_TEXTURE = new Identifier("textures/misc/white.png");
    private static final Identifier LAVA_TEXTURE = new Identifier("textures/block/lava_still.png");
    private static final Identifier WATER_TEXTURE = new Identifier("textures/block/water_still.png");

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

        // Выбираем текстуру и цвет в зависимости от стихии
        Identifier texture = getTextureForParticle(particle);
        int innerColor = getInnerColor(particle);
        int outerColor = getOuterColor(particle);

        matrices.push();
        matrices.translate(0, entity.getHeight() / 2.0, 0);

        // Внутреннее ядро с текстурой
        renderSphereQuads(matrices, vertexConsumers, radius, innerColor, light, texture);

        // Внешнее свечение (полупрозрачное, белая текстура + tint)
        renderSphereQuads(matrices, vertexConsumers, radius * 1.4f, outerColor, light, WHITE_TEXTURE);

        // Третий слой для очень больших снарядов
        if (entity.getRadius() > 6.0f) {
            renderSphereQuads(matrices, vertexConsumers, radius * 1.8f, outerColor, light, WHITE_TEXTURE);
        }

        matrices.pop();
    }

    private Identifier getTextureForParticle(String particle) {
        return switch (particle) {
            case "fire" -> LAVA_TEXTURE;      // Текстура лавы для огня
            case "water" -> WATER_TEXTURE;    // Текстура воды для воды
            default -> WHITE_TEXTURE;         // Белая + tint для остальных
        };
    }

    private int getInnerColor(String particle) {
        return switch (particle) {
            case "fire" -> 0xFFFFFFFF;       // Белый (текстура лавы сама оранжевая)
            case "water" -> 0xFFFFFFFF;      // Белый (текстура воды сама синяя)
            case "lightning" -> 0xFFFFFF44;  // Жёлтый
            case "wind" -> 0xFFDDDDDD;       // Светло-серый
            case "earth" -> 0xFF996633;      // Коричневый
            case "smoke" -> 0xFF888888;      // Серый
            default -> 0xFFFF6600;
        };
    }

    private int getOuterColor(String particle) {
        return switch (particle) {
            case "fire" -> 0x66FF4400;       // Полупрозрачный красный (свечение)
            case "water" -> 0x662266FF;      // Полупрозрачный синий
            case "lightning" -> 0x66FFFF00;  // Полупрозрачный жёлтый
            case "wind" -> 0x66CCCCCC;       // Полупрозрачный серый
            case "earth" -> 0x66774422;      // Полупрозрачный коричневый
            case "smoke" -> 0x66666666;      // Полупрозрачный тёмно-серый
            default -> 0x66FF4400;
        };
    }

    /**
     * Рисует 6 квадов под разными углами для создания объемного шара.
     */
    private void renderSphereQuads(MatrixStack matrices, VertexConsumerProvider vc,
                                    float size, int color, int light, Identifier texture) {
        VertexConsumer consumer = vc.getBuffer(RenderLayer.getEntityTranslucent(texture));

        float r = ((color >> 16) & 0xFF) / 255f;
        float g = ((color >> 8) & 0xFF) / 255f;
        float b = (color & 0xFF) / 255f;
        float a = ((color >> 24) & 0xFF) / 255f;

        float half = size;

        // 3 вертикальных квада (0°, 60°, 120°)
        for (int i = 0; i < 3; i++) {
            float angle = i * 60f;
            matrices.push();
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(angle));
            Matrix4f m = matrices.peek().getPositionMatrix();
            emitQuad(consumer, m,
                    -half, -half, 0,   half, -half, 0,   half, half, 0,   -half, half, 0,
                    r, g, b, a, light);
            matrices.pop();
        }

        // Горизонтальный квад
        matrices.push();
        matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(90));
        Matrix4f mH = matrices.peek().getPositionMatrix();
        emitQuad(consumer, mH,
                -half, -half, 0,   half, -half, 0,   half, half, 0,   -half, half, 0,
                r, g, b, a, light);
        matrices.pop();

        // 2 диагональных квада (±45°)
        for (int i = 0; i < 2; i++) {
            float yAngle = i * 90f;
            matrices.push();
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(yAngle));
            matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(45));
            Matrix4f mD = matrices.peek().getPositionMatrix();
            emitQuad(consumer, mD,
                    -half, -half, 0,   half, -half, 0,   half, half, 0,   -half, half, 0,
                    r, g, b, a, light);
            matrices.pop();
        }
    }

    private void emitQuad(VertexConsumer consumer, Matrix4f matrix,
                           float x1, float y1, float z1,
                           float x2, float y2, float z2,
                           float x3, float y3, float z3,
                           float x4, float y4, float z4,
                           float r, float g, float b, float a, int light) {
        // Передняя сторона
        vertex(consumer, matrix, x1, y1, z1, 0, 1, r, g, b, a, light);
        vertex(consumer, matrix, x2, y2, z2, 1, 1, r, g, b, a, light);
        vertex(consumer, matrix, x3, y3, z3, 1, 0, r, g, b, a, light);
        vertex(consumer, matrix, x4, y4, z4, 0, 0, r, g, b, a, light);
        // Задняя сторона
        vertex(consumer, matrix, x2, y2, z2, 0, 1, r, g, b, a, light);
        vertex(consumer, matrix, x1, y1, z1, 1, 1, r, g, b, a, light);
        vertex(consumer, matrix, x4, y4, z4, 1, 0, r, g, b, a, light);
        vertex(consumer, matrix, x3, y3, z3, 0, 0, r, g, b, a, light);
    }

    private void vertex(VertexConsumer consumer, Matrix4f matrix,
                         float x, float y, float z, float u, float v,
                         float r, float g, float b, float a, int light) {
        consumer.vertex(matrix, x, y, z)
                .color(r, g, b, a)
                .texture(u, v)
                .overlay(OverlayTexture.DEFAULT_UV)
                .light(light)
                .normal(0, 1, 0)
                .next();
    }

    @Override
    public Identifier getTexture(NinjaProjectileEntity entity) {
        return getTextureForParticle(entity.getParticleType());
    }
}
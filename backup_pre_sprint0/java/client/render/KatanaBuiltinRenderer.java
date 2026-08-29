package com.example.shinobicore.client.render;

import net.minecraft.client.render.RenderLayer;
import net.minecraft.client.render.VertexConsumer;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.item.ItemStack;
import net.minecraft.client.render.model.json.ModelTransformationMode;
import net.minecraft.util.Identifier;
import org.joml.Matrix4f;

public class KatanaBuiltinRenderer {
    private static final Identifier TEX = new Identifier("textures/misc/white.png");

    public static void render(ItemStack stack, ModelTransformationMode mode, MatrixStack matrices,
                              VertexConsumerProvider vertexConsumers, int light, int overlay) {
        matrices.push();
        VertexConsumer vc = vertexConsumers.getBuffer(RenderLayer.getEntityTranslucent(TEX));
        // blade (+Y up)
        cuboid(matrices, vc, light, -0.02f, 0.02f, -0.0075f, 0.04f, 0.85f, 0.015f, 0.85f, 0.87f, 0.90f);
        cuboid(matrices, vc, light, -0.026f, 0.02f, -0.002f, 0.008f, 0.85f, 0.004f, 0.95f, 0.97f, 1.0f);
        cuboid(matrices, vc, light, -0.015f, 0.87f, -0.005f, 0.03f, 0.07f, 0.01f, 0.95f, 0.97f, 1.0f);
        // tsuba
        cuboid(matrices, vc, light, -0.06f, 0.0f, -0.06f, 0.12f, 0.02f, 0.12f, 0.60f, 0.45f, 0.15f);
        // handle
        cuboid(matrices, vc, light, -0.02f, -0.30f, -0.02f, 0.04f, 0.30f, 0.04f, 0.25f, 0.18f, 0.12f);
        for (int i = 0; i < 4; i++) {
            float y = -0.28f + i * 0.065f;
            cuboid(matrices, vc, light, -0.025f, y, -0.025f, 0.05f, 0.02f, 0.05f, 0.70f, 0.15f, 0.10f);
        }
        cuboid(matrices, vc, light, -0.025f, -0.32f, -0.025f, 0.05f, 0.02f, 0.05f, 0.60f, 0.45f, 0.15f);
        matrices.pop();
    }

    private static void cuboid(MatrixStack matrices, VertexConsumer vc, int light,
                               float x, float y, float z, float w, float h, float d,
                               float r, float g, float b) {
        Matrix4f m = matrices.peek().getPositionMatrix();
        float x2 = x + w, y2 = y + h, z2 = z + d;
        face(vc, m, x, y, z2, x2, y, z2, x2, y2, z2, x, y2, z2, r, g, b, light);
        face(vc, m, x2, y, z, x, y, z, x, y2, z, x2, y2, z, r, g, b, light);
        face(vc, m, x, y, z, x, y, z2, x, y2, z2, x, y2, z, r, g, b, light);
        face(vc, m, x2, y, z2, x2, y, z, x2, y2, z, x2, y2, z2, r, g, b, light);
        face(vc, m, x, y2, z2, x2, y2, z2, x2, y2, z, x, y2, z, r, g, b, light);
        face(vc, m, x, y, z, x2, y, z, x2, y, z2, x, y, z2, r, g, b, light);
    }

    private static void face(VertexConsumer vc, Matrix4f m,
                             float x1, float y1, float z1, float x2, float y2, float z2,
                             float x3, float y3, float z3, float x4, float y4, float z4,
                             float r, float g, float b, int light) {
        v(vc, m, x1, y1, z1, r, g, b, light); v(vc, m, x2, y2, z2, r, g, b, light);
        v(vc, m, x3, y3, z3, r, g, b, light); v(vc, m, x4, y4, z4, r, g, b, light);
        v(vc, m, x4, y4, z4, r, g, b, light); v(vc, m, x3, y3, z3, r, g, b, light);
        v(vc, m, x2, y2, z2, r, g, b, light); v(vc, m, x1, y1, z1, r, g, b, light);
    }

    private static void v(VertexConsumer vc, Matrix4f m, float x, float y, float z,
                          float r, float g, float b, int light) {
        vc.vertex(m, x, y, z).color(r, g, b, 1.0f).texture(0, 0)
          .overlay(net.minecraft.client.render.OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
    }
}
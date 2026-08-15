package com.example.shinobicore.client.render;

import com.example.shinobicore.item.ModItems;
import net.fabricmc.fabric.api.client.rendering.v1.ArmorRenderer;
import net.minecraft.client.render.OverlayTexture;
import net.minecraft.client.render.RenderLayer;
import net.minecraft.client.render.VertexConsumer;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.render.entity.model.BipedEntityModel;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.entity.EquipmentSlot;
import net.minecraft.entity.LivingEntity;
import net.minecraft.item.ItemStack;
import net.minecraft.util.Identifier;
import org.joml.Matrix4f;

/**
 * Voxel Naruto-style armor: flak jacket with pockets, forehead protector,
 * shinobi pants with pouch + bandages, sandals. Pure cuboids, vanilla pipeline.
 */
public class NarutoArmorRenderer {
    private static final Identifier TEX = new Identifier("textures/misc/white.png");
    // Palette
    private static final float[] GREEN   = {0.37f, 0.45f, 0.24f};
    private static final float[] GREEN_D = {0.24f, 0.30f, 0.16f};
    private static final float[] GRAY    = {0.60f, 0.60f, 0.58f};
    private static final float[] BLUE    = {0.16f, 0.24f, 0.55f};
    private static final float[] BLUE_D  = {0.10f, 0.16f, 0.35f};
    private static final float[] STEEL   = {0.78f, 0.80f, 0.83f};
    private static final float[] DARK    = {0.18f, 0.20f, 0.28f};
    private static final float[] BANDAGE = {0.78f, 0.76f, 0.70f};
    private static final float[] BROWN   = {0.45f, 0.32f, 0.18f};

    public static void register() {
        ArmorRenderer.register(NarutoArmorRenderer::renderArmor,
                ModItems.FLAK_VEST, ModItems.NINJA_PANTS, ModItems.NINJA_SANDALS, ModItems.NINJA_HOOD);
    }

    private static void renderArmor(MatrixStack matrices, VertexConsumerProvider vertices, ItemStack stack,
                                    LivingEntity entity, EquipmentSlot slot, int light, BipedEntityModel<LivingEntity> model) {
        if (entity.isInvisible()) return;
        VertexConsumer vc = vertices.getBuffer(RenderLayer.getEntityTranslucent(TEX));
        if (slot == EquipmentSlot.CHEST) {
            matrices.push();
            model.body.rotate(matrices);
            cuboid(matrices, vc, light, -0.27f, -0.05f, -0.17f, 0.54f, 0.72f, 0.34f, GREEN);      // shell
            cuboid(matrices, vc, light, -0.24f, -0.12f, -0.14f, 0.48f, 0.10f, 0.28f, GREEN_D);    // collar
            cuboid(matrices, vc, light, -0.28f, -0.10f, -0.12f, 0.07f, 0.14f, 0.24f, GREEN_D);    // strap L
            cuboid(matrices, vc, light,  0.21f, -0.10f, -0.12f, 0.07f, 0.14f, 0.24f, GREEN_D);    // strap R
            cuboid(matrices, vc, light, -0.22f,  0.35f, -0.19f, 0.16f, 0.18f, 0.03f, GRAY);       // pocket L
            cuboid(matrices, vc, light,  0.06f,  0.35f, -0.19f, 0.16f, 0.18f, 0.03f, GRAY);       // pocket R
            cuboid(matrices, vc, light, -0.03f,  0.05f, -0.185f, 0.06f, 0.50f, 0.02f, GREEN_D);   // zip
            cuboid(matrices, vc, light, -0.24f,  0.00f,  0.15f, 0.48f, 0.55f, 0.03f, GREEN_D);    // back plate
            matrices.pop();
        } else if (slot == EquipmentSlot.HEAD) {
            matrices.push();
            model.head.rotate(matrices);
            cuboid(matrices, vc, light, -0.27f, -0.02f, -0.27f, 0.54f, 0.16f, 0.54f, BLUE);       // band
            cuboid(matrices, vc, light, -0.15f,  0.00f, -0.29f, 0.30f, 0.12f, 0.02f, STEEL);      // plate
            cuboid(matrices, vc, light,  0.24f,  0.02f,  0.18f, 0.05f, 0.10f, 0.05f, BLUE_D);     // knot
            matrices.pop();
        } else if (slot == EquipmentSlot.LEGS) {
            matrices.push(); model.rightLeg.rotate(matrices);
            legPants(matrices, vc, light, true);
            matrices.pop();
            matrices.push(); model.leftLeg.rotate(matrices);
            legPants(matrices, vc, light, false);
            matrices.pop();
        } else if (slot == EquipmentSlot.FEET) {
            matrices.push(); model.rightLeg.rotate(matrices);
            foot(matrices, vc, light);
            matrices.pop();
            matrices.push(); model.leftLeg.rotate(matrices);
            foot(matrices, vc, light);
            matrices.pop();
        }
    }

    private static void legPants(MatrixStack m, VertexConsumer vc, int light, boolean right) {
        cuboid(m, vc, light, -0.13f, -0.05f, -0.13f, 0.26f, 0.50f, 0.26f, DARK);    // thigh
        cuboid(m, vc, light, -0.13f,  0.45f, -0.13f, 0.26f, 0.18f, 0.26f, BANDAGE); // shin bandage
        if (right) cuboid(m, vc, light, 0.11f, 0.10f, -0.10f, 0.05f, 0.18f, 0.12f, BROWN); // pouch
    }

    private static void foot(MatrixStack m, VertexConsumer vc, int light) {
        cuboid(m, vc, light, -0.14f, 0.68f, -0.16f, 0.28f, 0.07f, 0.34f, DARK); // sole
        cuboid(m, vc, light, -0.14f, 0.55f, -0.14f, 0.28f, 0.06f, 0.30f, BLUE); // footbed
        cuboid(m, vc, light, -0.13f, 0.45f, -0.13f, 0.26f, 0.08f, 0.26f, BLUE_D); // ankle
    }

    private static void cuboid(MatrixStack matrices, VertexConsumer vc, int light,
                               float x, float y, float z, float w, float h, float d, float[] col) {
        Matrix4f m = matrices.peek().getPositionMatrix();
        float x2 = x + w, y2 = y + h, z2 = z + d;
        float r = col[0], g = col[1], b = col[2];
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

    private static void v(VertexConsumer vc, Matrix4f m, float x, float y, float z, float r, float g, float b, int light) {
        vc.vertex(m, x, y, z).color(r, g, b, 1.0f).texture(0, 0)
          .overlay(OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
    }
}
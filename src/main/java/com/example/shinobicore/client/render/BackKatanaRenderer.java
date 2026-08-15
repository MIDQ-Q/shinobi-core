package com.example.shinobicore.client.render;

import com.example.shinobicore.item.KatanaItem;
import com.example.shinobicore.item.ModItems;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.client.render.OverlayTexture;
import net.minecraft.client.render.RenderLayer;
import net.minecraft.client.render.VertexConsumer;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.render.entity.feature.FeatureRenderer;
import net.minecraft.client.render.entity.feature.FeatureRendererContext;
import net.minecraft.client.render.entity.model.PlayerEntityModel;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.item.Item;
import net.minecraft.item.ItemStack;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.RotationAxis;
import org.joml.Matrix4f;

/**
 * Scabbard (saya) on the back, colored per katana tier.
 * Visible whenever the player carries a katana in inventory.
 */
public class BackKatanaRenderer extends FeatureRenderer<AbstractClientPlayerEntity, PlayerEntityModel<AbstractClientPlayerEntity>> {
    private static final Identifier TEX = new Identifier("textures/misc/white.png");

    public BackKatanaRenderer(FeatureRendererContext<AbstractClientPlayerEntity, PlayerEntityModel<AbstractClientPlayerEntity>> context) {
        super(context);
    }

    @Override
    public void render(MatrixStack matrices, VertexConsumerProvider vertexConsumers, int light,
                       AbstractClientPlayerEntity entity, float limbAngle, float limbDistance, float tickDelta,
                       float animationProgress, float headYaw, float headPitch) {
        ItemStack katana = null;
        for (int i = 0; i < entity.getInventory().size(); i++) {
            ItemStack s = entity.getInventory().getStack(i);
            if (s.getItem() instanceof KatanaItem) { katana = s; break; }
        }
        if (katana == null) return;

        // Tier palette: scabbard, accent, wrap, tsuba, handle
        float[] saya, accent, wrap, tsuba, handle;
        Item it = katana.getItem();
        if (it == ModItems.KATANA_DIAMOND) {
            saya = new float[]{0.08f,0.12f,0.20f}; accent = new float[]{0.47f,0.86f,0.92f};
            wrap = new float[]{0.35f,0.78f,0.86f}; tsuba = new float[]{0.86f,0.88f,0.90f}; handle = new float[]{0.12f,0.14f,0.18f};
        } else if (it == ModItems.KATANA_NETHERITE) {
            saya = new float[]{0.12f,0.10f,0.12f}; accent = new float[]{0.78f,0.59f,0.24f};
            wrap = new float[]{0.43f,0.24f,0.51f}; tsuba = new float[]{0.78f,0.59f,0.24f}; handle = new float[]{0.10f,0.08f,0.09f};
        } else {
            saya = new float[]{0.10f,0.10f,0.11f}; accent = new float[]{0.90f,0.71f,0.24f};
            wrap = new float[]{0.16f,0.67f,0.67f}; tsuba = new float[]{0.90f,0.71f,0.24f}; handle = new float[]{0.14f,0.12f,0.11f};
        }

        matrices.push();
        this.getContextModel().body.rotate(matrices);
        matrices.translate(0.0f, 0.15f, 0.25f);
        matrices.multiply(RotationAxis.POSITIVE_Z.rotationDegrees(-40.0f));
        matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(180.0f));
        matrices.scale(0.65f, 0.65f, 0.65f);
        VertexConsumer vc = vertexConsumers.getBuffer(RenderLayer.getEntityTranslucent(TEX));
        // Saya (scabbard) + wraps + accent squares (like reference art)
        cuboid(matrices, vc, light, -0.05f, -1.70f, -0.05f, 0.10f, 2.05f, 0.10f, saya);
        cuboid(matrices, vc, light, -0.06f, -1.20f, -0.06f, 0.12f, 0.08f, 0.12f, wrap);
        cuboid(matrices, vc, light, -0.06f, -0.30f, -0.06f, 0.12f, 0.08f, 0.12f, wrap);
        cuboid(matrices, vc, light, -0.02f, -1.45f, -0.062f, 0.04f, 0.08f, 0.012f, accent);
        cuboid(matrices, vc, light, -0.02f, -0.55f, -0.062f, 0.04f, 0.08f, 0.012f, accent);
        // Tsuba + tsuka (handle) sticking out
        cuboid(matrices, vc, light, -0.09f, 0.35f, -0.09f, 0.18f, 0.03f, 0.18f, tsuba);
        cuboid(matrices, vc, light, -0.035f, 0.38f, -0.035f, 0.07f, 0.42f, 0.07f, handle);
        cuboid(matrices, vc, light, -0.04f, 0.46f, -0.04f, 0.08f, 0.03f, 0.08f, wrap);
        cuboid(matrices, vc, light, -0.04f, 0.60f, -0.04f, 0.08f, 0.03f, 0.08f, wrap);
        cuboid(matrices, vc, light, -0.04f, 0.80f, -0.04f, 0.08f, 0.04f, 0.08f, tsuba);
        matrices.pop();
    }

    private void cuboid(MatrixStack matrices, VertexConsumer vc, int light,
                        float x, float y, float z, float w, float h, float d, float[] col) {
        Matrix4f m = matrices.peek().getPositionMatrix();
        float x2 = x + w, y2 = y + h, z2 = z + d;
        float r = col[0], g = col[1], b = col[2];
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

    private void v(VertexConsumer vc, Matrix4f m, float x, float y, float z, float r, float g, float b, int light) {
        vc.vertex(m, x, y, z).color(r, g, b, 1.0f).texture(0, 0)
          .overlay(OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
    }
}
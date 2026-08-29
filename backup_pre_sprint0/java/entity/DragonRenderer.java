package com.example.shinobicore.entity;

import com.example.shinobicore.client.vfx.VoxelMeshCache;
import com.example.shinobicore.client.vfx.VoxelShapeGenerators;
import com.example.shinobicore.client.vfx.VoxelRenderManager;
import net.minecraft.client.render.RenderLayer;
import net.minecraft.client.render.VertexConsumer;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.render.entity.EntityRenderer;
import net.minecraft.client.render.entity.EntityRendererFactory;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.RotationAxis;
import com.example.shinobicore.client.vfx.VoxelPerformanceOptimizer;
import net.minecraft.util.math.Vec3d;

/**
 * S5-04: Renders dragon as segmented voxel serpent.
 * Maintains a local trail for smooth visual, independent of server.
 */
public class DragonRenderer extends EntityRenderer<DragonEntity> {
    private static final Identifier TEX = new Identifier("textures/misc/white.png");
    private static final int TRAIL_LENGTH = 16;
    private final Vec3d[] trail = new Vec3d[TRAIL_LENGTH];
    private Vec3d lastPos = Vec3d.ZERO;
    private boolean initialized = false;

    public DragonRenderer(EntityRendererFactory.Context ctx) { super(ctx); }

    @Override
    public void render(DragonEntity entity, float yaw, float tickDelta,
                       MatrixStack matrices, VertexConsumerProvider vc, int light) {
        super.render(entity, yaw, tickDelta, matrices, vc, light);

        Vec3d currentPos = entity.getPos();
        String elem = entity.getElement();
        int segCount = Math.min(entity.getSegmentCount(), VoxelPerformanceOptimizer.getMaxDragonSegments());
        float age = entity.age + tickDelta;

        // Update local trail
        if (!initialized) {
            for (int i = 0; i < TRAIL_LENGTH; i++) trail[i] = currentPos;
            lastPos = currentPos;
            initialized = true;
        } else if (lastPos.squaredDistanceTo(currentPos) > 0.001) {
            System.arraycopy(trail, 0, trail, 1, TRAIL_LENGTH - 1);
            trail[0] = currentPos;
            lastPos = currentPos;
        }

        // Element colors
        float r, g, b;
        if ("fire".equals(elem)) { r = 1.0f; g = 0.3f; b = 0.1f; }
        else if ("water".equals(elem)) { r = 0.2f; g = 0.5f; b = 1.0f; }
        else { r = 0.6f; g = 0.45f; b = 0.2f; }

        matrices.push();

        // Render head (larger)
        renderSegment(matrices, vc, currentPos, elem, 1.2f, age, light, r, g, b);

        // Render body segments along trail
        for (int i = 1; i < segCount; i++) {
            if (i >= TRAIL_LENGTH || trail[i] == null) break;
            Vec3d segPos = trail[i];
            float scale = 1.0f - (float) i / segCount * 0.5f;
            float wave = (float) Math.sin(age * 0.3 + i * 0.5) * 0.15f;
            Vec3d offsetPos = segPos.add(0, wave, 0);
            renderSegment(matrices, vc, offsetPos, elem, scale, age + i, light, r, g, b);
        }

        // Render tail tip (smallest)
        if (segCount < TRAIL_LENGTH && trail[segCount] != null) {
            Vec3d tailPos = trail[segCount];
            renderSegment(matrices, vc, tailPos, elem, 0.4f, age + segCount, light, r, g, b);
        }

        matrices.pop();
    }

    private void renderSegment(MatrixStack matrices, VertexConsumerProvider vc,
                               Vec3d pos, String elem, float scale, float age,
                               int light, float r, float g, float b) {
        matrices.push();
        matrices.translate(pos.x - lastPos.x, pos.y - lastPos.y, pos.z - lastPos.z);
        matrices.scale(scale, scale, scale);

        // Rotation for visual interest
        float rot = age * 5f;
        matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(rot));

        // Use snakeSegment generator for body, sphere for head
        String modelId = "dragon_seg_" + elem + "_" + (int)(scale * 10);
        var baked = VoxelMeshCache.getOrBakeModel(modelId, () ->
            VoxelShapeGenerators.snakeSegment(0.4f, 0.8f, r, g, b, 0.9f)
        );

        VertexConsumer consumer = vc.getBuffer(RenderLayer.getEntityTranslucent(TEX));
        VoxelMeshCache.renderBaked(matrices.peek().getPositionMatrix(), consumer, baked, light);

        matrices.pop();
    }

    @Override
    public Identifier getTexture(DragonEntity entity) { return TEX; }
}
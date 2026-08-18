package com.example.shinobicore.entity;
import com.example.shinobicore.client.vfx.VoxelCube;
import com.example.shinobicore.client.vfx.VoxelModel;
import com.example.shinobicore.client.vfx.VoxelRenderManager;
import com.example.shinobicore.client.vfx.VoxelShapeGenerators;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.render.entity.EntityRenderer;
import net.minecraft.client.render.entity.EntityRendererFactory;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.RotationAxis;
/**
 * S5-03: Voxel renderer for DoT zones.
 * Renders as expanding/fading dome or vortex depending on element.
 * FIXED: Uses safe copy pattern to avoid 'already baked' exception.
 */
public class DotZoneRenderer extends EntityRenderer<DotZoneEntity> {
    private static final Identifier TEX = new Identifier("textures/misc/white.png");
    public DotZoneRenderer(EntityRendererFactory.Context ctx) { super(ctx); }
    
    @Override
    public void render(DotZoneEntity entity, float yaw, float tickDelta,
                       MatrixStack matrices, VertexConsumerProvider vc, int light) {
        super.render(entity, yaw, tickDelta, matrices, vc, light);
        float radius = entity.getRadius();
        float progress = entity.getProgress();
        String element = entity.getElement();
        float age = entity.age + tickDelta;
        
        // Fade out in last 30% of lifetime
        float alpha = progress > 0.7f ? (1.0f - progress) / 0.3f : 1.0f;
        alpha *= 0.6f; // Base transparency
        
        // Element colors
        float r, g, b;
        switch (element) {
            case "fire" -> { r = 1.0f; g = 0.4f; b = 0.1f; }
            case "water" -> { r = 0.2f; g = 0.5f; b = 1.0f; }
            case "lightning" -> { r = 1.0f; g = 1.0f; b = 0.3f; }
            case "earth" -> { r = 0.7f; g = 0.5f; b = 0.2f; }
            default -> { r = 0.5f; g = 0.8f; b = 1.0f; } // wind
        }
        
        matrices.push();
        // Expand animation at start
        float scale = progress < 0.1f ? progress / 0.1f : 1.0f;
        matrices.scale(scale, scale, scale);
        // Rotation for vortex effect
        matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(age * 3f));
        
        // Generate dome/vortex model (SAFE COPY PATTERN)
        VoxelModel model = new VoxelModel("dot_zone_" + element + "_" + (int)(radius * 10) + "_" + (int)(progress * 10));
        
        if ("wind".equals(element)) {
            VoxelModel ringBase = VoxelShapeGenerators.ring(radius * 0.8f, radius, 0.15f, 16, r, g, b, alpha);
            for (VoxelCube cube : ringBase.getCubes()) model.addCube(cube);
            
            VoxelModel inner = VoxelShapeGenerators.sphere(radius * 0.4f, 6, r, g, b, alpha * 0.4f);
            for (VoxelCube cube : inner.getCubes()) model.addCube(cube);
        } else {
            VoxelModel sphereBase = VoxelShapeGenerators.sphere(radius, 8, r, g, b, alpha * 0.3f);
            for (VoxelCube cube : sphereBase.getCubes()) model.addCube(cube);
            
            VoxelModel shell = VoxelShapeGenerators.ring(radius * 0.9f, radius, 0.08f, 20, r, g, b, alpha);
            for (VoxelCube cube : shell.getCubes()) model.addCube(cube);
        }
        model.bake();
        
        VoxelRenderManager.renderWithCulling(matrices, vc, model,
                entity.getPos(), yaw, 0f, 1.0f, light);
        matrices.pop();
    }
    
    @Override
    public Identifier getTexture(DotZoneEntity entity) { return TEX; }
}
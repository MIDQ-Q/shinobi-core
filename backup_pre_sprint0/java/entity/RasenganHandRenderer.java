package com.example.shinobicore.entity;

import com.example.shinobicore.client.vfx.VoxelModel;
import com.example.shinobicore.client.vfx.VoxelRenderManager;
import com.example.shinobicore.client.vfx.models.VoxelRasenganModel;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.render.entity.EntityRenderer;
import net.minecraft.client.render.entity.EntityRendererFactory;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.RotationAxis;

/**
 * S5-01: Voxel Rasengan renderer replacing old 2D quad renderer.
 * Uses VoxelRenderManager for LOD/culling and VoxelMeshCache for performance.
 */
public class RasenganHandRenderer extends EntityRenderer<RasenganHandEntity> {
    private static final Identifier TEX = new Identifier("textures/misc/white.png");
    
    public RasenganHandRenderer(EntityRendererFactory.Context ctx) { super(ctx); }
    
    @Override
    public void render(RasenganHandEntity entity, float yaw, float tickDelta,
                       MatrixStack matrices, VertexConsumerProvider vc, int light) {
        super.render(entity, yaw, tickDelta, matrices, vc, light);
        
        float age = entity.age + tickDelta;
        float rotation = age * 12f;
        
        // Determine state based on entity age/lifecycle
        VoxelRasenganModel.State state;
        float stateProgress;
        
        if (entity.age < 20) {
            state = VoxelRasenganModel.State.FORMING;
            stateProgress = entity.age / 20f;
        } else if (entity.age < 60) {
            state = VoxelRasenganModel.State.STABILIZING;
            stateProgress = (entity.age - 20) / 40f;
        } else if (entity.age < 500) {
            state = VoxelRasenganModel.State.HELD;
            stateProgress = ((entity.age - 60) % 100) / 100f; // Cycle for ring rotation
        } else if (entity.age < 560) {
            state = VoxelRasenganModel.State.DISSIPATING;
            stateProgress = (entity.age - 500) / 60f;
        } else {
            state = VoxelRasenganModel.State.DISSIPATING;
            stateProgress = 1.0f;
        }
        
        // Pulse effect
        float pulse = 0.95f + 0.05f * (float)Math.sin(age * 0.2);
        
        matrices.push();
        matrices.scale(pulse, pulse, pulse);
        matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(rotation));
        matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(rotation * 0.3f));
        
        VoxelModel model = VoxelRasenganModel.generate(state, stateProgress, rotation);
        
        // Use VoxelRenderManager for optimized rendering
        VoxelRenderManager.renderWithCulling(matrices, vc, model, 
            entity.getPos(), yaw, 0f, 1.0f, light);
        
        matrices.pop();
    }
    
    @Override
    public Identifier getTexture(RasenganHandEntity entity) { return TEX; }
}
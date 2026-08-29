package com.example.shinobicore.entity;

import com.example.shinobicore.client.vfx.VoxelModel;
import com.example.shinobicore.client.vfx.VoxelRenderManager;
import com.example.shinobicore.client.vfx.models.VoxelRasenshurikenModel;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.render.entity.EntityRenderer;
import net.minecraft.client.render.entity.EntityRendererFactory;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.RotationAxis;

/**
 * S5-02: Voxel Rasenshuriken renderer replacing old 2D quad renderer.
 */
public class RasenshurikenRenderer extends EntityRenderer<RasenshurikenEntity> {
    private static final Identifier TEX = new Identifier("textures/misc/white.png");
    
    public RasenshurikenRenderer(EntityRendererFactory.Context ctx) { super(ctx); }
    
    @Override
    public void render(RasenshurikenEntity entity, float yaw, float tickDelta,
                       MatrixStack matrices, VertexConsumerProvider vc, int light) {
        super.render(entity, yaw, tickDelta, matrices, vc, light);
        
        float age = entity.age + tickDelta;
        float rotation = age * 20f; // Fast spin
        
        // Charge progress: grows over first 60 ticks when held
        float chargeProgress;
        if (!entity.isLaunched()) {
            chargeProgress = Math.min(1.0f, entity.age / 60f);
        } else {
            chargeProgress = 1.0f;
        }
        
        matrices.push();
        matrices.translate(0, 0.3, 0);
        
        // Spin around Y axis
        matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(rotation));
        // Slight tilt for visual interest
        matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(5f));
        
        VoxelModel model = VoxelRasenshurikenModel.generate(rotation, chargeProgress);
        
        VoxelRenderManager.renderWithCulling(matrices, vc, model,
            entity.getPos(), yaw, 0f, 1.0f, light);
        
        matrices.pop();
    }
    
    @Override
    public Identifier getTexture(RasenshurikenEntity entity) { return TEX; }
}
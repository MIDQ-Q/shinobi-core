package com.example.shinobicore.entity;

import com.example.shinobicore.client.vfx.VoxelMeshCache;
import com.example.shinobicore.client.vfx.VoxelModel;
import com.example.shinobicore.client.vfx.VoxelShapeGenerators;
import net.minecraft.client.render.OverlayTexture;
import net.minecraft.client.render.RenderLayer;
import net.minecraft.client.render.VertexConsumer;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.render.entity.EntityRenderer;
import net.minecraft.client.render.entity.EntityRendererFactory;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.RotationAxis;

public class VoxelProjectileRenderer extends EntityRenderer<VoxelProjectileEntity> {
    private static final Identifier TEX = new Identifier("textures/misc/white.png");

    public VoxelProjectileRenderer(EntityRendererFactory.Context ctx) { 
        super(ctx); 
    }

    @Override
    public void render(VoxelProjectileEntity entity, float yaw, float tickDelta, 
                       MatrixStack matrices, VertexConsumerProvider vcp, int light) {
        super.render(entity, yaw, tickDelta, matrices, vcp, light);
        
        String modelId = entity.getModelId();
        float scale = entity.getScale();
        int color = entity.getColor();
        
        // Extract RGBA from packed int
        float r = ((color >> 16) & 0xFF) / 255f;
        float g = ((color >> 8) & 0xFF) / 255f;
        float b = (color & 0xFF) / 255f;
        float a = ((color >> 24) & 0xFF) / 255f;
        if (a < 0.01f) a = 1.0f;
        
        // Generate model procedurally (cached internally by VoxelMeshCache ideally, 
        // but here we generate simple sphere for fallback)
        VoxelModel model = VoxelShapeGenerators.sphere(0.5f, 8, r, g, b, a);
        
        matrices.push();
        matrices.scale(scale, scale, scale);
        
        // FIX: Accessing public field 'age' directly
        float rotation = (entity.age + tickDelta) * 10f;
        matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(rotation));
        
        VertexConsumer vc = vcp.getBuffer(RenderLayer.getEntityTranslucent(TEX));
        var baked = VoxelMeshCache.getOrBake(modelId, model);
        VoxelMeshCache.renderBaked(matrices.peek().getPositionMatrix(), vc, baked, light);
        
        matrices.pop();
    }

    @Override 
    public Identifier getTexture(VoxelProjectileEntity entity) { 
        return TEX; 
    }
}
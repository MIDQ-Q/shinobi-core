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
        
        // Select shape based on modelId - FIX: No longer always uses sphere
        VoxelModel model = selectModelForId(modelId, scale, r, g, b, a);
        
        matrices.push();
        matrices.scale(scale, scale, scale);
        
        // Rotate projectile to face direction of travel
        float rotation = (entity.age + tickDelta) * 3f;
        matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(rotation));
        
        VertexConsumer vc = vcp.getBuffer(RenderLayer.getEntityTranslucent(TEX));
        var baked = VoxelMeshCache.getOrBake(modelId, model);
        VoxelMeshCache.renderBaked(matrices.peek().getPositionMatrix(), vc, baked, light);
        
        matrices.pop();
    }
    
    /**
     * Select appropriate voxel model based on technique model ID.
     * Maps model IDs from JSON to procedural shape generators.
     */
    private VoxelModel selectModelForId(String modelId, float scale, float r, float g, float b, float a) {
        // Default size parameters
        float size = scale * 0.5f;
        int resolution = 12;
        
        // Check modelId for known patterns
        String lowerId = modelId.toLowerCase();
        
        // Fire techniques - use dense fireball sphere
        if (lowerId.contains("fireball") || lowerId.contains("fire") || lowerId.contains("flame") || 
            lowerId.contains("phoenix") || lowerId.contains("barrage") || lowerId.contains("hard_work") ||
            lowerId.contains("toad_oil")) {
            return VoxelShapeGenerators.fireball(size, resolution, r, g, b, a);
        }
        
        // Water shark
        if (lowerId.contains("shark")) {
            return VoxelShapeGenerators.waterShark(size * 1.5f, size * 0.6f, r, g, b, a);
        }
        
        // Rasengan variants
        if (lowerId.contains("rasengan")) {
            return VoxelShapeGenerators.rasengan(size * 0.8f, resolution, r, g, b, a);
        }
        
        // Shuriken/star shapes
        if (lowerId.contains("shuriken") || lowerId.contains("star")) {
            return VoxelShapeGenerators.shurikenStar(size, size * 0.1f, r, g, b, a);
        }
        
        // Dragon segments
        if (lowerId.contains("dragon")) {
            return VoxelShapeGenerators.snakeSegment(size * 0.7f, size, r, g, b, a);
        }
        
        // Kunai/blade projectiles
        if (lowerId.contains("kunai") || lowerId.contains("blade")) {
            return VoxelShapeGenerators.kunaiBlade(size * 1.2f, size * 0.3f, r, g, b, a);
        }
        
        // Cone/projectile shapes
        if (lowerId.contains("cone") || lowerId.contains("projectile")) {
            return VoxelShapeGenerators.projectile(size, 1.5f, r, g, b, a);
        }
        
        // Disc/ring shapes
        if (lowerId.contains("disc") || lowerId.contains("ring")) {
            return VoxelShapeGenerators.ring(size * 0.5f, size, size * 0.1f, resolution, r, g, b, a);
        }
        
        // Default fallback - use dense sphere instead of hollow one
        return VoxelShapeGenerators.denseSphere(size, resolution, r, g, b, a);
    }

    @Override 
    public Identifier getTexture(VoxelProjectileEntity entity) { 
        return TEX; 
    }
}
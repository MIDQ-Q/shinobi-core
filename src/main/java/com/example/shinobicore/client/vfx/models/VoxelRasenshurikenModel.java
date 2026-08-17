package com.example.shinobicore.client.vfx.models;

import com.example.shinobicore.client.vfx.VoxelCube;
import com.example.shinobicore.client.vfx.VoxelModel;
import com.example.shinobicore.client.vfx.VoxelShapeGenerators;

/**
 * S5-02: Voxel Rasenshuriken model.
 * Central sphere + 4 rotating wind blades.
 */
public class VoxelRasenshurikenModel {
    
    /**
     * Generate Rasenshuriken model.
     * @param rotation Blade rotation angle (degrees)
     * @param chargeProgress 0.0 (forming) to 1.0 (full)
     * @return VoxelModel ready for rendering
     */
    public static VoxelModel generate(float rotation, float chargeProgress) {
        String id = "rasenshuriken_" + (int)(rotation % 360) + "_" + (int)(chargeProgress * 10);
        VoxelModel model = new VoxelModel(id);
        
        float r = 0.4f, g = 0.75f, b = 1.0f, a = 0.85f;
        float coreRadius = 0.3f * chargeProgress;
        
        if (coreRadius < 0.05f) coreRadius = 0.05f;
        
        // Central sphere (mini-rasengan core)
        VoxelModel core = VoxelShapeGenerators.sphere(coreRadius, 8, 0.5f, 0.8f, 1.0f, a);
        for (var cube : core.getCubes()) model.addCube(cube);
        
        // Inner glow
        VoxelModel glow = VoxelShapeGenerators.sphere(coreRadius * 0.5f, 6, 0.7f, 0.9f, 1.0f, 0.5f);
        for (var cube : glow.getCubes()) model.addCube(cube);
        
        // 4 Wind Blades
        float bladeLength = 1.2f * chargeProgress;
        float bladeWidth = 0.25f * chargeProgress;
        float bladeThickness = 0.06f;
        
        if (bladeLength < 0.1f) return model;
        
        for (int i = 0; i < 4; i++) {
            float bladeAngle = (float)(i * Math.PI / 2.0);
            float cos = (float)Math.cos(bladeAngle);
            float sin = (float)Math.sin(bladeAngle);
            
            // Each blade is a tapered shape made of segments
            int segments = 6;
            for (int s = 0; s < segments; s++) {
                float t = (s + 0.5f) / segments;
                float dist = coreRadius + t * bladeLength;
                float segWidth = bladeWidth * (1.0f - t * 0.6f); // Taper towards tip
                
                float bx = cos * dist;
                float bz = sin * dist;
                
                model.addCube(new VoxelCube(bx, 0, bz, 
                    segWidth, bladeThickness, segWidth, 
                    r, g, b, a * (1.0f - t * 0.3f), false, false));
            }
        }
        
        // Outer ring (torus approximation)
        if (chargeProgress > 0.5f) {
            float ringAlpha = (chargeProgress - 0.5f) * 2.0f;
            VoxelModel ring = VoxelShapeGenerators.ring(
                bladeLength * 0.7f, bladeLength * 0.85f, 0.04f, 20, 
                r, g, b, ringAlpha * 0.5f);
            for (var cube : ring.getCubes()) model.addCube(cube);
        }
        
        return model;
    }
}
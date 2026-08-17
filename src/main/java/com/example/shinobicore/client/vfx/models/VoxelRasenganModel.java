package com.example.shinobicore.client.vfx.models;

import com.example.shinobicore.client.vfx.VoxelCube;
import com.example.shinobicore.client.vfx.VoxelModel;
import com.example.shinobicore.client.vfx.VoxelShapeGenerators;

/**
 * S5-01: Voxel Rasengan with 5 animation states.
 * States: FORMING, STABILIZING, HELD, STRIKE, DISSIPATING
 */
public class VoxelRasenganModel {
    
    public enum State {
        FORMING, STABILIZING, HELD, STRIKE, DISSIPATING
    }
    
    /**
     * Generate Rasengan model for current state and progress.
     * @param state Current animation state
     * @param progress 0.0 to 1.0 within current state
     * @param rotation Continuous rotation angle (degrees)
     * @return Baked VoxelModel ready for rendering
     */
    public static VoxelModel generate(State state, float progress, float rotation) {
        String id = "rasengan_" + state.name() + "_" + (int)(progress * 10) + "_" + (int)(rotation % 360);
        VoxelModel model = new VoxelModel(id);
        
        float baseRadius = 0.35f;
        float r = 0.3f, g = 0.6f, b = 1.0f, a = 0.9f;
        
        switch (state) {
            case FORMING -> {
                // Small chaotic sphere growing
                float scale = 0.2f + progress * 0.8f;
                float chaos = (1.0f - progress) * 0.15f;
                VoxelModel core = VoxelShapeGenerators.sphere(baseRadius * scale, 6, r, g, b, a * progress);
                // Add random offset cubes for chaos effect
                for (int i = 0; i < 8; i++) {
                    float ox = (float)(Math.random() - 0.5) * chaos * 2;
                    float oy = (float)(Math.random() - 0.5) * chaos * 2;
                    float oz = (float)(Math.random() - 0.5) * chaos * 2;
                    core.addCube(VoxelCube.translucent(ox, oy, oz, 0.08f, 0.08f, 0.08f, r, g, b, a * 0.6f));
                }
                return core;
            }
            case STABILIZING -> {
                // Sphere becoming smooth, rings appearing
                VoxelModel core = VoxelShapeGenerators.sphere(baseRadius, 8, r, g, b, a);
                if (progress > 0.3f) {
                    float ringAlpha = (progress - 0.3f) / 0.7f;
                    VoxelModel ring = VoxelShapeGenerators.ring(baseRadius * 1.2f, baseRadius * 1.35f, 0.03f, 12, 0.6f, 0.8f, 1.0f, ringAlpha * 0.7f);
                    // Merge ring cubes into core
                    for (var cube : ring.getCubes()) core.addCube(cube);
                }
                return core;
            }
            case HELD -> {
                // Full stable rasengan with rotating rings
                VoxelModel core = VoxelShapeGenerators.sphere(baseRadius, 8, r, g, b, a);
                // Inner glow
                VoxelModel glow = VoxelShapeGenerators.sphere(baseRadius * 0.6f, 6, 0.6f, 0.85f, 1.0f, 0.5f);
                for (var cube : glow.getCubes()) core.addCube(cube);
                // Ring 1
                VoxelModel ring1 = VoxelShapeGenerators.ring(baseRadius * 1.2f, baseRadius * 1.35f, 0.03f, 16, 0.6f, 0.8f, 1.0f, 0.7f);
                for (var cube : ring1.getCubes()) core.addCube(cube);
                // Ring 2 (perpendicular approximation via offset cubes)
                VoxelModel ring2 = VoxelShapeGenerators.ring(baseRadius * 1.1f, baseRadius * 1.25f, 0.025f, 14, 0.5f, 0.7f, 1.0f, 0.5f);
                for (var cube : ring2.getCubes()) core.addCube(cube);
                return core;
            }
            case STRIKE -> {
                // Compressed, brighter, trailing
                float compression = 1.0f - progress * 0.3f;
                float brightness = 1.0f + progress * 0.5f;
                VoxelModel core = VoxelShapeGenerators.sphere(baseRadius * compression, 8, 
                    Math.min(1f, r * brightness), Math.min(1f, g * brightness), Math.min(1f, b * brightness), a);
                // Impact flash
                if (progress > 0.7f) {
                    float flashAlpha = (progress - 0.7f) / 0.3f;
                    VoxelModel flash = VoxelShapeGenerators.sphere(baseRadius * 2.0f, 6, 1.0f, 1.0f, 1.0f, flashAlpha * 0.4f);
                    for (var cube : flash.getCubes()) core.addCube(cube);
                }
                return core;
            }
            case DISSIPATING -> {
                // Expanding, fading, breaking apart
                float expansion = 1.0f + progress * 1.5f;
                float fade = 1.0f - progress;
                VoxelModel core = VoxelShapeGenerators.sphere(baseRadius * expansion, 6, r, g, b, a * fade);
                // Scatter particles
                int scatterCount = (int)(progress * 12);
                for (int i = 0; i < scatterCount; i++) {
                    float angle = (i / 12.0f) * (float)(Math.PI * 2);
                    float dist = baseRadius * expansion * (1.0f + progress);
                    float sx = (float)Math.cos(angle) * dist;
                    float sy = (float)(Math.random() - 0.5) * dist * 0.5f;
                    float sz = (float)Math.sin(angle) * dist;
                    core.addCube(VoxelCube.translucent(sx, sy, sz, 0.06f, 0.06f, 0.06f, r, g, b, fade * 0.5f));
                }
                return core;
            }
        }
        return VoxelShapeGenerators.sphere(baseRadius, 6, r, g, b, a);
    }
}
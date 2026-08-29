package com.example.shinobicore.client.vfx;

/**
 * S4-01: Single voxel cube definition.
 * Immutable record describing one cube in a voxel model.
 *
 * Fields:
 *   x, y, z   - center position
 *   w, h, d   - width, height, depth
 *   r, g, b, a - RGBA color (0..1)
 *   emissive  - if true, rendered at max light (glow)
 *   doubleSided - if true, both faces rendered (for thin effects)
 */
public record VoxelCube(
    float x, float y, float z,
    float w, float h, float d,
    float r, float g, float b, float a,
    boolean emissive,
    boolean doubleSided
) {
    /** Convenience: non-emissive, single-sided cube. */
    public static VoxelCube solid(float x, float y, float z,
                                  float w, float h, float d,
                                  float r, float g, float b) {
        return new VoxelCube(x, y, z, w, h, d, r, g, b, 1f, false, false);
    }

    /** Convenience: translucent, non-emissive cube. */
    public static VoxelCube translucent(float x, float y, float z,
                                        float w, float h, float d,
                                        float r, float g, float b, float a) {
        return new VoxelCube(x, y, z, w, h, d, r, g, b, a, false, false);
    }

    /** Convenience: emissive (glowing) cube. */
    public static VoxelCube emissive(float x, float y, float z,
                                     float w, float h, float d,
                                     float r, float g, float b) {
        return new VoxelCube(x, y, z, w, h, d, r, g, b, 1f, true, false);
    }
}
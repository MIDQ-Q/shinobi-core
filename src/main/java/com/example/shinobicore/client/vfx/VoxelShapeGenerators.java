package com.example.shinobicore.client.vfx;

/**
 * S4-02: Procedural voxel shape generators.
 * Each method returns a VoxelModel built from cubes.
 * Resolution controls detail vs performance.
 *
 * All shapes are centered at origin. Use MatrixStack to position.
 */
public class VoxelShapeGenerators {

    // --- SPHERE ---
    public static VoxelModel sphere(float radius, int resolution,
                                    float r, float g, float b, float a) {
        VoxelModel model = new VoxelModel("sphere_r" + radius + "_res" + resolution);
        float cubeSize = (radius * 2f) / resolution;
        for (int iy = 0; iy < resolution; iy++) {
            float phi = (iy + 0.5f) / resolution * (float) Math.PI;
            float y = (float) Math.cos(phi) * radius;
            float ringR = (float) Math.sin(phi) * radius;
            if (ringR < cubeSize * 0.3f) ringR = cubeSize * 0.3f;
            int count = Math.max(4, (int) (ringR * 2f * (float) Math.PI / cubeSize));
            for (int ix = 0; ix < count; ix++) {
                float theta = (ix + 0.5f) / count * (float) Math.PI * 2f;
                float x = ringR * (float) Math.cos(theta);
                float z = ringR * (float) Math.sin(theta);
                model.addCube(new VoxelCube(x, y, z,
                    cubeSize, cubeSize, cubeSize, r, g, b, a, false, false));
            }
        }
        model.bake();
        return model;
    }

    // --- CONE ---
    public static VoxelModel cone(float radius, float height, int resolution,
                                  float r, float g, float b, float a) {
        VoxelModel model = new VoxelModel("cone_r" + radius + "_h" + height);
        float cubeSize = Math.min(radius * 2f / resolution, height / resolution);
        for (int iy = 0; iy < resolution; iy++) {
            float t = (iy + 0.5f) / resolution;
            float y = -height * 0.5f + t * height;
            float ringR = radius * (1f - t);
            if (ringR < cubeSize * 0.3f) continue;
            int count = Math.max(4, (int) (ringR * 2f * (float) Math.PI / cubeSize));
            for (int ix = 0; ix < count; ix++) {
                float theta = (ix + 0.5f) / count * (float) Math.PI * 2f;
                float x = ringR * (float) Math.cos(theta);
                float z = ringR * (float) Math.sin(theta);
                model.addCube(new VoxelCube(x, y, z,
                    cubeSize, cubeSize, cubeSize, r, g, b, a, false, false));
            }
        }
        model.bake();
        return model;
    }

    // --- DISC (flat filled circle) ---
    public static VoxelModel disc(float radius, float thickness, int resolution,
                                  float r, float g, float b, float a) {
        VoxelModel model = new VoxelModel("disc_r" + radius);
        float cubeSize = (radius * 2f) / resolution;
        model.addCube(new VoxelCube(0, 0, 0,
            cubeSize, thickness, cubeSize, r, g, b, a, false, false));
        int rings = Math.max(1, resolution / 2);
        for (int ring = 1; ring <= rings; ring++) {
            float ringR = ring * cubeSize;
            if (ringR > radius) break;
            int count = Math.max(4, (int) (ringR * 2f * (float) Math.PI / cubeSize));
            for (int i = 0; i < count; i++) {
                float theta = (i + 0.5f) / count * (float) Math.PI * 2f;
                float x = ringR * (float) Math.cos(theta);
                float z = ringR * (float) Math.sin(theta);
                model.addCube(new VoxelCube(x, 0, z,
                    cubeSize, thickness, cubeSize, r, g, b, a, false, false));
            }
        }
        model.bake();
        return model;
    }

    // --- RING (torus-like) ---
    public static VoxelModel ring(float innerR, float outerR, float thickness,
                                  int resolution,
                                  float r, float g, float b, float a) {
        VoxelModel model = new VoxelModel("ring_" + innerR + "_" + outerR);
        float midR = (innerR + outerR) * 0.5f;
        float tubeR = (outerR - innerR) * 0.5f;
        int count = Math.max(8, resolution);
        for (int i = 0; i < count; i++) {
            float theta = (i + 0.5f) / count * (float) Math.PI * 2f;
            float x = midR * (float) Math.cos(theta);
            float z = midR * (float) Math.sin(theta);
            model.addCube(new VoxelCube(x, 0, z,
                tubeR * 2f, thickness, tubeR * 2f, r, g, b, a, false, false));
        }
        model.bake();
        return model;
    }

    // --- BLADE (tapered elongated shape) ---
    public static VoxelModel blade(float length, float width, float thickness,
                                   float r, float g, float b, float a) {
        VoxelModel model = new VoxelModel("blade_l" + length);
        int segments = Math.max(3, (int) (length / width));
        float segLen = length / segments;
        for (int i = 0; i < segments; i++) {
            float t = (i + 0.5f) / segments;
            float x = -length * 0.5f + t * length;
            float w = width * (1f - t * 0.6f);
            if (w < thickness * 0.5f) w = thickness * 0.5f;
            model.addCube(new VoxelCube(x, 0, 0,
                segLen, w, thickness, r, g, b, a, false, false));
        }
        model.bake();
        return model;
    }

    // --- PROJECTILE (elongated sphere / teardrop) ---
    public static VoxelModel projectile(float radius, float elongation,
                                        float r, float g, float b, float a) {
        VoxelModel model = new VoxelModel("projectile_r" + radius + "_e" + elongation);
        int resolution = Math.max(4, (int) (radius * 4f));
        float cubeSize = (radius * 2f) / resolution;
        for (int iy = 0; iy < resolution; iy++) {
            float phi = (iy + 0.5f) / resolution * (float) Math.PI;
            float y = (float) Math.cos(phi) * radius * elongation;
            float ringR = (float) Math.sin(phi) * radius;
            if (ringR < cubeSize * 0.3f) ringR = cubeSize * 0.3f;
            int count = Math.max(4, (int) (ringR * 2f * (float) Math.PI / cubeSize));
            for (int ix = 0; ix < count; ix++) {
                float theta = (ix + 0.5f) / count * (float) Math.PI * 2f;
                float x = ringR * (float) Math.cos(theta);
                float z = ringR * (float) Math.sin(theta);
                model.addCube(new VoxelCube(x, y, z,
                    cubeSize, cubeSize * elongation, cubeSize, r, g, b, a, false, false));
            }
        }
        model.bake();
        return model;
    }

    // --- SNAKE SEGMENT (cylinder for dragon/serpent bodies) ---
    public static VoxelModel snakeSegment(float radius, float length,
                                          float r, float g, float b, float a) {
        VoxelModel model = new VoxelModel("snake_r" + radius + "_l" + length);
        int segments = Math.max(3, (int) (length / radius));
        float segLen = length / segments;
        for (int i = 0; i < segments; i++) {
            float y = -length * 0.5f + (i + 0.5f) * segLen;
            float bulge = 0.8f + 0.2f * (float) Math.sin((i + 0.5f) / segments * (float) Math.PI);
            float segR = radius * bulge;
            model.addCube(new VoxelCube(0, y, 0,
                segR * 2f, segLen, segR * 2f, r, g, b, a, false, false));
        }
        model.bake();
        return model;
    }

    // === S4-07: LOD VARIANTS ===
    
    /** Low-detail sphere for far distances (4 segments instead of full resolution) */
    public static VoxelModel sphereLow(float radius, float r, float g, float b, float a) {
        return sphere(radius, 4, r, g, b, a);
    }
    
    /** Low-detail projectile (elongated sphere with minimal segments) */
    public static VoxelModel projectileLow(float radius, float elongation, float r, float g, float b, float a) {
        return projectile(radius, elongation, r, g, b, a);
    }}
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
    }

    // === S4-08: ADDITIONAL SHAPES FOR NARUTO TECHNIQUES ===

    /** Improved fireball sphere - more dense and round */
    public static VoxelModel fireball(float radius, int resolution, float r, float g, float b, float a) {
        VoxelModel model = new VoxelModel("fireball_r" + radius + "_res" + resolution);
        float cubeSize = (radius * 2f) / resolution;
        
        // Fill the sphere more densely
        for (int iy = 0; iy < resolution; iy++) {
            float y = -radius + (iy + 0.5f) * cubeSize;
            for (int ix = 0; ix < resolution; ix++) {
                float x = -radius + (ix + 0.5f) * cubeSize;
                for (int iz = 0; iz < resolution; iz++) {
                    float z = -radius + (iz + 0.5f) * cubeSize;
                    float distSq = x*x + y*y + z*z;
                    if (distSq <= radius * radius && distSq >= (radius * 0.6f) * (radius * 0.6f)) {
                        model.addCube(new VoxelCube(x, y, z,
                            cubeSize * 0.9f, cubeSize * 0.9f, cubeSize * 0.9f, r, g, b, a, false, false));
                    }
                }
            }
        }
        model.bake();
        return model;
    }

    /** Shuriken star shape - flat with 4 points */
    public static VoxelModel shurikenStar(float size, float thickness, float r, float g, float b, float a) {
        VoxelModel model = new VoxelModel("shuriken_size" + size);
        float armWidth = size * 0.25f;
        float centerSize = size * 0.3f;
        
        // Center square
        model.addCube(new VoxelCube(0, 0, 0,
            centerSize, thickness, centerSize, r, g, b, a, false, false));
        
        // Four arms
        float armLength = size * 0.5f;
        // Right arm
        model.addCube(new VoxelCube(armLength * 0.7f, 0, 0,
            armLength, armWidth, thickness, r, g, b, a, false, false));
        // Left arm
        model.addCube(new VoxelCube(-armLength * 0.7f, 0, 0,
            armLength, armWidth, thickness, r, g, b, a, false, false));
        // Top arm
        model.addCube(new VoxelCube(0, 0, armLength * 0.7f,
            armWidth, thickness, armLength, r, g, b, a, false, false));
        // Bottom arm
        model.addCube(new VoxelCube(0, 0, -armLength * 0.7f,
            armWidth, thickness, armLength, r, g, b, a, false, false));
        
        // Diagonal tips for star effect
        float tipOffset = armLength * 0.8f;
        float tipSize = armWidth * 0.8f;
        model.addCube(new VoxelCube(tipOffset, 0, tipOffset, tipSize, thickness, tipSize, r, g, b, a, false, false));
        model.addCube(new VoxelCube(-tipOffset, 0, tipOffset, tipSize, thickness, tipSize, r, g, b, a, false, false));
        model.addCube(new VoxelCube(tipOffset, 0, -tipOffset, tipSize, thickness, tipSize, r, g, b, a, false, false));
        model.addCube(new VoxelCube(-tipOffset, 0, -tipOffset, tipSize, thickness, tipSize, r, g, b, a, false, false));
        
        model.bake();
        return model;
    }

    /** Water shark - elongated teardrop shape */
    public static VoxelModel waterShark(float length, float width, float r, float g, float b, float a) {
        VoxelModel model = new VoxelModel("water_shark_l" + length);
        int segments = 8;
        float segLen = length / segments;
        
        for (int i = 0; i < segments; i++) {
            float t = i / (float)segments;
            float x = -length * 0.5f + (i + 0.5f) * segLen;
            
            // Taper at both ends, wider in middle
            float widthFactor = 1f - Math.abs(t - 0.5f) * 1.2f;
            if (widthFactor < 0.3f) widthFactor = 0.3f;
            float segWidth = width * widthFactor;
            float segHeight = segWidth * 0.8f;
            
            model.addCube(new VoxelCube(x, 0, 0,
                segLen * 0.95f, segHeight, segWidth, r, g, b, a, false, false));
        }
        
        // Add fin on top
        float finX = -length * 0.1f;
        float finHeight = width * 0.6f;
        model.addCube(new VoxelCube(finX, finHeight * 0.5f, 0,
            length * 0.3f, finHeight, width * 0.1f, r, g, b, a * 0.8f, false, false));
        
        // Tail fin
        float tailX = -length * 0.45f;
        model.addCube(new VoxelCube(tailX, 0, width * 0.3f,
            length * 0.15f, width * 0.4f, width * 0.3f, r, g, b, a, false, false));
        model.addCube(new VoxelCube(tailX, 0, -width * 0.3f,
            length * 0.15f, width * 0.4f, width * 0.3f, r, g, b, a, false, false));
        
        model.bake();
        return model;
    }

    /** Kunai blade shape */
    public static VoxelModel kunaiBlade(float length, float width, float r, float g, float b, float a) {
        VoxelModel model = new VoxelModel("kunai_l" + length);
        
        // Blade (triangular taper)
        float bladeLen = length * 0.6f;
        float handleLen = length * 0.4f;
        
        // Main blade
        model.addCube(new VoxelCube(bladeLen * 0.3f, 0, 0,
            bladeLen * 0.5f, width * 0.9f, width, r, g, b, a, false, false));
        // Blade tip
        model.addCube(new VoxelCube(bladeLen * 0.8f, 0, 0,
            bladeLen * 0.2f, width * 0.4f, width * 0.6f, r, g, b, a, false, false));
        // Handle
        model.addCube(new VoxelCube(-handleLen * 0.5f, 0, 0,
            handleLen, width * 0.5f, width * 0.5f, r * 0.7f, g * 0.7f, b * 0.7f, a, false, false));
        // Ring at end of handle
        model.addCube(new VoxelCube(-handleLen * 0.95f, 0, 0,
            width * 0.1f, width * 0.8f, width * 0.8f, r * 0.5f, g * 0.5f, b * 0.5f, a, false, false));
        
        model.bake();
        return model;
    }

    /** Dense sphere - solid filled sphere for better visual */
    public static VoxelModel denseSphere(float radius, int resolution, float r, float g, float b, float a) {
        VoxelModel model = new VoxelModel("dense_sphere_r" + radius);
        float cubeSize = (radius * 2f) / resolution;
        
        for (int iy = 0; iy < resolution; iy++) {
            float y = -radius + (iy + 0.5f) * cubeSize;
            for (int ix = 0; ix < resolution; ix++) {
                float x = -radius + (ix + 0.5f) * cubeSize;
                for (int iz = 0; iz < resolution; iz++) {
                    float z = -radius + (iz + 0.5f) * cubeSize;
                    float distSq = x*x + y*y + z*z;
                    if (distSq <= radius * radius) {
                        model.addCube(new VoxelCube(x, y, z,
                            cubeSize * 0.95f, cubeSize * 0.95f, cubeSize * 0.95f, r, g, b, a, false, false));
                    }
                }
            }
        }
        model.bake();
        return model;
    }

    /** Rasengan sphere - smaller, denser with swirling effect suggestion */
    public static VoxelModel rasengan(float radius, int resolution, float r, float g, float b, float a) {
        VoxelModel model = new VoxelModel("rasengan_r" + radius);
        float cubeSize = (radius * 2f) / resolution;
        float innerRadius = radius * 0.7f;
        
        for (int iy = 0; iy < resolution; iy++) {
            float y = -radius + (iy + 0.5f) * cubeSize;
            for (int ix = 0; ix < resolution; ix++) {
                float x = -radius + (ix + 0.5f) * cubeSize;
                for (int iz = 0; iz < resolution; iz++) {
                    float z = -radius + (iz + 0.5f) * cubeSize;
                    float distSq = x*x + y*y + z*z;
                    
                    // Dense core
                    if (distSq <= innerRadius * innerRadius) {
                        model.addCube(new VoxelCube(x, y, z,
                            cubeSize * 0.9f, cubeSize * 0.9f, cubeSize * 0.9f, r, g, b, a, false, false));
                    }
                    // Outer swirling layer (sparse)
                    else if (distSq <= radius * radius && ((ix + iy + iz) % 3 == 0)) {
                        model.addCube(new VoxelCube(x, y, z,
                            cubeSize * 0.7f, cubeSize * 0.7f, cubeSize * 0.7f, r, g, b, a * 0.7f, false, false));
                    }
                }
            }
        }
        model.bake();
        return model;
    }

    /** Dragon head segment - for dragon techniques */
    public static VoxelModel dragonHead(float size, float r, float g, float b, float a) {
        VoxelModel model = new VoxelModel("dragon_head_size" + size);
        
        // Main head
        model.addCube(new VoxelCube(size * 0.3f, 0, 0,
            size * 0.6f, size * 0.7f, size * 0.5f, r, g, b, a, false, false));
        // Snout
        model.addCube(new VoxelCube(size * 0.8f, 0, 0,
            size * 0.3f, size * 0.4f, size * 0.3f, r, g, b, a, false, false));
        // Eyes
        model.addCube(new VoxelCube(size * 0.5f, size * 0.2f, size * 0.3f,
            size * 0.15f, size * 0.15f, size * 0.1f, 1f, 1f, 0f, a, false, false));
        model.addCube(new VoxelCube(size * 0.5f, size * 0.2f, -size * 0.3f,
            size * 0.15f, size * 0.15f, size * 0.1f, 1f, 1f, 0f, a, false, false));
        // Horns
        model.addCube(new VoxelCube(size * 0.4f, size * 0.5f, size * 0.1f,
            size * 0.2f, size * 0.3f, size * 0.1f, r * 0.8f, g * 0.8f, b * 0.8f, a, false, false));
        model.addCube(new VoxelCube(size * 0.4f, size * 0.5f, -size * 0.1f,
            size * 0.2f, size * 0.3f, size * 0.1f, r * 0.8f, g * 0.8f, b * 0.8f, a, false, false));
        
        model.bake();
        return model;
    }
}
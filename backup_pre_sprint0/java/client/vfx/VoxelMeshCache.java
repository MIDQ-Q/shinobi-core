package com.example.shinobicore.client.vfx;

import net.minecraft.client.render.*;
import net.minecraft.util.Identifier;
import org.joml.Matrix4f;
import java.util.HashMap;
import java.util.Map;

/**
 * S4-03: Caches baked voxel meshes for efficient batch rendering.
 * Instead of generating vertices every frame, we bake once and reuse.
 */
public class VoxelMeshCache {
    private static final Identifier TEX = new Identifier("textures/misc/white.png");
    private static final Map<String, BakedMesh> CACHE = new HashMap<>();

    public record BakedMesh(float[] vertices, int vertexCount) {}

    /**
     * Get or create a baked mesh for a model ID.
     */
    public static BakedMesh getOrBake(String modelId, VoxelModel model) {
        return CACHE.computeIfAbsent(modelId, id -> bake(model));
    }

    private static BakedMesh bake(VoxelModel model) {
        // Each cube has 6 faces * 4 vertices * 8 floats (x,y,z, r,g,b,a, light/norm packed?) 
        // Actually VertexConsumer format: pos(3) + color(4) + uv(2) + overlay(1) + light(1) + normal(3) = 14 floats per vertex
        // Simplified: We store raw float data matching our render layout
        int cubes = model.getCubeCount();
        int vertsPerCube = 24; // 6 faces * 4 verts
        float[] data = new float[cubes * vertsPerCube * 10]; // 10 floats per vert simplified storage
        int idx = 0;

        for (VoxelCube c : model.getCubes()) {
            float x0 = c.x() - c.w() * 0.5f; float y0 = c.y() - c.h() * 0.5f; float z0 = c.z() - c.d() * 0.5f;
            float x1 = c.x() + c.w() * 0.5f; float y1 = c.y() + c.h() * 0.5f; float z1 = c.z() + c.d() * 0.5f;
            
            // Emit 6 faces directly into array (simplified emitter)
            idx = emitFace(data, idx, x0,y0,z1, x1,y0,z1, x1,y1,z1, x0,y1,z1, c, 0,0,1);
            idx = emitFace(data, idx, x1,y0,z0, x0,y0,z0, x0,y1,z0, x1,y1,z0, c, 0,0,-1);
            idx = emitFace(data, idx, x0,y1,z1, x1,y1,z1, x1,y1,z0, x0,y1,z0, c, 0,1,0);
            idx = emitFace(data, idx, x0,y0,z0, x1,y0,z0, x1,y0,z1, x0,y0,z1, c, 0,-1,0);
            idx = emitFace(data, idx, x1,y0,z1, x1,y0,z0, x1,y1,z0, x1,y1,z1, c, 1,0,0);
            idx = emitFace(data, idx, x0,y0,z0, x0,y0,z1, x0,y1,z1, x0,y1,z0, c, -1,0,0);
        }
        return new BakedMesh(data, idx / 10);
    }

    private static int emitFace(float[] d, int i, float x1,float y1,float z1, float x2,float y2,float z2, 
                                float x3,float y3,float z3, float x4,float y4,float z4, VoxelCube c, float nx,float ny,float nz) {
        // Store: x,y,z, r,g,b,a, nx,ny,nz
        putVert(d, i, x1,y1,z1, c.r(),c.g(),c.b(),c.a(), nx,ny,nz); i+=10;
        putVert(d, i, x2,y2,z2, c.r(),c.g(),c.b(),c.a(), nx,ny,nz); i+=10;
        putVert(d, i, x3,y3,z3, c.r(),c.g(),c.b(),c.a(), nx,ny,nz); i+=10;
        putVert(d, i, x4,y4,z4, c.r(),c.g(),c.b(),c.a(), nx,ny,nz); i+=10;
        return i;
    }

    private static void putVert(float[] d, int i, float x,float y,float z, float r,float g,float b,float a, float nx,float ny,float nz) {
        d[i]=x; d[i+1]=y; d[i+2]=z; d[i+3]=r; d[i+4]=g; d[i+5]=b; d[i+6]=a; d[i+7]=nx; d[i+8]=ny; d[i+9]=nz;
    }

    /**
     * Render a cached mesh with transformation.
     */
    public static void renderBaked(Matrix4f matrix, VertexConsumer vc, BakedMesh mesh, int light) {
        for (int i = 0; i < mesh.vertexCount(); i++) {
            int off = i * 10;
            vc.vertex(matrix, mesh.vertices()[off], mesh.vertices()[off+1], mesh.vertices()[off+2])
              .color(mesh.vertices()[off+3], mesh.vertices()[off+4], mesh.vertices()[off+5], mesh.vertices()[off+6])
              .texture(0, 0)
              .overlay(OverlayTexture.DEFAULT_UV)
              .light(light)
              .normal(mesh.vertices()[off+7], mesh.vertices()[off+8], mesh.vertices()[off+9])
              .next();
        }
    }

    /**
     * S5-04: Get or create a baked mesh using a model factory.
     */
    public static BakedMesh getOrBakeModel(String modelId, java.util.function.Supplier<VoxelModel> factory) {
        return CACHE.computeIfAbsent(modelId, id -> bake(factory.get()));
    }

    public static void clear() { CACHE.clear(); }
}
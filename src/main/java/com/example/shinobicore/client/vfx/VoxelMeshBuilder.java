package com.example.shinobicore.client.vfx;

import net.minecraft.client.render.OverlayTexture;
import net.minecraft.client.render.VertexConsumer;
import net.minecraft.client.util.math.MatrixStack;
import org.joml.Matrix4f;

/**
 * S4-01: Bakes a VoxelModel into vertex calls.
 * Each cube emits 6 faces (quads). Emissive cubes use max light.
 * No world blocks involved - pure render-time geometry.
 */
public class VoxelMeshBuilder {

    private static final int EMISSIVE_LIGHT = 0xF000F0;

    /**
     * Render all cubes in the model.
     * @param matrices current matrix stack (already positioned)
     * @param vc       vertex consumer from a RenderLayer
     * @param model    the voxel model to draw
     * @param baseLight default light level for non-emissive cubes
     */
    public static void renderModel(MatrixStack matrices, VertexConsumer vc,
                                   VoxelModel model, int baseLight) {
        Matrix4f m = matrices.peek().getPositionMatrix();
        for (VoxelCube cube : model.getCubes()) {
            int light = cube.emissive() ? EMISSIVE_LIGHT : baseLight;
            emitCube(vc, m, cube, light);
        }
    }

    private static void emitCube(VertexConsumer vc, Matrix4f m,
                                 VoxelCube c, int light) {
        float x0 = c.x() - c.w() * 0.5f;
        float y0 = c.y() - c.h() * 0.5f;
        float z0 = c.z() - c.d() * 0.5f;
        float x1 = c.x() + c.w() * 0.5f;
        float y1 = c.y() + c.h() * 0.5f;
        float z1 = c.z() + c.d() * 0.5f;

        // +Z (front)
        emitFace(vc, m, x0,y0,z1, x1,y0,z1, x1,y1,z1, x0,y1,z1, c, light, 0f,0f,1f);
        // -Z (back)
        emitFace(vc, m, x1,y0,z0, x0,y0,z0, x0,y1,z0, x1,y1,z0, c, light, 0f,0f,-1f);
        // +Y (top)
        emitFace(vc, m, x0,y1,z1, x1,y1,z1, x1,y1,z0, x0,y1,z0, c, light, 0f,1f,0f);
        // -Y (bottom)
        emitFace(vc, m, x0,y0,z0, x1,y0,z0, x1,y0,z1, x0,y0,z1, c, light, 0f,-1f,0f);
        // +X (right)
        emitFace(vc, m, x1,y0,z1, x1,y0,z0, x1,y1,z0, x1,y1,z1, c, light, 1f,0f,0f);
        // -X (left)
        emitFace(vc, m, x0,y0,z0, x0,y0,z1, x0,y1,z1, x0,y1,z0, c, light, -1f,0f,0f);

        if (c.doubleSided()) {
            emitFace(vc, m, x0,y1,z1, x1,y1,z1, x1,y0,z1, x0,y0,z1, c, light, 0f,0f,-1f);
            emitFace(vc, m, x1,y1,z0, x0,y1,z0, x0,y0,z0, x1,y0,z0, c, light, 0f,0f,1f);
            emitFace(vc, m, x0,y0,z1, x1,y0,z1, x1,y1,z1, x0,y1,z1, c, light, 0f,-1f,0f);
            emitFace(vc, m, x0,y1,z0, x1,y1,z0, x1,y0,z0, x0,y0,z0, c, light, 0f,1f,0f);
            emitFace(vc, m, x1,y1,z1, x1,y0,z0, x1,y0,z0, x1,y1,z1, c, light, -1f,0f,0f);
            emitFace(vc, m, x0,y0,z0, x0,y0,z1, x0,y0,z1, x0,y0,z0, c, light, 1f,0f,0f);
        }
    }

    private static void emitFace(VertexConsumer vc, Matrix4f m,
            float ax, float ay, float az,
            float bx, float by, float bz,
            float cx, float cy, float cz,
            float dx, float dy, float dz,
            VoxelCube c, int light, float nx, float ny, float nz) {
        vc.vertex(m, ax, ay, az).color(c.r(), c.g(), c.b(), c.a())
          .texture(0f, 0f).overlay(OverlayTexture.DEFAULT_UV)
          .light(light).normal(nx, ny, nz).next();
        vc.vertex(m, bx, by, bz).color(c.r(), c.g(), c.b(), c.a())
          .texture(0f, 0f).overlay(OverlayTexture.DEFAULT_UV)
          .light(light).normal(nx, ny, nz).next();
        vc.vertex(m, cx, cy, cz).color(c.r(), c.g(), c.b(), c.a())
          .texture(0f, 0f).overlay(OverlayTexture.DEFAULT_UV)
          .light(light).normal(nx, ny, nz).next();
        vc.vertex(m, dx, dy, dz).color(c.r(), c.g(), c.b(), c.a())
          .texture(0f, 0f).overlay(OverlayTexture.DEFAULT_UV)
          .light(light).normal(nx, ny, nz).next();
    }
}
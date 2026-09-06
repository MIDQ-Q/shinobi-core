package com.example.shinobicore.client.voxel;

import net.fabricmc.fabric.api.client.rendering.v1.WorldRenderContext;
import net.minecraft.client.render.OverlayTexture;
import net.minecraft.client.render.RenderLayer;
import net.minecraft.client.render.VertexConsumer;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.RotationAxis;
import net.minecraft.util.math.Vec3d;
import org.joml.Matrix4f;

import java.util.ArrayList;
import java.util.List;

public final class ClientVoxelProjectiles {
    private static final List<VisProj> ACTIVE = new ArrayList<>();
    private static final Identifier WHITE = new Identifier("textures/misc/white.png");
    private static final int FULL_LIGHT = 0x00F000F0;
    private static final float BASE_YAW = -90f;
    private static final float BASE_PITCH = 0f;
    private static final float BASE_ROLL = 0f;

    private static final class VisProj {
        Vec3d prevPos; Vec3d pos; Vec3d vel;
        double gravity; int life; int maxLife;
        String model; float scale; float[] off;
        double yaw, pitch;
    }

    public static void onSpawn(double px, double py, double pz, double vx, double vy, double vz,
                               double gravity, int life, String model, float scale) {
        synchronized (ACTIVE) {
            VisProj p = new VisProj();
            p.prevPos = new Vec3d(px, py, pz);
            p.pos = new Vec3d(px, py, pz);
            p.vel = new Vec3d(vx, vy, vz);
            p.gravity = gravity; p.life = life; p.maxLife = life;
            p.model = model; p.scale = scale;
            p.off = VoxelRotationConfig.get(model);
            updateOrientation(p);
            ACTIVE.add(p);
            if (ACTIVE.size() > 80) ACTIVE.remove(0);
        }
    }

    public static void onImpact(double x, double y, double z) {
        synchronized (ACTIVE) {
            int best = -1; double bd = 16.0;
            for (int i = 0; i < ACTIVE.size(); i++) {
                double d = ACTIVE.get(i).pos.squaredDistanceTo(x, y, z);
                if (d < bd) { bd = d; best = i; }
            }
            if (best >= 0) ACTIVE.remove(best);
        }
    }

    private static void updateOrientation(VisProj p) {
        Vec3d flat = new Vec3d(p.vel.x, 0, p.vel.z);
        if (flat.lengthSquared() > 1e-9) {
            p.yaw = Math.toDegrees(Math.atan2(-p.vel.x, p.vel.z));
            p.pitch = Math.toDegrees(-Math.atan2(p.vel.y, flat.length()));
        }
    }

    public static void tick() {
        synchronized (ACTIVE) {
            for (int i = ACTIVE.size() - 1; i >= 0; i--) {
                VisProj p = ACTIVE.get(i);
                p.prevPos = p.pos;
                p.vel = p.vel.add(0, -p.gravity, 0);
                p.pos = p.pos.add(p.vel);
                updateOrientation(p);
                p.life--;
                if (p.life <= 0) ACTIVE.remove(i);
            }
        }
    }

    public static void render(WorldRenderContext ctx) {
        synchronized (ACTIVE) {
            if (ACTIVE.isEmpty()) return;
            MatrixStack matrices = ctx.matrixStack();
            VertexConsumerProvider consumers = ctx.consumers();
            Vec3d cam = ctx.camera().getPos();
            float tickDelta = ctx.tickDelta();
            for (VisProj p : ACTIVE) {
                VoxelModel m = VoxelModelRegistry.get(p.model);
                if (m == null || m.elements().isEmpty()) continue;
                registerTextures(m);
                Vec3d renderPos = p.prevPos.lerp(p.pos, tickDelta);
                float alpha = 1.0f;
                int elapsed = p.maxLife - p.life;
                if (elapsed < 5) alpha = elapsed / 5f;
                if (p.life < 10) alpha = p.life / 10f;
                matrices.push();
                matrices.translate(renderPos.x - cam.x, renderPos.y - cam.y, renderPos.z - cam.z);
                matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees((float) p.yaw + BASE_YAW + p.off[0]));
                matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees((float) p.pitch + BASE_PITCH + p.off[1]));
                matrices.multiply(RotationAxis.POSITIVE_Z.rotationDegrees(BASE_ROLL + p.off[2]));
                matrices.scale(p.scale, p.scale, p.scale);
                matrices.translate(-m.cx(), -m.cy(), -m.cz());
                for (VoxelModel.Element e : m.elements()) {
                    if (e instanceof VoxelModel.CubeElement c) drawCube(consumers, matrices, c, p.model, alpha);
                    else if (e instanceof VoxelModel.MeshElement mesh) drawMesh(consumers, matrices.peek().getPositionMatrix(), mesh, p.model, alpha);
                }
                matrices.pop();
            }
        }
    }

    public static void renderAt(MatrixStack matrices, VertexConsumerProvider consumers, String modelName, float scale) {
        VoxelModel m = VoxelModelRegistry.get(modelName);
        if (m == null || m.elements().isEmpty()) return;
        registerTextures(m);
        matrices.push();
        matrices.scale(scale, scale, scale);
        matrices.translate(-m.cx(), -m.cy(), -m.cz());
        for (VoxelModel.Element e : m.elements()) {
            if (e instanceof VoxelModel.CubeElement c) drawCube(consumers, matrices, c, modelName, 1.0f);
            else if (e instanceof VoxelModel.MeshElement mesh) drawMesh(consumers, matrices.peek().getPositionMatrix(), mesh, modelName, 1.0f);
        }
        matrices.pop();
    }

    private static void registerTextures(VoxelModel m) {
        for (int i = 0; i < m.textures().size(); i++) {
            VoxelModel.TextureRef t = m.textures().get(i);
            VoxelTextureManager.register(m.name(), i, t.source(), t.width(), t.height());
        }
    }

    private static void drawCube(VertexConsumerProvider consumers, MatrixStack matrices, VoxelModel.CubeElement c, String modelName, float alpha) {
        boolean hasRot = c.rotation() != null && c.rotation().angle() != 0;
        if (hasRot) {
            matrices.push();
            float[] o = c.rotation().origin();
            matrices.translate(o[0], o[1], o[2]);
            RotationAxis axis = switch (c.rotation().axis()) {
                case "x" -> RotationAxis.POSITIVE_X;
                case "z" -> RotationAxis.POSITIVE_Z;
                default -> RotationAxis.POSITIVE_Y;
            };
            matrices.multiply(axis.rotationDegrees(c.rotation().angle()));
            matrices.translate(-o[0], -o[1], -o[2]);
        }
        float x1 = c.from()[0], y1 = c.from()[1], z1 = c.from()[2];
        float x2 = c.to()[0], y2 = c.to()[1], z2 = c.to()[2];
        Matrix4f m = matrices.peek().getPositionMatrix();
        if (c.faces().isEmpty()) {
            float r = ((c.color() >> 16) & 0xFF) / 255f;
            float g = ((c.color() >> 8) & 0xFF) / 255f;
            float b = (c.color() & 0xFF) / 255f;
            VertexConsumer vc = consumers.getBuffer(RenderLayer.getEntityTranslucent(WHITE));
            solidQuad(vc, m, r, g, b, alpha, x1,y1,z1, x2,y1,z1, x2,y1,z2, x1,y1,z2, 0,-1,0);
            solidQuad(vc, m, r, g, b, alpha, x1,y2,z1, x1,y2,z2, x2,y2,z2, x2,y2,z1, 0,1,0);
            solidQuad(vc, m, r, g, b, alpha, x1,y1,z1, x2,y1,z1, x2,y2,z1, x1,y2,z1, 0,0,-1);
            solidQuad(vc, m, r, g, b, alpha, x1,y1,z2, x2,y1,z2, x2,y2,z2, x1,y2,z2, 0,0,1);
            solidQuad(vc, m, r, g, b, alpha, x1,y1,z1, x1,y1,z2, x1,y2,z2, x1,y2,z1, -1,0,0);
            solidQuad(vc, m, r, g, b, alpha, x2,y1,z1, x2,y1,z2, x2,y2,z2, x2,y2,z1, 1,0,0);
        } else {
            face(consumers, m, c, modelName, "north", 0,0,-1, new float[][]{{x2,y1,z1},{x1,y1,z1},{x1,y2,z1},{x2,y2,z1}}, alpha);
            face(consumers, m, c, modelName, "south", 0,0,1, new float[][]{{x1,y1,z2},{x2,y1,z2},{x2,y2,z2},{x1,y2,z2}}, alpha);
            face(consumers, m, c, modelName, "east", 1,0,0, new float[][]{{x2,y1,z2},{x2,y1,z1},{x2,y2,z1},{x2,y2,z2}}, alpha);
            face(consumers, m, c, modelName, "west", -1,0,0, new float[][]{{x1,y1,z1},{x1,y1,z2},{x1,y2,z2},{x1,y2,z1}}, alpha);
            face(consumers, m, c, modelName, "up", 0,1,0, new float[][]{{x1,y2,z1},{x2,y2,z1},{x2,y2,z2},{x1,y2,z2}}, alpha);
            face(consumers, m, c, modelName, "down", 0,-1,0, new float[][]{{x1,y1,z1},{x2,y1,z1},{x2,y1,z2},{x1,y1,z2}}, alpha);
        }
        if (hasRot) matrices.pop();
    }

    private static void face(VertexConsumerProvider cons, Matrix4f m, VoxelModel.CubeElement c,
                             String mn, String name, float nx, float ny, float nz, float[][] corners, float alpha) {
        VoxelModel.Face f = c.faces().get(name);
        if (f == null || f.uv().length < 4) return;
        Identifier tex = VoxelTextureManager.getTexture(mn, f.texture());
        if (tex == null) tex = WHITE;
        VertexConsumer vc = cons.getBuffer(RenderLayer.getEntityTranslucent(tex));
        int[] dims = VoxelTextureManager.getDims(mn, f.texture());
        float w = dims[0], h = dims[1];
        float u1 = f.uv()[0]/w, v1 = f.uv()[1]/h, u2 = f.uv()[2]/w, v2 = f.uv()[3]/h;
        float[][] uvs = {{u1,v2},{u2,v2},{u2,v1},{u1,v1}};
        int[][] tris = {{0,1,2},{0,2,3}};
        for (int[] t : tris) {
            for (int k = 0; k < 3; k++) vert(vc, m, corners[t[k]], nx, ny, nz, uvs[t[k]], alpha);
            for (int k = 2; k >= 0; k--) vert(vc, m, corners[t[k]], nx, ny, nz, uvs[t[k]], alpha);
        }
    }

    private static void drawMesh(VertexConsumerProvider consumers, Matrix4f mat, VoxelModel.MeshElement mesh, String modelName, float alpha) {
        for (VoxelModel.MeshFace mf : mesh.faces()) {
            if (mf.indices().length < 3 || mf.uv().length < mf.indices().length) continue;
            Identifier tex = VoxelTextureManager.getTexture(modelName, mf.texture());
            if (tex == null) tex = WHITE;
            VertexConsumer vc = consumers.getBuffer(RenderLayer.getEntityTranslucent(tex));
            int[] dims = VoxelTextureManager.getDims(modelName, mf.texture());
            float w = dims[0], h = dims[1];
            for (int i = 1; i < mf.indices().length - 1; i++) {
                int[] tri = {0, i, i + 1};
                for (int k : tri) emit(vc, mat, mesh.vertices()[mf.indices()[k]], mf.uv()[k], w, h, alpha);
                for (int k = 2; k >= 0; k--) emit(vc, mat, mesh.vertices()[mf.indices()[k]], mf.uv()[k], w, h, alpha);
            }
        }
    }

    private static void emit(VertexConsumer vc, Matrix4f m, float[] p, float[] uv, float w, float h, float alpha) {
        vc.vertex(m, p[0], p[1], p[2]).color(1f, 1f, 1f, alpha).texture(uv[0]/w, uv[1]/h)
          .overlay(OverlayTexture.DEFAULT_UV).light(FULL_LIGHT).normal(0,1,0).next();
    }

    private static void vert(VertexConsumer vc, Matrix4f m, float[] p, float nx, float ny, float nz, float[] uv, float alpha) {
        vc.vertex(m, p[0], p[1], p[2]).color(1f, 1f, 1f, alpha).texture(uv[0], uv[1])
          .overlay(OverlayTexture.DEFAULT_UV).light(FULL_LIGHT).normal(nx, ny, nz).next();
    }

    private static void solidQuad(VertexConsumer vc, Matrix4f m, float r, float g, float b, float alpha,
                                  float ax,float ay,float az, float bx,float by,float bz,
                                  float cx,float cy,float cz, float dx,float dy,float dz,
                                  float nx,float ny,float nz) {
        sv(vc,m,ax,ay,az,r,g,b,alpha,nx,ny,nz); sv(vc,m,bx,by,bz,r,g,b,alpha,nx,ny,nz);
        sv(vc,m,cx,cy,cz,r,g,b,alpha,nx,ny,nz); sv(vc,m,dx,dy,dz,r,g,b,alpha,nx,ny,nz);
        sv(vc,m,dx,dy,dz,r,g,b,alpha,nx,ny,nz); sv(vc,m,cx,cy,cz,r,g,b,alpha,nx,ny,nz);
        sv(vc,m,bx,by,bz,r,g,b,alpha,nx,ny,nz); sv(vc,m,ax,ay,az,r,g,b,alpha,nx,ny,nz);
    }

    private static void sv(VertexConsumer vc, Matrix4f m, float x, float y, float z,
                           float r, float g, float b, float alpha, float nx, float ny, float nz) {
        vc.vertex(m, x, y, z).color(r, g, b, alpha).texture(0, 0)
          .overlay(OverlayTexture.DEFAULT_UV).light(FULL_LIGHT).normal(nx, ny, nz).next();
    }
}
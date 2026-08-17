# ============================================================
# SHINOBICORE MASTER SCRIPT: S4-01 + S4-02
# Voxel Model Format + Procedural Shape Generators
# Sprint 4 - Voxel Visual: Base Layer
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$vfxDir = Join-Path $root "src\main\java\com\example\shinobicore\client\vfx"

function Write-VfxFile($name, $content) {
    $path = Join-Path $vfxDir $name
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (Test-Path $path) {
        $existing = [System.IO.File]::ReadAllText($path, $utf8)
        if ($existing -eq $content) {
            Write-Host "  [SKIP] $name (unchanged)" -ForegroundColor Yellow
            return
        }
    }
    [System.IO.File]::WriteAllText($path, $content, $utf8)
    Write-Host "  [OK] $name" -ForegroundColor Green
}

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "  SPRINT 4 BASE LAYER: S4-01 Voxel Format + S4-02 Generators" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# FILE 1: VoxelCube.java (S4-01)
# Single cube definition in a voxel model.
# ============================================================
Write-Host "[S4-01] Creating VoxelCube.java..." -ForegroundColor Yellow

$voxelCube = @'
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
'@

Write-VfxFile "VoxelCube.java" $voxelCube

# ============================================================
# FILE 2: VoxelModel.java (S4-01)
# Collection of cubes forming a model.
# ============================================================
Write-Host "[S4-01] Creating VoxelModel.java..." -ForegroundColor Yellow

$voxelModel = @'
package com.example.shinobicore.client.vfx;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * S4-01: Voxel model = named collection of VoxelCubes.
 * Built procedurally via VoxelShapeGenerators or manually.
 * After building, treat as immutable for render-thread safety.
 */
public class VoxelModel {

    private final String id;
    private final List<VoxelCube> cubes;
    private boolean baked = false;

    public VoxelModel(String id) {
        this.id = id;
        this.cubes = new ArrayList<>();
    }

    public void addCube(VoxelCube cube) {
        if (baked) {
            throw new IllegalStateException("Model '" + id + "' is already baked");
        }
        cubes.add(cube);
    }

    /** Freeze the model. No more cubes can be added. */
    public void bake() {
        baked = true;
    }

    public boolean isBaked() { return baked; }

    public String getId() { return id; }

    public int getCubeCount() { return cubes.size(); }

    /**
     * Returns unmodifiable view of cubes.
     * Call bake() before passing to render thread.
     */
    public List<VoxelCube> getCubes() {
        return Collections.unmodifiableList(cubes);
    }
}
'@

Write-VfxFile "VoxelModel.java" $voxelModel

# ============================================================
# FILE 3: VoxelMeshBuilder.java (S4-01)
# Renders a VoxelModel via VertexConsumer (no world blocks).
# ============================================================
Write-Host "[S4-01] Creating VoxelMeshBuilder.java..." -ForegroundColor Yellow

$meshBuilder = @'
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
'@

Write-VfxFile "VoxelMeshBuilder.java" $meshBuilder

# ============================================================
# FILE 4: VoxelShapeGenerators.java (S4-02)
# Procedural primitives: sphere, cone, disc, ring, blade,
# projectile, snake segment.
# ============================================================
Write-Host "[S4-02] Creating VoxelShapeGenerators.java..." -ForegroundColor Yellow

$generators = @'
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
}
'@

Write-VfxFile "VoxelShapeGenerators.java" $generators

# ============================================================
# FILE 5: VoxelEffectRenderer.java (S4-01)
# High-level render helper: position, rotate, scale, draw.
# ============================================================
Write-Host "[S4-01] Creating VoxelEffectRenderer.java..." -ForegroundColor Yellow

$effectRenderer = @'
package com.example.shinobicore.client.vfx;

import net.minecraft.client.render.RenderLayer;
import net.minecraft.client.render.VertexConsumer;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.RotationAxis;
import net.minecraft.util.math.Vec3d;

/**
 * S4-01: High-level renderer for voxel effects in the world.
 * Uses translucent render layer + white texture.
 * Emissive cubes automatically get max light via VoxelMeshBuilder.
 */
public class VoxelEffectRenderer {

    private static final Identifier TEX =
        new Identifier("textures/misc/white.png");

    /**
     * Render a voxel model at the current matrix position.
     * Caller must push/pop MatrixStack.
     */
    public static void render(MatrixStack matrices,
                              VertexConsumerProvider vcProvider,
                              VoxelModel model,
                              float yaw, float pitch, float scale,
                              int light) {
        if (model.getCubeCount() == 0) return;
        matrices.push();
        if (pitch != 0f) {
            matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(pitch));
        }
        if (yaw != 0f) {
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(yaw));
        }
        matrices.scale(scale, scale, scale);
        VertexConsumer vc =
            vcProvider.getBuffer(RenderLayer.getEntityTranslucent(TEX));
        VoxelMeshBuilder.renderModel(matrices, vc, model, light);
        matrices.pop();
    }

    /**
     * Render a voxel model at a world position.
     * Convenience wrapper that handles translate internally.
     */
    public static void renderAt(MatrixStack matrices,
                                VertexConsumerProvider vcProvider,
                                VoxelModel model,
                                Vec3d pos,
                                float yaw, float pitch, float scale,
                                int light) {
        matrices.push();
        matrices.translate(pos.x, pos.y, pos.z);
        render(matrices, vcProvider, model, yaw, pitch, scale, light);
        matrices.pop();
    }

    /**
     * Render with emissive glow (ignores world lighting).
     * All cubes treated as emissive regardless of their flag.
     */
    public static void renderGlow(MatrixStack matrices,
                                  VertexConsumerProvider vcProvider,
                                  VoxelModel model,
                                  float yaw, float pitch, float scale) {
        if (model.getCubeCount() == 0) return;
        matrices.push();
        if (pitch != 0f) {
            matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(pitch));
        }
        if (yaw != 0f) {
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(yaw));
        }
        matrices.scale(scale, scale, scale);
        VertexConsumer vc =
            vcProvider.getBuffer(RenderLayer.getEntityTranslucent(TEX));
        VoxelMeshBuilder.renderModel(matrices, vc, model, 0xF000F0);
        matrices.pop();
    }
}
'@

Write-VfxFile "VoxelEffectRenderer.java" $effectRenderer

# ============================================================
# FILE 6: VfxBudget.java (S4-08 groundwork)
# Budget limiter for active VFX. Prevents particle spam.
# ============================================================
Write-Host "[S4-08 prep] Creating VfxBudget.java..." -ForegroundColor Yellow

$vfxBudget = @'
package com.example.shinobicore.client.vfx;

import com.example.shinobicore.ShinobiCore;

/**
 * S4-08 groundwork: Budget limiter for active voxel effects.
 * Prevents performance degradation from VFX spam.
 *
 * Usage:
 *   if (!VfxBudget.canSpawn()) return;
 *   VfxBudget.register();
 *   ... spawn effect ...
 *   VfxBudget.unregister(); // on effect end
 */
public class VfxBudget {

    private static int activeVfx = 0;
    private static int maxGlobalVfx = 50;
    private static int maxPerPlayerVfx = 10;
    private static int maxParticlesPerEffect = 200;

    public static void register() {
        activeVfx++;
    }

    public static void unregister() {
        activeVfx = Math.max(0, activeVfx - 1);
    }

    public static boolean canSpawn() {
        return activeVfx < maxGlobalVfx;
    }

    public static int getActiveCount() {
        return activeVfx;
    }

    public static void setMaxGlobalVfx(int max) {
        maxGlobalVfx = Math.max(1, max);
        ShinobiCore.LOGGER.debug("[VFX] Max global VFX set to {}", maxGlobalVfx);
    }

    public static void setMaxPerPlayerVfx(int max) {
        maxPerPlayerVfx = Math.max(1, max);
    }

    public static void setMaxParticlesPerEffect(int max) {
        maxParticlesPerEffect = Math.max(10, max);
    }

    public static int getMaxGlobalVfx() { return maxGlobalVfx; }
    public static int getMaxPerPlayerVfx() { return maxPerPlayerVfx; }
    public static int getMaxParticlesPerEffect() { return maxParticlesPerEffect; }

    /** Reset on disconnect. */
    public static void reset() {
        activeVfx = 0;
    }
}
'@

Write-VfxFile "VfxBudget.java" $vfxBudget

# ============================================================
# BUILD VERIFICATION
# ============================================================
Write-Host ""
Write-Host "[BUILD] Verifying compilation..." -ForegroundColor Yellow
Push-Location $root
try {
    $buildOutput = & ".\gradlew.bat" build 2>&1
    $buildExit = $LASTEXITCODE
    if ($buildExit -eq 0) {
        Write-Host "  [PASS] Build successful!" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Build failed (exit code: $buildExit)" -ForegroundColor Red
        $buildOutput | Select-Object -Last 20 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    }
} finally {
    Pop-Location
}

# ============================================================
# SUMMARY
# ============================================================
Write-Host ""
Write-Host "==============================================================" -ForegroundColor Green
Write-Host "  S4-01 + S4-02 COMPLETE" -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Created files (client/vfx/):" -ForegroundColor White
Write-Host "  VoxelCube.java           - Single cube record (pos, size, color, emissive)" -ForegroundColor Cyan
Write-Host "  VoxelModel.java          - Named collection of cubes, bake() to freeze" -ForegroundColor Cyan
Write-Host "  VoxelMeshBuilder.java    - Renders model via VertexConsumer (6 faces/cube)" -ForegroundColor Cyan
Write-Host "  VoxelShapeGenerators.java - 7 procedural primitives:" -ForegroundColor Cyan
Write-Host "    sphere, cone, disc, ring, blade, projectile, snakeSegment" -ForegroundColor Cyan
Write-Host "  VoxelEffectRenderer.java - High-level render helper (position/rotate/scale)" -ForegroundColor Cyan
Write-Host "  VfxBudget.java           - Active VFX limiter (S4-08 groundwork)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Architecture:" -ForegroundColor White
Write-Host "  VoxelShapeGenerators -> VoxelModel -> VoxelMeshBuilder -> VertexConsumer" -ForegroundColor Yellow
Write-Host "  VoxelEffectRenderer wraps the pipeline for world-space rendering" -ForegroundColor Yellow
Write-Host "  No world blocks used. Pure render-time geometry." -ForegroundColor Yellow
Write-Host ""
Write-Host "Next steps (S4-03..S4-06):" -ForegroundColor Yellow
Write-Host "  S4-03: VBO rendering + batching for many effects" -ForegroundColor White
Write-Host "  S4-04: Entity carrier for effects (server logic + client visual)" -ForegroundColor White
Write-Host "  S4-05: Unified projectile system" -ForegroundColor White
Write-Host "  S4-06: Replace 2D squares in existing techniques" -ForegroundColor White
Write-Host ""
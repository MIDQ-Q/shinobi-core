$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"

Write-Host "=== FIX: VoxelModel 'already baked' IllegalStateException ===" -ForegroundColor Cyan

# ============================================================
# FIX 1: Rewrite VoxelRasenganModel.java (Safe cube copying)
# ============================================================
Write-Host "[1/2] Rewriting VoxelRasenganModel.java..." -ForegroundColor Yellow
$rasenganModelPath = Join-Path $root "src\main\java\com\example\shinobicore\client\vfx\models\VoxelRasenganModel.java"

$rasenganModelContent = @'
package com.example.shinobicore.client.vfx.models;
import com.example.shinobicore.client.vfx.VoxelCube;
import com.example.shinobicore.client.vfx.VoxelModel;
import com.example.shinobicore.client.vfx.VoxelShapeGenerators;
/**
* S5-01: Voxel Rasengan with 5 animation states.
* States: FORMING, STABILIZING, HELD, STRIKE, DISSIPATING
*/
public class VoxelRasenganModel {
public enum State { FORMING, STABILIZING, HELD, STRIKE, DISSIPATING }

public static VoxelModel generate(State state, float progress, float rotation) {
String id = "rasengan_" + state.name() + "_" + (int)(progress * 10) + "_" + (int)(rotation % 360);
VoxelModel model = new VoxelModel(id);
float baseRadius = 0.35f;
float r = 0.3f, g = 0.6f, b = 1.0f, a = 0.9f;

switch (state) {
case FORMING -> {
float scale = 0.2f + progress * 0.8f;
float chaos = (1.0f - progress) * 0.15f;
VoxelModel base = VoxelShapeGenerators.sphere(baseRadius * scale, 6, r, g, b, a * progress);
for (VoxelCube cube : base.getCubes()) model.addCube(cube);
for (int i = 0; i < 8; i++) {
float ox = (float)(Math.random() - 0.5) * chaos * 2;
float oy = (float)(Math.random() - 0.5) * chaos * 2;
float oz = (float)(Math.random() - 0.5) * chaos * 2;
model.addCube(VoxelCube.translucent(ox, oy, oz, 0.08f, 0.08f, 0.08f, r, g, b, a * 0.6f));
}
model.bake();
}
case STABILIZING -> {
VoxelModel base = VoxelShapeGenerators.sphere(baseRadius, 8, r, g, b, a);
for (VoxelCube cube : base.getCubes()) model.addCube(cube);
if (progress > 0.3f) {
float ringAlpha = (progress - 0.3f) / 0.7f;
VoxelModel ring = VoxelShapeGenerators.ring(baseRadius * 1.2f, baseRadius * 1.35f, 0.03f, 12, 0.6f, 0.8f, 1.0f, ringAlpha * 0.7f);
for (VoxelCube cube : ring.getCubes()) model.addCube(cube);
}
model.bake();
}
case HELD -> {
VoxelModel base = VoxelShapeGenerators.sphere(baseRadius, 8, r, g, b, a);
for (VoxelCube cube : base.getCubes()) model.addCube(cube);
VoxelModel glow = VoxelShapeGenerators.sphere(baseRadius * 0.6f, 6, 0.6f, 0.85f, 1.0f, 0.5f);
for (VoxelCube cube : glow.getCubes()) model.addCube(cube);
VoxelModel ring1 = VoxelShapeGenerators.ring(baseRadius * 1.2f, baseRadius * 1.35f, 0.03f, 16, 0.6f, 0.8f, 1.0f, 0.7f);
for (VoxelCube cube : ring1.getCubes()) model.addCube(cube);
VoxelModel ring2 = VoxelShapeGenerators.ring(baseRadius * 1.1f, baseRadius * 1.25f, 0.025f, 14, 0.5f, 0.7f, 1.0f, 0.5f);
for (VoxelCube cube : ring2.getCubes()) model.addCube(cube);
model.bake();
}
case STRIKE -> {
float compression = 1.0f - progress * 0.3f;
float brightness = 1.0f + progress * 0.5f;
VoxelModel base = VoxelShapeGenerators.sphere(baseRadius * compression, 8, Math.min(1f, r * brightness), Math.min(1f, g * brightness), Math.min(1f, b * brightness), a);
for (VoxelCube cube : base.getCubes()) model.addCube(cube);
if (progress > 0.7f) {
float flashAlpha = (progress - 0.7f) / 0.3f;
VoxelModel flash = VoxelShapeGenerators.sphere(baseRadius * 2.0f, 6, 1.0f, 1.0f, 1.0f, flashAlpha * 0.4f);
for (VoxelCube cube : flash.getCubes()) model.addCube(cube);
}
model.bake();
}
case DISSIPATING -> {
float expansion = 1.0f + progress * 1.5f;
float fade = 1.0f - progress;
VoxelModel base = VoxelShapeGenerators.sphere(baseRadius * expansion, 6, r, g, b, a * fade);
for (VoxelCube cube : base.getCubes()) model.addCube(cube);
int scatterCount = (int)(progress * 12);
for (int i = 0; i < scatterCount; i++) {
float angle = (i / 12.0f) * (float)(Math.PI * 2);
float dist = baseRadius * expansion * (1.0f + progress);
float sx = (float)Math.cos(angle) * dist;
float sy = (float)(Math.random() - 0.5) * dist * 0.5f;
float sz = (float)Math.sin(angle) * dist;
model.addCube(VoxelCube.translucent(sx, sy, sz, 0.06f, 0.06f, 0.06f, r, g, b, fade * 0.5f));
}
model.bake();
}
}
return model;
}
}
'@
[System.IO.File]::WriteAllText($rasenganModelPath, $rasenganModelContent, $utf8)
Write-Host "  [OK] VoxelRasenganModel.java rewritten with safe cube copying" -ForegroundColor Green

# ============================================================
# FIX 2: Patch DotZoneRenderer.java (Same issue)
# ============================================================
Write-Host "[2/2] Patching DotZoneRenderer.java..." -ForegroundColor Yellow
$dotZonePath = Join-Path $root "src\main\java\com\example\shinobicore\entity\DotZoneRenderer.java"
if (Test-Path $dotZonePath) {
$c = [System.IO.File]::ReadAllText($dotZonePath, $utf8)
$c = $c.Replace("`r`n", "`n")

$oldLogic = @'
// Generate dome/vortex model
VoxelModel model;
if ("wind".equals(element)) {
// Vortex: ring stack
model = VoxelShapeGenerators.ring(radius * 0.8f, radius, 0.15f, 16, r, g, b, alpha);
// Add inner turbulence
VoxelModel inner = VoxelShapeGenerators.sphere(radius * 0.4f, 6, r, g, b, alpha * 0.4f);
for (var cube : inner.getCubes()) model.addCube(cube);
} else {
// Dome for other elements
model = VoxelShapeGenerators.sphere(radius, 8, r, g, b, alpha * 0.3f);
// Outer shell ring
VoxelModel shell = VoxelShapeGenerators.ring(radius * 0.9f, radius, 0.08f, 20, r, g, b, alpha);
for (var cube : shell.getCubes()) model.addCube(cube);
}
VoxelRenderManager.renderWithCulling(matrices, vc, model,
entity.getPos(), yaw, 0f, 1.0f, light);
'@

$newLogic = @'
// Generate dome/vortex model (Safe copy pattern)
VoxelModel model = new VoxelModel("dot_zone_" + element);
if ("wind".equals(element)) {
VoxelModel ringBase = VoxelShapeGenerators.ring(radius * 0.8f, radius, 0.15f, 16, r, g, b, alpha);
for (VoxelCube cube : ringBase.getCubes()) model.addCube(cube);
VoxelModel inner = VoxelShapeGenerators.sphere(radius * 0.4f, 6, r, g, b, alpha * 0.4f);
for (VoxelCube cube : inner.getCubes()) model.addCube(cube);
} else {
VoxelModel sphereBase = VoxelShapeGenerators.sphere(radius, 8, r, g, b, alpha * 0.3f);
for (VoxelCube cube : sphereBase.getCubes()) model.addCube(cube);
VoxelModel shell = VoxelShapeGenerators.ring(radius * 0.9f, radius, 0.08f, 20, r, g, b, alpha);
for (VoxelCube cube : shell.getCubes()) model.addCube(cube);
}
model.bake();
VoxelRenderManager.renderWithCulling(matrices, vc, model,
entity.getPos(), yaw, 0f, 1.0f, light);
'@

if ($c.Contains($oldLogic)) {
$c = $c.Replace($oldLogic, $newLogic)
[System.IO.File]::WriteAllText($dotZonePath, $c, $utf8)
Write-Host "  [OK] DotZoneRenderer.java patched" -ForegroundColor Green
} else {
Write-Host "  [SKIP] DotZoneRenderer.java already patched or pattern not found" -ForegroundColor Yellow
}
} else {
Write-Host "  [MISS] DotZoneRenderer.java not found" -ForegroundColor Red
}

# ============================================================
# BUILD
# ============================================================
Write-Host ""
Write-Host "[BUILD] Verifying compilation..." -ForegroundColor Yellow
Push-Location $root
try {
$out = & ".\gradlew.bat" build 2>&1
if ($LASTEXITCODE -eq 0) {
Write-Host "  [PASS] Build successful!" -ForegroundColor Green
Write-Host "`n  Now run: .\gradlew.bat runClient" -ForegroundColor Yellow
} else {
Write-Host "  [FAIL] Build failed" -ForegroundColor Red
$out | Select-Object -Last 15 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
}
} finally { Pop-Location }
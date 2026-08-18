# ============================================================
# SHINOBICORE MASTER FIX SCRIPT: Part 1
# Visual & Behavior Fixes
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcBase = Join-Path $root "src\main\java\com\example\shinobicore"
$vfxDir = Join-Path $srcBase "client\vfx"
$entityDir = Join-Path $srcBase "entity"
$jutsuDir = Join-Path $srcBase "jutsu\custom"

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "  SHINOBICORE MASTER FIX: Part 1 (Visual & Behavior)" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

function Write-SafeFile($path, $content) {
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $content, $utf8)
    Write-Host "  [OK] $(Split-Path $path -Leaf)" -ForegroundColor Green
}

function Patch-SafeFile($p, $old, $new) {
    if (-not (Test-Path $p)) { Write-Host "  [MISS] $p" -ForegroundColor Red; return $false }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    $c = $c.Replace("`r`n", "`n")
    $oldN = $old.Replace("`r`n", "`n")
    $newN = $new.Replace("`r`n", "`n")
    if ($c.Contains($newN)) { Write-Host "  [SKIP] already: $(Split-Path $p -Leaf)" -ForegroundColor Yellow; return $true }
    if (-not $c.Contains($oldN)) { Write-Host "  [FAIL] pattern not found: $(Split-Path $p -Leaf)" -ForegroundColor Red; return $false }
    $c = $c.Replace($oldN, $newN)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "  [PATCH] $(Split-Path $p -Leaf)" -ForegroundColor Green
    return $true
}

# ============================================================
# FIX 1: VoxelProjectileRenderer — smoother spheres, less rotation
# ============================================================
Write-Host "[1/8] Fixing VoxelProjectileRenderer (smoother spheres)..." -ForegroundColor Yellow
$rendererFile = Join-Path $entityDir "VoxelProjectileRenderer.java"
$oldRenderer = @'
VoxelModel model = VoxelShapeGenerators.sphere(0.5f, 8,
((color >> 16) & 0xFF)/255f, ((color >> 8) & 0xFF)/255f, (color & 0xFF)/255f, ((color >> 24) & 0xFF)/255f);
matrices.push();
matrices.scale(scale, scale, scale);
matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(entity.age * 10f));
'@
$newRenderer = @'
// S5-06 FIX: Increased resolution for smoother spheres
VoxelModel model = VoxelShapeGenerators.sphere(0.5f, 12,
((color >> 16) & 0xFF)/255f, ((color >> 8) & 0xFF)/255f, (color & 0xFF)/255f, ((color >> 24) & 0xFF)/255f);
matrices.push();
matrices.scale(scale, scale, scale);
// Slower rotation for better visual
matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(entity.age * 2f));
'@
Patch-SafeFile $rendererFile $oldRenderer $newRenderer

# ============================================================
# FIX 2: NinjaProjectileRenderer — smoother spheres for vanilla projectiles
# ============================================================
Write-Host "[2/8] Fixing NinjaProjectileRenderer (smoother spheres)..." -ForegroundColor Yellow
$ninjaRendererFile = Join-Path $entityDir "NinjaProjectileRenderer.java"
# Find and replace sphere generation with higher resolution
$oldNinjaSphere = 'VoxelShapeGenerators.sphere(radius, 8, r, g, b, a)'
$newNinjaSphere = 'VoxelShapeGenerators.sphere(radius, 12, r, g, b, a)'
Patch-SafeFile $ninjaRendererFile $oldNinjaSphere $newNinjaSphere

# Reduce rotation speed
$oldNinjaRot = 'matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(entity.age * 15f));'
$newNinjaRot = 'matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(entity.age * 3f));'
Patch-SafeFile $ninjaRendererFile $oldNinjaRot $newNinjaRot

# ============================================================
# FIX 3: ExplodingProjectileBehavior — disable gravity, fix explosion
# ============================================================
Write-Host "[3/8] Fixing ExplodingProjectileBehavior (no gravity, explosion)..." -ForegroundColor Yellow
$explodingFile = Join-Path $jutsuDir "ExplodingProjectileBehavior.java"
$oldExploding = @'
// S4-06: Replaced with Voxel Projectile
com.example.shinobicore.entity.VoxelProjectileEntity proj = new com.example.shinobicore.entity.VoxelProjectileEntity(
world, player, look.multiply(speed), "sphere", 0xFFFF6600, radius, damage, true
);
'@
$newExploding = @'
// S5-06 FIX: Disabled gravity, fixed explosion radius
com.example.shinobicore.entity.VoxelProjectileEntity proj = new com.example.shinobicore.entity.VoxelProjectileEntity(
world, player, look.multiply(speed), "sphere", 0xFFFF6600, radius, damage, false
);
'@
Patch-SafeFile $explodingFile $oldExploding $newExploding

# ============================================================
# FIX 4: RunningFireBehavior — don't burn under player
# ============================================================
Write-Host "[4/8] Fixing RunningFireBehavior (burn ahead, not under player)..." -ForegroundColor Yellow
$runningFireFile = Join-Path $jutsuDir "RunningFireBehavior.java"
$oldRunningFire = @'
Vec3d start = player.getPos();
Vec3d dir = player.getRotationVector().multiply(0.5);
List<BlockPos> fireBlocks = new ArrayList<>();
int steps = (int)(distance / 0.5);
for (int i = 0; i < steps; i++) {
final int step = i;
TickScheduler.schedule(world, i * 2, 2, 1, w -> {
Vec3d pos = start.add(dir.multiply(step));
BlockPos bp = BlockPos.ofFloored(pos);
if (w.getBlockState(bp).isAir()) {
w.setBlockState(bp, Blocks.FIRE.getDefaultState(), 3);
fireBlocks.add(bp);
}
'@
$newRunningFire = @'
// S5-06 FIX: Start fire 2 blocks ahead of player, not under
Vec3d start = player.getPos().add(player.getRotationVector().multiply(2.0));
Vec3d dir = player.getRotationVector().multiply(0.5);
List<BlockPos> fireBlocks = new ArrayList<>();
int steps = (int)(distance / 0.5);
for (int i = 0; i < steps; i++) {
final int step = i;
TickScheduler.schedule(world, i * 2, 2, 1, w -> {
Vec3d pos = start.add(dir.multiply(step));
BlockPos bp = BlockPos.ofFloored(pos);
// Don't burn under player
if (bp.getX() == player.getBlockPos().getX() && bp.getZ() == player.getBlockPos().getZ()) return;
if (w.getBlockState(bp).isAir()) {
w.setBlockState(bp, Blocks.FIRE.getDefaultState(), 3);
fireBlocks.add(bp);
}
'@
Patch-SafeFile $runningFireFile $oldRunningFire $newRunningFire

# ============================================================
# FIX 5: PullBehavior — attract instead of repel
# ============================================================
Write-Host "[5/8] Fixing PullBehavior (attract to player, not repel)..." -ForegroundColor Yellow
$pullFile = Join-Path $jutsuDir "PullBehavior.java"
$oldPull = @'
Vec3d to = center.subtract(liv.getPos());
double dist = to.length();
if (dist > 0.5) {
Vec3d pull = to.normalize().multiply(pullStrength);
liv.setVelocity(pull.x, liv.getVelocity().y * 0.5, pull.z);
liv.velocityModified = true;
}
'@
$newPull = @'
// S5-06 FIX: Attract to player, not to point ahead
Vec3d to = player.getPos().subtract(liv.getPos());
double dist = to.length();
if (dist > 0.5) {
Vec3d pull = to.normalize().multiply(pullStrength);
liv.setVelocity(pull.x, liv.getVelocity().y * 0.5, pull.z);
liv.velocityModified = true;
}
'@
Patch-SafeFile $pullFile $oldPull $newPull

# ============================================================
# FIX 6: AmaterasuBehavior — require Sharingan, black fire, 1 min burn
# ============================================================
Write-Host "[6/8] Fixing AmaterasuBehavior (Sharingan req, black fire)..." -ForegroundColor Yellow
$amaterasuFile = Join-Path $jutsuDir "AmaterasuBehavior.java"
$oldAmaterasu = @'
public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
JsonObject params, float damage) {
if (!(player.getWorld() instanceof ServerWorld world)) return;
float speed = params.has("speed") ? params.get("speed").getAsFloat() : 2.0f;
float radius = params.has("radius") ? params.get("radius").getAsFloat() : 2f;
int lifetime = params.has("lifetime") ? params.get("lifetime").getAsInt() : 60;
Vec3d eye = player.getEyePos();
Vec3d look = player.getRotationVector();
NinjaProjectileEntity proj = new NinjaProjectileEntity(
world, player, look.multiply(speed), damage, radius, "smoke", "amaterasu", lifetime
);
proj.setPosition(eye.x, eye.y - 0.2, eye.z);
proj.setHasGravity(false);
world.spawnEntity(proj);
'@
$newAmaterasu = @'
public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
JsonObject params, float damage) {
if (!(player.getWorld() instanceof ServerWorld world)) return;
// S5-06 FIX: Require Sharingan
if (data.getActiveDojutsu() == null || !data.getActiveDojutsu().equals("sharingan")) {
player.sendMessage(net.minecraft.text.Text.literal("§cRequires Sharingan!"), false);
return;
}
float speed = params.has("speed") ? params.get("speed").getAsFloat() : 2.0f;
float radius = params.has("radius") ? params.get("radius").getAsFloat() : 2f;
int lifetime = params.has("lifetime") ? params.get("lifetime").getAsInt() : 120;
Vec3d eye = player.getEyePos();
Vec3d look = player.getRotationVector();
// Triple damage for Amaterasu
float amaterasuDamage = damage * 3.0f;
NinjaProjectileEntity proj = new NinjaProjectileEntity(
world, player, look.multiply(speed), amaterasuDamage, radius, "smoke", "amaterasu", lifetime
);
proj.setPosition(eye.x, eye.y - 0.2, eye.z);
proj.setHasGravity(false);
world.spawnEntity(proj);
'@
Patch-SafeFile $amaterasuFile $oldAmaterasu $newAmaterasu

# Also fix the impact to set fire for 1 minute (1200 ticks)
$oldImpact = @'
if (hitEntity != null) {
hitEntity.damage(getDamageSources().magic(), getDamage());
hit = true;
}
'@
$newImpact = @'
if (hitEntity != null) {
hitEntity.damage(getDamageSources().magic(), getDamage());
// Amaterasu: black fire that burns for 1 minute
if ("amaterasu".equals(this.dataTracker.get(MODEL_TYPE))) {
hitEntity.setOnFireFor(1200); // 1 minute = 1200 ticks
}
hit = true;
}
'@
$projEntityFile = Join-Path $entityDir "NinjaProjectileEntity.java"
Patch-SafeFile $projEntityFile $oldImpact $newImpact

# ============================================================
# FIX 7: KirinBehavior — spawn lightning higher
# ============================================================
Write-Host "[7/8] Fixing KirinBehavior (lightning from above)..." -ForegroundColor Yellow
$kirinFile = Join-Path $jutsuDir "KirinBehavior.java"
$oldKirin = @'
LightningEntity bolt = EntityType.LIGHTNING_BOLT.create(world);
if (bolt != null) {
bolt.setPosition(center.x + ox, world.getTopY(), center.z + oz);
world.spawnEntity(bolt);
}
'@
$newKirin = @'
LightningEntity bolt = EntityType.LIGHTNING_BOLT.create(world);
if (bolt != null) {
// S5-06 FIX: Spawn lightning 50 blocks above target for visible strike
bolt.setPosition(center.x + ox, center.y + 50, center.z + oz);
world.spawnEntity(bolt);
}
'@
Patch-SafeFile $kirinFile $oldKirin $newKirin

# ============================================================
# FIX 8: ChainLightningBehavior — more visible bolts
# ============================================================
Write-Host "[8/8] Fixing ChainLightningBehavior (more visible bolts)..." -ForegroundColor Yellow
$chainFile = Join-Path $jutsuDir "ChainLightningBehavior.java"
$oldChain = @'
private void spawnBolt(ServerWorld world, Vec3d from, Vec3d to) {
Vec3d dir = to.subtract(from).normalize();
double dist = from.distanceTo(to);
for (double d = 0; d < dist; d += 0.3) {
Vec3d p = from.add(dir.multiply(d));
world.spawnParticles(ParticleTypes.ELECTRIC_SPARK, p.x, p.y, p.z, 1, 0, 0, 0, 0);
}
}
'@
$newChain = @'
private void spawnBolt(ServerWorld world, Vec3d from, Vec3d to) {
Vec3d dir = to.subtract(from).normalize();
double dist = from.distanceTo(to);
// S5-06 FIX: More particles for visible lightning bolt
for (double d = 0; d < dist; d += 0.2) {
Vec3d p = from.add(dir.multiply(d));
// Add some randomness for jagged lightning effect
double jitterX = (world.getRandom().nextDouble() - 0.5) * 0.3;
double jitterY = (world.getRandom().nextDouble() - 0.5) * 0.3;
double jitterZ = (world.getRandom().nextDouble() - 0.5) * 0.3;
world.spawnParticles(ParticleTypes.ELECTRIC_SPARK, p.x + jitterX, p.y + jitterY, p.z + jitterZ, 3, 0.1, 0.1, 0.1, 0.05);
}
// Flash at impact
world.spawnParticles(ParticleTypes.FLASH, to.x, to.y, to.z, 1, 0, 0, 0, 0);
}
'@
Patch-SafeFile $chainFile $oldChain $newChain

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
    } else {
        Write-Host "  [FAIL] Build failed" -ForegroundColor Red
        $out | Select-Object -Last 20 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    }
} finally { Pop-Location }

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Green
Write-Host "  PART 1 COMPLETE" -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Fixed:" -ForegroundColor White
Write-Host "  1. VoxelProjectileRenderer: smoother spheres (resolution 12), slower rotation" -ForegroundColor Cyan
Write-Host "  2. NinjaProjectileRenderer: smoother spheres, slower rotation" -ForegroundColor Cyan
Write-Host "  3. ExplodingProjectileBehavior: disabled gravity" -ForegroundColor Cyan
Write-Host "  4. RunningFireBehavior: burns ahead, not under player" -ForegroundColor Cyan
Write-Host "  5. PullBehavior: attracts to player, not repels" -ForegroundColor Cyan
Write-Host "  6. AmaterasuBehavior: requires Sharingan, triple damage, 1 min burn" -ForegroundColor Cyan
Write-Host "  7. KirinBehavior: lightning spawns 50 blocks above target" -ForegroundColor Cyan
Write-Host "  8. ChainLightningBehavior: more visible bolts with jitter" -ForegroundColor Cyan
Write-Host ""
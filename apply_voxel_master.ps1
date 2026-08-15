# ============================================================
#  MASTER: VOXEL 3D MODELS + ATMOSPHERE/UX POLISH
#  Запуск: powershell -ExecutionPolicy Bypass -File .\apply_voxel_master.ps1
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$java = "$root\src\main\java\com\example\shinobicore"
$assets = "$root\src\main\resources\assets\shinobicore"
$ok = 0; $skip = 0; $err = 0

function Write-File($p, $c) {
    $dir = [System.IO.Path]::GetDirectoryName($p)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] $($p.Replace("$root\src\main\", ''))" -ForegroundColor Green
    $script:ok++
}
function Patch-File($p, $old, $new) {
    if (-not (Test-Path $p)) { Write-Host "[MISS] $p" -ForegroundColor Red; $script:err++; return }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    if ($c.Contains($new)) { Write-Host "[SKIP] already: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Yellow; $script:skip++; return }
    if (-not $c.Contains($old)) { Write-Host "[FAIL] pattern: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Red; $script:err++; return }
    $c = $c.Replace($old, $new)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] patched: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Green
    $script:ok++
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  VOXEL MODELS MASTER: katanas / armor / icons / UX / atmosphere" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# ================================================================
# 1. TEXTURES (System.Drawing -> PNG, без BOM, без base64-магии)
# ================================================================
Write-Host "`n[1/7] Generating textures..." -ForegroundColor White
Add-Type -AssemblyName System.Drawing
$texDir = "$assets\textures\item"
if (-not (Test-Path $texDir)) { New-Item -ItemType Directory -Path $texDir -Force | Out-Null }

function C($r,$g,$b) { [System.Drawing.Color]::FromArgb(255,[int]$r,[int]$g,[int]$b) }
function Save-Bmp($bmp, $path) { $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose(); Write-Host "  [tex] $([System.IO.Path]::GetFileName($path))" -ForegroundColor DarkCyan }

# --- Палитры катан: ряд 0 = пиксели цветов (0 blade,1 light,2 dark,3 tsuba,5 handle,6 wrap,8 pommel) ---
$katanaPalettes = @{
    "katana_iron"     = @((70,190,180),(140,230,220),(40,140,135),(230,180,60),(35,30,28),(40,170,170),(230,180,60))
    "katana_diamond"  = @((120,220,235),(210,245,250),(70,170,190),(220,225,230),(30,35,45),(90,200,220),(220,225,230))
    "katana_netherite"= @((95,85,100),(150,135,160),(60,52,66),(200,150,60),(25,20,22),(110,60,130),(200,150,60))
}
foreach ($name in $katanaPalettes.Keys) {
    $pal = $katanaPalettes[$name]
    $bmp = New-Object System.Drawing.Bitmap(16,16)
    $cols = @(0,1,2,3,5,6,8)
    for ($i = 0; $i -lt 7; $i++) { $p = $pal[$i]; $bmp.SetPixel($cols[$i], 0, (C $p[0] $p[1] $p[2])) }
    Save-Bmp $bmp "$texDir\$name.png"
}

# --- Пиксель-арт иконки ---
function Draw-Map($rows, $palette) {
    $bmp = New-Object System.Drawing.Bitmap(16,16)
    for ($y = 0; $y -lt 16; $y++) {
        $line = $rows[$y]
        for ($x = 0; $x -lt [Math]::Min(16, $line.Length); $x++) {
            $ch = $line[$x]
            if ($ch -ne '.' -and $palette.ContainsKey([string]$ch)) {
                $p = $palette[[string]$ch]; $bmp.SetPixel($x, $y, (C $p[0] $p[1] $p[2]))
            }
        }
    }
    return $bmp
}

$shurikenRows = @(
".......SS.......",".......SS.......","......SSSS......","......SDDS......",
".....SDDDDS.....",".....SDDDDS.....","....SDDDDDDS....","SSSSDDCCDDSSSS",
"SSSSDDCCDDSSSS..","....SDDDDDDS....",".....SDDDDS.....",".....SDDDDS.....",
"......SDDS......","......SSSS......",".......SS.......",".......SS.......")
Save-Bmp (Draw-Map $shurikenRows @{S=(205,210,215);D=(120,128,140);C=(50,52,60)}) "$texDir\shuriken.png"

$kunaiRows = @(
"................",".......S........",".......SS.......","......SSSS......",
"......SSSS......",".....SSSSSS.....",".....SSSSSS.....",".......HH.......",
".......HH.......",".......HH.......",".......HH.......","......R..R......",
"......R..R......",".......RR.......","................","................")
Save-Bmp (Draw-Map $kunaiRows @{S=(195,200,205);H=(70,60,50);R=(110,115,125)}) "$texDir\kunai.png"

$vestRows = @(
"................","..GG......GG....",".GGG......GGG...",".GGGGGGGGGGGG...",
".GGGGGGGGGGGG...",".GGGGGGGGGGGG...",".GGGGGGGGGGGG...",".GGppGGGGppGG...",
".GGppGGGGppGG...",".GGppGGGGppGG...",".GGGGGGGGGGGG...",".GGGGGGGGGGGG...",
"..GGGGGGGGGG....","...GGGGGGGG.....","................","................")
Save-Bmp (Draw-Map $vestRows @{G=(95,115,60);p=(160,160,150)}) "$texDir\flak_vest.png"

$hoodRows = @(
"................","................","................","................",
"................","...BBBBBBBBBB...","...BBBBBBBBBB...","...BBBSSSSBBB...",
"...BBBSSSSBBB...","...BBBBBBBBBB...","................","................",
"................","................","................","................")
Save-Bmp (Draw-Map $hoodRows @{B=(40,60,140);S=(200,205,210)}) "$texDir\ninja_hood.png"

$pantsRows = @(
"................","....DDDDDDDD....","....DDDDDDDD....","....DDD..DDD....",
"....DDD..DDD....","....DDD..DDD....","....DDD..DDD....","....DDD..DDD....",
"....LLL..LLL....","....LLL..LLL....","....DDD..DDD....","....DDD..DDD....",
"................","................","................","................")
Save-Bmp (Draw-Map $pantsRows @{D=(45,50,70);L=(200,195,180)}) "$texDir\ninja_pants.png"

$sandalRows = @(
"................","................","................","................",
"................","................","......S.S.......",".....S...S......",
"....SS...SS.....","....BBBBBBBB....","....BBBBBBBB....","...DDDDDDDDDD...",
"...DDDDDDDDDD...","................","................","................")
Save-Bmp (Draw-Map $sandalRows @{B=(50,70,150);D=(35,30,28);S=(35,50,110)}) "$texDir\ninja_sandals.png"

# --- empty.png (1x1 transparent) для скрытой модели в ножнах ---
$e = New-Object System.Drawing.Bitmap(1,1); $e.SetPixel(0,0,[System.Drawing.Color]::FromArgb(0,0,0,0))
Save-Bmp $e "$texDir\empty.png"

# ================================================================
# 2. JSON 3D-МОДЕЛИ КАТАН (ванильные elements)
# ================================================================
Write-Host "`n[2/7] Writing voxel katana JSON models..." -ForegroundColor White
$modelsDir = "$assets\models\item"

function El($f, $t, $px) {
    $uv = @($px, 0, ($px + 1), 1)
    $faces = @{}
    foreach ($s in @("north","east","south","west","up","down")) { $faces[$s] = @{ uv = $uv; texture = "#0" } }
    return @{ from = $f; to = $t; faces = $faces }
}
function New-KatanaModelJson($tex) {
    $els = [System.Collections.ArrayList]::new()
    [void]$els.Add((El @(7,0,7)       @(9,1.5,9)     8))   # pommel (kashira)
    [void]$els.Add((El @(7.4,1.5,7.6) @(8.6,6.5,8.4) 5))   # handle (tsuka)
    [void]$els.Add((El @(7.2,2.4,7.4) @(8.8,3.0,8.6) 6))   # wrap 1
    [void]$els.Add((El @(7.2,3.9,7.4) @(8.8,4.5,8.6) 6))   # wrap 2
    [void]$els.Add((El @(7.2,5.4,7.4) @(8.8,6.0,8.6) 6))   # wrap 3
    [void]$els.Add((El @(6.4,6.5,6.4) @(9.6,7.3,9.6) 3))   # tsuba
    [void]$els.Add((El @(7.6,7.3,7.8) @(8.4,15.2,8.2) 0))  # blade
    [void]$els.Add((El @(7.6,7.3,7.68) @(8.4,15.2,7.8) 1)) # edge (light)
    [void]$els.Add((El @(7.6,7.3,8.2) @(8.4,15.2,8.32) 2)) # spine (dark)
    [void]$els.Add((El @(7.75,15.2,7.85) @(8.25,16.3,8.15) 1)) # kissaki
    $model = [ordered]@{
        gui_light = "front"
        textures = @{ "0" = $tex; particle = $tex }
        elements = $els
        overrides = @(@{ predicate = @{ custom_model_data = 1 }; model = "shinobicore:item/katana_sheathed" })
        display = [ordered]@{
            thirdperson_righthand = @{ rotation = @(0,-90,55); translation = @(0,5.5,0.5); scale = @(0.85,0.85,0.85) }
            thirdperson_lefthand  = @{ rotation = @(0,90,-55); translation = @(0,5.5,0.5); scale = @(0.85,0.85,0.85) }
            firstperson_righthand = @{ rotation = @(0,-90,25); translation = @(1.13,3.2,1.13); scale = @(0.8,0.8,0.8) }
            firstperson_lefthand  = @{ rotation = @(0,90,-25); translation = @(1.13,3.2,1.13); scale = @(0.8,0.8,0.8) }
            gui    = @{ rotation = @(30,225,0); translation = @(0,-1.5,0); scale = @(0.62,0.62,0.62) }
            ground = @{ rotation = @(0,0,0); translation = @(0,3,0); scale = @(0.4,0.4,0.4) }
            fixed  = @{ rotation = @(0,0,45); translation = @(0,0,0); scale = @(0.55,0.55,0.55) }
        }
    }
    return ($model | ConvertTo-Json -Depth 12)
}
foreach ($n in @("katana_iron","katana_diamond","katana_netherite")) {
    Write-File "$modelsDir\$n.json" (New-KatanaModelJson "shinobicore:item/$n")
}
Write-File "$modelsDir\katana.json" (@{
    parent = "shinobicore:item/katana_iron"
    overrides = @(@{ predicate = @{ custom_model_data = 1 }; model = "shinobicore:item/katana_sheathed" })
} | ConvertTo-Json -Depth 6)
Write-File "$modelsDir\katana_sheathed.json" (@{
    parent = "item/generated"; textures = @{ layer0 = "shinobicore:item/empty" }
} | ConvertTo-Json -Depth 6)

# --- Иконки: переключаем модели на новые текстуры ---
foreach ($m in @(@("shuriken","shuriken"),@("kunai","kunai"),@("flak_vest","flak_vest"),@("ninja_hood","ninja_hood"),@("ninja_pants","ninja_pants"),@("ninja_sandals","ninja_sandals"))) {
    Write-File "$modelsDir\$($m[0]).json" (@{ parent = "item/generated"; textures = @{ layer0 = "shinobicore:item/$($m[1])" } } | ConvertTo-Json -Depth 6)
}

# ================================================================
# 3. JAVA: NarutoArmorRenderer (ArmorRenderer, воксельная броня)
# ================================================================
Write-Host "`n[3/7] Writing NarutoArmorRenderer.java (voxel armor)..." -ForegroundColor White
Write-File "$java\client\render\NarutoArmorRenderer.java" @'
package com.example.shinobicore.client.render;

import com.example.shinobicore.item.ModItems;
import net.fabricmc.fabric.api.client.rendering.v1.ArmorRenderer;
import net.minecraft.client.render.OverlayTexture;
import net.minecraft.client.render.RenderLayer;
import net.minecraft.client.render.VertexConsumer;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.render.entity.model.BipedEntityModel;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.entity.EquipmentSlot;
import net.minecraft.entity.LivingEntity;
import net.minecraft.item.ItemStack;
import net.minecraft.util.Identifier;
import org.joml.Matrix4f;

/**
 * Voxel Naruto-style armor: flak jacket with pockets, forehead protector,
 * shinobi pants with pouch + bandages, sandals. Pure cuboids, vanilla pipeline.
 */
public class NarutoArmorRenderer {
    private static final Identifier TEX = new Identifier("textures/misc/white.png");
    // Palette
    private static final float[] GREEN   = {0.37f, 0.45f, 0.24f};
    private static final float[] GREEN_D = {0.24f, 0.30f, 0.16f};
    private static final float[] GRAY    = {0.60f, 0.60f, 0.58f};
    private static final float[] BLUE    = {0.16f, 0.24f, 0.55f};
    private static final float[] BLUE_D  = {0.10f, 0.16f, 0.35f};
    private static final float[] STEEL   = {0.78f, 0.80f, 0.83f};
    private static final float[] DARK    = {0.18f, 0.20f, 0.28f};
    private static final float[] BANDAGE = {0.78f, 0.76f, 0.70f};
    private static final float[] BROWN   = {0.45f, 0.32f, 0.18f};

    public static void register() {
        ArmorRenderer.register(NarutoArmorRenderer::renderArmor,
                ModItems.FLAK_VEST, ModItems.NINJA_PANTS, ModItems.NINJA_SANDALS, ModItems.NINJA_HOOD);
    }

    private static void renderArmor(MatrixStack matrices, VertexConsumerProvider vertices, ItemStack stack,
                                    LivingEntity entity, EquipmentSlot slot, int light, BipedEntityModel<LivingEntity> model) {
        if (entity.isInvisible()) return;
        VertexConsumer vc = vertices.getBuffer(RenderLayer.getEntityTranslucent(TEX));
        if (slot == EquipmentSlot.CHEST) {
            matrices.push();
            model.body.rotate(matrices);
            cuboid(matrices, vc, light, -0.27f, -0.05f, -0.17f, 0.54f, 0.72f, 0.34f, GREEN);      // shell
            cuboid(matrices, vc, light, -0.24f, -0.12f, -0.14f, 0.48f, 0.10f, 0.28f, GREEN_D);    // collar
            cuboid(matrices, vc, light, -0.28f, -0.10f, -0.12f, 0.07f, 0.14f, 0.24f, GREEN_D);    // strap L
            cuboid(matrices, vc, light,  0.21f, -0.10f, -0.12f, 0.07f, 0.14f, 0.24f, GREEN_D);    // strap R
            cuboid(matrices, vc, light, -0.22f,  0.35f, -0.19f, 0.16f, 0.18f, 0.03f, GRAY);       // pocket L
            cuboid(matrices, vc, light,  0.06f,  0.35f, -0.19f, 0.16f, 0.18f, 0.03f, GRAY);       // pocket R
            cuboid(matrices, vc, light, -0.03f,  0.05f, -0.185f, 0.06f, 0.50f, 0.02f, GREEN_D);   // zip
            cuboid(matrices, vc, light, -0.24f,  0.00f,  0.15f, 0.48f, 0.55f, 0.03f, GREEN_D);    // back plate
            matrices.pop();
        } else if (slot == EquipmentSlot.HEAD) {
            matrices.push();
            model.head.rotate(matrices);
            cuboid(matrices, vc, light, -0.27f, -0.02f, -0.27f, 0.54f, 0.16f, 0.54f, BLUE);       // band
            cuboid(matrices, vc, light, -0.15f,  0.00f, -0.29f, 0.30f, 0.12f, 0.02f, STEEL);      // plate
            cuboid(matrices, vc, light,  0.24f,  0.02f,  0.18f, 0.05f, 0.10f, 0.05f, BLUE_D);     // knot
            matrices.pop();
        } else if (slot == EquipmentSlot.LEGS) {
            matrices.push(); model.rightLeg.rotate(matrices);
            legPants(matrices, vc, light, true);
            matrices.pop();
            matrices.push(); model.leftLeg.rotate(matrices);
            legPants(matrices, vc, light, false);
            matrices.pop();
        } else if (slot == EquipmentSlot.FEET) {
            matrices.push(); model.rightLeg.rotate(matrices);
            foot(matrices, vc, light);
            matrices.pop();
            matrices.push(); model.leftLeg.rotate(matrices);
            foot(matrices, vc, light);
            matrices.pop();
        }
    }

    private static void legPants(MatrixStack m, VertexConsumer vc, int light, boolean right) {
        cuboid(m, vc, light, -0.13f, -0.05f, -0.13f, 0.26f, 0.50f, 0.26f, DARK);    // thigh
        cuboid(m, vc, light, -0.13f,  0.45f, -0.13f, 0.26f, 0.18f, 0.26f, BANDAGE); // shin bandage
        if (right) cuboid(m, vc, light, 0.11f, 0.10f, -0.10f, 0.05f, 0.18f, 0.12f, BROWN); // pouch
    }

    private static void foot(MatrixStack m, VertexConsumer vc, int light) {
        cuboid(m, vc, light, -0.14f, 0.68f, -0.16f, 0.28f, 0.07f, 0.34f, DARK); // sole
        cuboid(m, vc, light, -0.14f, 0.55f, -0.14f, 0.28f, 0.06f, 0.30f, BLUE); // footbed
        cuboid(m, vc, light, -0.13f, 0.45f, -0.13f, 0.26f, 0.08f, 0.26f, BLUE_D); // ankle
    }

    private static void cuboid(MatrixStack matrices, VertexConsumer vc, int light,
                               float x, float y, float z, float w, float h, float d, float[] col) {
        Matrix4f m = matrices.peek().getPositionMatrix();
        float x2 = x + w, y2 = y + h, z2 = z + d;
        float r = col[0], g = col[1], b = col[2];
        face(vc, m, x, y, z2, x2, y, z2, x2, y2, z2, x, y2, z2, r, g, b, light);
        face(vc, m, x2, y, z, x, y, z, x, y2, z, x2, y2, z, r, g, b, light);
        face(vc, m, x, y, z, x, y, z2, x, y2, z2, x, y2, z, r, g, b, light);
        face(vc, m, x2, y, z2, x2, y, z, x2, y2, z, x2, y2, z2, r, g, b, light);
        face(vc, m, x, y2, z2, x2, y2, z2, x2, y2, z, x, y2, z, r, g, b, light);
        face(vc, m, x, y, z, x2, y, z, x2, y, z2, x, y, z2, r, g, b, light);
    }

    private static void face(VertexConsumer vc, Matrix4f m,
                             float x1, float y1, float z1, float x2, float y2, float z2,
                             float x3, float y3, float z3, float x4, float y4, float z4,
                             float r, float g, float b, int light) {
        v(vc, m, x1, y1, z1, r, g, b, light); v(vc, m, x2, y2, z2, r, g, b, light);
        v(vc, m, x3, y3, z3, r, g, b, light); v(vc, m, x4, y4, z4, r, g, b, light);
        v(vc, m, x4, y4, z4, r, g, b, light); v(vc, m, x3, y3, z3, r, g, b, light);
        v(vc, m, x2, y2, z2, r, g, b, light); v(vc, m, x1, y1, z1, r, g, b, light);
    }

    private static void v(VertexConsumer vc, Matrix4f m, float x, float y, float z, float r, float g, float b, int light) {
        vc.vertex(m, x, y, z).color(r, g, b, 1.0f).texture(0, 0)
          .overlay(OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
    }
}
'@

# ================================================================
# 4. JAVA: BackKatanaRenderer (ножны с палитрой тира)
# ================================================================
Write-Host "[4/7] Writing BackKatanaRenderer.java (tier-colored scabbard)..." -ForegroundColor White
Write-File "$java\client\render\BackKatanaRenderer.java" @'
package com.example.shinobicore.client.render;

import com.example.shinobicore.item.KatanaItem;
import com.example.shinobicore.item.ModItems;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.client.render.OverlayTexture;
import net.minecraft.client.render.RenderLayer;
import net.minecraft.client.render.VertexConsumer;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.render.entity.feature.FeatureRenderer;
import net.minecraft.client.render.entity.feature.FeatureRendererContext;
import net.minecraft.client.render.entity.model.PlayerEntityModel;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.item.Item;
import net.minecraft.item.ItemStack;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.RotationAxis;
import org.joml.Matrix4f;

/**
 * Scabbard (saya) on the back, colored per katana tier.
 * Visible whenever the player carries a katana in inventory.
 */
public class BackKatanaRenderer extends FeatureRenderer<AbstractClientPlayerEntity, PlayerEntityModel<AbstractClientPlayerEntity>> {
    private static final Identifier TEX = new Identifier("textures/misc/white.png");

    public BackKatanaRenderer(FeatureRendererContext<AbstractClientPlayerEntity, PlayerEntityModel<AbstractClientPlayerEntity>> context) {
        super(context);
    }

    @Override
    public void render(MatrixStack matrices, VertexConsumerProvider vertexConsumers, int light,
                       AbstractClientPlayerEntity entity, float limbAngle, float limbDistance, float tickDelta,
                       float animationProgress, float headYaw, float headPitch) {
        ItemStack katana = null;
        for (int i = 0; i < entity.getInventory().size(); i++) {
            ItemStack s = entity.getInventory().getStack(i);
            if (s.getItem() instanceof KatanaItem) { katana = s; break; }
        }
        if (katana == null) return;

        // Tier palette: scabbard, accent, wrap, tsuba, handle
        float[] saya, accent, wrap, tsuba, handle;
        Item it = katana.getItem();
        if (it == ModItems.KATANA_DIAMOND) {
            saya = new float[]{0.08f,0.12f,0.20f}; accent = new float[]{0.47f,0.86f,0.92f};
            wrap = new float[]{0.35f,0.78f,0.86f}; tsuba = new float[]{0.86f,0.88f,0.90f}; handle = new float[]{0.12f,0.14f,0.18f};
        } else if (it == ModItems.KATANA_NETHERITE) {
            saya = new float[]{0.12f,0.10f,0.12f}; accent = new float[]{0.78f,0.59f,0.24f};
            wrap = new float[]{0.43f,0.24f,0.51f}; tsuba = new float[]{0.78f,0.59f,0.24f}; handle = new float[]{0.10f,0.08f,0.09f};
        } else {
            saya = new float[]{0.10f,0.10f,0.11f}; accent = new float[]{0.90f,0.71f,0.24f};
            wrap = new float[]{0.16f,0.67f,0.67f}; tsuba = new float[]{0.90f,0.71f,0.24f}; handle = new float[]{0.14f,0.12f,0.11f};
        }

        matrices.push();
        this.getContextModel().body.rotate(matrices);
        matrices.translate(0.0f, 0.15f, 0.25f);
        matrices.multiply(RotationAxis.POSITIVE_Z.rotationDegrees(-40.0f));
        matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(180.0f));
        matrices.scale(0.65f, 0.65f, 0.65f);
        VertexConsumer vc = vertexConsumers.getBuffer(RenderLayer.getEntityTranslucent(TEX));
        // Saya (scabbard) + wraps + accent squares (like reference art)
        cuboid(matrices, vc, light, -0.05f, -0.95f, -0.05f, 0.10f, 1.30f, 0.10f, saya);
        cuboid(matrices, vc, light, -0.06f, -0.55f, -0.06f, 0.12f, 0.08f, 0.12f, wrap);
        cuboid(matrices, vc, light, -0.06f, -0.15f, -0.06f, 0.12f, 0.08f, 0.12f, wrap);
        cuboid(matrices, vc, light, -0.02f, -0.78f, -0.062f, 0.04f, 0.08f, 0.012f, accent);
        cuboid(matrices, vc, light, -0.02f, -0.34f, -0.062f, 0.04f, 0.08f, 0.012f, accent);
        // Tsuba + tsuka (handle) sticking out
        cuboid(matrices, vc, light, -0.09f, 0.35f, -0.09f, 0.18f, 0.03f, 0.18f, tsuba);
        cuboid(matrices, vc, light, -0.035f, 0.38f, -0.035f, 0.07f, 0.42f, 0.07f, handle);
        cuboid(matrices, vc, light, -0.04f, 0.46f, -0.04f, 0.08f, 0.03f, 0.08f, wrap);
        cuboid(matrices, vc, light, -0.04f, 0.60f, -0.04f, 0.08f, 0.03f, 0.08f, wrap);
        cuboid(matrices, vc, light, -0.04f, 0.80f, -0.04f, 0.08f, 0.04f, 0.08f, tsuba);
        matrices.pop();
    }

    private void cuboid(MatrixStack matrices, VertexConsumer vc, int light,
                        float x, float y, float z, float w, float h, float d, float[] col) {
        Matrix4f m = matrices.peek().getPositionMatrix();
        float x2 = x + w, y2 = y + h, z2 = z + d;
        float r = col[0], g = col[1], b = col[2];
        addQuad(vc, m, x, y, z2, x2, y, z2, x2, y2, z2, x, y2, z2, r, g, b, light);
        addQuad(vc, m, x2, y, z, x, y, z, x, y2, z, x2, y2, z, r, g, b, light);
        addQuad(vc, m, x, y, z, x, y, z2, x, y2, z2, x, y2, z, r, g, b, light);
        addQuad(vc, m, x2, y, z2, x2, y, z, x2, y2, z, x2, y2, z2, r, g, b, light);
    }

    private void addQuad(VertexConsumer vc, Matrix4f m,
                         float x1, float y1, float z1, float x2, float y2, float z2,
                         float x3, float y3, float z3, float x4, float y4, float z4,
                         float r, float g, float b, int light) {
        v(vc, m, x1, y1, z1, r, g, b, light); v(vc, m, x2, y2, z2, r, g, b, light);
        v(vc, m, x3, y3, z3, r, g, b, light); v(vc, m, x4, y4, z4, r, g, b, light);
    }

    private void v(VertexConsumer vc, Matrix4f m, float x, float y, float z, float r, float g, float b, int light) {
        vc.vertex(m, x, y, z).color(r, g, b, 1.0f).texture(0, 0)
          .overlay(OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
    }
}
'@

# ================================================================
# 5. JAVA: ModItems + creative tab
# ================================================================
Write-Host "[5/7] Rewriting ModItems.java (+creative tab)..." -ForegroundColor White
Write-File "$java\item\ModItems.java" @'
package com.example.shinobicore.item;

import com.example.shinobicore.ShinobiCore;
import net.fabricmc.fabric.api.itemgroup.v1.FabricItemGroup;
import net.minecraft.item.ArmorItem;
import net.minecraft.item.Item;
import net.minecraft.item.ItemStack;
import net.minecraft.item.ToolMaterials;
import net.minecraft.registry.Registries;
import net.minecraft.registry.Registry;
import net.minecraft.text.Text;
import net.minecraft.util.Identifier;

public class ModItems {
    public static final Item KATANA_IRON = Registry.register(Registries.ITEM,
            new Identifier(ShinobiCore.MOD_ID, "katana_iron"), new KatanaItem(ToolMaterials.IRON, new Item.Settings().maxCount(1)));
    public static final Item KATANA_DIAMOND = Registry.register(Registries.ITEM,
            new Identifier(ShinobiCore.MOD_ID, "katana_diamond"), new KatanaItem(ToolMaterials.DIAMOND, new Item.Settings().maxCount(1)));
    public static final Item KATANA_NETHERITE = Registry.register(Registries.ITEM,
            new Identifier(ShinobiCore.MOD_ID, "katana_netherite"), new KatanaItem(ToolMaterials.NETHERITE, new Item.Settings().maxCount(1).fireproof()));
    public static final Item KATANA = KATANA_IRON; // Alias for backwards compatibility
    public static final Item FLAK_VEST = Registry.register(Registries.ITEM,
            new Identifier(ShinobiCore.MOD_ID, "flak_vest"), new ArmorItem(ModArmorMaterials.NARUTO_FLAK, ArmorItem.Type.CHESTPLATE, new Item.Settings()));
    public static final Item NINJA_PANTS = Registry.register(Registries.ITEM,
            new Identifier(ShinobiCore.MOD_ID, "ninja_pants"), new ArmorItem(ModArmorMaterials.NARUTO_FLAK, ArmorItem.Type.LEGGINGS, new Item.Settings()));
    public static final Item NINJA_SANDALS = Registry.register(Registries.ITEM,
            new Identifier(ShinobiCore.MOD_ID, "ninja_sandals"), new ArmorItem(ModArmorMaterials.NARUTO_FLAK, ArmorItem.Type.BOOTS, new Item.Settings()));
    public static final Item NINJA_HOOD = Registry.register(Registries.ITEM,
            new Identifier(ShinobiCore.MOD_ID, "ninja_hood"), new ArmorItem(ModArmorMaterials.NARUTO_FLAK, ArmorItem.Type.HELMET, new Item.Settings()));
    public static final Item SHURIKEN = Registry.register(Registries.ITEM,
            new Identifier(ShinobiCore.MOD_ID, "shuriken"),
            new ThrowingWeaponItem(new Item.Settings().maxCount(16), 3f, 3.0f, 8));
    public static final Item KUNAI = Registry.register(Registries.ITEM,
            new Identifier(ShinobiCore.MOD_ID, "kunai"),
            new ThrowingWeaponItem(new Item.Settings().maxCount(16), 5f, 2.2f, 12));
    public static final Item SCROLL = Registry.register(Registries.ITEM,
            new Identifier(ShinobiCore.MOD_ID, "scroll"),
            new ScrollItem(new Item.Settings().maxCount(1)));

    public static void register() {
        Registry.register(Registries.ITEM_GROUP, new Identifier(ShinobiCore.MOD_ID, "main"),
                FabricItemGroup.builder()
                        .displayName(Text.translatable("itemGroup.shinobicore.main"))
                        .icon(() -> new ItemStack(KATANA_IRON))
                        .entries((context, entries) -> {
                            entries.add(KATANA_IRON);
                            entries.add(KATANA_DIAMOND);
                            entries.add(KATANA_NETHERITE);
                            entries.add(NINJA_HOOD);
                            entries.add(FLAK_VEST);
                            entries.add(NINJA_PANTS);
                            entries.add(NINJA_SANDALS);
                            entries.add(SHURIKEN);
                            entries.add(KUNAI);
                            entries.add(SCROLL);
                        })
                        .build());
        ShinobiCore.LOGGER.info("Registered katanas, armor, shuriken/kunai items + creative tab");
    }
}
'@

# ================================================================
# 6. PATCHES: client registration + scabbard UX + lang
# ================================================================
Write-Host "`n[6/7] Patching client registration, scabbard UX, lang..." -ForegroundColor White

# --- ShinobiCoreClient: регистрируем броню и ножны (вместо пустой лямбды) ---
Patch-File "$java\client\ShinobiCoreClient.java" `
"LivingEntityFeatureRendererRegistrationCallback.EVENT.register((entityType, entityModel, registrationHelper, context) -> {});" `
"NarutoArmorRenderer.register();
        LivingEntityFeatureRendererRegistrationCallback.EVENT.register((entityType, entityRenderer, registrationHelper, context) -> {
            if (entityRenderer instanceof net.minecraft.client.render.entity.PlayerEntityRenderer playerRenderer) {
                registrationHelper.register(new BackKatanaRenderer(playerRenderer));
            }
        });"

# --- ClientInputHandler: скрытие клинка в ножнах (custom_model_data) + звуки ---
Patch-File "$java\client\ClientInputHandler.java" `
"                boolean isSheathed = nbt.getBoolean(""Sheathed"");
                nbt.putBoolean(""Sheathed"", !isSheathed);" `
"                boolean isSheathed = nbt.getBoolean(""Sheathed"");
                nbt.putBoolean(""Sheathed"", !isSheathed);
                nbt.putInt(""CustomModelData"", !isSheathed ? 1 : 0);
                client.player.playSound(!isSheathed ? net.minecraft.sound.SoundEvents.ITEM_SHIELD_BLOCK : net.minecraft.sound.SoundEvents.ENTITY_PLAYER_ATTACK_SWEEP, 0.5f, !isSheathed ? 1.6f : 1.1f);"

# --- Lang files: полные переводы ---
Write-File "$assets\lang\en_us.json" @'
{
  "itemGroup.shinobicore.main": "Shinobi Core",
  "item.shinobicore.katana": "Katana",
  "item.shinobicore.katana_iron": "Iron Katana",
  "item.shinobicore.katana_diamond": "Diamond Katana",
  "item.shinobicore.katana_netherite": "Netherite Katana",
  "item.shinobicore.shuriken": "Shuriken",
  "item.shinobicore.kunai": "Kunai",
  "item.shinobicore.scroll": "Jutsu Scroll",
  "item.shinobicore.ninja_hood": "Forehead Protector",
  "item.shinobicore.flak_vest": "Flak Jacket",
  "item.shinobicore.ninja_pants": "Shinobi Pants",
  "item.shinobicore.ninja_sandals": "Shinobi Sandals",
  "key.shinobicore.meditate": "Meditate (M)",
  "key.shinobicore.progression": "Ninja Progression (K)",
  "key.shinobicore.chakra_mode": "Chakra Mode (L)",
  "key.shinobicore.cast": "Cast A (R)",
  "key.shinobicore.cast_b": "Cast B (T)",
  "key.shinobicore.cycle_slot": "Cycle Slots A (G)",
  "key.shinobicore.cycle_b": "Cycle Slots B (H)",
  "key.shinobicore.dodge_left": "Dodge Left (Z)",
  "key.shinobicore.dodge_right": "Dodge Right (C)",
  "key.shinobicore.crawl": "Crawl (N)",
  "key.shinobicore.kick": "Kick (V)",
  "key.shinobicore.switch_style": "Switch Style (B)",
  "key.shinobicore.switch_stance": "Switch Stance (F)",
  "key.shinobicore.katana_deflect": "Parry (X)",
  "key.shinobicore.iai_dash": "Iai Dash (Alt)",
  "key.shinobicore.toggle_sensory": "Sensory (Y)",
  "key.shinobicore.toggle_scabbard": "Sheathe / Draw Katana (O)",
  "key.categories.shinobicore": "ShinobiCore",
  "key.categories.shinobicore.combat": "ShinobiCore - Combat"
}
'@
Write-File "$assets\lang\ru_ru.json" @'
{
  "itemGroup.shinobicore.main": "Shinobi Core",
  "item.shinobicore.katana": "Катана",
  "item.shinobicore.katana_iron": "Железная катана",
  "item.shinobicore.katana_diamond": "Алмазная катана",
  "item.shinobicore.katana_netherite": "Незеритовая катана",
  "item.shinobicore.shuriken": "Сюрикен",
  "item.shinobicore.kunai": "Кунай",
  "item.shinobicore.scroll": "Свиток дзюцу",
  "item.shinobicore.ninja_hood": "Протектор лба",
  "item.shinobicore.flak_vest": "Бронежилет ниндзя",
  "item.shinobicore.ninja_pants": "Штаны синоби",
  "item.shinobicore.ninja_sandals": "Сандалии синоби",
  "key.shinobicore.meditate": "Медитация (M)",
  "key.shinobicore.progression": "Прокачка ниндзя (K)",
  "key.shinobicore.chakra_mode": "Режим чакры (L)",
  "key.shinobicore.cast": "Каст A (R)",
  "key.shinobicore.cast_b": "Каст B (T)",
  "key.shinobicore.cycle_slot": "Цикл слотов A (G)",
  "key.shinobicore.cycle_b": "Цикл слотов B (H)",
  "key.shinobicore.dodge_left": "Уворот влево (Z)",
  "key.shinobicore.dodge_right": "Уворот вправо (C)",
  "key.shinobicore.crawl": "Ползание (N)",
  "key.shinobicore.kick": "Удар ногой (V)",
  "key.shinobicore.switch_style": "Смена стиля (B)",
  "key.shinobicore.switch_stance": "Смена стойки (F)",
  "key.shinobicore.katana_deflect": "Парирование (X)",
  "key.shinobicore.iai_dash": "Иай-рывок (Alt)",
  "key.shinobicore.toggle_sensory": "Сенсорика (Y)",
  "key.shinobicore.toggle_scabbard": "Ножны / достать катану (O)",
  "key.categories.shinobicore": "ShinobiCore",
  "key.categories.shinobicore.combat": "ShinobiCore - Бой"
}
'@

# ================================================================
# 7. CHANGELOG в CONTEXT.md
# ================================================================
Write-Host "[7/7] Updating CONTEXT.md..." -ForegroundColor White
$ctx = "$root\CONTEXT.md"
if (Test-Path $ctx) {
    $c = [System.IO.File]::ReadAllText($ctx, $utf8)
    if (-not $c.Contains("VOXEL MODELS MASTER")) {
        $c += @'

## Фаза: VOXEL MODELS MASTER (apply_voxel_master.ps1)
- Катаны: ванильные JSON-модели с elements (10 кубов: клинок/ха/цуба/обмотка), палитры текстур на тир, overrides custom_model_data для ножен.
- Ножны на спине: палитра под тир катаны (iron/diamond/netherite), сайя + обмотки + акценты как в референсе.
- Броня: ArmorRenderer (Fabric API) — воксельный жилет с карманами, повязка-протектор со стальной пластиной, подсумок, бинты, сандалии.
- UX: клавиша O скрывает клинок (empty-модель) + звуки доставания/ножен; creative-вкладка; полные lang en/ru; пиксель-арт иконки сюрикена/куная/брони.
'@
        [System.IO.File]::WriteAllText($ctx, $c, $utf8)
        Write-Host "[OK] CONTEXT.md updated" -ForegroundColor Green
    } else { Write-Host "[SKIP] CONTEXT.md already updated" -ForegroundColor Yellow }
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "  MASTER COMPLETE: OK=$ok SKIP=$skip ERR=$err" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next:" -ForegroundColor Cyan
Write-Host "  1. .\gradlew.bat build" -ForegroundColor White
Write-Host "  2. .\gradlew.bat runClient" -ForegroundColor White
Write-Host "  3. /give @s shinobicore:katana_iron -> 3D в руке/GUI/рамке" -ForegroundColor White
Write-Host "  4. O - убрать в ножны (клинок исчезает, ножны на спине, звук)" -ForegroundColor White
Write-Host "  5. Надеть flak_vest/ninja_hood -> воксельная броня на модели" -ForegroundColor White
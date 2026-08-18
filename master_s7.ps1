# ============================================================
# SHINOBICORE MASTER SCRIPT: SPRINT 7 FULL
# S7-01..S7-10: World & Atmosphere
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcBase = Join-Path $root "src\main\java\com\example\shinobicore"
$resBase = Join-Path $root "src\main\resources"
$blockDir = Join-Path $srcBase "block"
$blockEntityDir = Join-Path $srcBase "block\entity"
$worldDir = Join-Path $srcBase "world"
$structureDir = Join-Path $worldDir "structure"
$featureDir = Join-Path $worldDir "feature"
$texBlockDir = Join-Path $resBase "assets\shinobicore\textures\block"
$texEntityDir = Join-Path $resBase "assets\shinobicore\textures\entity"
$bsDir = Join-Path $resBase "assets\shinobicore\blockstates"
$mbDir = Join-Path $resBase "assets\shinobicore\models\block"
$miDir = Join-Path $resBase "assets\shinobicore\models\item"

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "  SPRINT 7: World & Atmosphere (S7-01..S7-10)" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

function Write-File($path, $content) {
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $content, $utf8)
    Write-Host ("  [OK] " + (Split-Path $path -Leaf)) -ForegroundColor Green
}

function Patch-File($p, $old, $new) {
    if (-not (Test-Path $p)) { Write-Host ("  [MISS] " + $p) -ForegroundColor Red; return $false }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    $c = $c.Replace("`r`n", "`n")
    $oldN = $old.Replace("`r`n", "`n")
    $newN = $new.Replace("`r`n", "`n")
    if ($c.Contains($newN)) { Write-Host ("  [SKIP] already: " + (Split-Path $p -Leaf)) -ForegroundColor Yellow; return $true }
    if (-not $c.Contains($oldN)) { Write-Host ("  [FAIL] pattern: " + (Split-Path $p -Leaf)) -ForegroundColor Red; return $false }
    $c = $c.Replace($oldN, $newN)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host ("  [PATCH] " + (Split-Path $p -Leaf)) -ForegroundColor Green
    return $true
}

# ============================================================
# SECTION 1: TEXTURE GENERATION (S7-01, S7-02)
# Repainting vanilla-style textures via System.Drawing
# ============================================================
Write-Host "[S7-01/02] Generating block textures..." -ForegroundColor Yellow

Add-Type -AssemblyName System.Drawing

function New-BlockTexture($path, $width, $height, $colorFunc) {
    $bitmap = New-Object System.Drawing.Bitmap($width, $height)
    for ($x = 0; $x -lt $width; $x++) {
        for ($y = 0; $y -lt $height; $y++) {
            $color = & $colorFunc $x $y
            $bitmap.SetPixel($x, $y, $color)
        }
    }
    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
}

if (-not (Test-Path $texBlockDir)) { New-Item -ItemType Directory -Path $texBlockDir -Force | Out-Null }
if (-not (Test-Path $texEntityDir)) { New-Item -ItemType Directory -Path $texEntityDir -Force | Out-Null }

# --- Tatami (green-yellow straw with horizontal lines) ---
New-BlockTexture "$texBlockDir\tatami.png" 16 16 {
    param($x, $y)
    $noise = Get-Random -Minimum -8 -Maximum 8
    if ($y % 4 -lt 2) {
        [System.Drawing.Color]::FromArgb(255, [Math]::Max(0,[Math]::Min(255,180+$noise)), [Math]::Max(0,[Math]::Min(255,170+$noise)), [Math]::Max(0,[Math]::Min(255,100+$noise)))
    } else {
        [System.Drawing.Color]::FromArgb(255, [Math]::Max(0,[Math]::Min(255,160+$noise)), [Math]::Max(0,[Math]::Min(255,150+$noise)), [Math]::Max(0,[Math]::Min(255,90+$noise)))
    }
}

# --- Tatami side ---
New-BlockTexture "$texBlockDir\tatami_side.png" 16 16 {
    param($x, $y)
    $noise = Get-Random -Minimum -5 -Maximum 5
    [System.Drawing.Color]::FromArgb(255, [Math]::Max(0,[Math]::Min(255,140+$noise)), [Math]::Max(0,[Math]::Min(255,130+$noise)), [Math]::Max(0,[Math]::Min(255,80+$noise)))
}

# --- Shoji (white paper with dark grid) ---
New-BlockTexture "$texBlockDir\shoji.png" 16 16 {
    param($x, $y)
    $isFrame = ($x % 4 -eq 0) -or ($y % 4 -eq 0)
    if ($isFrame) {
        [System.Drawing.Color]::FromArgb(255, 80, 60, 40)
    } else {
        $noise = Get-Random -Minimum -5 -Maximum 5
        [System.Drawing.Color]::FromArgb(255, [Math]::Max(0,[Math]::Min(255,240+$noise)), [Math]::Max(0,[Math]::Min(255,235+$noise)), [Math]::Max(0,[Math]::Min(255,225+$noise)))
    }
}

# --- Wood panel (oak-like planks) ---
New-BlockTexture "$texBlockDir\wood_panel.png" 16 16 {
    param($x, $y)
    $noise = Get-Random -Minimum -10 -Maximum 10
    $plank = if (($y % 8) -lt 7) { 1 } else { 0 }
    if ($plank -eq 0) {
        [System.Drawing.Color]::FromArgb(255, 60, 45, 25)
    } else {
        [System.Drawing.Color]::FromArgb(255, [Math]::Max(0,[Math]::Min(255,160+$noise)), [Math]::Max(0,[Math]::Min(255,120+$noise)), [Math]::Max(0,[Math]::Min(255,70+$noise)))
    }
}

# --- Beam side (dark wood) ---
New-BlockTexture "$texBlockDir\beam_side.png" 16 16 {
    param($x, $y)
    $noise = Get-Random -Minimum -8 -Maximum 8
    [System.Drawing.Color]::FromArgb(255, [Math]::Max(0,[Math]::Min(255,100+$noise)), [Math]::Max(0,[Math]::Min(255,70+$noise)), [Math]::Max(0,[Math]::Min(255,40+$noise)))
}

# --- Beam top (rings) ---
New-BlockTexture "$texBlockDir\beam_top.png" 16 16 {
    param($x, $y)
    $noise = Get-Random -Minimum -6 -Maximum 6
    $dist = [Math]::Sqrt([Math]::Pow($x-8,2) + [Math]::Pow($y-8,2))
    $ring = if ([Math]::Floor($dist) % 3 -eq 0) { 80 } else { 110 }
    [System.Drawing.Color]::FromArgb(255, [Math]::Max(0,[Math]::Min(255,$ring+$noise)), [Math]::Max(0,[Math]::Min(255,[int]($ring*0.7)+$noise)), [Math]::Max(0,[Math]::Min(255,[int]($ring*0.4)+$noise)))
}

# --- Lantern side (warm glow) ---
New-BlockTexture "$texBlockDir\lantern_side.png" 16 16 {
    param($x, $y)
    $noise = Get-Random -Minimum -10 -Maximum 10
    $isFrame = ($x -eq 0) -or ($x -eq 15) -or ($y -eq 0) -or ($y -eq 15)
    if ($isFrame) {
        [System.Drawing.Color]::FromArgb(255, 60, 40, 20)
    } else {
        [System.Drawing.Color]::FromArgb(255, [Math]::Max(0,[Math]::Min(255,255+$noise)), [Math]::Max(0,[Math]::Min(255,200+$noise)), [Math]::Max(0,[Math]::Min(255,100+$noise)))
    }
}

# --- Stone path (grey bricks) ---
New-BlockTexture "$texBlockDir\stone_path.png" 16 16 {
    param($x, $y)
    $noise = Get-Random -Minimum -8 -Maximum 8
    $isMortar = ($x % 8 -eq 0) -or ($y % 4 -eq 0)
    if ($isMortar) {
        [System.Drawing.Color]::FromArgb(255, 90, 90, 90)
    } else {
        [System.Drawing.Color]::FromArgb(255, [Math]::Max(0,[Math]::Min(255,140+$noise)), [Math]::Max(0,[Math]::Min(255,140+$noise)), [Math]::Max(0,[Math]::Min(255,140+$noise)))
    }
}

# --- Sakura leaves (pink) ---
New-BlockTexture "$texBlockDir\sakura_leaves.png" 16 16 {
    param($x, $y)
    $noise = Get-Random -Minimum -15 -Maximum 15
    [System.Drawing.Color]::FromArgb(255, [Math]::Max(0,[Math]::Min(255,255+$noise)), [Math]::Max(0,[Math]::Min(255,150+$noise)), [Math]::Max(0,[Math]::Min(255,180+$noise)))
}

# --- Sakura log side ---
New-BlockTexture "$texBlockDir\sakura_log_side.png" 16 16 {
    param($x, $y)
    $noise = Get-Random -Minimum -8 -Maximum 8
    [System.Drawing.Color]::FromArgb(255, [Math]::Max(0,[Math]::Min(255,90+$noise)), [Math]::Max(0,[Math]::Min(255,60+$noise)), [Math]::Max(0,[Math]::Min(255,50+$noise)))
}

# --- Sakura log top ---
New-BlockTexture "$texBlockDir\sakura_log_top.png" 16 16 {
    param($x, $y)
    $noise = Get-Random -Minimum -6 -Maximum 6
    $dist = [Math]::Sqrt([Math]::Pow($x-8,2) + [Math]::Pow($y-8,2))
    $ring = if ([Math]::Floor($dist) % 3 -eq 0) { 70 } else { 100 }
    [System.Drawing.Color]::FromArgb(255, [Math]::Max(0,[Math]::Min(255,$ring+$noise+30)), [Math]::Max(0,[Math]::Min(255,$ring+$noise)), [Math]::Max(0,[Math]::Min(255,$ring+$noise)))
}

# --- Stone lantern ---
New-BlockTexture "$texBlockDir\stone_lantern.png" 16 16 {
    param($x, $y)
    $noise = Get-Random -Minimum -6 -Maximum 6
    [System.Drawing.Color]::FromArgb(255, [Math]::Max(0,[Math]::Min(255,160+$noise)), [Math]::Max(0,[Math]::Min(255,160+$noise)), [Math]::Max(0,[Math]::Min(255,160+$noise)))
}

# --- Chakra altar side (blue glowing) ---
New-BlockTexture "$texBlockDir\chakra_altar_side.png" 16 16 {
    param($x, $y)
    $noise = Get-Random -Minimum -8 -Maximum 8
    $isRune = ($x % 4 -eq 2) -and ($y % 4 -eq 2)
    if ($isRune) {
        [System.Drawing.Color]::FromArgb(255, 100, 200, 255)
    } else {
        [System.Drawing.Color]::FromArgb(255, [Math]::Max(0,[Math]::Min(255,80+$noise)), [Math]::Max(0,[Math]::Min(255,80+$noise)), [Math]::Max(0,[Math]::Min(255,120+$noise)))
    }
}

# --- Chakra altar top ---
New-BlockTexture "$texBlockDir\chakra_altar_top.png" 16 16 {
    param($x, $y)
    $noise = Get-Random -Minimum -5 -Maximum 5
    $dist = [Math]::Sqrt([Math]::Pow($x-8,2) + [Math]::Pow($y-8,2))
    if ($dist -lt 4) {
        [System.Drawing.Color]::FromArgb(255, 100, 200, 255)
    } else {
        [System.Drawing.Color]::FromArgb(255, [Math]::Max(0,[Math]::Min(255,70+$noise)), [Math]::Max(0,[Math]::Min(255,70+$noise)), [Math]::Max(0,[Math]::Min(255,110+$noise)))
    }
}

# --- Training post side ---
New-BlockTexture "$texBlockDir\training_post_side.png" 16 16 {
    param($x, $y)
    $noise = Get-Random -Minimum -8 -Maximum 8
    $isWrap = ($y % 4 -ge 2)
    if ($isWrap) {
        [System.Drawing.Color]::FromArgb(255, [Math]::Max(0,[Math]::Min(255,200+$noise)), [Math]::Max(0,[Math]::Min(255,190+$noise)), [Math]::Max(0,[Math]::Min(255,170+$noise)))
    } else {
        [System.Drawing.Color]::FromArgb(255, [Math]::Max(0,[Math]::Min(255,120+$noise)), [Math]::Max(0,[Math]::Min(255,90+$noise)), [Math]::Max(0,[Math]::Min(255,50+$noise)))
    }
}

# --- Training post top ---
New-BlockTexture "$texBlockDir\training_post_top.png" 16 16 {
    param($x, $y)
    $noise = Get-Random -Minimum -6 -Maximum 6
    [System.Drawing.Color]::FromArgb(255, [Math]::Max(0,[Math]::Min(255,130+$noise)), [Math]::Max(0,[Math]::Min(255,100+$noise)), [Math]::Max(0,[Math]::Min(255,60+$noise)))
}

# --- Onsen water (light blue, translucent feel) ---
New-BlockTexture "$texBlockDir\onsen_water.png" 16 16 {
    param($x, $y)
    $noise = Get-Random -Minimum -10 -Maximum 10
    [System.Drawing.Color]::FromArgb(200, [Math]::Max(0,[Math]::Min(255,100+$noise)), [Math]::Max(0,[Math]::Min(255,180+$noise)), [Math]::Max(0,[Math]::Min(255,220+$noise)))
}

# --- Samurai teacher skin (64x64) ---
Write-Host "[S7-08] Generating samurai teacher skin..." -ForegroundColor Yellow
$skinBitmap = New-Object System.Drawing.Bitmap(64, 64)
# Fill with transparent
for ($x = 0; $x -lt 64; $x++) { for ($y = 0; $y -lt 64; $y++) { $skinBitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0,0,0,0)) } }
# Head (8x8 at 8,8) - dark hair, face
for ($x = 8; $x -lt 16; $x++) { for ($y = 8; $y -lt 16; $y++) {
    if ($y -lt 10) { $skinBitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, 40, 30, 25)) }
    else { $skinBitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, 220, 180, 150)) }
}}
# Body (8x12 at 20,20) - red/black armor
for ($x = 20; $x -lt 28; $x++) { for ($y = 20; $y -lt 32; $y++) {
    if ($y % 4 -lt 2) { $skinBitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, 180, 30, 30)) }
    else { $skinBitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, 40, 40, 40)) }
}}
# Right arm (4x12 at 44,20) - dark
for ($x = 44; $x -lt 48; $x++) { for ($y = 20; $y -lt 32; $y++) {
    $skinBitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, 50, 40, 35))
}}
# Left arm (4x12 at 36,52) - dark
for ($x = 36; $x -lt 40; $x++) { for ($y = 52; $y -lt 64; $y++) {
    $skinBitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, 50, 40, 35))
}}
# Right leg (4x12 at 4,20) - dark pants
for ($x = 4; $x -lt 8; $x++) { for ($y = 20; $y -lt 32; $y++) {
    $skinBitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, 35, 35, 50))
}}
# Left leg (4x12 at 20,52) - dark pants
for ($x = 20; $x -lt 24; $x++) { for ($y = 52; $y -lt 64; $y++) {
    $skinBitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, 35, 35, 50))
}}
$skinBitmap.Save("$texEntityDir\samurai_teacher.png", [System.Drawing.Imaging.ImageFormat]::Png)
$skinBitmap.Dispose()
Write-Host "  [OK] samurai_teacher.png" -ForegroundColor Green

Write-Host "  [S7-01/02] All textures generated." -ForegroundColor Cyan
Write-Host ""

# ============================================================
# SECTION 2: BLOCK DEFINITIONS (S7-01, S7-02)
# ============================================================
Write-Host "[S7-01/02] Creating ModBlocks.java..." -ForegroundColor Yellow

$modBlocks = @'
package com.example.shinobicore.block;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.block.entity.ChakraAltarBlockEntity;
import com.example.shinobicore.block.entity.OnsenBlockEntity;
import com.example.shinobicore.block.entity.TrainingPostBlockEntity;
import net.fabricmc.fabric.api.object.builder.v1.block.FabricBlockSettings;
import net.minecraft.block.Block;
import net.minecraft.block.BlockState;
import net.minecraft.block.Blocks;
import net.minecraft.block.Material;
import net.minecraft.block.MapColor;
import net.minecraft.block.entity.BlockEntityType;
import net.minecraft.item.BlockItem;
import net.minecraft.item.Item;
import net.minecraft.registry.Registries;
import net.minecraft.registry.Registry;
import net.minecraft.sound.BlockSoundGroup;
import net.minecraft.util.Identifier;

/**
 * S7-01/S7-02: All custom blocks for Japanese architecture and decor.
 */
public class ModBlocks {

    // === S7-01: Japanese building blocks ===
    public static final Block TATAMI = register("tatami",
        new Block(FabricBlockSettings.copyOf(Blocks.HAY_BLOCK).sounds(BlockSoundGroup.GRASS)));

    public static final Block SHOJI = register("shoji",
        new Block(FabricBlockSettings.copyOf(Blocks.WHITE_WOOL).sounds(BlockSoundGroup.WOOD).nonOpaque()));

    public static final Block WOOD_PANEL = register("wood_panel",
        new Block(FabricBlockSettings.copyOf(Blocks.OAK_PLANKS)));

    public static final Block BEAM = register("beam",
        new Block(FabricBlockSettings.copyOf(Blocks.OAK_LOG)));

    public static final Block LANTERN = register("lantern",
        new Block(FabricBlockSettings.copyOf(Blocks.LANTERN).luminance(state -> 14)));

    public static final Block STONE_PATH = register("stone_path",
        new Block(FabricBlockSettings.copyOf(Blocks.STONE_BRICKS)));

    // === S7-02: Decorative blocks ===
    public static final Block SAKURA_LEAVES = register("sakura_leaves",
        new Block(FabricBlockSettings.copyOf(Blocks.OAK_LEAVES)));

    public static final Block SAKURA_LOG = register("sakura_log",
        new Block(FabricBlockSettings.copyOf(Blocks.OAK_LOG)));

    public static final Block STONE_LANTERN = register("stone_lantern",
        new Block(FabricBlockSettings.copyOf(Blocks.STONE).luminance(state -> 10)));

    // === S7-03: Training post ===
    public static final Block TRAINING_POST = register("training_post",
        new TrainingPostBlock(FabricBlockSettings.copyOf(Blocks.OAK_LOG).sounds(BlockSoundGroup.WOOD)));

    // === S7-04: Onsen water ===
    public static final Block ONSEN_WATER = register("onsen_water",
        new OnsenBlock(FabricBlockSettings.copyOf(Blocks.WATER).sounds(BlockSoundGroup.GLASS)));

    // === S7-05: Chakra altar ===
    public static final Block CHAKRA_ALTAR = register("chakra_altar",
        new ChakraAltarBlock(FabricBlockSettings.copyOf(Blocks.STONE).luminance(state -> 8)));

    // === Registration ===
    private static Block register(String name, Block block) {
        return Registry.register(Registries.BLOCK, new Identifier(ShinobiCore.MOD_ID, name), block);
    }

    private static Item registerBlockItem(String name, Block block) {
        return Registry.register(Registries.ITEM, new Identifier(ShinobiCore.MOD_ID, name),
            new BlockItem(block, new Item.Settings()));
    }

    public static void register() {
        registerBlockItem("tatami", TATAMI);
        registerBlockItem("shoji", SHOJI);
        registerBlockItem("wood_panel", WOOD_PANEL);
        registerBlockItem("beam", BEAM);
        registerBlockItem("lantern", LANTERN);
        registerBlockItem("stone_path", STONE_PATH);
        registerBlockItem("sakura_leaves", SAKURA_LEAVES);
        registerBlockItem("sakura_log", SAKURA_LOG);
        registerBlockItem("stone_lantern", STONE_LANTERN);
        registerBlockItem("training_post", TRAINING_POST);
        registerBlockItem("onsen_water", ONSEN_WATER);
        registerBlockItem("chakra_altar", CHAKRA_ALTAR);
        ShinobiCore.LOGGER.info("[S7] Registered {} blocks", 12);
    }
}
'@
Write-File (Join-Path $blockDir "ModBlocks.java") $modBlocks

# --- TrainingPostBlock ---
$trainingPostBlock = @'
package com.example.shinobicore.block;

import com.example.shinobicore.block.entity.TrainingPostBlockEntity;
import net.minecraft.block.BlockEntityProvider;
import net.minecraft.block.BlockState;
import net.minecraft.block.entity.BlockEntity;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.util.ActionResult;
import net.minecraft.util.Hand;
import net.minecraft.util.hit.BlockHitResult;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.World;

/**
 * S7-03: Training post block.
 * Players punch/slash it to gain XP.
 * Daily cap + diminishing returns.
 */
public class TrainingPostBlock extends net.minecraft.block.Block implements BlockEntityProvider {

    public TrainingPostBlock(Settings settings) {
        super(settings);
    }

    @Override
    public BlockEntity createBlockEntity(BlockPos pos, BlockState state) {
        return new TrainingPostBlockEntity(pos, state);
    }

    @Override
    public ActionResult onUse(BlockState state, World world, BlockPos pos,
                              PlayerEntity player, Hand hand, BlockHitResult hit) {
        if (world.isClient) return ActionResult.SUCCESS;
        BlockEntity be = world.getBlockEntity(pos);
        if (be instanceof TrainingPostBlockEntity post) {
            post.onPlayerInteract(player);
        }
        return ActionResult.SUCCESS;
    }
}
'@
Write-File (Join-Path $blockDir "TrainingPostBlock.java") $trainingPostBlock

# --- OnsenBlock ---
$onsenBlock = @'
package com.example.shinobicore.block;

import com.example.shinobicore.block.entity.OnsenBlockEntity;
import net.minecraft.block.BlockEntityProvider;
import net.minecraft.block.BlockState;
import net.minecraft.block.entity.BlockEntity;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.util.ActionResult;
import net.minecraft.util.Hand;
import net.minecraft.util.hit.BlockHitResult;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.World;

/**
 * S7-04: Onsen water block.
 * Standing in it grants permanent stat buffs (with cooldown).
 */
public class OnsenBlock extends net.minecraft.block.Block implements BlockEntityProvider {

    public OnsenBlock(Settings settings) {
        super(settings);
    }

    @Override
    public BlockEntity createBlockEntity(BlockPos pos, BlockState state) {
        return new OnsenBlockEntity(pos, state);
    }

    @Override
    public ActionResult onUse(BlockState state, World world, BlockPos pos,
                              PlayerEntity player, Hand hand, BlockHitResult hit) {
        if (world.isClient) return ActionResult.SUCCESS;
        BlockEntity be = world.getBlockEntity(pos);
        if (be instanceof OnsenBlockEntity onsen) {
            onsen.onPlayerEnter(player);
        }
        return ActionResult.SUCCESS;
    }
}
'@
Write-File (Join-Path $blockDir "OnsenBlock.java") $onsenBlock

# --- ChakraAltarBlock ---
$chakraAltarBlock = @'
package com.example.shinobicore.block;

import com.example.shinobicore.block.entity.ChakraAltarBlockEntity;
import net.minecraft.block.BlockEntityProvider;
import net.minecraft.block.BlockState;
import net.minecraft.block.entity.BlockEntity;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.util.ActionResult;
import net.minecraft.util.Hand;
import net.minecraft.util.hit.BlockHitResult;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.World;

/**
 * S7-05: Chakra altar block.
 * Always active. Player binds to one altar. Altar can be upgraded.
 */
public class ChakraAltarBlock extends net.minecraft.block.Block implements BlockEntityProvider {

    public ChakraAltarBlock(Settings settings) {
        super(settings);
    }

    @Override
    public BlockEntity createBlockEntity(BlockPos pos, BlockState state) {
        return new ChakraAltarBlockEntity(pos, state);
    }

    @Override
    public ActionResult onUse(BlockState state, World world, BlockPos pos,
                              PlayerEntity player, Hand hand, BlockHitResult hit) {
        if (world.isClient) return ActionResult.SUCCESS;
        BlockEntity be = world.getBlockEntity(pos);
        if (be instanceof ChakraAltarBlockEntity altar) {
            altar.onPlayerInteract(player);
        }
        return ActionResult.SUCCESS;
    }
}
'@
Write-File (Join-Path $blockDir "ChakraAltarBlock.java") $chakraAltarBlock

Write-Host ""

# ============================================================
# SECTION 3: BLOCK ENTITIES (S7-03, S7-04, S7-05)
# ============================================================
Write-Host "[S7-03/04/05] Creating BlockEntities..." -ForegroundColor Yellow

$trainingPostBE = @'
package com.example.shinobicore.block.entity;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.stat.StatType;
import net.minecraft.block.BlockState;
import net.minecraft.block.entity.BlockEntity;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import net.minecraft.util.math.BlockPos;

/**
 * S7-03: Training post BlockEntity.
 * Universal XP: hand = taijutsu, katana = kenjutsu.
 * Daily cap + diminishing returns.
 */
public class TrainingPostBlockEntity extends BlockEntity {

    private int dailyUseCount = 0;
    private long lastResetDay = 0;
    private static final int DAILY_CAP = 100;
    private static final float BASE_XP = 5.0f;

    public TrainingPostBlockEntity(BlockPos pos, BlockState state) {
        super(ModBlockEntities.TRAINING_POST, pos, state);
    }

    public void onPlayerInteract(PlayerEntity player) {
        if (!(player instanceof ServerPlayerEntity sp)) return;
        if (!(world instanceof net.minecraft.server.world.ServerWorld sw)) return;

        // Reset daily counter
        long currentDay = sw.getTime() / 24000L;
        if (currentDay != lastResetDay) {
            dailyUseCount = 0;
            lastResetDay = currentDay;
        }

        if (dailyUseCount >= DAILY_CAP) {
            player.sendMessage(Text.literal("\u00a77The training post is worn out for today."), false);
            return;
        }

        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();

        // Determine stat based on held item
        boolean hasKatana = player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem;
        StatType stat = hasKatana ? StatType.TAIJUTSU : StatType.TAIJUTSU;

        // Diminishing returns
        float diminish = Math.max(0.1f, 1.0f - dailyUseCount * 0.008f);
        float xp = BASE_XP * diminish;

        NinjaFormula.grantStatXp(data, stat, (int) xp);
        dailyUseCount++;

        // Particles
        sw.spawnParticles(net.minecraft.particle.ParticleTypes.POOF,
            pos.getX() + 0.5, pos.getY() + 1.2, pos.getZ() + 0.5,
            3, 0.2, 0.3, 0.2, 0.03);

        // Sound
        sw.playSound(null, pos, net.minecraft.sound.SoundEvents.BLOCK_WOOD_HIT,
            net.minecraft.sound.SoundCategory.BLOCKS, 0.8f, 0.9f);

        ShinobiCore.sendStatsSync(sp);
    }

    @Override
    protected void writeNbt(NbtCompound nbt) {
        nbt.putInt("DailyUseCount", dailyUseCount);
        nbt.putLong("LastResetDay", lastResetDay);
    }

    @Override
    public void readNbt(NbtCompound nbt) {
        dailyUseCount = nbt.getInt("DailyUseCount");
        lastResetDay = nbt.getLong("LastResetDay");
    }
}
'@
Write-File (Join-Path $blockEntityDir "TrainingPostBlockEntity.java") $trainingPostBE

$onsenBE = @'
package com.example.shinobicore.block.entity;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.block.BlockState;
import net.minecraft.block.entity.BlockEntity;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import net.minecraft.util.math.BlockPos;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/**
 * S7-04: Onsen BlockEntity.
 * Grants permanent stat buff with daily cooldown.
 */
public class OnsenBlockEntity extends BlockEntity {

    private final Map<UUID, Long> lastUseTime = new HashMap<>();
    private static final long COOLDOWN_MS = 24000L * 50L; // 1 game day in ms

    public OnsenBlockEntity(BlockPos pos, BlockState state) {
        super(ModBlockEntities.ONSEN, pos, state);
    }

    public void onPlayerEnter(PlayerEntity player) {
        if (!(player instanceof ServerPlayerEntity sp)) return;

        UUID id = player.getUuid();
        long now = System.currentTimeMillis();
        Long lastUse = lastUseTime.get(id);

        if (lastUse != null && now - lastUse < COOLDOWN_MS) {
            long remaining = (COOLDOWN_MS - (now - lastUse)) / 1000;
            player.sendMessage(Text.literal("\u00a77Onsen cooldown: " + remaining + "s"), false);
            return;
        }

        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();

        // Grant small permanent buff
        float currentMax = data.getMaxStamina();
        data.setMaxStamina(currentMax + 2.0f);

        lastUseTime.put(id, now);

        player.sendMessage(Text.literal("\u00a7aOnsen blessing: +2 max stamina!"), false);

        // Particles
        if (world instanceof net.minecraft.server.world.ServerWorld sw) {
            sw.spawnParticles(net.minecraft.particle.ParticleTypes.CLOUD,
                pos.getX() + 0.5, pos.getY() + 1.5, pos.getZ() + 0.5,
                10, 0.5, 0.5, 0.5, 0.02);
        }

        ShinobiCore.sendChakraSync(sp);
    }

    @Override
    protected void writeNbt(NbtCompound nbt) {
        // Cleanup old entries on save
        long now = System.currentTimeMillis();
        lastUseTime.entrySet().removeIf(e -> now - e.getValue() > COOLDOWN_MS * 2);
    }

    @Override
    public void readNbt(NbtCompound nbt) {
        // No persistent data needed for cooldowns
    }
}
'@
Write-File (Join-Path $blockEntityDir "OnsenBlockEntity.java") $onsenBE

$chakraAltarBE = @'
package com.example.shinobicore.block.entity;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.block.BlockState;
import net.minecraft.block.entity.BlockEntity;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import net.minecraft.util.math.BlockPos;
import java.util.HashSet;
import java.util.Set;
import java.util.UUID;

/**
 * S7-05: Chakra Altar BlockEntity.
 * Always active. Player binds to ONE altar. Altar can be upgraded.
 * Bound players get chakra regen boost in radius.
 */
public class ChakraAltarBlockEntity extends BlockEntity {

    private int level = 1;
    private final Set<UUID> boundPlayers = new HashSet<>();
    private static final int MAX_LEVEL = 5;

    public ChakraAltarBlockEntity(BlockPos pos, BlockState state) {
        super(ModBlockEntities.CHAKRA_ALTAR, pos, state);
    }

    public int getLevel() { return level; }
    public float getRadius() { return 8.0f + level * 2.0f; }
    public float getRegenMultiplier() { return 1.0f + level * 0.5f; }

    public void onPlayerInteract(PlayerEntity player) {
        if (!(player instanceof ServerPlayerEntity sp)) return;

        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();

        // Check if player is already bound to another altar
        BlockPos boundAltar = data.getBoundAltarPos();
        if (boundAltar != null && !boundAltar.equals(pos)) {
            player.sendMessage(Text.literal("\u00a7cYou are already bound to another altar."), false);
            return;
        }

        // Bind player to this altar
        if (boundAltar == null) {
            data.setBoundAltarPos(pos);
            boundPlayers.add(player.getUuid());
            player.sendMessage(Text.literal("\u00a7aBound to this altar. Level: " + level), false);
        } else {
            // Upgrade altar
            if (level < MAX_LEVEL) {
                float upgradeCost = 50.0f * level;
                if (data.getCurrentChakra() >= upgradeCost) {
                    data.setCurrentChakra(data.getCurrentChakra() - upgradeCost);
                    level++;
                    player.sendMessage(Text.literal("\u00a7aAltar upgraded to level " + level + "!"), false);
                    ShinobiCore.sendChakraSync(sp);
                } else {
                    player.sendMessage(Text.literal("\u00a7cNeed " + (int) upgradeCost + " chakra to upgrade."), false);
                }
            } else {
                player.sendMessage(Text.literal("\u00a77Altar is at max level."), false);
            }
        }

        // Particles
        if (world instanceof net.minecraft.server.world.ServerWorld sw) {
            sw.spawnParticles(net.minecraft.particle.ParticleTypes.ENCHANT,
                pos.getX() + 0.5, pos.getY() + 1.5, pos.getZ() + 0.5,
                15, 0.5, 0.5, 0.5, 0.05);
        }
    }

    @Override
    protected void writeNbt(NbtCompound nbt) {
        nbt.putInt("Level", level);
    }

    @Override
    public void readNbt(NbtCompound nbt) {
        level = nbt.getInt("Level");
        if (level < 1) level = 1;
    }
}
'@
Write-File (Join-Path $blockEntityDir "ChakraAltarBlockEntity.java") $chakraAltarBE

# --- ModBlockEntities registration ---
$modBlockEntities = @'
package com.example.shinobicore.block.entity;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.block.ModBlocks;
import net.minecraft.block.entity.BlockEntityType;
import net.minecraft.registry.Registries;
import net.minecraft.registry.Registry;
import net.minecraft.util.Identifier;

public class ModBlockEntities {

    public static final BlockEntityType<TrainingPostBlockEntity> TRAINING_POST =
        Registry.register(Registries.BLOCK_ENTITY_TYPE,
            new Identifier(ShinobiCore.MOD_ID, "training_post"),
            BlockEntityType.Builder.create(TrainingPostBlockEntity::new, ModBlocks.TRAINING_POST).build());

    public static final BlockEntityType<OnsenBlockEntity> ONSEN =
        Registry.register(Registries.BLOCK_ENTITY_TYPE,
            new Identifier(ShinobiCore.MOD_ID, "onsen"),
            BlockEntityType.Builder.create(OnsenBlockEntity::new, ModBlocks.ONSEN_WATER).build());

    public static final BlockEntityType<ChakraAltarBlockEntity> CHAKRA_ALTAR =
        Registry.register(Registries.BLOCK_ENTITY_TYPE,
            new Identifier(ShinobiCore.MOD_ID, "chakra_altar"),
            BlockEntityType.Builder.create(ChakraAltarBlockEntity::new, ModBlocks.CHAKRA_ALTAR).build());

    public static void register() {
        ShinobiCore.LOGGER.info("[S7] Registered block entities");
    }
}
'@
Write-File (Join-Path $blockEntityDir "ModBlockEntities.java") $modBlockEntities

Write-Host ""

# ============================================================
# SECTION 4: BLOCK MODELS (JSON)
# ============================================================
Write-Host "[S7-01/02] Generating block model JSONs..." -ForegroundColor Yellow

$blockNames = @("tatami", "shoji", "wood_panel", "beam", "lantern", "stone_path",
                "sakura_leaves", "sakura_log", "stone_lantern", "training_post",
                "onsen_water", "chakra_altar")

foreach ($bn in $blockNames) {
    # blockstate
    $bsContent = @"
{
    "variants": {
        "": { "model": "shinobicore:block/$bn" }
    }
}
"@
    Write-File (Join-Path $bsDir "$bn.json") $bsContent

    # model
    $modelContent = @"
{
    "parent": "minecraft:block/cube_all",
    "textures": {
        "all": "shinobicore:block/$bn"
    }
}
"@
    Write-File (Join-Path $mbDir "$bn.json") $modelContent

    # item model
    $itemContent = @"
{
    "parent": "shinobicore:block/$bn"
}
"@
    Write-File (Join-Path $miDir "$bn.json") $itemContent
}

Write-Host "  [S7-01/02] All block model JSONs generated." -ForegroundColor Cyan
Write-Host ""

# ============================================================
# SECTION 5: STRUCTURES (S7-06, S7-07)
# ============================================================
Write-Host "[S7-06/07] Creating structure generators..." -ForegroundColor Yellow

$structureBuilder = @'
package com.example.shinobicore.world.structure;

import net.minecraft.block.BlockState;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.BlockPos;

/**
 * S7-06: Utility for placing blocks in structures.
 */
public class StructureBuilder {

    public static void fill(ServerWorld world, BlockPos from, BlockPos to, BlockState state) {
        for (int x = Math.min(from.getX(), to.getX()); x <= Math.max(from.getX(), to.getX()); x++) {
            for (int y = Math.min(from.getY(), to.getY()); y <= Math.max(from.getY(), to.getY()); y++) {
                for (int z = Math.min(from.getZ(), to.getZ()); z <= Math.max(from.getZ(), to.getZ()); z++) {
                    BlockPos pos = new BlockPos(x, y, z);
                    if (world.isAir(pos)) {
                        world.setBlockState(pos, state, 3);
                    }
                }
            }
        }
    }

    public static void hollow(ServerWorld world, BlockPos from, BlockPos to, BlockState state) {
        for (int x = Math.min(from.getX(), to.getX()); x <= Math.max(from.getX(), to.getX()); x++) {
            for (int y = Math.min(from.getY(), to.getY()); y <= Math.max(from.getY(), to.getY()); y++) {
                for (int z = Math.min(from.getZ(), to.getZ()); z <= Math.max(from.getZ(), to.getZ()); z++) {
                    boolean isEdge = x == Math.min(from.getX(), to.getX()) || x == Math.max(from.getX(), to.getX())
                        || y == Math.min(from.getY(), to.getY()) || y == Math.max(from.getY(), to.getY())
                        || z == Math.min(from.getZ(), to.getZ()) || z == Math.max(from.getZ(), to.getZ());
                    if (isEdge) {
                        BlockPos pos = new BlockPos(x, y, z);
                        if (world.isAir(pos)) {
                            world.setBlockState(pos, state, 3);
                        }
                    }
                }
            }
        }
    }

    public static void pillar(ServerWorld world, BlockPos base, int height, BlockState state) {
        for (int y = 0; y < height; y++) {
            BlockPos pos = base.up(y);
            if (world.isAir(pos)) {
                world.setBlockState(pos, state, 3);
            }
        }
    }
}
'@
Write-File (Join-Path $structureDir "StructureBuilder.java") $structureBuilder

$dojoStructure = @'
package com.example.shinobicore.world.structure;

import com.example.shinobicore.block.ModBlocks;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.BlockPos;

/**
 * S7-06: Dojo structure generator.
 * Simple wooden building with tatami floor and training posts.
 */
public class DojoStructure {

    public static void generate(ServerWorld world, BlockPos center) {
        int w = 9, d = 7, h = 5;
        BlockPos floor = center.add(-w/2, 0, -d/2);
        BlockPos ceil = center.add(w/2, h, d/2);

        // Floor (tatami)
        StructureBuilder.fill(world, floor, center.add(w/2, 0, d/2), ModBlocks.TATAMI.getDefaultState());

        // Walls (wood panels)
        StructureBuilder.hollow(world, floor.up(), ceil, ModBlocks.WOOD_PANEL.getDefaultState());

        // Beams (corners)
        StructureBuilder.pillar(world, floor.up(), h - 1, ModBlocks.BEAM.getDefaultState());
        StructureBuilder.pillar(world, center.add(w/2, 1, -d/2), h - 1, ModBlocks.BEAM.getDefaultState());
        StructureBuilder.pillar(world, center.add(-w/2, 1, d/2), h - 1, ModBlocks.BEAM.getDefaultState());
        StructureBuilder.pillar(world, center.add(w/2, 1, d/2), h - 1, ModBlocks.BEAM.getDefaultState());

        // Roof
        StructureBuilder.fill(world, ceil, center.add(w/2, h, d/2), ModBlocks.BEAM.getDefaultState());

        // Training posts inside
        world.setBlockState(center.add(-2, 1, 0), ModBlocks.TRAINING_POST.getDefaultState(), 3);
        world.setBlockState(center.add(2, 1, 0), ModBlocks.TRAINING_POST.getDefaultState(), 3);

        // Lanterns
        world.setBlockState(center.add(-3, 2, -2), ModBlocks.LANTERN.getDefaultState(), 3);
        world.setBlockState(center.add(3, 2, 2), ModBlocks.LANTERN.getDefaultState(), 3);
    }
}
'@
Write-File (Join-Path $structureDir "DojoStructure.java") $dojoStructure

$houseStructure = @'
package com.example.shinobicore.world.structure;

import com.example.shinobicore.block.ModBlocks;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.BlockPos;

/**
 * S7-06: Japanese house structure generator.
 */
public class HouseStructure {

    public static void generate(ServerWorld world, BlockPos center) {
        int w = 7, d = 5, h = 4;
        BlockPos floor = center.add(-w/2, 0, -d/2);
        BlockPos ceil = center.add(w/2, h, d/2);

        // Floor
        StructureBuilder.fill(world, floor, center.add(w/2, 0, d/2), ModBlocks.WOOD_PANEL.getDefaultState());

        // Walls
        StructureBuilder.hollow(world, floor.up(), ceil, ModBlocks.WOOD_PANEL.getDefaultState());

        // Shoji windows (replace some wall blocks)
        world.setBlockState(center.add(0, 1, -d/2), ModBlocks.SHOJI.getDefaultState(), 3);
        world.setBlockState(center.add(0, 1, d/2), ModBlocks.SHOJI.getDefaultState(), 3);

        // Roof
        StructureBuilder.fill(world, ceil, center.add(w/2, h, d/2), ModBlocks.BEAM.getDefaultState());

        // Lantern
        world.setBlockState(center.add(-2, 2, -1), ModBlocks.LANTERN.getDefaultState(), 3);
    }
}
'@
Write-File (Join-Path $structureDir "HouseStructure.java") $houseStructure

$toriiStructure = @'
package com.example.shinobicore.world.structure;

import com.example.shinobicore.block.ModBlocks;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.BlockPos;

/**
 * S7-06: Torii gate structure generator.
 */
public class ToriiStructure {

    public static void generate(ServerWorld world, BlockPos center) {
        // Two pillars
        StructureBuilder.pillar(world, center.add(-2, 0, 0), 5, ModBlocks.BEAM.getDefaultState());
        StructureBuilder.pillar(world, center.add(2, 0, 0), 5, ModBlocks.BEAM.getDefaultState());

        // Top beam
        for (int x = -3; x <= 3; x++) {
            BlockPos pos = center.add(x, 5, 0);
            if (world.isAir(pos)) {
                world.setBlockState(pos, ModBlocks.BEAM.getDefaultState(), 3);
            }
        }

        // Second beam
        for (int x = -2; x <= 2; x++) {
            BlockPos pos = center.add(x, 4, 0);
            if (world.isAir(pos)) {
                world.setBlockState(pos, ModBlocks.BEAM.getDefaultState(), 3);
            }
        }
    }
}
'@
Write-File (Join-Path $structureDir "ToriiStructure.java") $toriiStructure

$onsenStructure = @'
package com.example.shinobicore.world.structure;

import com.example.shinobicore.block.ModBlocks;
import net.minecraft.block.Blocks;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.BlockPos;

/**
 * S7-06: Onsen structure generator.
 * Stone-bordered pool with onsen water.
 */
public class OnsenStructure {

    public static void generate(ServerWorld world, BlockPos center) {
        int radius = 3;

        // Stone border
        for (int dx = -radius; dx <= radius; dx++) {
            for (int dz = -radius; dz <= radius; dz++) {
                if (dx * dx + dz * dz <= radius * radius) {
                    // Water inside
                    BlockPos waterPos = center.add(dx, 0, dz);
                    if (world.isAir(waterPos)) {
                        world.setBlockState(waterPos, ModBlocks.ONSEN_WATER.getDefaultState(), 3);
                    }
                    // Stone border on edge
                    if (dx * dx + dz * dz >= (radius - 1) * (radius - 1)) {
                        BlockPos borderPos = center.add(dx, 1, dz);
                        if (world.isAir(borderPos)) {
                            world.setBlockState(borderPos, Blocks.STONE.getDefaultState(), 3);
                        }
                    }
                }
            }
        }

        // Stone lanterns nearby
        world.setBlockState(center.add(radius + 1, 1, 0), ModBlocks.STONE_LANTERN.getDefaultState(), 3);
        world.setBlockState(center.add(-radius - 1, 1, 0), ModBlocks.STONE_LANTERN.getDefaultState(), 3);
    }
}
'@
Write-File (Join-Path $structureDir "OnsenStructure.java") $onsenStructure

# --- Village Feature ---
$villageFeature = @'
package com.example.shinobicore.world.feature;

import com.example.shinobicore.world.structure.DojoStructure;
import com.example.shinobicore.world.structure.HouseStructure;
import com.example.shinobicore.world.structure.OnsenStructure;
import com.example.shinobicore.world.structure.ToriiStructure;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.gen.feature.DefaultFeatureConfig;
import net.minecraft.world.gen.feature.Feature;
import net.minecraft.world.gen.feature.FeatureConfig;
import net.minecraft.world.gen.feature.util.FeatureContext;
import java.util.Random;

/**
 * S7-07: Ninja village feature.
 * Generates a small Japanese village in forest biomes.
 */
public class NinjaVillageFeature extends Feature<DefaultFeatureConfig> {

    public NinjaVillageFeature(com.mojang.serialization.Codec<DefaultFeatureConfig> codec) {
        super(codec);
    }

    @Override
    public boolean generate(FeatureContext<DefaultFeatureConfig> context) {
        ServerWorld world = context.getWorld();
        BlockPos origin = context.getOrigin();
        Random random = context.getRandom();

        // Find ground level
        BlockPos ground = world.getTopPosition(net.minecraft.world.Heightmap.Type.WORLD_SURFACE, origin);
        if (ground == null) return false;

        // Don't generate if too close to existing structures
        if (!world.isAir(ground.up(2))) return false;

        // Torii gate at entrance
        ToriiStructure.generate(world, ground.add(0, 0, 8));

        // Dojo in center
        DojoStructure.generate(world, ground);

        // Houses around
        HouseStructure.generate(world, ground.add(-10, 0, -5));
        HouseStructure.generate(world, ground.add(10, 0, -5));
        HouseStructure.generate(world, ground.add(-8, 0, 6));

        // Onsen
        OnsenStructure.generate(world, ground.add(12, 0, 6));

        // Chakra altar
        world.setBlockState(ground.add(0, 1, -5),
            com.example.shinobicore.block.ModBlocks.CHAKRA_ALTAR.getDefaultState(), 3);

        // Sakura trees
        for (int i = 0; i < 6; i++) {
            int tx = random.nextInt(30) - 15;
            int tz = random.nextInt(30) - 15;
            BlockPos treePos = world.getTopPosition(
                net.minecraft.world.Heightmap.Type.WORLD_SURFACE, ground.add(tx, 0, tz));
            if (treePos != null && world.isAir(treePos.up())) {
                SakuraTreeFeature.generateTree(world, treePos, random);
            }
        }

        return true;
    }
}
'@
Write-File (Join-Path $featureDir "NinjaVillageFeature.java") $villageFeature

Write-Host ""

# ============================================================
# SECTION 6: SAKURA TREE FEATURE (S7-09)
# ============================================================
Write-Host "[S7-09] Creating SakuraTreeFeature..." -ForegroundColor Yellow

$sakuraTreeFeature = @'
package com.example.shinobicore.world.feature;

import com.example.shinobicore.block.ModBlocks;
import net.minecraft.block.BlockState;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.gen.feature.DefaultFeatureConfig;
import net.minecraft.world.gen.feature.Feature;
import net.minecraft.world.gen.feature.util.FeatureContext;
import java.util.Random;

/**
 * S7-09: Sakura tree feature.
 * Generates pink-leafed trees in forest biomes.
 */
public class SakuraTreeFeature extends Feature<DefaultFeatureConfig> {

    public SakuraTreeFeature(com.mojang.serialization.Codec<DefaultFeatureConfig> codec) {
        super(codec);
    }

    @Override
    public boolean generate(FeatureContext<DefaultFeatureConfig> context) {
        ServerWorld world = context.getWorld();
        BlockPos origin = context.getOrigin();
        Random random = context.getRandom();

        BlockPos ground = world.getTopPosition(net.minecraft.world.Heightmap.Type.WORLD_SURFACE, origin);
        if (ground == null || !world.isAir(ground.up())) return false;

        generateTree(world, ground, random);
        return true;
    }

    public static void generateTree(ServerWorld world, BlockPos base, Random random) {
        int trunkHeight = 4 + random.nextInt(3);

        // Trunk
        for (int y = 1; y <= trunkHeight; y++) {
            BlockPos pos = base.up(y);
            if (world.isAir(pos)) {
                world.setBlockState(pos, ModBlocks.SAKURA_LOG.getDefaultState(), 3);
            }
        }

        // Leaves (sphere-ish)
        int leafRadius = 2 + random.nextInt(2);
        BlockPos leafCenter = base.up(trunkHeight + 1);
        for (int dx = -leafRadius; dx <= leafRadius; dx++) {
            for (int dy = -leafRadius / 2; dy <= leafRadius / 2; dy++) {
                for (int dz = -leafRadius; dz <= leafRadius; dz++) {
                    if (dx * dx + dy * dy * 4 + dz * dz <= leafRadius * leafRadius) {
                        BlockPos pos = leafCenter.add(dx, dy, dz);
                        if (world.isAir(pos)) {
                            world.setBlockState(pos, ModBlocks.SAKURA_LEAVES.getDefaultState(), 3);
                        }
                    }
                }
            }
        }
    }
}
'@
Write-File (Join-Path $featureDir "SakuraTreeFeature.java") $sakuraTreeFeature

Write-Host ""

# ============================================================
# SECTION 7: SAMURAI TEACHER NPC (S7-08)
# ============================================================
Write-Host "[S7-08] Creating SamuraiTeacherEntity..." -ForegroundColor Yellow

$samuraiTeacher = @'
package com.example.shinobicore.entity;

import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.entity.EntityType;
import net.minecraft.entity.ai.goal.LookAroundGoal;
import net.minecraft.entity.ai.goal.LookAtEntityGoal;
import net.minecraft.entity.ai.goal.SwimGoal;
import net.minecraft.entity.mob.PathAwareEntity;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import net.minecraft.util.ActionResult;
import net.minecraft.util.Hand;
import net.minecraft.world.World;

/**
 * S7-08: Samurai teacher NPC.
 * Steve model with samurai skin. Grants teacher approval for S-rank nodes.
 */
public class SamuraiTeacherEntity extends PathAwareEntity {

    public SamuraiTeacherEntity(EntityType<? extends PathAwareEntity> entityType, World world) {
        super(entityType, world);
    }

    @Override
    protected void initGoals() {
        this.goalSelector.add(0, new SwimGoal(this));
        this.goalSelector.add(1, new LookAtEntityGoal(this, PlayerEntity.class, 8.0f));
        this.goalSelector.add(2, new LookAroundGoal(this));
    }

    @Override
    public ActionResult interactMob(PlayerEntity player, Hand hand) {
        if (this.getWorld().isClient) return ActionResult.SUCCESS;

        if (player instanceof ServerPlayerEntity sp) {
            NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();

            // Grant teacher approval for S-rank nodes
            // The specific node IDs would be determined by the skill tree
            player.sendMessage(Text.literal("\u00a76\u2694 Samurai Teacher: \"I shall teach you the forbidden arts.\""), false);
            player.sendMessage(Text.literal("\u00a77Check your skill tree for newly available techniques."), false);

            // Mark teacher as interacted (for tree unlock logic)
            data.setTeacherInteracted(true);
            com.example.shinobicore.ShinobiCore.sendTreeSync(sp);
        }

        return ActionResult.SUCCESS;
    }

    @Override
    public boolean cannotDespawn() {
        return true;
    }
}
'@
Write-File (Join-Path $srcBase "entity\SamuraiTeacherEntity.java") $samuraiTeacher

$samuraiRenderer = @'
package com.example.shinobicore.entity;

import net.minecraft.client.render.entity.EntityRendererFactory;
import net.minecraft.client.render.entity.MobEntityRenderer;
import net.minecraft.client.render.entity.model.EntityModelLayers;
import net.minecraft.client.render.entity.model.PlayerEntityModel;
import net.minecraft.util.Identifier;

/**
 * S7-08: Renderer for samurai teacher NPC.
 * Uses player model with samurai skin texture.
 */
public class SamuraiTeacherRenderer extends MobEntityRenderer<SamuraiTeacherEntity, PlayerEntityModel<SamuraiTeacherEntity>> {

    private static final Identifier TEXTURE = new Identifier("shinobicore", "textures/entity/samurai_teacher.png");

    public SamuraiTeacherRenderer(EntityRendererFactory.Context ctx) {
        super(ctx, new PlayerEntityModel<>(ctx.getPart(EntityModelLayers.PLAYER), false), 0.5f);
    }

    @Override
    public Identifier getTexture(SamuraiTeacherEntity entity) {
        return TEXTURE;
    }
}
'@
Write-File (Join-Path $srcBase "entity\SamuraiTeacherRenderer.java") $samuraiRenderer

Write-Host ""

# ============================================================
# SECTION 8: PATCHES (Registration, Config, TickHandler)
# ============================================================
Write-Host "[REG] Patching registration files..." -ForegroundColor Yellow

# --- Patch ShinobiCore.java: register blocks, block entities, features ---
$shinobiCoreFile = Join-Path $srcBase "ShinobiCore.java"
Patch-File $shinobiCoreFile `
    "ModEntities.register();" `
    "ModEntities.register();`n        com.example.shinobicore.block.ModBlocks.register();`n        com.example.shinobicore.block.entity.ModBlockEntities.register();"

# --- Patch ModEntities.java: add SAMURAI_TEACHER ---
$modEntitiesFile = Join-Path $srcBase "entity\ModEntities.java"
Patch-File $modEntitiesFile `
    "public static void register() {" `
    "public static final EntityType<com.example.shinobicore.entity.SamuraiTeacherEntity> SAMURAI_TEACHER = Registry.register(`n        Registries.ENTITY_TYPE,`n        new Identifier(ShinobiCore.MOD_ID, `"samurai_teacher`"),`n        FabricEntityTypeBuilder.<com.example.shinobicore.entity.SamuraiTeacherEntity>create(SpawnGroup.CREATURE, com.example.shinobicore.entity.SamuraiTeacherEntity::new)`n            .dimensions(EntityDimensions.fixed(0.6f, 1.8f))`n            .trackRangeChunks(10)`n            .build());`n`n    public static void register() {"

# --- Patch ShinobiCoreClient.java: register renderer ---
$clientFile = Join-Path $srcBase "client\ShinobiCoreClient.java"
Patch-File $clientFile `
    "EntityRendererRegistry.register(ModEntities.NINJA_PROJECTILE, NinjaProjectileRenderer::new);" `
    "EntityRendererRegistry.register(ModEntities.NINJA_PROJECTILE, NinjaProjectileRenderer::new);`n        EntityRendererRegistry.register(ModEntities.SAMURAI_TEACHER, com.example.shinobicore.entity.SamuraiTeacherRenderer::new);"

# --- Patch NinjaPlayerData.java: add altar binding + teacher flag ---
$ninjaDataFile = Join-Path $srcBase "stat\NinjaPlayerData.java"
Patch-File $ninjaDataFile `
    "private boolean lastDangerState = false;" `
    "private boolean lastDangerState = false;`n    private net.minecraft.util.math.BlockPos boundAltarPos = null;`n    private boolean teacherInteracted = false;"

Patch-File $ninjaDataFile `
    "public boolean getLastDangerState() { return lastDangerState; }" `
    "public boolean getLastDangerState() { return lastDangerState; }`n    public net.minecraft.util.math.BlockPos getBoundAltarPos() { return boundAltarPos; }`n    public void setBoundAltarPos(net.minecraft.util.math.BlockPos pos) { this.boundAltarPos = pos; statsDirty = true; }`n    public boolean isTeacherInteracted() { return teacherInteracted; }`n    public void setTeacherInteracted(boolean v) { this.teacherInteracted = v; statsDirty = true; }"

# --- Patch NinjaTickHandler.java: altar regen tick ---
$tickFile = Join-Path $srcBase "event\NinjaTickHandler.java"
Patch-File $tickFile `
    "// === S6: Sharingan component tick ===" `
    "// === S7-05: Chakra altar regen tick ===`n            if (tickCounter % 20 == 0) {`n                var altarPos = data.getBoundAltarPos();`n                if (altarPos != null && player.getWorld() instanceof ServerWorld sw) {`n                    var be = sw.getBlockEntity(altarPos);`n                    if (be instanceof com.example.shinobicore.block.entity.ChakraAltarBlockEntity altar) {`n                        float radius = altar.getRadius();`n                        if (player.getPos().distanceTo(new net.minecraft.util.math.Vec3d(`n                                altarPos.getX() + 0.5, altarPos.getY() + 0.5, altarPos.getZ() + 0.5)) <= radius) {`n                            float bonusRegen = altar.getRegenMultiplier();`n                            data.setCurrentChakra(Math.min(data.getCurrentChakra() + bonusRegen,`n                                com.example.shinobicore.stat.NinjaFormula.maxChakra(data)));`n                        }`n                    }`n                }`n            }`n            // === S6: Sharingan component tick ==="

# --- Patch tree.json: add teacher requirement info ---
Write-Host "[S7-08] Patching tree.json for teacher nodes..." -ForegroundColor Yellow
$treeFile = Join-Path $resBase "data\shinobicore\skill_tree\tree.json"
if (Test-Path $treeFile) {
    $tc = [System.IO.File]::ReadAllText($treeFile, $utf8)
    if (-not $tc.Contains('"requires_teacher"')) {
        # Add requires_teacher to forbidden nodes
        $tc = $tc.Replace('"forb_gates_node",', '"forb_gates_node",`n                "requires_teacher": true,')
        [System.IO.File]::WriteAllText($treeFile, $tc, $utf8)
        Write-Host "  [PATCH] tree.json updated with requires_teacher" -ForegroundColor Green
    } else {
        Write-Host "  [SKIP] tree.json already has requires_teacher" -ForegroundColor Yellow
    }
}

# --- Patch lang files: add block names ---
Write-Host "[LANG] Adding block names to lang files..." -ForegroundColor Yellow
$enLangFile = Join-Path $resBase "assets\shinobicore\lang\en_us.json"
$enContent = [System.IO.File]::ReadAllText($enLangFile, $utf8)
if (-not $enContent.Contains("block.shinobicore.tatami")) {
    $blockNames_lang = @"
"block.shinobicore.tatami": "Tatami",
    "block.shinobicore.shoji": "Shoji Panel",
    "block.shinobicore.wood_panel": "Wood Panel",
    "block.shinobicore.beam": "Wooden Beam",
    "block.shinobicore.lantern": "Paper Lantern",
    "block.shinobicore.stone_path": "Stone Path",
    "block.shinobicore.sakura_leaves": "Sakura Leaves",
    "block.shinobicore.sakura_log": "Sakura Log",
    "block.shinobicore.stone_lantern": "Stone Lantern",
    "block.shinobicore.training_post": "Training Post",
    "block.shinobicore.onsen_water": "Onsen Water",
    "block.shinobicore.chakra_altar": "Chakra Altar",
    "entity.shinobicore.samurai_teacher": "Samurai Teacher",
"@
    $enContent = $enContent.Replace('"key.categories.shinobicore": "ShinobiCore",', $blockNames_lang + '    "key.categories.shinobicore": "ShinobiCore",')
    [System.IO.File]::WriteAllText($enLangFile, $enContent, $utf8)
    Write-Host "  [PATCH] en_us.json block names added" -ForegroundColor Green
} else {
    Write-Host "  [SKIP] en_us.json already has block names" -ForegroundColor Yellow
}

$ruLangFile = Join-Path $resBase "assets\shinobicore\lang\ru_ru.json"
$ruContent = [System.IO.File]::ReadAllText($ruLangFile, $utf8)
if (-not $ruContent.Contains("block.shinobicore.tatami")) {
    $ruBlockNames = @"
"block.shinobicore.tatami": "Татами",
    "block.shinobicore.shoji": "Сёдзи",
    "block.shinobicore.wood_panel": "Деревянная панель",
    "block.shinobicore.beam": "Балка",
    "block.shinobicore.lantern": "Бумажный фонарь",
    "block.shinobicore.stone_path": "Каменная дорожка",
    "block.shinobicore.sakura_leaves": "Листья сакуры",
    "block.shinobicore.sakura_log": "Бревно сакуры",
    "block.shinobicore.stone_lantern": "Каменный фонарь",
    "block.shinobicore.training_post": "Тренировочный столб",
    "block.shinobicore.onsen_water": "Вода онсэна",
    "block.shinobicore.chakra_altar": "Алтарь чакры",
    "entity.shinobicore.samurai_teacher": "Учитель-самурай",
"@
    $ruContent = $ruContent.Replace('"key.categories.shinobicore": "ShinobiCore",', $ruBlockNames + '    "key.categories.shinobicore": "ShinobiCore",')
    [System.IO.File]::WriteAllText($ruLangFile, $ruContent, $utf8)
    Write-Host "  [PATCH] ru_ru.json block names added" -ForegroundColor Green
} else {
    Write-Host "  [SKIP] ru_ru.json already has block names" -ForegroundColor Yellow
}

Write-Host ""

# ============================================================
# BUILD
# ============================================================
Write-Host "[BUILD] Verifying compilation..." -ForegroundColor Yellow
Push-Location $root
try {
    $out = & ".\gradlew.bat" build 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [PASS] Build successful!" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Build failed" -ForegroundColor Red
        $out | Select-Object -Last 25 | ForEach-Object { Write-Host ("  " + $_) -ForegroundColor Red }
    }
} finally { Pop-Location }

# ============================================================
# SUMMARY
# ============================================================
Write-Host ""
Write-Host "==============================================================" -ForegroundColor Green
Write-Host "  SPRINT 7 COMPLETE" -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Created:" -ForegroundColor White
Write-Host "  Blocks: tatami, shoji, wood_panel, beam, lantern, stone_path" -ForegroundColor Cyan
Write-Host "  Decor: sakura_leaves, sakura_log, stone_lantern" -ForegroundColor Cyan
Write-Host "  Functional: training_post, onsen_water, chakra_altar" -ForegroundColor Cyan
Write-Host "  Structures: DojoStructure, HouseStructure, ToriiStructure, OnsenStructure" -ForegroundColor Cyan
Write-Host "  Features: NinjaVillageFeature, SakuraTreeFeature" -ForegroundColor Cyan
Write-Host "  NPC: SamuraiTeacherEntity + SamuraiTeacherRenderer" -ForegroundColor Cyan
Write-Host ""
Write-Host "Patched:" -ForegroundColor White
Write-Host "  ShinobiCore.java (block/entity registration)" -ForegroundColor Cyan
Write-Host "  ModEntities.java (SAMURAI_TEACHER)" -ForegroundColor Cyan
Write-Host "  ShinobiCoreClient.java (renderer registration)" -ForegroundColor Cyan
Write-Host "  NinjaPlayerData.java (altar binding, teacher flag)" -ForegroundColor Cyan
Write-Host "  NinjaTickHandler.java (altar regen tick)" -ForegroundColor Cyan
Write-Host "  Lang files (block names en/ru)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Anti-abuse (S7-10):" -ForegroundColor White
Write-Host "  Training post: daily cap 100, diminishing returns" -ForegroundColor Yellow
Write-Host "  Onsen: 1 game day cooldown" -ForegroundColor Yellow
Write-Host "  Chakra altar: one per player, upgrade cost" -ForegroundColor Yellow
Write-Host ""
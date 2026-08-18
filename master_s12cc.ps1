# ============================================================
# SPRINT 12 PHASE C2: Clan Villages
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcBase = Join-Path $root "src\main\java\com\example\shinobicore"
$structureDir = Join-Path $srcBase "world\structure"
$featureDir = Join-Path $srcBase "world\feature"

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "  SPRINT 12 PHASE C2: Clan Villages" -ForegroundColor Cyan
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
# SECTION 1: ClanVillageGenerator
# ============================================================
Write-Host "[C2] Creating ClanVillageGenerator..." -ForegroundColor Yellow

$villageGen = @'
package com.example.shinobicore.world.structure;

import com.example.shinobicore.block.ModBlocks;
import net.minecraft.block.Blocks;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.WorldAccess;

/**
 * S12-04: Clan village generator.
 * Generates 5-8 houses + 2 unique clan structures.
 * Uses StructureBuilder from Sprint 7.
 */
public class ClanVillageGenerator {

    private static final String[] CLAN_IDS = {
        "uchiha", "hyuga", "uzumaki", "senju", "nara",
        "aburame", "inuzuka", "akimichi", "hatake"
    };

    public static void generate(WorldAccess world, BlockPos center, String clanId) {
        // Generate 5-8 houses in a circle
        int houseCount = 5 + (int)(Math.random() * 4);
        for (int i = 0; i < houseCount; i++) {
            double angle = (i / (double) houseCount) * Math.PI * 2;
            double dist = 10 + Math.random() * 6;
            int x = center.getX() + (int)(Math.cos(angle) * dist);
            int z = center.getZ() + (int)(Math.sin(angle) * dist);
            int y = center.getY();
            BlockPos housePos = new BlockPos(x, y, z);
            generateHouse(world, housePos);
        }

        // Generate 2 unique structures
        BlockPos struct1 = center.add(0, 0, 0);
        BlockPos struct2 = center.add(6, 0, 6);
        generateUniqueStructure(world, struct1, clanId, true);
        generateUniqueStructure(world, struct2, clanId, false);

        // Add lanterns along paths
        for (int i = 0; i < 6; i++) {
            double angle = (i / 6.0) * Math.PI * 2;
            int lx = center.getX() + (int)(Math.cos(angle) * 5);
            int lz = center.getZ() + (int)(Math.sin(angle) * 5);
            BlockPos lanternPos = new BlockPos(lx, center.getY() + 1, lz);
            if (world.isAir(lanternPos)) {
                world.setBlockState(lanternPos, ModBlocks.LANTERN.getDefaultState(), 3);
            }
        }
    }

    private static void generateHouse(WorldAccess world, BlockPos pos) {
        int w = 5, d = 5, h = 4;
        BlockPos floor = pos;
        BlockPos ceil = pos.add(w, h, d);

        // Floor
        StructureBuilder.fill(world, floor, pos.add(w, 0, d), ModBlocks.WOOD_PANEL.getDefaultState());
        // Walls
        StructureBuilder.hollow(world, floor.up(), ceil, ModBlocks.WOOD_PANEL.getDefaultState());
        // Roof
        StructureBuilder.fill(world, pos.add(0, h, 0), pos.add(w, h, d), ModBlocks.BEAM.getDefaultState());
        // Shoji window
        if (world.isAir(pos.add(2, 1, 0))) {
            world.setBlockState(pos.add(2, 1, 0), ModBlocks.SHOJI.getDefaultState(), 3);
        }
        // Lantern inside
        if (world.isAir(pos.add(2, 2, 2))) {
            world.setBlockState(pos.add(2, 2, 2), ModBlocks.LANTERN.getDefaultState(), 3);
        }
    }

    private static void generateUniqueStructure(WorldAccess world, BlockPos center, String clanId, boolean primary) {
        switch (clanId) {
            case "uchiha" -> generateFireAltar(world, center, primary);
            case "hyuga" -> generateDojo(world, center, primary);
            case "uzumaki" -> generateBarrierSeal(world, center, primary);
            case "senju" -> generateForestGrove(world, center, primary);
            case "nara" -> generateShadowWell(world, center, primary);
            case "aburame" -> generateHive(world, center, primary);
            case "inuzuka" -> generateKennel(world, center, primary);
            case "akimichi" -> generateEatery(world, center, primary);
            case "hatake" -> generateMemorial(world, center, primary);
            default -> generateDojo(world, center, primary);
        }
    }

    // === UNIQUE STRUCTURES ===

    private static void generateFireAltar(WorldAccess world, BlockPos center, boolean primary) {
        // Uchiha: Fire altar with netherrack base and flame
        StructureBuilder.fill(world, center.add(-2, 0, -2), center.add(2, 0, 2), Blocks.NETHERRACK.getDefaultState());
        StructureBuilder.pillar(world, center.up(), 2, Blocks.NETHER_BRICKS.getDefaultState());
        if (world.isAir(center.up(3))) {
            world.setBlockState(center.up(3), Blocks.FIRE.getDefaultState(), 3);
        }
        if (primary) {
            StructureBuilder.pillar(world, center.add(-2, 1, -2), 2, Blocks.NETHER_BRICKS.getDefaultState());
            StructureBuilder.pillar(world, center.add(2, 1, 2), 2, Blocks.NETHER_BRICKS.getDefaultState());
        }
    }

    private static void generateDojo(WorldAccess world, BlockPos center, boolean primary) {
        // Hyuga: Large tatami dojo
        int size = primary ? 7 : 5;
        int half = size / 2;
        StructureBuilder.fill(world, center.add(-half, 0, -half), center.add(half, 0, half), ModBlocks.TATAMI.getDefaultState());
        StructureBuilder.hollow(world, center.add(-half, 1, -half), center.add(half, 4, half), ModBlocks.WOOD_PANEL.getDefaultState());
        StructureBuilder.fill(world, center.add(-half, 4, -half), center.add(half, 4, half), ModBlocks.BEAM.getDefaultState());
        if (primary) {
            world.setBlockState(center.add(0, 1, 0), ModBlocks.STONE_LANTERN.getDefaultState(), 3);
        }
    }

    private static void generateBarrierSeal(WorldAccess world, BlockPos center, boolean primary) {
        // Uzumaki: Barrier seal pillar
        StructureBuilder.pillar(world, center, 4, Blocks.CHISELED_STONE_BRICKS.getDefaultState());
        StructureBuilder.fill(world, center.add(-1, 0, -1), center.add(1, 0, 1), Blocks.STONE_BRICKS.getDefaultState());
        if (primary && world.isAir(center.up(5))) {
            world.setBlockState(center.up(5), ModBlocks.LANTERN.getDefaultState(), 3);
        }
    }

    private static void generateForestGrove(WorldAccess world, BlockPos center, boolean primary) {
        // Senju: Forest grove with sakura trees
        int treeCount = primary ? 4 : 2;
        for (int i = 0; i < treeCount; i++) {
            double angle = (i / (double) treeCount) * Math.PI * 2;
            int tx = center.getX() + (int)(Math.cos(angle) * 3);
            int tz = center.getZ() + (int)(Math.sin(angle) * 3);
            BlockPos treePos = new BlockPos(tx, center.getY(), tz);
            if (world.isAir(treePos.up())) {
                com.example.shinobicore.world.feature.SakuraTreeFeature.generateTree(
                    (net.minecraft.server.world.ServerWorld) world, treePos, new java.util.Random());
            }
        }
    }

    private static void generateShadowWell(WorldAccess world, BlockPos center, boolean primary) {
        // Nara: Shadow well (dark stone circle)
        StructureBuilder.fill(world, center.add(-2, 0, -2), center.add(2, 0, 2), Blocks.DEEPSLATE.getDefaultState());
        StructureBuilder.fill(world, center.add(-1, 0, -1), center.add(1, 0, 1), Blocks.BLACK_CONCRETE.getDefaultState());
        if (primary) {
            StructureBuilder.pillar(world, center.add(-2, 1, -2), 2, Blocks.DEEPSLATE_BRICKS.getDefaultState());
            StructureBuilder.pillar(world, center.add(2, 1, 2), 2, Blocks.DEEPSLATE_BRICKS.getDefaultState());
        }
    }

    private static void generateHive(WorldAccess world, BlockPos center, boolean primary) {
        // Aburame: Hive structure
        StructureBuilder.fill(world, center.add(-1, 0, -1), center.add(1, 3, 1), Blocks.HONEYCOMB_BLOCK.getDefaultState());
        StructureBuilder.fill(world, center.add(-1, 1, -1), center.add(1, 2, 1), Blocks.HONEY_BLOCK.getDefaultState());
        if (primary) {
            StructureBuilder.fill(world, center.add(-2, 0, -2), center.add(2, 0, 2), Blocks.MOSS_BLOCK.getDefaultState());
        }
    }

    private static void generateKennel(WorldAccess world, BlockPos center, boolean primary) {
        // Inuzuka: Kennel with fences
        int size = primary ? 6 : 4;
        int half = size / 2;
        StructureBuilder.fill(world, center.add(-half, 0, -half), center.add(half, 0, half), Blocks.GRASS_BLOCK.getDefaultState());
        // Fence perimeter
        for (int x = -half; x <= half; x++) {
            if (world.isAir(center.add(x, 1, -half))) world.setBlockState(center.add(x, 1, -half), Blocks.OAK_FENCE.getDefaultState(), 3);
            if (world.isAir(center.add(x, 1, half))) world.setBlockState(center.add(x, 1, half), Blocks.OAK_FENCE.getDefaultState(), 3);
        }
        for (int z = -half; z <= half; z++) {
            if (world.isAir(center.add(-half, 1, z))) world.setBlockState(center.add(-half, 1, z), Blocks.OAK_FENCE.getDefaultState(), 3);
            if (world.isAir(center.add(half, 1, z))) world.setBlockState(center.add(half, 1, z), Blocks.OAK_FENCE.getDefaultState(), 3);
        }
    }

    private static void generateEatery(WorldAccess world, BlockPos center, boolean primary) {
        // Akimichi: Eatery building
        int w = primary ? 7 : 5, d = primary ? 5 : 4, h = 4;
        int hw = w / 2, hd = d / 2;
        StructureBuilder.fill(world, center.add(-hw, 0, -hd), center.add(hw, 0, hd), ModBlocks.WOOD_PANEL.getDefaultState());
        StructureBuilder.hollow(world, center.add(-hw, 1, -hd), center.add(hw, h, hd), ModBlocks.WOOD_PANEL.getDefaultState());
        StructureBuilder.fill(world, center.add(-hw, h, -hd), center.add(hw, h, hd), ModBlocks.BEAM.getDefaultState());
        // Tables inside
        if (world.isAir(center.add(0, 1, 0))) {
            world.setBlockState(center.add(0, 1, 0), Blocks.OAK_SLAB.getDefaultState(), 3);
        }
        if (world.isAir(center.up(2))) {
            world.setBlockState(center.up(2), ModBlocks.LANTERN.getDefaultState(), 3);
        }
    }

    private static void generateMemorial(WorldAccess world, BlockPos center, boolean primary) {
        // Hatake: Memorial stone monument
        StructureBuilder.pillar(world, center, 5, Blocks.POLISHED_ANDESITE.getDefaultState());
        StructureBuilder.fill(world, center.add(-2, 0, -2), center.add(2, 0, 2), Blocks.STONE_BRICKS.getDefaultState());
        if (primary) {
            StructureBuilder.pillar(world, center.add(-2, 1, -2), 2, Blocks.POLISHED_ANDESITE.getDefaultState());
            StructureBuilder.pillar(world, center.add(2, 1, 2), 2, Blocks.POLISHED_ANDESITE.getDefaultState());
            if (world.isAir(center.up(6))) {
                world.setBlockState(center.up(6), Blocks.SOUL_LANTERN.getDefaultState(), 3);
            }
        }
    }
}
'@
Write-File (Join-Path $structureDir "ClanVillageGenerator.java") $villageGen

# ============================================================
# SECTION 2: ClanVillageFeature
# ============================================================
Write-Host "[C2] Creating ClanVillageFeature..." -ForegroundColor Yellow

$villageFeature = @'
package com.example.shinobicore.world.feature;

import com.example.shinobicore.world.structure.ClanVillageGenerator;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.Heightmap;
import net.minecraft.world.StructureWorldAccess;
import net.minecraft.world.gen.feature.DefaultFeatureConfig;
import net.minecraft.world.gen.feature.Feature;
import net.minecraft.world.gen.feature.util.FeatureContext;
import java.util.Random;

/**
 * S12-04: Clan village feature.
 * Generates a clan village with 5-8 houses and 2 unique structures.
 * Clan is chosen randomly or by position hash.
 */
public class ClanVillageFeature extends Feature<DefaultFeatureConfig> {

    private static final String[] CLAN_IDS = {
        "uchiha", "hyuga", "uzumaki", "senju", "nara",
        "aburame", "inuzuka", "akimichi", "hatake"
    };

    public ClanVillageFeature(com.mojang.serialization.Codec<DefaultFeatureConfig> codec) {
        super(codec);
    }

    @Override
    public boolean generate(FeatureContext<DefaultFeatureConfig> context) {
        StructureWorldAccess world = context.getWorld();
        BlockPos origin = context.getOrigin();
        Random random = context.getRandom();

        int topY = world.getTopY(Heightmap.Type.WORLD_SURFACE_WG, origin.getX(), origin.getZ());
        BlockPos ground = new BlockPos(origin.getX(), topY, origin.getZ());

        if (!world.isAir(ground.up(2))) return false;

        // Determine clan by position hash (deterministic per location)
        int clanIndex = Math.abs((origin.getX() * 31 + origin.getZ() * 17) % CLAN_IDS.length);
        String clanId = CLAN_IDS[clanIndex];

        ClanVillageGenerator.generate(world, ground, clanId);
        return true;
    }
}
'@
Write-File (Join-Path $featureDir "ClanVillageFeature.java") $villageFeature

# ============================================================
# SECTION 3: PATCHES
# ============================================================
Write-Host "[C2] Patching registration files..." -ForegroundColor Yellow

# Register ClanVillageFeature in ShinobiCore
$shinobiCoreFile = Join-Path $srcBase "ShinobiCore.java"
Patch-File $shinobiCoreFile `
    "import com.example.shinobicore.config.RoadConfig;" `
    "import com.example.shinobicore.config.RoadConfig;`nimport com.example.shinobicore.world.feature.ClanVillageFeature;"

Patch-File $shinobiCoreFile `
    "// S9-01: Register enemy entity attributes" `
    "// S12-04: Register clan village feature`n        net.minecraft.registry.Registries.FEATURE.getClass(); // ensure registry loaded`n        // Feature registration happens via ModFeatures`n        ModFeatures.register();`n        // S9-01: Register enemy entity attributes"

# Create ModFeatures.java
Write-Host "[C2] Creating ModFeatures..." -ForegroundColor Yellow

$modFeatures = @'
package com.example.shinobicore;

import com.example.shinobicore.world.feature.ClanVillageFeature;
import net.minecraft.registry.Registries;
import net.minecraft.registry.Registry;
import net.minecraft.util.Identifier;
import net.minecraft.world.gen.feature.DefaultFeatureConfig;
import net.minecraft.world.gen.feature.Feature;

/**
 * S12-04: Feature registration for clan villages.
 */
public class ModFeatures {
    public static final Feature<DefaultFeatureConfig> CLAN_VILLAGE =
        Registry.register(Registries.FEATURE,
            new Identifier(ShinobiCore.MOD_ID, "clan_village"),
            new ClanVillageFeature(DefaultFeatureConfig.CODEC));

    public static void register() {
        ShinobiCore.LOGGER.info("[S12-04] Registered clan village feature");
    }
}
'@
Write-File (Join-Path $srcBase "ModFeatures.java") $modFeatures

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
        $out | Select-Object -Last 20 | ForEach-Object { Write-Host ("  " + $_) -ForegroundColor Red }
    }
} finally { Pop-Location }

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Green
Write-Host "  SPRINT 12 PHASE C2 COMPLETE" -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Clan villages:" -ForegroundColor White
Write-Host "  5-8 houses + 2 unique structures per village" -ForegroundColor Yellow
Write-Host "  Uchiha: fire altar | Hyuga: tatami dojo" -ForegroundColor Yellow
Write-Host "  Uzumaki: barrier seal | Senju: forest grove" -ForegroundColor Yellow
Write-Host "  Nara: shadow well | Aburame: hive" -ForegroundColor Yellow
Write-Host "  Inuzuka: kennel | Akimichi: eatery" -ForegroundColor Yellow
Write-Host "  Hatake: memorial monument" -ForegroundColor Yellow
Write-Host ""
Write-Host "Clan determined by position hash (deterministic)." -ForegroundColor Cyan
Write-Host "Use /place feature shinobicore:clan_village to test." -ForegroundColor Cyan
Write-Host ""
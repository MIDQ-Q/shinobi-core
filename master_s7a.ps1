$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcBase = Join-Path $root "src\main\java\com\example\shinobicore"
$structureDir = Join-Path $srcBase "world\structure"
$featureDir = Join-Path $srcBase "world\feature"

function Write-File($path, $content) {
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $content, $utf8)
    Write-Host ("  [OK] " + (Split-Path $path -Leaf)) -ForegroundColor Green
}

Write-Host "=== FIX: StructureWorldAccess compatibility ===" -ForegroundColor Cyan

# 1. StructureBuilder - use WorldAccess instead of ServerWorld
$structureBuilder = @'
package com.example.shinobicore.world.structure;

import net.minecraft.block.BlockState;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.WorldAccess;

public class StructureBuilder {

    public static void fill(WorldAccess world, BlockPos from, BlockPos to, BlockState state) {
        int minX = Math.min(from.getX(), to.getX());
        int maxX = Math.max(from.getX(), to.getX());
        int minY = Math.min(from.getY(), to.getY());
        int maxY = Math.max(from.getY(), to.getY());
        int minZ = Math.min(from.getZ(), to.getZ());
        int maxZ = Math.max(from.getZ(), to.getZ());
        for (int x = minX; x <= maxX; x++) {
            for (int y = minY; y <= maxY; y++) {
                for (int z = minZ; z <= maxZ; z++) {
                    BlockPos pos = new BlockPos(x, y, z);
                    if (world.isAir(pos)) {
                        world.setBlockState(pos, state, 3);
                    }
                }
            }
        }
    }

    public static void hollow(WorldAccess world, BlockPos from, BlockPos to, BlockState state) {
        int minX = Math.min(from.getX(), to.getX());
        int maxX = Math.max(from.getX(), to.getX());
        int minY = Math.min(from.getY(), to.getY());
        int maxY = Math.max(from.getY(), to.getY());
        int minZ = Math.min(from.getZ(), to.getZ());
        int maxZ = Math.max(from.getZ(), to.getZ());
        for (int x = minX; x <= maxX; x++) {
            for (int y = minY; y <= maxY; y++) {
                for (int z = minZ; z <= maxZ; z++) {
                    boolean isEdge = x == minX || x == maxX
                        || y == minY || y == maxY
                        || z == minZ || z == maxZ;
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

    public static void pillar(WorldAccess world, BlockPos base, int height, BlockState state) {
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

# 2. DojoStructure - WorldAccess
$dojoStructure = @'
package com.example.shinobicore.world.structure;

import com.example.shinobicore.block.ModBlocks;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.WorldAccess;

public class DojoStructure {
    public static void generate(WorldAccess world, BlockPos center) {
        int w = 9, d = 7, h = 5;
        BlockPos floor = center.add(-w/2, 0, -d/2);
        BlockPos ceil = center.add(w/2, h, d/2);
        StructureBuilder.fill(world, floor, center.add(w/2, 0, d/2), ModBlocks.TATAMI.getDefaultState());
        StructureBuilder.hollow(world, floor.up(), ceil, ModBlocks.WOOD_PANEL.getDefaultState());
        StructureBuilder.pillar(world, floor.up(), h - 1, ModBlocks.BEAM.getDefaultState());
        StructureBuilder.pillar(world, center.add(w/2, 1, -d/2), h - 1, ModBlocks.BEAM.getDefaultState());
        StructureBuilder.pillar(world, center.add(-w/2, 1, d/2), h - 1, ModBlocks.BEAM.getDefaultState());
        StructureBuilder.pillar(world, center.add(w/2, 1, d/2), h - 1, ModBlocks.BEAM.getDefaultState());
        StructureBuilder.fill(world, ceil, center.add(w/2, h, d/2), ModBlocks.BEAM.getDefaultState());
        world.setBlockState(center.add(-2, 1, 0), ModBlocks.TRAINING_POST.getDefaultState(), 3);
        world.setBlockState(center.add(2, 1, 0), ModBlocks.TRAINING_POST.getDefaultState(), 3);
        world.setBlockState(center.add(-3, 2, -2), ModBlocks.LANTERN.getDefaultState(), 3);
        world.setBlockState(center.add(3, 2, 2), ModBlocks.LANTERN.getDefaultState(), 3);
    }
}
'@
Write-File (Join-Path $structureDir "DojoStructure.java") $dojoStructure

# 3. HouseStructure - WorldAccess
$houseStructure = @'
package com.example.shinobicore.world.structure;

import com.example.shinobicore.block.ModBlocks;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.WorldAccess;

public class HouseStructure {
    public static void generate(WorldAccess world, BlockPos center) {
        int w = 7, d = 5, h = 4;
        BlockPos floor = center.add(-w/2, 0, -d/2);
        BlockPos ceil = center.add(w/2, h, d/2);
        StructureBuilder.fill(world, floor, center.add(w/2, 0, d/2), ModBlocks.WOOD_PANEL.getDefaultState());
        StructureBuilder.hollow(world, floor.up(), ceil, ModBlocks.WOOD_PANEL.getDefaultState());
        world.setBlockState(center.add(0, 1, -d/2), ModBlocks.SHOJI.getDefaultState(), 3);
        world.setBlockState(center.add(0, 1, d/2), ModBlocks.SHOJI.getDefaultState(), 3);
        StructureBuilder.fill(world, ceil, center.add(w/2, h, d/2), ModBlocks.BEAM.getDefaultState());
        world.setBlockState(center.add(-2, 2, -1), ModBlocks.LANTERN.getDefaultState(), 3);
    }
}
'@
Write-File (Join-Path $structureDir "HouseStructure.java") $houseStructure

# 4. ToriiStructure - WorldAccess
$toriiStructure = @'
package com.example.shinobicore.world.structure;

import com.example.shinobicore.block.ModBlocks;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.WorldAccess;

public class ToriiStructure {
    public static void generate(WorldAccess world, BlockPos center) {
        StructureBuilder.pillar(world, center.add(-2, 0, 0), 5, ModBlocks.BEAM.getDefaultState());
        StructureBuilder.pillar(world, center.add(2, 0, 0), 5, ModBlocks.BEAM.getDefaultState());
        for (int x = -3; x <= 3; x++) {
            BlockPos pos = center.add(x, 5, 0);
            if (world.isAir(pos)) {
                world.setBlockState(pos, ModBlocks.BEAM.getDefaultState(), 3);
            }
        }
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

# 5. OnsenStructure - WorldAccess
$onsenStructure = @'
package com.example.shinobicore.world.structure;

import com.example.shinobicore.block.ModBlocks;
import net.minecraft.block.Blocks;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.WorldAccess;

public class OnsenStructure {
    public static void generate(WorldAccess world, BlockPos center) {
        int radius = 3;
        for (int dx = -radius; dx <= radius; dx++) {
            for (int dz = -radius; dz <= radius; dz++) {
                if (dx * dx + dz * dz <= radius * radius) {
                    BlockPos waterPos = center.add(dx, 0, dz);
                    if (world.isAir(waterPos)) {
                        world.setBlockState(waterPos, ModBlocks.ONSEN_WATER.getDefaultState(), 3);
                    }
                    if (dx * dx + dz * dz >= (radius - 1) * (radius - 1)) {
                        BlockPos borderPos = center.add(dx, 1, dz);
                        if (world.isAir(borderPos)) {
                            world.setBlockState(borderPos, Blocks.STONE.getDefaultState(), 3);
                        }
                    }
                }
            }
        }
        world.setBlockState(center.add(radius + 1, 1, 0), ModBlocks.STONE_LANTERN.getDefaultState(), 3);
        world.setBlockState(center.add(-radius - 1, 1, 0), ModBlocks.STONE_LANTERN.getDefaultState(), 3);
    }
}
'@
Write-File (Join-Path $structureDir "OnsenStructure.java") $onsenStructure

# 6. SakuraTreeFeature - StructureWorldAccess
$sakuraTreeFeature = @'
package com.example.shinobicore.world.feature;

import com.example.shinobicore.block.ModBlocks;
import net.minecraft.block.BlockState;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.Heightmap;
import net.minecraft.world.StructureWorldAccess;
import net.minecraft.world.gen.feature.DefaultFeatureConfig;
import net.minecraft.world.gen.feature.Feature;
import net.minecraft.world.gen.feature.util.FeatureContext;
import java.util.Random;

public class SakuraTreeFeature extends Feature<DefaultFeatureConfig> {

    public SakuraTreeFeature(com.mojang.serialization.Codec<DefaultFeatureConfig> codec) {
        super(codec);
    }

    @Override
    public boolean generate(FeatureContext<DefaultFeatureConfig> context) {
        StructureWorldAccess world = context.getWorld();
        BlockPos origin = context.getOrigin();
        Random random = context.getRandom();

        int topY = world.getTopY(Heightmap.Type.WORLD_SURFACE_WG, origin.getX(), origin.getZ());
        BlockPos ground = new BlockPos(origin.getX(), topY, origin.getZ());
        if (!world.isAir(ground.up())) return false;

        generateTree(world, ground, random);
        return true;
    }

    public static void generateTree(StructureWorldAccess world, BlockPos base, Random random) {
        int trunkHeight = 4 + random.nextInt(3);

        for (int y = 1; y <= trunkHeight; y++) {
            BlockPos pos = base.up(y);
            if (world.isAir(pos)) {
                world.setBlockState(pos, ModBlocks.SAKURA_LOG.getDefaultState(), 3);
            }
        }

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

# 7. NinjaVillageFeature - StructureWorldAccess
$ninjaVillageFeature = @'
package com.example.shinobicore.world.feature;

import com.example.shinobicore.world.structure.DojoStructure;
import com.example.shinobicore.world.structure.HouseStructure;
import com.example.shinobicore.world.structure.OnsenStructure;
import com.example.shinobicore.world.structure.ToriiStructure;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.Heightmap;
import net.minecraft.world.StructureWorldAccess;
import net.minecraft.world.gen.feature.DefaultFeatureConfig;
import net.minecraft.world.gen.feature.Feature;
import net.minecraft.world.gen.feature.util.FeatureContext;
import java.util.Random;

public class NinjaVillageFeature extends Feature<DefaultFeatureConfig> {

    public NinjaVillageFeature(com.mojang.serialization.Codec<DefaultFeatureConfig> codec) {
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

        ToriiStructure.generate(world, ground.add(0, 0, 8));
        DojoStructure.generate(world, ground);
        HouseStructure.generate(world, ground.add(-10, 0, -5));
        HouseStructure.generate(world, ground.add(10, 0, -5));
        HouseStructure.generate(world, ground.add(-8, 0, 6));
        OnsenStructure.generate(world, ground.add(12, 0, 6));

        for (int i = 0; i < 6; i++) {
            int tx = random.nextInt(30) - 15;
            int tz = random.nextInt(30) - 15;
            int treeTopY = world.getTopY(Heightmap.Type.WORLD_SURFACE_WG,
                ground.getX() + tx, ground.getZ() + tz);
            BlockPos treePos = new BlockPos(ground.getX() + tx, treeTopY, ground.getZ() + tz);
            if (world.isAir(treePos.up())) {
                SakuraTreeFeature.generateTree(world, treePos, random);
            }
        }

        return true;
    }
}
'@
Write-File (Join-Path $featureDir "NinjaVillageFeature.java") $ninjaVillageFeature

Write-Host ""
Write-Host "=== BUILD ===" -ForegroundColor Cyan
Push-Location $root
try {
    $out = & ".\gradlew.bat" build 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [PASS] Build successful!" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Build failed" -ForegroundColor Red
        $out | Select-Object -Last 15 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    }
} finally { Pop-Location }
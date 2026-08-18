package com.example.shinobicore.world.feature;

import com.example.shinobicore.world.structure.ClanVillageGenerator;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.Heightmap;
import net.minecraft.world.StructureWorldAccess;
import net.minecraft.world.gen.feature.DefaultFeatureConfig;
import net.minecraft.world.gen.feature.Feature;
import net.minecraft.world.gen.feature.util.FeatureContext;
import net.minecraft.util.math.random.Random;

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
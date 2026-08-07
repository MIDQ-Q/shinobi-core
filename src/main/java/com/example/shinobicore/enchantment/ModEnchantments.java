package com.example.shinobicore.enchantment;

import com.example.shinobicore.ShinobiCore;
import net.minecraft.enchantment.Enchantment;
import net.minecraft.registry.Registries;
import net.minecraft.registry.Registry;
import net.minecraft.util.Identifier;

public class ModEnchantments {
    public static final Enchantment CHAKRA_WATER_WALK = Registry.register(
        Registries.ENCHANTMENT,
        new Identifier(ShinobiCore.MOD_ID, "chakra_water_walk"),
        new ChakraWaterWalkEnchantment()
    );

    public static void register() {
        ShinobiCore.LOGGER.info("Registered enchantments");
    }
}
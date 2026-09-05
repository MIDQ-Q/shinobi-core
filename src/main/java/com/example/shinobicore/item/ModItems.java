package com.example.shinobicore.item;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.compat.TrinketsCompat;
import net.minecraft.item.Item;
import net.minecraft.registry.Registries;
import net.minecraft.registry.Registry;
import net.minecraft.util.Identifier;

public class ModItems {
    public static final Item KATANA = Registry.register(Registries.ITEM,
        new Identifier(ShinobiCore.MOD_ID, "katana"), new KatanaItem());
    public static final Item SHURIKEN = Registry.register(Registries.ITEM,
        new Identifier(ShinobiCore.MOD_ID, "shuriken"),
        new ThrowingWeaponItem(new Item.Settings().maxCount(16), 3f, 3.0f, 8));
    public static final Item KUNAI = Registry.register(Registries.ITEM,
        new Identifier(ShinobiCore.MOD_ID, "kunai"),
        new ThrowingWeaponItem(new Item.Settings().maxCount(16), 5f, 2.2f, 12));

    /** Registered only when Trinkets/Artifacts is installed. */
    public static Item SHINOBI_CHARM = null;

    public static void register() {
        if (TrinketsCompat.isLoaded()) {
            SHINOBI_CHARM = new com.example.shinobicore.item.artifacts.ShinobiCharmItem();
            Registry.register(Registries.ITEM,
                new Identifier(ShinobiCore.MOD_ID, "shinobi_charm"), SHINOBI_CHARM);
            ShinobiCore.LOGGER.info("Trinkets/Artifacts detected: shinobi_charm registered");
        } else {
            ShinobiCore.LOGGER.info("Trinkets/Artifacts not present: charm skipped");
        }
        ShinobiCore.LOGGER.info("Registered katana/shuriken/kunai items");
    }
}
package com.example.shinobicore.item;
import com.example.shinobicore.ShinobiCore;
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
    public static void register() {
        ShinobiCore.LOGGER.info("Registered katana/shuriken/kunai items");
    }
}
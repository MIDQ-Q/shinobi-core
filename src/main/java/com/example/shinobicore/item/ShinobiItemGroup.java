package com.example.shinobicore.item;

import com.example.shinobicore.ShinobiCore;
import net.fabricmc.fabric.api.itemgroup.v1.FabricItemGroup;
import net.fabricmc.fabric.api.itemgroup.v1.ItemGroupEvents;
import net.minecraft.item.ItemGroup;
import net.minecraft.item.ItemStack;
import net.minecraft.registry.Registries;
import net.minecraft.registry.Registry;
import net.minecraft.registry.RegistryKey;
import net.minecraft.registry.RegistryKeys;
import net.minecraft.text.Text;
import net.minecraft.util.Identifier;

/**
 * Part 3 (WS-3): креативная вкладка мода.
 *
 * До этого ItemGroup не упоминался в проекте ни разу, поэтому все пять
 * зарегистрированных предметов (katana, shuriken, kunai, scroll,
 * explosive_tag) были доступны только через /give и не появлялись
 * в креативном инвентаре.
 *
 * Используется fabric-item-group-api-v1, входящий в состав fabric-api
 * (в build.gradle подключён полный fabric-api:0.92.3+1.20.1).
 */
public final class ShinobiItemGroup {

    public static final RegistryKey<ItemGroup> KEY =
            RegistryKey.of(RegistryKeys.ITEM_GROUP, new Identifier(ShinobiCore.MOD_ID, "main"));

    public static final ItemGroup GROUP = FabricItemGroup.builder()
            .icon(() -> new ItemStack(ModItems.KATANA))
            .displayName(Text.translatable("itemGroup.shinobicore.main"))
            .build();

    private ShinobiItemGroup() {}

    public static void register() {
        Registry.register(Registries.ITEM_GROUP, KEY, GROUP);
        ItemGroupEvents.modifyEntriesEvent(KEY).register(entries -> {
            entries.add(ModItems.KATANA);
            entries.add(ModItems.SHURIKEN);
            entries.add(ModItems.KUNAI);
            entries.add(ModItems.SCROLL);
            entries.add(ModItems.EXPLOSIVE_TAG);
        });
        ShinobiCore.LOGGER.info("Registered ShinobiCore creative tab");
    }
}
// P3_ITEM_GROUP_DONE
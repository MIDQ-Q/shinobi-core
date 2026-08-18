package com.example.shinobicore.entity.enemy;

import com.example.shinobicore.item.ModItems;
import net.minecraft.entity.LivingEntity;
import net.minecraft.item.ItemStack;
import net.minecraft.item.Items;
import net.minecraft.util.math.random.Random;

/**
 * S9-09: Loot table for enemy drops.
 * Drops based on rank. Configurable via difficulty multiplier.
 */
public class EnemyLootTable {

    /**
     * Drop loot when enemy dies.
     * Called from NinjaEnemyEntity.onDeath() or dropLoot().
     */
    public static void dropLoot(LivingEntity entity, NinjaRank rank, float lootQualityMultiplier) {
        Random rand = entity.getWorld().getRandom();
        float dropChance = 0.5f * lootQualityMultiplier;

        switch (rank) {
            case GENIN -> {
                if (rand.nextFloat() < dropChance) {
                    entity.dropStack(new ItemStack(ModItems.KUNAI, 1 + rand.nextInt(3)));
                }
            }
            case CHUNIN -> {
                if (rand.nextFloat() < dropChance) {
                    entity.dropStack(new ItemStack(ModItems.SHURIKEN, 2 + rand.nextInt(4)));
                }
                if (rand.nextFloat() < dropChance * 0.5f) {
                    entity.dropStack(new ItemStack(ModItems.KUNAI, 1 + rand.nextInt(2)));
                }
            }
            case JONIN -> {
                if (rand.nextFloat() < dropChance) {
                    entity.dropStack(new ItemStack(ModItems.SHURIKEN, 3 + rand.nextInt(5)));
                }
                if (rand.nextFloat() < dropChance * 0.3f) {
                    entity.dropStack(new ItemStack(Items.PAPER, 1)); // Scroll material
                }
            }
            case ANBU -> {
                if (rand.nextFloat() < dropChance) {
                    entity.dropStack(new ItemStack(ModItems.SHURIKEN, 4 + rand.nextInt(6)));
                }
                if (rand.nextFloat() < dropChance * 0.5f) {
                    entity.dropStack(new ItemStack(Items.PAPER, 1 + rand.nextInt(2)));
                }
            }
            case NUKE_NIN -> {
                if (rand.nextFloat() < dropChance) {
                    entity.dropStack(new ItemStack(ModItems.SHURIKEN, 5 + rand.nextInt(8)));
                }
                if (rand.nextFloat() < dropChance * 0.7f) {
                    entity.dropStack(new ItemStack(Items.PAPER, 2 + rand.nextInt(3)));
                }
                if (rand.nextFloat() < dropChance * 0.2f) {
                    entity.dropStack(new ItemStack(ModItems.KATANA, 1));
                }
            }
        }
    }
}
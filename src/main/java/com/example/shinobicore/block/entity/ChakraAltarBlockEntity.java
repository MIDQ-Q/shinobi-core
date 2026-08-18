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
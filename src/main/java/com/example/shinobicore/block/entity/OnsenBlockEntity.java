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
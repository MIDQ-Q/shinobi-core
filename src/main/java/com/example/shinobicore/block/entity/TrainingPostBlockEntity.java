package com.example.shinobicore.block.entity;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.stat.StatType;
import net.minecraft.block.BlockState;
import net.minecraft.block.entity.BlockEntity;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import net.minecraft.util.math.BlockPos;

/**
 * S7-03: Training post BlockEntity.
 * Universal XP: hand = taijutsu, katana = kenjutsu.
 * Daily cap + diminishing returns.
 */
public class TrainingPostBlockEntity extends BlockEntity {

    private int dailyUseCount = 0;
    private long lastResetDay = 0;
    private static final int DAILY_CAP = 100;
    private static final float BASE_XP = 5.0f;

    public TrainingPostBlockEntity(BlockPos pos, BlockState state) {
        super(ModBlockEntities.TRAINING_POST, pos, state);
    }

    public void onPlayerInteract(PlayerEntity player) {
        if (!(player instanceof ServerPlayerEntity sp)) return;
        if (!(world instanceof net.minecraft.server.world.ServerWorld sw)) return;

        // Reset daily counter
        long currentDay = sw.getTime() / 24000L;
        if (currentDay != lastResetDay) {
            dailyUseCount = 0;
            lastResetDay = currentDay;
        }

        if (dailyUseCount >= DAILY_CAP) {
            player.sendMessage(Text.literal("\u00a77The training post is worn out for today."), false);
            return;
        }

        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();

        // Determine stat based on held item
        boolean hasKatana = player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem;
        StatType stat = hasKatana ? StatType.TAIJUTSU : StatType.TAIJUTSU;

        // Diminishing returns
        float diminish = Math.max(0.1f, 1.0f - dailyUseCount * 0.008f);
        float xp = BASE_XP * diminish;

        NinjaFormula.grantStatXp(data, stat, (int) xp);
        dailyUseCount++;

        // Particles
        sw.spawnParticles(net.minecraft.particle.ParticleTypes.POOF,
            pos.getX() + 0.5, pos.getY() + 1.2, pos.getZ() + 0.5,
            3, 0.2, 0.3, 0.2, 0.03);

        // Sound
        sw.playSound(null, pos, net.minecraft.sound.SoundEvents.BLOCK_WOOD_HIT,
            net.minecraft.sound.SoundCategory.BLOCKS, 0.8f, 0.9f);

        ShinobiCore.sendStatsSync(sp);
    }

    @Override
    protected void writeNbt(NbtCompound nbt) {
        nbt.putInt("DailyUseCount", dailyUseCount);
        nbt.putLong("LastResetDay", lastResetDay);
    }

    @Override
    public void readNbt(NbtCompound nbt) {
        dailyUseCount = nbt.getInt("DailyUseCount");
        lastResetDay = nbt.getLong("LastResetDay");
    }
}
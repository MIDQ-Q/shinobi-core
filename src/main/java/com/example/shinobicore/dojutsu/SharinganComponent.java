package com.example.shinobicore.dojutsu;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.network.ModPackets;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.entity.LivingEntity;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import java.util.HashSet;
import java.util.Set;

/**
 * S6-07/S6-08: Server-side Sharingan component.
 * Evolution: combined (usage progress + stress events).
 * Stages: NONE -> ONE_TOMOE -> TWO_TOMOE -> THREE_TOMOE -> MANGEKYO
 *
 * Usage sources: fire/genjutsu casts, successful parries, combat hits.
 * Stress sources: HP < 15%, near-lethal damage, fighting stronger enemy,
 *                 casting at < 10% chakra.
 *
 * Thresholds:
 *   1 tomoe: 50 usage + 1 stress
 *   2 tomoe: 150 usage + 2 stress
 *   3 tomoe: 300 usage + 3 stress
 *   Mangekyo: 500 usage + 5 stress + quest (stub)
 */
public class SharinganComponent {

    public enum Stage {
        NONE(0, 0, 0),
        ONE_TOMOE(1, 50, 1),
        TWO_TOMOE(2, 150, 2),
        THREE_TOMOE(3, 300, 3),
        MANGEKYO(4, 500, 5);

        public final int level;
        public final int usageRequired;
        public final int stressRequired;

        Stage(int level, int usageReq, int stressReq) {
            this.level = level;
            this.usageRequired = usageReq;
            this.stressRequired = stressReq;
        }
    }

    private Stage stage = Stage.NONE;
    private int usageProgress = 0;
    private int stressCount = 0;
    private boolean active = false;
    private boolean hasMangekyoQuest = false;

    // 3 tomoe: auto-parry cooldown
    private long lastAutoParryMs = 0;
    private static final long AUTO_PARRY_COOLDOWN_MS = 2000;
    private static final float AUTO_PARRY_CHANCE = 0.35f;

    // Chakra drain: 5% max per 10 seconds while active
    private long lastDrainTimeMs = 0;
    private static final long DRAIN_INTERVAL_MS = 10000;
    private static final float DRAIN_PERCENT = 0.05f;

    // Track stress sources to avoid counting same event multiple times
    private final Set<String> recentStressSources = new HashSet<>();
    private long lastStressResetMs = 0;

    public Stage getStage() { return stage; }
    public boolean isActive() { return active; }
    public int getUsageProgress() { return usageProgress; }
    public int getStressCount() { return stressCount; }
    public boolean hasMangekyoQuest() { return hasMangekyoQuest; }
    public void setMangekyoQuestComplete(boolean v) { this.hasMangekyoQuest = v; }

    /**
     * Toggle sharingan activation. Requires at least 1 tomoe.
     */
    public boolean toggle(ServerPlayerEntity player) {
        if (stage == Stage.NONE) {
            player.sendMessage(Text.literal("\u00a7cSharingan not awakened yet."), false);
            return false;
        }
        active = !active;
        if (active) {
            lastDrainTimeMs = System.currentTimeMillis();
            player.sendMessage(Text.literal("\u00a7cSharingan activated."), true);
        } else {
            player.sendMessage(Text.literal("\u00a77Sharingan deactivated."), true);
        }
        syncToClient(player);
        return true;
    }

    /**
     * Called every server tick from NinjaTickHandler.
     */
    public void tick(ServerPlayerEntity player) {
        if (!active || stage == Stage.NONE) return;

        // Chakra drain: 5% max per 10 seconds
        long now = System.currentTimeMillis();
        if (now - lastDrainTimeMs >= DRAIN_INTERVAL_MS) {
            lastDrainTimeMs = now;
            NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
            float maxChakra = com.example.shinobicore.stat.NinjaFormula.maxChakra(data);
            float drain = maxChakra * DRAIN_PERCENT;
            if (data.getCurrentChakra() < drain) {
                active = false;
                syncToClient(player);
                player.sendMessage(Text.literal("\u00a77Sharingan deactivated - no chakra."), true);
                return;
            }
            data.setCurrentChakra(data.getCurrentChakra() - drain);
            ShinobiCore.sendChakraSync(player);
        }

        // Stress check: HP < 15%
        if (player.getHealth() < player.getMaxHealth() * 0.15f) {
            addStress("low_hp");
        }

        // Stress check: chakra < 10%
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        float maxChakra = com.example.shinobicore.stat.NinjaFormula.maxChakra(data);
        if (data.getCurrentChakra() < maxChakra * 0.10f) {
            addStress("low_chakra");
        }
    }

    /**
     * S6-07: Add usage progress. Called when casting fire/genjutsu,
     * successful parry, or landing a hit.
     */
    public void addUsage(int amount) {
        usageProgress += amount;
        checkEvolution(null);
    }

    /**
     * S6-08: Add stress event. Deduplicated by source within 30s window.
     */
    public void addStress(String source) {
        long now = System.currentTimeMillis();
        // Reset stress sources every 30 seconds
        if (now - lastStressResetMs > 30000) {
            recentStressSources.clear();
            lastStressResetMs = now;
        }
        if (recentStressSources.contains(source)) return;
        recentStressSources.add(source);
        stressCount++;
        ShinobiCore.LOGGER.debug("[SHARINGAN] Stress event: {} (total: {})", source, stressCount);
        checkEvolution(null);
    }

    /**
     * Check if evolution threshold is met.
     */
    private void checkEvolution(ServerPlayerEntity player) {
        Stage next = getNextStage();
        if (next == null) return;
        if (usageProgress >= next.usageRequired && stressCount >= next.stressRequired) {
            if (next == Stage.MANGEKYO && !hasMangekyoQuest) return;
            stage = next;
            ShinobiCore.LOGGER.info("[SHARINGAN] Evolved to {}", stage);
            if (player != null) {
                player.sendMessage(Text.literal("\u00a7cSharingan evolved: " + stage.name()), false);
                syncToClient(player);
            }
        }
    }

    private Stage getNextStage() {
        switch (stage) {
            case NONE: return Stage.ONE_TOMOE;
            case ONE_TOMOE: return Stage.TWO_TOMOE;
            case TWO_TOMOE: return Stage.THREE_TOMOE;
            case THREE_TOMOE: return Stage.MANGEKYO;
            default: return null;
        }
    }

    /**
     * S6-08: 3 tomoe auto-parry. 35% chance, 2s cooldown.
     * Returns true if attack should be negated.
     */
    public boolean checkAutoParry(ServerPlayerEntity player, float amount) {
        if (stage.level < 3 || !active) return false;
        long now = System.currentTimeMillis();
        if (now - lastAutoParryMs < AUTO_PARRY_COOLDOWN_MS) return false;
        if (player.getWorld().getRandom().nextFloat() < AUTO_PARRY_CHANCE) {
            lastAutoParryMs = now;
            ShinobiCore.LOGGER.debug("[SHARINGAN] Auto-parry! Negated {} damage", amount);
            return true;
        }
        return false;
    }

    /**
     * S6-07: Check if player can copy a technique (2 tomoe).
     * Only T1-T3 techniques, requires unlocked element.
     */
    public boolean canCopyTechnique(int tier) {
        if (stage.level < 2) return false;
        return tier <= 3;
    }

    /**
     * Sync sharingan state to client.
     */
    public void syncToClient(ServerPlayerEntity player) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(stage.level);
        buf.writeBoolean(active);
        buf.writeInt(usageProgress);
        buf.writeInt(stressCount);
        ServerPlayNetworking.send(player, ModPackets.SHARINGAN_SYNC_ID, buf);
    }

    /**
     * Write to NBT for persistence.
     */
    public void writeNbt(net.minecraft.nbt.NbtCompound nbt) {
        nbt.putInt("SharinganStage", stage.level);
        nbt.putInt("SharinganUsage", usageProgress);
        nbt.putInt("SharinganStress", stressCount);
        nbt.putBoolean("SharinganActive", active);
        nbt.putBoolean("MangekyoQuest", hasMangekyoQuest);
    }

    /**
     * Read from NBT.
     */
    public void readNbt(net.minecraft.nbt.NbtCompound nbt) {
        int lvl = nbt.getInt("SharinganStage");
        stage = Stage.NONE;
        for (Stage s : Stage.values()) {
            if (s.level == lvl) { stage = s; break; }
        }
        usageProgress = nbt.getInt("SharinganUsage");
        stressCount = nbt.getInt("SharinganStress");
        active = nbt.getBoolean("SharinganActive");
        hasMangekyoQuest = nbt.getBoolean("MangekyoQuest");
    }
}
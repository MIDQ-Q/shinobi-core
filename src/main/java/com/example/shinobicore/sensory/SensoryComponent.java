package com.example.shinobicore.sensory;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.network.ModPackets;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.mob.MobEntity;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;
import java.util.ArrayList;
import java.util.List;

/**
 * S6-01: Server-side sensory component.
 * Manages sensory tier, scan cooldown, and aura mode.
 * Ticks every 5 server ticks for performance.
 */
public class SensoryComponent {

    private SensoryTier currentTier = SensoryTier.NONE;
    private long lastScanTimeMs = 0;
    private boolean auraActive = false;
    private int tickCounter = 0;

    public SensoryTier getTier() { return currentTier; }
    public void setTier(SensoryTier tier) { this.currentTier = tier; }
    public boolean isAuraActive() { return auraActive; }
    public void setAuraActive(boolean v) { this.auraActive = v; }

    public boolean canScan() {
        if (currentTier.getLevel() < 3) return false;
        long elapsed = System.currentTimeMillis() - lastScanTimeMs;
        return elapsed >= (long)(currentTier.getScanCooldownSeconds() * 1000);
    }

    public float getScanCooldownRemaining() {
        if (currentTier.getLevel() < 3) return 0;
        long elapsed = System.currentTimeMillis() - lastScanTimeMs;
        long total = (long)(currentTier.getScanCooldownSeconds() * 1000);
        long remaining = total - elapsed;
        return remaining > 0 ? remaining / 1000f : 0f;
    }

    /**
     * Called every server tick from NinjaTickHandler.
     * Only processes every 5 ticks for performance.
     */
    public void tick(ServerPlayerEntity player) {
        tickCounter++;
        if (tickCounter % 5 != 0) return;
        if (currentTier == SensoryTier.NONE) return;

        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        if (!data.isSensoryEnabled()) return;
        if (!(player.getWorld() instanceof ServerWorld world)) return;

        // T1: Danger sense
        if (currentTier.isAtLeast(SensoryTier.T1_DANGER)) {
            tickDangerSense(player, world, data);
        }

        // T2: Direction of nearest threat
        if (currentTier.isAtLeast(SensoryTier.T2_DIRECTION)) {
            tickDirectionSense(player, world);
        }

        // T4: Aura (GLOWING effect on entities)
        if (currentTier.isAtLeast(SensoryTier.T4_AURA) && auraActive) {
            tickAura(player, world);
        }
    }

    private void tickDangerSense(ServerPlayerEntity player, ServerWorld world, NinjaPlayerData data) {
        boolean danger = false;
        int radius = currentTier.getRadius();
        for (LivingEntity mob : world.getEntitiesByClass(LivingEntity.class,
                player.getBoundingBox().expand(radius), e -> e instanceof MobEntity)) {
            if (((MobEntity) mob).getTarget() == player) {
                danger = true;
                break;
            }
        }
        if (danger != data.getLastDangerState()) {
            data.setLastDangerState(danger);
            PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
            buf.writeBoolean(danger);
            ServerPlayNetworking.send(player, ModPackets.DANGER_SYNC_ID, buf);
        }
    }

    private void tickDirectionSense(ServerPlayerEntity player, ServerWorld world) {
        int radius = currentTier.getRadius();
        LivingEntity nearest = null;
        double nearestDist = Double.MAX_VALUE;

        for (LivingEntity e : world.getEntitiesByClass(LivingEntity.class,
                player.getBoundingBox().expand(radius),
                e -> e instanceof MobEntity && ((MobEntity) e).getTarget() == player)) {
            double d = e.getPos().squaredDistanceTo(player.getPos());
            if (d < nearestDist) {
                nearestDist = d;
                nearest = e;
            }
        }

        if (nearest != null) {
            Vec3d toThreat = nearest.getPos().subtract(player.getPos()).normalize();
            PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
            buf.writeBoolean(true);
            buf.writeFloat((float) toThreat.x);
            buf.writeFloat((float) toThreat.z);
            ServerPlayNetworking.send(player, ModPackets.SENSORY_DIRECTION_ID, buf);
        }
    }

    private void tickAura(ServerPlayerEntity player, ServerWorld world) {
        int radius = currentTier.getRadius();
        for (LivingEntity mob : world.getEntitiesByClass(LivingEntity.class,
                player.getBoundingBox().expand(radius),
                e -> !(e instanceof PlayerEntity))) {
            mob.addStatusEffect(new net.minecraft.entity.effect.StatusEffectInstance(
                net.minecraft.entity.effect.StatusEffects.GLOWING, 40, 0, false, false));
        }
    }

    /**
     * S6-04: Activate scan pulse. Returns entity positions to client.
     */
    public void activateScan(ServerPlayerEntity player) {
        if (!canScan()) return;
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();

        // Chakra cost
        float cost = currentTier.getChakraCostPerUse();
        if (data.getCurrentChakra() < cost) {
            player.sendMessage(net.minecraft.text.Text.literal("\u00a7cNot enough chakra for scan!"), true);
            return;
        }
        data.setCurrentChakra(data.getCurrentChakra() - cost);
        ShinobiCore.sendChakraSync(player);
        lastScanTimeMs = System.currentTimeMillis();

        if (!(player.getWorld() instanceof ServerWorld world)) return;
        int radius = currentTier.getRadius();

        // Collect living entities in radius
        List<LivingEntity> entities = new ArrayList<>();
        for (LivingEntity e : world.getEntitiesByClass(LivingEntity.class,
                player.getBoundingBox().expand(radius),
                e -> e.isAlive() && e != player)) {
            entities.add(e);
        }

        // Send scan results to client
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(entities.size());
        for (LivingEntity e : entities) {
            buf.writeInt(e.getId());
            buf.writeDouble(e.getX());
            buf.writeDouble(e.getY());
            buf.writeDouble(e.getZ());
            buf.writeFloat(e.getHeight());
            buf.writeBoolean(e instanceof MobEntity);
        }
        ServerPlayNetworking.send(player, ModPackets.SENSORY_SCAN_ID, buf);

        ShinobiCore.LOGGER.debug("[SENSORY] Scan: {} entities in radius {}", entities.size(), radius);
    }

    /**
     * S6-06: Read chakra of nearby entities.
     */
    public void readChakra(ServerPlayerEntity player, int targetEntityId) {
        if (currentTier.getLevel() < 5) return;
        if (!(player.getWorld() instanceof ServerWorld world)) return;

        var entity = world.getEntityById(targetEntityId);
        if (!(entity instanceof LivingEntity living)) return;

        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(targetEntityId);
        buf.writeString(living.getName().getString());

        // Determine chakra level approximation
        if (living instanceof ServerPlayerEntity targetPlayer) {
            NinjaPlayerData targetData = ((NinjaDataHolder) targetPlayer).shinobicore_getData();
            float chakraRatio = targetData.getCurrentChakra() /
                Math.max(1f, com.example.shinobicore.stat.NinjaFormula.maxChakra(targetData));
            buf.writeFloat(chakraRatio);
            buf.writeBoolean(targetData.isChakraMode());
            buf.writeInt(targetData.getReserveLevel());
            buf.writeBoolean(targetData.getActiveDojutsu() != null);
            buf.writeString(targetData.getActiveDojutsu() != null ? targetData.getActiveDojutsu() : "");
        } else if (living instanceof MobEntity) {
            // Mobs have "wild chakra" - approximate by health
            float healthRatio = living.getHealth() / living.getMaxHealth();
            buf.writeFloat(healthRatio * 0.5f); // Mobs have less chakra
            buf.writeBoolean(false);
            buf.writeInt(0);
            buf.writeBoolean(false);
            buf.writeString("");
        } else {
            buf.writeFloat(0f);
            buf.writeBoolean(false);
            buf.writeInt(0);
            buf.writeBoolean(false);
            buf.writeString("");
        }

        ServerPlayNetworking.send(player, ModPackets.SENSORY_READING_ID, buf);
    }

    /**
     * Determine tier from unlocked tree nodes.
     */
    public static SensoryTier determineTier(NinjaPlayerData data) {
        var nodes = data.getUnlockedNodes();
        if (nodes.contains("sen_reading")) return SensoryTier.T5_READING;
        if (nodes.contains("sen_glow")) return SensoryTier.T4_AURA;
        if (nodes.contains("sen_scan")) return SensoryTier.T3_SCAN;
        if (nodes.contains("sen_direction")) return SensoryTier.T2_DIRECTION;
        if (nodes.contains("sen_danger")) return SensoryTier.T1_DANGER;
        return SensoryTier.NONE;
    }
}
package com.example.shinobicore.modules.jutsu.view;

import com.example.shinobicore.modules.jutsu.cast.CastPhase;
import com.example.shinobicore.modules.jutsu.cooldown.JutsuCooldownService;
import com.example.shinobicore.modules.jutsu.slot.JutsuLoadout;
import com.example.shinobicore.modules.jutsu.slot.JutsuSlotService;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import java.util.UUID;

public final class JutsuVisualViewImpl implements JutsuVisualView {
    private final PlayerEntity player;
    private final UUID uuid;

    public JutsuVisualViewImpl(PlayerEntity player) {
        this.player = player;
        this.uuid = player.getUuid();
    }

    private ServerPlayerEntity getServerPlayer() {
        if (player instanceof ServerPlayerEntity sp) return sp;
        return null;
    }

    @Override public boolean isCasting() { return false; }
    @Override public float getCastProgress() { return 0.0f; }
    @Override public CastPhase getCurrentPhase() { return CastPhase.IDLE; }
    @Override public String getCurrentJutsuId() { return ""; }
    @Override public boolean isCharging() { return getCurrentPhase() == CastPhase.CHARGE; }
    @Override public boolean isQueued() { return false; }
    @Override public String getQueuedJutsuId() { return null; }

    @Override
    public String getSlotJutsuId(int slot) {
        ServerPlayerEntity sp = getServerPlayer();
        if (sp == null) return null;
        return JutsuSlotService.getLoadout(sp).getSlot(slot);
    }

    @Override
    public int getSelectedSlot() {
        ServerPlayerEntity sp = getServerPlayer();
        if (sp == null) return 0;
        return JutsuSlotService.getLoadout(sp).selectedSlot();
    }

    @Override
    public int getSlotCount() { return 3; }

    @Override
    public int getCooldownTicks(String jutsuId) {
        return JutsuCooldownService.getRemainingTicks(uuid, jutsuId);
    }

    @Override
    public int getMaxCooldownTicks(String jutsuId) { return 0; }

    @Override
    public float getCooldownProgress(String jutsuId) {
        int max = getMaxCooldownTicks(jutsuId);
        if (max <= 0) return 0.0f;
        return 1.0f - ((float) getCooldownTicks(jutsuId) / max);
    }
}
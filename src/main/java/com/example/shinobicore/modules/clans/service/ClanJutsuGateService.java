package com.example.shinobicore.modules.clans.service;
import com.example.shinobicore.modules.clans.component.ClanComponentKey;
import net.minecraft.entity.player.PlayerEntity;
import java.util.Optional;
public final class ClanJutsuGateService {
    public static void init() {}
    public static boolean isJutsuAccessible(PlayerEntity player, String jutsuId, String requiredClan) {
        if (requiredClan == null || requiredClan.isEmpty()) return true;
        Optional<com.example.shinobicore.modules.clans.component.ClanComponent> compOpt = ClanComponentKey.get(player);
        if (compOpt.isEmpty()) return false;
        return requiredClan.equals(compOpt.get().getClanId());
    }
}
package com.example.shinobicore.event.tick;

import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.stat.StatType;
import com.example.shinobicore.config.ModConfig;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;

public final class MeditationService {
    private MeditationService() {}

    public static void tick(MinecraftServer server, ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        if (!data.isMeditating()) return;
        if (!canMeditate(player, data)) {
            data.setMeditating(false);
            return;
        }
        NinjaFormula.grantReserveXp(data, NinjaFormula.meditationReserveXpPerSecond());
        NinjaFormula.grantStatXp(data, StatType.CONTROL, NinjaFormula.meditationControlXpPerSecond());
        int baseAmp = (int) ModConfig.instance.meditation.slownessBase;
        float red = data.getStatLevel(StatType.CONTROL) / 100f * ModConfig.instance.meditation.slownessControlReduction;
        int amp = Math.max(0, (int) (baseAmp - red));
        if (amp > 0) {
            player.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, 40, amp, false, false, true));
        }
    }

    private static boolean canMeditate(ServerPlayerEntity player, NinjaPlayerData data) {
        if (data.isExhausted()) return false;
        if (!player.isOnGround()) return false;
        if (player.getHungerManager().getFoodLevel() < 6) return false;
        double dx = player.getX() - player.prevX;
        double dz = player.getZ() - player.prevZ;
        if (dx * dx + dz * dz > 0.01) return false;
        return true;
    }
}
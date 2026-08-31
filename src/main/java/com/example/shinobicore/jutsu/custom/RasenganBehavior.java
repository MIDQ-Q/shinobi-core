package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.stat.StatType;
import com.google.gson.JsonObject;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;

public class RasenganBehavior implements JutsuBehavior {

    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (data.isRasenganCharging() || data.isRasenganReady()) {
            player.sendMessage(Text.literal("§7Rasengan is already active!"), false);
            return;
        }

        int controlLevel = data.getStatLevel(StatType.CONTROL);

        // === ИСПРАВЛЕНО: быстрая зарядка ===
        // baseChargeTicks=120 (6 сек), minChargeTicks=40 (2 сек)
        // Формула: chargeTicks = max(min, base - control * 0.8)
        // control=0 → 120 тиков (6 сек), за 3 сек = 50%
        // control=50 → 80 тиков (4 сек)
        // control=100 → max(40, 40) = 40 тиков (2 сек)
        int baseChargeTicks = params.has("baseChargeTicks") ? params.get("baseChargeTicks").getAsInt() : 120;
        int minChargeTicks = params.has("minChargeTicks") ? params.get("minChargeTicks").getAsInt() : 40;
        int chargeTicks = Math.max(minChargeTicks, baseChargeTicks - (int)(controlLevel * 0.8));

        data.setRasenganCharging(true);
        data.setRasenganChargeTicks(0);
        data.setRasenganChargeTarget(chargeTicks);
        data.setRasenganReady(false);

        float chargeSeconds = chargeTicks / 20.0f;
        player.sendMessage(Text.literal("§bRasengan charging... " + String.format("%.1f", chargeSeconds) + "s"), false);

        JutsuLogger.logBehavior("rasengan", String.format(
                "CHARGE START: player=%s, control=%d, chargeTicks=%d (%.1fs)",
                player.getName().getString(), controlLevel, chargeTicks, chargeSeconds));
    }
}
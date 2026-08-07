package com.example.shinobicore.jutsu;

import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;

public class WallBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data, JsonObject params, float damage) {
        player.sendMessage(Text.literal("§7[Earth Wall - placeholder]"), false);
    }
}
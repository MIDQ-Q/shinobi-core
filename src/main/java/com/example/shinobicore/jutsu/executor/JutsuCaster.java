package com.example.shinobicore.jutsu.executor;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.jutsu.core.JutsuDefinition;
import com.example.shinobicore.jutsu.enums.ResourceType;
import com.example.shinobicore.jutsu.registry.JutsuRegistry;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;

public class JutsuCaster {

    public static boolean cast(ServerPlayerEntity player, JutsuDefinition jutsu) {
        if (jutsu == null) return false;
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();

        // Requirements (skipped for ops in dev)
        if (!player.hasPermissionLevel(2) && !NinjaFormula.checkRequirements(jutsu, data)) {
            player.sendMessage(Text.literal("\u00a7cRequirements not met for " + jutsu.getName()), false);
            return false;
        }

        if (!checkAndPayCost(player, jutsu, data)) {
            player.sendMessage(Text.literal("\u00a7cNot enough chakra!"), false);
            return false;
        }

        FormExecutor.executeForm(player, jutsu);
        return true;
    }

    private static boolean checkAndPayCost(ServerPlayerEntity player, JutsuDefinition jutsu, NinjaPlayerData data) {
        int chakra = jutsu.getCost().getOrDefault(ResourceType.CHAKRA, 0);
        if (data.getCurrentChakra() < chakra) return false;
        data.setCurrentChakra(data.getCurrentChakra() - chakra);

        int fatigue = jutsu.getCost().getOrDefault(ResourceType.FATIGUE, 0);
        if (fatigue > 0) data.setFatigue(data.getFatigue() + fatigue);

        ShinobiCore.sendChakraSync(player);
        return true;
    }

    // === Legacy API compatibility ===
    public static boolean beginCast(ServerPlayerEntity player, String jutsuId) {
        JutsuDefinition def = JutsuRegistry.get(jutsuId);
        if (def == null) return false;
        return cast(player, def);
    }
}
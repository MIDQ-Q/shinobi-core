package com.example.shinobicore.modules.jutsu.requirement;

import com.example.shinobicore.core.api.ChakraApi;
import com.example.shinobicore.core.api.ClanApi;
import com.example.shinobicore.core.api.FormulaApi;
import com.example.shinobicore.core.api.ProgressionApi;
import com.example.shinobicore.core.api.StatsApi;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.core.service.CoreServices;
import com.example.shinobicore.modules.jutsu.data.JutsuDefinition;
import net.minecraft.server.network.ServerPlayerEntity;
import java.util.Map;
import java.util.Optional;

public final class JutsuRequirementService {

    public static void init() {}

    public static RequirementCheckResult check(ServerPlayerEntity player, JutsuDefinition def) {
        if (def == null) return RequirementCheckResult.fail("jutsu_not_found");

        // Check progression (learned via tree node)
        Optional<ProgressionApi> progOpt = CoreServices.get(ProgressionApi.class);
        if (progOpt.isPresent()) {
            ProgressionApi prog = progOpt.get();
            if (def.requirements().treeNode() != null && !def.requirements().treeNode().isEmpty()) {
                if (!prog.isNodeUnlocked(player, def.requirements().treeNode())) {
                    return RequirementCheckResult.fail("not_learned");
                }
            }
            if (def.requirements().minPlayerLevel() > 0) {
                if (prog.getPlayerLevel(player) < def.requirements().minPlayerLevel()) {
                    return RequirementCheckResult.fail("level_too_low");
                }
            }
            for (String element : def.requirements().elements()) {
                if (!prog.isElementUnlocked(player, element)) {
                    return RequirementCheckResult.fail("element_not_unlocked");
                }
            }
        }

        // Check stats
        Optional<StatsApi> statsOpt = CoreServices.get(StatsApi.class);
        if (statsOpt.isPresent()) {
            StatsApi stats = statsOpt.get();
            for (Map.Entry<String, Integer> entry : def.requirements().stats().entrySet()) {
                if (stats.getStatLevel(player, entry.getKey()) < entry.getValue()) {
                    return RequirementCheckResult.fail("stat_too_low");
                }
            }
        }

        // Check clan
        if (def.requirements().clanJutsu()) {
            Optional<ClanApi> clanOpt = CoreServices.get(ClanApi.class);
            if (clanOpt.isPresent()) {
                ClanApi clan = clanOpt.get();
                if (!clan.isClanJutsu(player, def.id())) {
                    return RequirementCheckResult.fail("clan_restricted");
                }
            }
        }

        // Check chakra
        Optional<ChakraApi> chakraOpt = CoreServices.get(ChakraApi.class);
        if (chakraOpt.isPresent()) {
            ChakraApi chakra = chakraOpt.get();
            float cost = def.baseCost();
            Optional<FormulaApi> formulaOpt = CoreServices.get(FormulaApi.class);
            if (formulaOpt.isPresent()) {
                cost = formulaOpt.get().calcJutsuCost(player, def.id());
            }
            if (chakra.getCurrent(player) < cost) {
                return RequirementCheckResult.fail("insufficient_chakra", cost);
            }
        }

        return RequirementCheckResult.success();
    }
}
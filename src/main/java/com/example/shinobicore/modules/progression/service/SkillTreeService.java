package com.example.shinobicore.modules.progression.service;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.progression.component.ProgressionComponent;
import com.example.shinobicore.modules.progression.component.ProgressionComponentKey;
import com.example.shinobicore.modules.progression.data.TreeNodeDefinition;
import com.example.shinobicore.modules.progression.data.TreeNodeRegistry;
import com.example.shinobicore.modules.progression.network.ProgressionStateSyncPacket;
import net.minecraft.server.network.ServerPlayerEntity;

import java.util.Optional;

public final class SkillTreeService {
    private SkillTreeService() {}

    public static boolean unlockNode(ServerPlayerEntity player, String nodeId) {
        Optional<TreeNodeDefinition> nodeOpt = TreeNodeRegistry.get(nodeId);
        if (nodeOpt.isEmpty()) {
            ShinobiLogger.module("progression", "Unknown tree node: " + nodeId);
            return false;
        }

        Optional<ProgressionComponent> compOpt = ProgressionComponentKey.get(player);
        if (compOpt.isEmpty()) return false;

        ProgressionComponent comp = compOpt.get();
        TreeNodeDefinition node = nodeOpt.get();

        if (comp.isNodeUnlocked(nodeId)) return false;

        for (String req : node.requires()) {
            if (!comp.isNodeUnlocked(req)) {
                ShinobiLogger.module("progression", "Prereq missing: " + req + " for " + nodeId);
                return false;
            }
        }

        if (!SpService.spendSp(player, node.spCost(), "tree_node:" + nodeId)) {
            return false;
        }

        comp.unlockNode(nodeId);
        ShinobiLogger.module("progression",
            player.getName().getString() + " unlocked node: " + nodeId);
        ProgressionStateSyncPacket.sendTo(player);
        return true;
    }
}
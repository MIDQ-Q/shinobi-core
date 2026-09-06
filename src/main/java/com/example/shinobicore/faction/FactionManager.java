package com.example.shinobicore.faction;
import net.minecraft.server.network.ServerPlayerEntity;
public class FactionManager {
    public static boolean isHostileTo(ServerPlayerEntity player, String factionId) {
        FactionDefinition def = FactionRegistry.get(factionId);
        if (def == null) return false;
        return ReputationComponent.KEY.get(player).getReputation(factionId) <= def.hostileThreshold();
    }
    public static boolean isFriendlyTo(ServerPlayerEntity player, String factionId) {
        FactionDefinition def = FactionRegistry.get(factionId);
        if (def == null) return false;
        return ReputationComponent.KEY.get(player).getReputation(factionId) >= def.friendlyThreshold();
    }
}
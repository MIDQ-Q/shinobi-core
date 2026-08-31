package com.example.shinobicore.modules.clans.data;
import com.example.shinobicore.core.log.ShinobiLogger;
public final class ClanJsonValidator {
    public static void validateAll() {
        int errors = 0;
        for (ClanDefinition clan : ClanRegistry.all()) {
            if (clan.id() == null || clan.id().isEmpty()) errors++;
            if (clan.name() == null || clan.name().isEmpty()) errors++;
            if (clan.affinity() == null || clan.affinity().isEmpty()) errors++;
        }
        if (errors > 0) ShinobiLogger.error("clans", "Validation completed with " + errors + " errors.", null);
        else ShinobiLogger.module("clans", "All " + ClanRegistry.size() + " clans validated successfully.");
    }
}
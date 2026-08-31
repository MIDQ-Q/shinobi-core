package com.example.shinobicore.modules.jutsu.data;

import com.example.shinobicore.core.log.ShinobiLogger;

public final class JutsuJsonValidator {
    private static int errorCount = 0;

    public static void validateAll() {
        errorCount = 0;
        for (JutsuDefinition def : JutsuRegistry.all()) {
            validate(def);
        }
        if (errorCount > 0) {
            ShinobiLogger.error("jutsu", "Validation completed with " + errorCount + " errors. Check logs.", null);
        } else {
            ShinobiLogger.module("jutsu", "All " + JutsuRegistry.size() + " jutsu validated successfully.");
        }
    }

    private static void validate(JutsuDefinition def) {
        if (def.baseCost() < 0) error(def, "baseCost cannot be negative");
        if (def.cooldownTicks() < 0) error(def, "cooldownTicks cannot be negative");
        if (def.maxChargeMultiplier() < 1.0f) error(def, "maxChargeMultiplier must be >= 1.0");
        if (def.id() == null || def.id().isEmpty()) error(def, "id is missing or empty");
    }

    private static void error(JutsuDefinition def, String msg) {
        ShinobiLogger.error("jutsu", "Validation error in [" + def.id() + "]: " + msg, null);
        errorCount++;
    }
}
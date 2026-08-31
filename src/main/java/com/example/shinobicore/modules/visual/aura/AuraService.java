package com.example.shinobicore.modules.visual.aura;

public final class AuraService {
    private static boolean chakraModeActive = false;

    public static void init() {
        chakraModeActive = false;
    }

    // Accepts Object to avoid hard dependency on Chakra module events before they are ready
    public static void onChakraModeEnabled(Object event) {
        chakraModeActive = true;
    }

    public static void onChakraModeDisabled(Object event) {
        chakraModeActive = false;
    }

    public static boolean isChakraModeActive() {
        return chakraModeActive;
    }
    
    public static void tick() {
        // Future: Sync with CoreServices.get(ChakraApi.class) to prevent desync
    }
}
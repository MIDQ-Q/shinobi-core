package com.example.shinobicore.client.ui.widgets;

public class HudConfig {
    public static class Instance {
        public boolean showCastBar = true;
        public int hudOffsetX = 0;
        public int hudOffsetY = 0;
        public boolean showChakraBar = true;
        public boolean showStaminaBar = true;
        public boolean showStatusIcons = true;
    }
    
    public static Instance instance = new Instance();
}
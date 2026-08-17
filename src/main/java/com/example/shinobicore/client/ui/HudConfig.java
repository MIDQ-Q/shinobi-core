package com.example.shinobicore.client.ui;

public class HudConfig {
    public static class Instance {
        public boolean showCastBar = true;
        public boolean showChakraBar = true;
        public boolean showStaminaBar = true;
        public boolean showStatusIcons = true;
        public int hudOffsetX = 0;
        public int hudOffsetY = 0;

        public boolean contextualHide = true;
    }
    public static Instance instance = new Instance();
}
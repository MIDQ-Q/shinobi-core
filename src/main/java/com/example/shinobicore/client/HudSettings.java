package com.example.shinobicore.client;

public class HudSettings {
    public static class Settings {
        public boolean showCastBar = true;
        public float opacity = 1.0f;
        public int offsetX = 0;
        public int offsetY = 0;
        public boolean showStatusIcons = true;
        public boolean showChakraBar = true;
        public boolean showStaminaBar = true;
    }
    
    public static Settings current = new Settings();
    
    public static void load() {
        // S3-05: Заглушка для загрузки настроек (можно связать с ModConfig.instance.hud)
    }
}
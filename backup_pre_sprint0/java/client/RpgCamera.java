package com.example.shinobicore.client;

import net.minecraft.util.math.Vec3d;

public class RpgCamera {
    public static boolean enabled = true;        // РїРѕ СѓРјРѕР»С‡Р°РЅРёСЋ Р’РљР›
    public static float distance = 3.0f;
    public static float shoulder = 0.7f;
    public static float smoothing = 0.85f;       // Р±РѕР»СЊС€Рµ = РїР»Р°РІРЅРµРµ
    public static int shoulderSide = 1;          // +1 = РїСЂР°РІРѕРµ РїР»РµС‡Рѕ, -1 = Р»РµРІРѕРµ
    private static Vec3d lastPos = null;

    public static void toggle() {
        enabled = !enabled;
        lastPos = null;
    }

    public static void flipShoulder() {
        shoulderSide = -shoulderSide;
        lastPos = null;
    }

    public static Vec3d smooth(Vec3d target) {
        if (lastPos == null || lastPos.squaredDistanceTo(target) > 25) {
            lastPos = target;
        } else {
            lastPos = lastPos.lerp(target, smoothing);
        }
        return lastPos;
    }
}
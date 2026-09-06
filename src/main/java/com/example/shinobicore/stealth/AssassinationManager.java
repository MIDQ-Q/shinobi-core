package com.example.shinobicore.stealth;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.math.Vec3d;
public class AssassinationManager {
    public static boolean isBackstab(ServerPlayerEntity attacker, LivingEntity target) {
        StealthComponent comp = StealthComponent.KEY.get(attacker);
        if (!comp.isHidden()) return false;
        Vec3d attackerPos = attacker.getPos();
        Vec3d targetPos = target.getPos();
        Vec3d targetLook = target.getRotationVector();
        Vec3d toAttacker = attackerPos.subtract(targetPos).normalize();
        double dot = targetLook.dotProduct(toAttacker);
        return dot < -0.5; 
    }
    public static float getBackstabMultiplier() { return 3.0f; }
}
package com.example.shinobicore.modules.visual.stub;

import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.util.math.Vec3d;

public final class StubEvents {
    public static class JutsuCastStartedEvent {
        public final PlayerEntity caster;
        public final String elementId;
        public JutsuCastStartedEvent(PlayerEntity caster, String elementId) {
            this.caster = caster; this.elementId = elementId;
        }
    }
    public static class JutsuCastFinishedEvent {
        public final PlayerEntity caster;
        public final String elementId;
        public JutsuCastFinishedEvent(PlayerEntity caster, String elementId) {
            this.caster = caster; this.elementId = elementId;
        }
    }
    public static class CombatHitEvent {
        public final PlayerEntity attacker;
        public final float damage;
        public CombatHitEvent(PlayerEntity attacker, float damage) {
            this.attacker = attacker; this.damage = damage;
        }
    }
    public static class CombatBlockedEvent {
        public final PlayerEntity blocker;
        public CombatBlockedEvent(PlayerEntity blocker) { this.blocker = blocker; }
    }
    public static class CombatParriedEvent {
        public final PlayerEntity parrier;
        public CombatParriedEvent(PlayerEntity parrier) { this.parrier = parrier; }
    }
    public static class LevelChangedEvent {
        public final PlayerEntity player;
        public final int oldLevel;
        public final int newLevel;
        public LevelChangedEvent(PlayerEntity player, int oldLevel, int newLevel) {
            this.player = player; this.oldLevel = oldLevel; this.newLevel = newLevel;
        }
    }
    public static class XpGainedEvent {
        public final PlayerEntity player;
        public final int amount;
        public XpGainedEvent(PlayerEntity player, int amount) {
            this.player = player; this.amount = amount;
        }
    }
    public static class ChakraModeEnabledEvent {
        public final PlayerEntity player;
        public ChakraModeEnabledEvent(PlayerEntity player) { this.player = player; }
    }
    public static class ChakraModeDisabledEvent {
        public final PlayerEntity player;
        public ChakraModeDisabledEvent(PlayerEntity player) { this.player = player; }
    }
    public static class WaterWalkStartedEvent {
        public final PlayerEntity player;
        public WaterWalkStartedEvent(PlayerEntity player) { this.player = player; }
    }
    public static class WallRunStartedEvent {
        public final PlayerEntity player;
        public WallRunStartedEvent(PlayerEntity player) { this.player = player; }
    }
    public static class SlideStartedEvent {
        public final PlayerEntity player;
        public SlideStartedEvent(PlayerEntity player) { this.player = player; }
    }
    public static class RollStartedEvent {
        public final PlayerEntity player;
        public RollStartedEvent(PlayerEntity player) { this.player = player; }
    }
    public static class DodgeEvent {
        public final PlayerEntity player;
        public DodgeEvent(PlayerEntity player) { this.player = player; }
    }
    public static class EnemyStateChangedEvent {
        public final int entityId;
        public final Vec3d pos;
        public final String newState;
        public EnemyStateChangedEvent(int entityId, Vec3d pos, String newState) {
            this.entityId = entityId; this.pos = pos; this.newState = newState;
        }
    }
}
package com.example.shinobicore.jutsu.executor;

import com.example.shinobicore.jutsu.core.EffectDefinition;
import com.example.shinobicore.jutsu.core.JutsuDefinition;
import com.example.shinobicore.jutsu.core.PropertyDefinition;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;

import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

public class CastContext {
    public final LivingEntity caster;
    public final JutsuDefinition jutsu;
    public final int level;
    public final double damageScale;
    public final List<PropertyDefinition> props;
    public final List<EffectDefinition> effects;
    public final int multiCap;
    public final Set<UUID> globalHit = new HashSet<>();

    public CastContext(LivingEntity caster, JutsuDefinition jutsu, int level, double damageScale,
                       List<PropertyDefinition> props, List<EffectDefinition> effects, int multiCap) {
        this.caster = caster; this.jutsu = jutsu; this.level = level;
        this.damageScale = damageScale; this.props = props; this.effects = effects; this.multiCap = multiCap;
    }

    public ServerWorld world() { return (ServerWorld) caster.getWorld(); }
    public ServerPlayerEntity player() { return caster instanceof ServerPlayerEntity sp ? sp : null; }

    public boolean hasProp(String id) { return props.stream().anyMatch(p -> p.getId().equals(id)); }
    public PropertyDefinition prop(String id) { return props.stream().filter(p -> p.getId().equals(id)).findFirst().orElse(null); }
    public boolean capReached() { return multiCap > 0 && globalHit.size() >= multiCap; }
    public boolean markHit(LivingEntity e) {
        if (capReached()) return false;
        globalHit.add(e.getUuid());
        return true;
    }

    public void sendMsg(Text msg, boolean actionBar) {
        if (caster instanceof ServerPlayerEntity sp) sp.sendMessage(msg, actionBar);
    }
}
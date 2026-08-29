package com.example.shinobicore.jutsu;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.command.CastCommand;
import com.example.shinobicore.command.DevCommand;
import com.example.shinobicore.command.LearnCommand;
import com.example.shinobicore.command.TestJutsuCommand;
import com.example.shinobicore.entity.ModEntities;
import com.example.shinobicore.jutsu.behavior.AoeBehavior;
import com.example.shinobicore.jutsu.behavior.BehaviorRegistry;
import com.example.shinobicore.jutsu.behavior.DashBehavior;
import com.example.shinobicore.jutsu.behavior.GenjutsuBehavior;
import com.example.shinobicore.jutsu.behavior.MeleeBehavior;
import com.example.shinobicore.jutsu.behavior.ProjectileBehavior;
import com.example.shinobicore.jutsu.behavior.UtilityBehavior;
import com.example.shinobicore.jutsu.behavior.WallBehavior;
import com.example.shinobicore.jutsu.custom.FireDragonBehavior;
import com.example.shinobicore.jutsu.data.JutsuRegistry;
import com.example.shinobicore.util.TickScheduler;
import net.fabricmc.fabric.api.command.v2.CommandRegistrationCallback;

/**
 * Sprint 1 wiring: entities, behaviors, registry listener, commands.
 * HLD: Section 2
 */
public final class JutsuEngineBootstrap {

    private JutsuEngineBootstrap() {}

    public static void init() {
        ModEntities.init();
        TickScheduler.init();
        registerBehaviors();
        JutsuRegistry.registerReloadListener();

        CommandRegistrationCallback.EVENT.register((dispatcher, registryAccess, environment) -> {
            CastCommand.register(dispatcher);
            TestJutsuCommand.register(dispatcher);
            LearnCommand.register(dispatcher);
            DevCommand.register(dispatcher);
        });

        ShinobiCore.LOGGER.info("Jutsu Engine bootstrapped (Sprint 1)");
    }

    private static void registerBehaviors() {
        BehaviorRegistry.register("projectile", new ProjectileBehavior());
        BehaviorRegistry.register("aoe", new AoeBehavior());
        BehaviorRegistry.register("dash", new DashBehavior());
        BehaviorRegistry.register("melee", new MeleeBehavior());
        BehaviorRegistry.register("wall", new WallBehavior());
        BehaviorRegistry.register("utility", new UtilityBehavior());
        BehaviorRegistry.register("genjutsu", new GenjutsuBehavior());
        BehaviorRegistry.register("fire_dragon", new FireDragonBehavior());
    }
}
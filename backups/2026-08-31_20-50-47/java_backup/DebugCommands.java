package com.example.shinobicore;

import net.fabricmc.api.ModInitializer;
import net.fabricmc.fabric.api.command.v2.CommandRegistrationCallback;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import java.lang.reflect.Method;
import java.util.Collection;

import static net.minecraft.server.command.CommandManager.literal;

public class DebugCommands implements ModInitializer {
    @Override
    public void onInitialize() {
        CommandRegistrationCallback.EVENT.register((d, r, e) -> {
            d.register(literal("unlockall").executes(ctx -> unlock(ctx.getSource())));
        });
    }

    private int unlock(ServerCommandSource src) {
        try {
            ServerPlayerEntity p = src.getPlayer();
            Object data = p.getClass().getMethod("shinobicore_getData").invoke(p);
            if (data == null) { src.sendError(Text.literal("no data")); return 0; }
            int natures = 0, stats = 0, jutsus = 0;

            for (Object et : Class.forName("com.example.shinobicore.stat.ElementType").getEnumConstants()) {
                if (call(data, "setNatureUnlocked", new Class[]{Class.forName("com.example.shinobicore.stat.ElementType"), boolean.class}, et, true)) natures++;
                call(data, "setNatureLevel", new Class[]{Class.forName("com.example.shinobicore.stat.ElementType"), int.class}, et, 100);
            }
            for (Object st : Class.forName("com.example.shinobicore.stat.StatType").getEnumConstants()) {
                if (call(data, "setStatLevel", new Class[]{Class.forName("com.example.shinobicore.stat.StatType"), int.class}, st, 100)) stats++;
            }
            Class<?> reg = Class.forName("com.example.shinobicore.jutsu.JutsuRegistry");
            Collection<?> all = (Collection<?>) reg.getMethod("getAll").invoke(null);
            for (Object jd : all) {
                String id = (String) jd.getClass().getMethod("id").invoke(jd);
                if (call(data, "learnJutsu", new Class[]{String.class}, id)) jutsus++;
                else call(data, "learnJutsu", new Class[]{Class.forName("com.example.shinobicore.jutsu.JutsuDefinition")}, jd);
            }
            call(data, "addSkillPoints", new Class[]{int.class}, 300);
            com.example.shinobicore.util.ActionLogger.log("unlockall: natures=" + natures + " stats=" + stats + " jutsus=" + jutsus);
            p.sendMessage(Text.literal("\u00a7aUnlocked: " + natures + " natures, " + stats + " stats, " + jutsus + " jutsu. +300 SP"), false);
        } catch (Exception ex) {
            com.example.shinobicore.util.ActionLogger.log("unlockall ERROR: " + ex);
            src.sendError(Text.literal("error: " + ex.getMessage()));
        }
        return 1;
    }

    private boolean call(Object target, String name, Class[] sig, Object... args) {
        try {
            Method m = target.getClass().getMethod(name, sig);
            m.setAccessible(true);
            m.invoke(target, args);
            return true;
        } catch (Exception e) { return false; }
    }
}
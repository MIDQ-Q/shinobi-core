package com.example.shinobicore.util;

import net.fabricmc.loader.api.FabricLoader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.LocalTime;

public class ActionLogger {
    private static final Path FILE = FabricLoader.getInstance().getGameDir().resolve("shinobicore_actions.log");
    public static synchronized void log(String msg) {
        try {
            String line = "[" + LocalTime.now() + "] " + msg + "\n";
            Files.write(FILE, line.getBytes(), StandardOpenOption.CREATE, StandardOpenOption.APPEND);
        } catch (Exception e) { }
    }
}
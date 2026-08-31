package com.example.shinobicore.modules.example;
import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.api.ShinobiModule;
import com.example.shinobicore.core.log.ShinobiLogger;
public class ExampleModule implements ShinobiModule {
    @Override public String id() { return "example"; }
    @Override public void onEnable(ModuleContext ctx) {
        ShinobiLogger.module(id(), "Example module enabled");
    }
    @Override public void onDisable(ModuleContext ctx) {
        ShinobiLogger.module(id(), "Example module disabled");
    }
}
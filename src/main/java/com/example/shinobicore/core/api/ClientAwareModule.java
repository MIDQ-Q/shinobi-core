package com.example.shinobicore.core.api;
public interface ClientAwareModule extends ShinobiModule {
    default void onClientInit(ModuleContext ctx) {}
    default void onClientTick(ModuleContext ctx) {}
}
package com.example.shinobicore.core.api;

/**
 * Extension of ShinobiModule for modules with client-side functionality.
 */
public interface ClientAwareModule extends ShinobiModule {
    /**
     * Called on client initialization.
     */
    default void onClientInit(ModuleContext ctx) {}
    
    /**
     * Called every client tick.
     */
    default void onClientTick(ModuleContext ctx) {}
}
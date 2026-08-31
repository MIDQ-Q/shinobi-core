package com.example.shinobicore.core.api;

import com.example.shinobicore.core.config.ModuleConfigLoader;

public final class ModuleContext {
    private final String moduleId;
    private final ModuleConfigLoader configs;

    public ModuleContext(String moduleId, ModuleConfigLoader configs) {
        this.moduleId = moduleId;
        this.configs = configs;
    }

    public String moduleId() {
        return moduleId;
    }

    public ModuleConfigLoader configs() {
        return configs;
    }
}
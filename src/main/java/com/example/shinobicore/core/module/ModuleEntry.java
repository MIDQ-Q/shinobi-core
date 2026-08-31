package com.example.shinobicore.core.module;
import com.example.shinobicore.core.api.ShinobiModule;
public final class ModuleEntry {
    private final ShinobiModule module;
    private final String provider;
    private ModuleState state;
    private String failReason;
    public ModuleEntry(ShinobiModule module, String provider) {
        this.module = module;
        this.provider = provider;
        this.state = ModuleState.ENABLED;
        this.failReason = "";
    }
    public ShinobiModule module() { return module; }
    public String provider() { return provider; }
    public ModuleState state() { return state; }
    public String failReason() { return failReason; }
    public void setState(ModuleState state) { this.state = state; }
    public void fail(String reason) { this.state = ModuleState.FAILED; this.failReason = reason; }
}
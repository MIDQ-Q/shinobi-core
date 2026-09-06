package com.example.shinobicore.stealth;
import dev.onyxstudios.cca.api.v3.component.Component;
import dev.onyxstudios.cca.api.v3.component.ComponentKey;
import dev.onyxstudios.cca.api.v3.component.ComponentRegistry;
import net.minecraft.util.Identifier;
public interface StealthComponent extends Component {
    ComponentKey<StealthComponent> KEY = ComponentRegistry.getOrCreate(new Identifier("shinobicore", "stealth"), StealthComponent.class);
    float getVisibility();
    void setVisibility(float visibility);
    boolean isHidden();
    void addNoise(float amount);
    float getNoise();
    void tick();
}
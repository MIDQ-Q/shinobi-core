package com.example.shinobicore.faction;
import dev.onyxstudios.cca.api.v3.component.Component;
import dev.onyxstudios.cca.api.v3.component.ComponentKey;
import dev.onyxstudios.cca.api.v3.component.ComponentRegistry;
import net.minecraft.util.Identifier;
import java.util.Map;
public interface ReputationComponent extends Component {
    ComponentKey<ReputationComponent> KEY = ComponentRegistry.getOrCreate(new Identifier("shinobicore", "reputation"), ReputationComponent.class);
    int getReputation(String factionId);
    void addReputation(String factionId, int amount);
    Map<String, Integer> getAllReputations();
}
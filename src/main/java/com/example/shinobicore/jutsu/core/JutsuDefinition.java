package com.example.shinobicore.jutsu.core;

import com.example.shinobicore.jutsu.enums.ElementType;
import com.example.shinobicore.jutsu.enums.ResourceType;

import java.util.List;
import java.util.Map;

public class JutsuDefinition {
    private final String id;
    private final String name;
    private final String description;
    private final String category;
    private final String rank;
    private final List<String> tags;
    private final FormDefinition form;
    private final List<EffectDefinition> effects;
    private final List<PropertyDefinition> properties;
    private final ElementType element;
    private final ActivationDefinition activation;
    private final Map<ResourceType, Integer> cost;
    private final RequirementsDefinition requirements;
    private final LevelingDefinition leveling;
    private final VisualDefinition visual;
    private final SoundDefinition sound;
    private final double cooldown;

    public JutsuDefinition(String id, String name, String description, String category, String rank, List<String> tags,
                           FormDefinition form, List<EffectDefinition> effects, List<PropertyDefinition> properties, ElementType element,
                           ActivationDefinition activation, Map<ResourceType, Integer> cost, RequirementsDefinition requirements,
                           LevelingDefinition leveling, VisualDefinition visual, SoundDefinition sound, double cooldown) {
        this.id = id; this.name = name; this.description = description; this.category = category;
        this.rank = rank; this.tags = tags; this.form = form; this.effects = effects;
        this.properties = properties; this.element = element; this.activation = activation;
        this.cost = cost; this.requirements = requirements; this.leveling = leveling;
        this.visual = visual; this.sound = sound; this.cooldown = cooldown;
    }

    public String getId() { return id; }
    public String getName() { return name; }
    public String getDescription() { return description; }
    public String getCategory() { return category; }
    public String getRank() { return rank; }
    public List<String> getTags() { return tags; }
    public FormDefinition getForm() { return form; }
    public List<EffectDefinition> getEffects() { return effects; }
    public List<PropertyDefinition> getProperties() { return properties; }
    public ElementType getElement() { return element; }
    public ActivationDefinition getActivation() { return activation; }
    public Map<ResourceType, Integer> getCost() { return cost; }
    public RequirementsDefinition getRequirements() { return requirements; }
    public LevelingDefinition getLeveling() { return leveling; }
    public VisualDefinition getVisual() { return visual; }
    public SoundDefinition getSound() { return sound; }
    public double getCooldown() { return cooldown; }

    public boolean hasElement() { return element != ElementType.NONE; }
    public boolean hasProperty(String propertyId) {
        return properties.stream().anyMatch(p -> p.getId().equals(propertyId));
    }
}
package com.example.shinobicore.client.render;

import com.example.shinobicore.entity.CloneEntity;
import net.minecraft.util.Identifier;
import software.bernie.geckolib.model.GeoModel;

/**
 * GeckoLib model for CloneEntity (reuses ninja geometry/animation).
 * HLD: Blueprint (static decoy clones)
 */
public class CloneModel extends GeoModel<CloneEntity> {
    @Override
    public Identifier getModelResource(CloneEntity object) {
        return new Identifier("shinobicore", "geo/ninja_enemy.geo.json");
    }
    @Override
    public Identifier getTextureResource(CloneEntity object) {
        return new Identifier("shinobicore", "textures/entity/ninja_enemy.png");
    }
    @Override
    public Identifier getAnimationResource(CloneEntity object) {
        return new Identifier("shinobicore", "animations/ninja_enemy.animation.json");
    }
}
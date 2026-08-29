package com.example.shinobicore.entity.enemy;

import net.minecraft.util.Identifier;
import software.bernie.geckolib.model.GeoModel;

/**
 * GeckoLib model/texture/animation resource provider.
 * HLD: Section 5
 */
public class NinjaEnemyModel extends GeoModel<NinjaEnemyEntity> {

    @Override
    public Identifier getModelResource(NinjaEnemyEntity object) {
        return new Identifier("shinobicore", "geo/ninja_enemy.geo.json");
    }

    @Override
    public Identifier getTextureResource(NinjaEnemyEntity object) {
        return new Identifier("shinobicore", "textures/entity/ninja_enemy.png");
    }

    @Override
    public Identifier getAnimationResource(NinjaEnemyEntity object) {
        return new Identifier("shinobicore", "animations/ninja_enemy.animation.json");
    }
}
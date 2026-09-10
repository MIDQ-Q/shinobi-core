package com.example.shinobicore.client.render;

import net.minecraft.client.model.ModelPart;
import net.minecraft.client.render.entity.model.PlayerEntityModel;
import net.minecraft.entity.LivingEntity;
import java.util.Collections;

/**
 * Custom player model with 11 bones from Blockbench.
 * Extends PlayerEntityModel to preserve armor/item rendering.
 *
 * Extra bones (forearms, shins) are standalone ModelParts.
 * They store rotation data from JSON animations.
 * Their rotations are applied additively to parent arms/legs
 * in PlayerJsonAnimOverride.
 *
 * Bone hierarchy (logical):
 *   root
 *   +-- body
 *   |   +-- head
 *   |   +-- leftArm -> leftForeArm (additive)
 *   |   +-- rightArm -> rightForeArm (additive)
 *   +-- leftLeg -> leftShin (additive)
 *   +-- rightLeg -> rightShin (additive)
 */
public class ShinobiPlayerModel<T extends LivingEntity> extends PlayerEntityModel<T> {

    // Extra bones rotation holders (not rendered, just store anim data)
    public float rootOffsetY = 0;
    public final ModelPart leftForeArm;
    public final ModelPart rightForeArm;
    public final ModelPart leftShin;
    public final ModelPart rightShin;

    public ShinobiPlayerModel(ModelPart root, boolean thinArms) {
        super(root, thinArms);

        // Create standalone empty ModelParts for extra bones
        // They are NOT children of existing parts (children is private)
        // They just store rotation values from JSON animations
        this.leftForeArm = createEmptyPart();
        this.rightForeArm = createEmptyPart();
        this.leftShin = createEmptyPart();
        this.rightShin = createEmptyPart();
    }

    private static ModelPart createEmptyPart() {
        return new ModelPart(Collections.emptyList(), Collections.emptyMap());
    }

    /**
     * Reset extra bones each frame before animation applies.
     */
        @Override
    public void render(net.minecraft.client.util.math.MatrixStack matrices, net.minecraft.client.render.VertexConsumer vertices, int light, int overlay, float red, float green, float blue, float alpha) {
        matrices.push();
        matrices.translate(0, this.rootOffsetY, 0);
        super.render(matrices, vertices, light, overlay, red, green, blue, alpha);
        matrices.pop();
    }
    public void resetExtraBones() {
        this.leftForeArm.pitch = 0;
        this.leftForeArm.yaw = 0;
        this.leftForeArm.roll = 0;
        this.rightForeArm.pitch = 0;
        this.rightForeArm.yaw = 0;
        this.rightForeArm.roll = 0;
        this.leftShin.pitch = 0;
        this.leftShin.yaw = 0;
        this.leftShin.roll = 0;
        this.rightShin.pitch = 0;
        this.rightShin.yaw = 0;
        this.rightShin.roll = 0;
    }
}
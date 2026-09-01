package com.example.shinobicore.client.combat;

import net.minecraft.client.model.ModelPart;

public class HandSealPoses {
    public static void apply(String nature, ModelPart rArm, ModelPart lArm, ModelPart body, ModelPart head) {
        float t = (float) (Math.sin(System.currentTimeMillis() / 150.0) * 0.05f);

        switch (nature) {
            case "fire" -> {
                rArm.pitch = -0.8f + t; rArm.yaw = -0.6f; rArm.roll = 0.3f;
                lArm.pitch = -0.8f + t; lArm.yaw = 0.6f; lArm.roll = -0.3f;
                body.pitch += 0.1f;
                head.pitch += 0.15f;
            }
            case "water" -> {
                rArm.pitch = -1.0f + t; rArm.yaw = -0.1f;
                lArm.pitch = -1.0f + t; lArm.yaw = 0.1f;
                body.pitch += 0.08f;
                head.pitch += 0.12f;
            }
            case "wind" -> {
                rArm.pitch = -0.5f + t; rArm.yaw = -1.2f; rArm.roll = 0.4f;
                lArm.pitch = -0.5f + t; lArm.yaw = 1.2f; lArm.roll = -0.4f;
                body.pitch += 0.05f;
                head.pitch += 0.08f;
            }
            case "earth" -> {
                rArm.pitch = -0.4f + t; rArm.yaw = -0.15f;
                lArm.pitch = -0.4f + t; lArm.yaw = 0.15f;
                body.pitch += 0.15f;
                head.pitch += 0.2f;
            }
            case "lightning" -> {
                rArm.pitch = -1.8f + t; rArm.yaw = -0.3f;
                lArm.pitch = -0.6f + t; lArm.yaw = 0.3f;
                body.pitch += 0.05f;
                head.pitch -= 0.1f;
            }
            default -> {
                rArm.pitch = -1.1f + t; rArm.yaw = -0.2f;
                lArm.pitch = -1.1f + t; lArm.yaw = 0.2f;
                body.pitch += 0.1f;
                head.pitch += 0.1f;
            }
        }
    }
}
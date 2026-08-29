// SHINOBICORE:SPRINT8:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.client.input.KeyBindings;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.client.option.KeyBinding;

/**
 * SPRINT 8 input handler for Roll and Dodge keys.
 */
public final class RollDodgeInputHandler {
    private static boolean wasRoll = false;
    private static boolean rollEdge = false;

    private static boolean wasDodgeLeft = false;
    private static boolean dodgeLeftEdge = false;

    private static boolean wasDodgeRight = false;
    private static boolean dodgeRightEdge = false;

    private RollDodgeInputHandler() {}

    public static void update(ClientPlayerEntity player) {
        boolean roll = isKeyDown(KeyBindings.ROLL);
        rollEdge = roll && !wasRoll;
        wasRoll = roll;

        boolean left = isKeyDown(KeyBindings.DODGE_LEFT);
        dodgeLeftEdge = left && !wasDodgeLeft;
        wasDodgeLeft = left;

        boolean right = isKeyDown(KeyBindings.DODGE_RIGHT);
        dodgeRightEdge = right && !wasDodgeRight;
        wasDodgeRight = right;
    }

    public static boolean wasRollPressed() {
        return rollEdge;
    }

    public static boolean wasDodgeLeftPressed() {
        return dodgeLeftEdge;
    }

    public static boolean wasDodgeRightPressed() {
        return dodgeRightEdge;
    }

    private static boolean isKeyDown(KeyBinding key) {
        return key != null && key.isPressed();
    }
}
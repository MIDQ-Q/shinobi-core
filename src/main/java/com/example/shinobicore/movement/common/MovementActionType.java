// SHINOBICORE:SPRINT3-FINAL:FILE
package com.example.shinobicore.movement.common;

/**
 * SPRINT 3 FINAL action types with network IDs.
 */
public enum MovementActionType {
    NONE(0),
    CHAKRA_MODE_ON(1),
    CHAKRA_MODE_OFF(2),
    WATER_START(3),
    WATER_STOP(4),
    WALL_START(5),
    WALL_STOP(6),
    WALL_JUMP(7),
    SLIDE_START(8),
    SLIDE_STOP(9),
    CRAWL_START(10),
    CRAWL_STOP(11),
    ROLL_START(12),
    ROLL_STOP(13),
    DODGE_LEFT(14),
    DODGE_RIGHT(15),
    CHARGED_JUMP_START(16),
    CHARGED_JUMP_RELEASE(17),
    DOUBLE_JUMP(18),
    EDGE_GRAB_START(19),
    EDGE_GRAB_STOP(20),
    MEDITATION_START(21),
    MEDITATION_STOP(22),
    MOVEMENT_HEARTBEAT(23),
    RESET(24);

    private final int id;

    MovementActionType(int id) {
        this.id = id;
    }

    public int getId() {
        return id;
    }

    public static MovementActionType fromId(int id) {
        for (MovementActionType t : values()) {
            if (t.id == id) return t;
        }
        return NONE;
    }
}
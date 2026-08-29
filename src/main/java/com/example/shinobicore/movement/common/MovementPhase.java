// SHINOBICORE:SPRINT3:FILE
package com.example.shinobicore.movement.common;

/**
 * SPRINT 3 movement state machine phases.
 * Foundation for Sprint 4 (parkour actions).
 */
public enum MovementPhase {
    NORMAL,
    MEDITATING,
    WATER_WALKING,
    WALL_RUNNING,
    SLIDING,
    CRAWLING,
    ROLLING,
    DODGING,
    CHARGING_JUMP,
    EDGE_GRABBING;

    public boolean isAirborne() {
        return this == CHARGING_JUMP || this == EDGE_GRABBING || this == WALL_RUNNING;
    }

    public boolean isGrounded() {
        return this == NORMAL || this == SLIDING || this == CRAWLING || this == ROLLING || this == MEDITATING;
    }

    public boolean blocksOtherActions() {
        return this != NORMAL && this != MEDITATING;
    }
}
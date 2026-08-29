package com.example.shinobicore.entity.enemy;

/**
 * FSM states for rogue ninja enemies.
 * HLD: Section 5 (EnemyCombatController FSM)
 */
public enum EnemyState {
    IDLE,
    PATROL,
    APPROACH,
    TELEGRAPH,
    ATTACK,
    BLOCK,
    KAWARIMI,
    FLEE
}
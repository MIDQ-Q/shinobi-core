package com.example.shinobicore.entity.enemy;

/**
 * S9-02: FSM states for enemy AI.
 * States are managed by EnemyCombatController.
 */
public enum EnemyState {
    IDLE,           // Standing, looking around
    PATROL,         // Walking between patrol points
    INVESTIGATE,    // Moving to point of interest
    APPROACH,       // Moving toward target
    TELEGRAPH,      // Playing attack warning (sound + particles)
    MELEE_ATTACK,   // Executing melee attack
    RANGED_ATTACK,  // Executing ranged attack (projectile)
    AOE_ATTACK,     // Executing area attack
    BLOCK,          // Blocking incoming attacks
    DASH,           // Quick movement (toward/away from target)
    KAWARIMI,       // Substitution jutsu
    RECOVER,        // Recovery after attack or block break
    FLEE            // Running away (low HP)
}
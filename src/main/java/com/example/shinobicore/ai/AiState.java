package com.example.shinobicore.ai;

public interface AiState {
    default void enter(AiBrain b) {}
    void tick(AiBrain b);
    default void exit(AiBrain b) {}
}
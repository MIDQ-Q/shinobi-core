package com.example.shinobicore.item.crafting;
public interface IInfusableItem {
    boolean canBeInfused();
    void onInfused(String jutsuId);
}
package com.example.shinobicore.api.chakra;

import dev.onyxstudios.cca.api.v3.component.Component;

public interface IChakraComponent extends Component {
    double getCurrent();
    double getMax();
    boolean isChakraModeActive();
    boolean isExhausted();
    void setCurrent(double value);
    void setMax(double value);
    void setChakraModeActive(boolean active);
    void setExhausted(boolean exhausted);
    boolean trySpend(double amount);
    void regenerate(double amount);
}
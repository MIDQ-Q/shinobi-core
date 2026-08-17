package com.example.shinobicore.client.vfx;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * S4-01: Voxel model = named collection of VoxelCubes.
 * Built procedurally via VoxelShapeGenerators or manually.
 * After building, treat as immutable for render-thread safety.
 */
public class VoxelModel {

    private final String id;
    private final List<VoxelCube> cubes;
    private boolean baked = false;

    public VoxelModel(String id) {
        this.id = id;
        this.cubes = new ArrayList<>();
    }

    public void addCube(VoxelCube cube) {
        if (baked) {
            throw new IllegalStateException("Model '" + id + "' is already baked");
        }
        cubes.add(cube);
    }

    /** Freeze the model. No more cubes can be added. */
    public void bake() {
        baked = true;
    }

    public boolean isBaked() { return baked; }

    public String getId() { return id; }

    public int getCubeCount() { return cubes.size(); }

    /**
     * Returns unmodifiable view of cubes.
     * Call bake() before passing to render thread.
     */
    public List<VoxelCube> getCubes() {
        return Collections.unmodifiableList(cubes);
    }
}
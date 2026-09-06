package com.example.shinobicore.client.voxel;

import java.util.List;
import java.util.Map;

public record VoxelModel(String name, List<Element> elements, List<TextureRef> textures, float cx, float cy, float cz) {
    public sealed interface Element permits CubeElement, MeshElement {}
    public record CubeElement(float[] from, float[] to, int color, Map<String, Face> faces, Rotation rotation) implements Element {}
    public record MeshElement(float[][] vertices, MeshFace[] faces) implements Element {}
    public record MeshFace(int[] indices, float[][] uv, int texture) {}
    public record Face(float[] uv, int texture) {}
    public record Rotation(String axis, float angle, float[] origin) {}
    public record TextureRef(String name, String source, String uuid, int width, int height) {}
}
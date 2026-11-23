// Stable modulo-world coordinates for repeating world-space procedural textures.
// Reduce the integer camera origin before float conversion so block precision is
// retained even near Minecraft's world border. Iris binds noisetex with GL_REPEAT.
vec2 sereneStableWorldXZ(vec3 playerPosition, float worldPeriod) {
    int periodInt = int(worldPeriod);
    ivec2 cameraModuloInt = cameraPositionInt.xz % ivec2(periodInt);
    vec2 cameraModulo = mod(vec2(cameraModuloInt), vec2(worldPeriod));
    return mod(
        cameraModulo + cameraPositionFract.xz + playerPosition.xz,
        vec2(worldPeriod)
    );
}

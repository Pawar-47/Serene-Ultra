#version 330 compatibility

// These are Iris shader options as well as the shadow pipeline's active
// constants, allowing profiles and the Quality menu to tune them.
const int shadowMapResolution = 1024; // [512 768 1024 1536 2048] Shadow-map resolution
const float shadowDistance = 96.0; // [64.0 96.0 128.0 160.0 192.0 224.0] Shadow draw distance in blocks

void main() {
    gl_Position = ftransform();
}

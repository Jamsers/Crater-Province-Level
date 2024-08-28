#[vertex]
#version 450
layout(location = 0) in vec4 vert;
layout(location = 0) out vec2 tex_coord;
layout(location = 1) out vec4 offset[3];

layout(constant_id = 0) const float SMAA_THRESHOLD = 0.1;

layout(push_constant, std430) uniform Params {
    vec4 smaa_rt_metrics;
} params;

void main() {
    tex_coord = vert.zw;
    offset[0] = fma(params.smaa_rt_metrics.xyxy, vec4(-1.0, 0.0, 0.0, -1.0), tex_coord.xyxy);
    offset[1] = fma(params.smaa_rt_metrics.xyxy, vec4(1.0, 0.0, 0.0, 1.0), tex_coord.xyxy);
    offset[2] = fma(params.smaa_rt_metrics.xyxy, vec4(-2.0, 0.0, 0.0, -2.0), tex_coord.xyxy);
    gl_Position = vec4(vert.xy, 1.0, 1.0);
}

#[fragment]
#version 450
layout(location = 0) in vec2 tex_coord;
layout(location = 1) in vec4 offset[3];
layout(set = 0, binding = 0) uniform sampler2D depth_tex;
layout(location = 0) out vec2 edges;

layout(constant_id = 0) const float SMAA_THRESHOLD = 0.1;
#define SMAA_DEPTH_THRESHOLD (0.1 * SMAA_THRESHOLD)

layout(push_constant, std430) uniform Params {
    vec4 smaa_rt_metrics;
} params;

vec3 SMAAGatherNeighbours() {
    return textureGather(depth_tex, tex_coord + params.smaa_rt_metrics.xy * vec2(-0.5, -0.5)).grb;
}

void main() {
    // Since the depth buffer is non-linear, we would need an inverse
    // projection matrix to make depth edge detection usable.
    vec3 neighbours = SMAAGatherNeighbours();
    vec2 delta = abs(neighbours.xx - vec2(neighbours.y, neighbours.z));
    edges = step(SMAA_DEPTH_THRESHOLD, delta);

    if (dot(edges, vec2(1.0, 1.0)) == 0.0) {
        discard;
    }
}

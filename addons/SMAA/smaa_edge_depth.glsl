#[vertex]
#version 450

#include "smaa_settings_inc.glsl"

layout(location = 0) out vec2 tex_coord;
layout(location = 1) out vec4 offset[3];

void main() {
	vec2 vertex_base;
	if (gl_VertexIndex == 0) {
		vertex_base = vec2(-1.0, -1.0);
	} else if (gl_VertexIndex == 1) {
		vertex_base = vec2(-1.0, 3.0);
	} else {
		vertex_base = vec2(3.0, -1.0);
	}
	gl_Position = vec4(vertex_base, 0.0, 1.0);
	tex_coord = clamp(vertex_base, vec2(0.0, 0.0), vec2(1.0, 1.0)) * 2.0; // saturate(x) * 2.0

    offset[0] = fma(smaa.settings.SMAA_RT_METRICS.xyxy, vec4(-1.0, 0.0, 0.0, -1.0), tex_coord.xyxy);
    offset[1] = fma(smaa.settings.SMAA_RT_METRICS.xyxy, vec4(1.0, 0.0, 0.0, 1.0), tex_coord.xyxy);
    offset[2] = fma(smaa.settings.SMAA_RT_METRICS.xyxy, vec4(-2.0, 0.0, 0.0, -2.0), tex_coord.xyxy);
}

#[fragment]
#version 450

#include "smaa_settings_inc.glsl"

layout(location = 0) in vec2 tex_coord;
layout(location = 1) in vec4 offset[3];
layout(set = 0, binding = 0) uniform sampler2D depth_tex;
layout(location = 0) out vec2 edges;

#define SMAA_DEPTH_THRESHOLD (0.1 * smaa.settings.threshold)

vec3 SMAAGatherNeighbours() {
    return textureGather(depth_tex, tex_coord + smaa.settings.SMAA_RT_METRICS.xy * vec2(-0.5, -0.5)).grb;
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

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
layout(set = 1, binding = 0) uniform sampler2D color_tex;
layout(location = 0) out vec2 edges;

#define SMAA_LOCAL_CONTRAST_ADAPTATION_FACTOR 2.0

void main() {
    // TODO(?): Predicated Thresholding
    vec2 threshold = vec2(smaa.settings.threshold);
    vec3 weights = vec3(0.2126, 0.7152, 0.0722);
    float L = dot(texture(color_tex, tex_coord).xyz, weights);
    float Lleft = dot(texture(color_tex, offset[0].xy).xyz, weights);
    float Ltop = dot(texture(color_tex, offset[0].zw).xyz, weights);

    vec4 delta;
    delta.xy = abs(L - vec2(Lleft, Ltop));
    edges = step(threshold, delta.xy);

    if (dot(edges, vec2(1.0, 1.0)) == 0.0)
        discard;

    float Lright = dot(texture(color_tex, offset[1].xy).xyz, weights);
    float Lbottom = dot(texture(color_tex, offset[1].zw).xyz, weights);
    delta.zw = abs(L - vec2(Lright, Lbottom));

    vec2 maxDelta = max(delta.xy, delta.zw);

    float Lleftleft = dot(texture(color_tex, offset[2].xy).xyz, weights);
    float Ltoptop = dot(texture(color_tex, offset[2].zw).xyz, weights);
    delta.zw = abs(vec2(Lleft, Ltop) - vec2(Lleftleft, Ltoptop));

    maxDelta = max(maxDelta.xy, delta.zw);
    float finalDelta = max(maxDelta.x, maxDelta.y);

    edges.xy *= step(finalDelta, SMAA_LOCAL_CONTRAST_ADAPTATION_FACTOR * delta.xy);
}

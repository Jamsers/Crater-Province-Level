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
layout(set = 0, binding = 0) uniform sampler2D color_tex;
layout(location = 0) out vec2 edges;

layout(constant_id = 0) const float SMAA_THRESHOLD = 0.1;

layout(push_constant, std430) uniform Params {
    vec4 smaa_rt_metrics;
} params;

#define SMAA_LOCAL_CONTRAST_ADAPTATION_FACTOR 2.0
// SMAA requires that the source image isn't in sRGB
#define textureGamma(tex, uv) pow(texture(tex, uv), vec4(1 / 2.2))

void main() {
    // TODO(?): Predicated Thresholding
    vec2 threshold = vec2(SMAA_THRESHOLD);
    vec3 weights = vec3(0.2126, 0.7152, 0.0722);
    float L = dot(textureGamma(color_tex, tex_coord).xyz, weights);
    float Lleft = dot(textureGamma(color_tex, offset[0].xy).xyz, weights);
    float Ltop = dot(textureGamma(color_tex, offset[0].zw).xyz, weights);

    vec4 delta;
    delta.xy = abs(L - vec2(Lleft, Ltop));
    edges = step(threshold, delta.xy);

    if (dot(edges, vec2(1.0, 1.0)) == 0.0)
        discard;

    float Lright = dot(textureGamma(color_tex, offset[1].xy).xyz, weights);
    float Lbottom = dot(textureGamma(color_tex, offset[1].zw).xyz, weights);
    delta.zw = abs(L - vec2(Lright, Lbottom));

    vec2 maxDelta = max(delta.xy, delta.zw);

    float Lleftleft = dot(textureGamma(color_tex, offset[2].xy).xyz, weights);
    float Ltoptop = dot(textureGamma(color_tex, offset[2].zw).xyz, weights);
    delta.zw = abs(vec2(Lleft, Ltop) - vec2(Lleftleft, Ltoptop));

    maxDelta = max(maxDelta.xy, delta.zw);
    float finalDelta = max(maxDelta.x, maxDelta.y);

    edges.xy *= step(finalDelta, SMAA_LOCAL_CONTRAST_ADAPTATION_FACTOR * delta.xy);
}

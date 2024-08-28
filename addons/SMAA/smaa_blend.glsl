#[vertex]
#version 450
layout(location = 0) in vec4 vert;
layout(location = 0) out vec2 tex_coord;
layout(location = 1) out vec4 offset;

layout(push_constant, std430) uniform Params {
    vec4 smaa_rt_metrics;
} params;

void main() {
    offset = fma(params.smaa_rt_metrics.xyxy, vec4(1.0, 0.0, 0.0, 1.0), vert.zwzw);
    gl_Position = vec4(vert.xy, 1.0, 1.0);
    tex_coord = vert.zw;
}

#[fragment]
#version 450
layout(location = 0) in vec2 tex_coord;
layout(location = 1) in vec4 offset;
layout(set = 0, binding = 0) uniform sampler2D color_tex;
layout(set = 0, binding = 1) uniform sampler2D blend_tex;
layout(location = 0) out vec4 out_color;

layout(push_constant, std430) uniform Params {
    vec4 smaa_rt_metrics;
} params;

void SMAAMovc(bvec2 cond, inout vec2 variable, vec2 value) {
    if (cond.x) variable.x = value.x;
    if (cond.y) variable.y = value.y;
}

void SMAAMovc(bvec4 cond, inout vec4 variable, vec4 value) {
    SMAAMovc(cond.xy, variable.xy, value.xy);
    SMAAMovc(cond.zw, variable.zw, value.zw);
}

void main() {
    vec4 a;
    a.x = texture(blend_tex, offset.xy).a;
    a.y = texture(blend_tex, offset.zw).g;
    a.wz = texture(blend_tex, tex_coord).xz;

    if (dot(a, vec4(1.0, 1.0, 1.0, 1.0)) < 1e-5) {
        out_color = textureLod(color_tex, tex_coord, 0.0);
    } else {
        bool h = max(a.x, a.z) > max(a.y, a.w);

        vec4 blending_offset = vec4(0.0, a.y, 0.0, a.w);
        vec2 blending_weight = a.yw;
        
        SMAAMovc(bvec4(h, h, h, h), blending_offset, vec4(a.x, 0.0, a.z, 0.0));
        SMAAMovc(bvec2(h, h), blending_weight, a.xz);
        blending_weight /= dot(blending_weight, vec2(1.0, 1.0));

        vec4 blending_coord = fma(blending_offset, vec4(params.smaa_rt_metrics.xy, -params.smaa_rt_metrics.xy), tex_coord.xyxy);

        out_color = blending_weight.x * textureLod(color_tex, blending_coord.xy, 0.0);
        out_color += blending_weight.y * textureLod(color_tex, blending_coord.zw, 0.0);
    }
}

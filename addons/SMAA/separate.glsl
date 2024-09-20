#[vertex]
#version 450

layout(location = 0) in vec4 vert;
layout(location = 0) out vec2 tex_coord;

layout(push_constant, std430) uniform Params {
    vec2 inv_size;
    vec2 raster_size;
} params;

void main() {
    gl_Position = vec4(vert.xy, 1.0, 1.0);
    tex_coord = vert.zw;
}

#[fragment]
#version 450
layout(location = 0) in vec2 tex_coord;
layout(set = 0, binding = 0) uniform sampler2DMS src;
layout(location = 0) out vec4 out_color1;
layout(location = 1) out vec4 out_color2;

layout(push_constant, std430) uniform Parmas {
    vec2 inv_size;
    vec2 raster_size;
} params;

void main() {
    ivec2 uv = ivec2(tex_coord * params.raster_size);
    out_color1 = texelFetch(src, uv, 0);
    out_color2 = texelFetch(src, uv, 1);
}

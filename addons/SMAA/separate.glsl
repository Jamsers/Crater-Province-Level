#[vertex]
#version 450

layout(location = 0) out vec2 tex_coord;

layout(push_constant, std430) uniform Params {
    vec2 inv_size;
    vec2 raster_size;
} params;

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

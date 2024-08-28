#[vertex]
#version 450
layout(location = 0) in vec4 vert;
layout(location = 0) out vec2 tex_coord;

layout (constant_id = 0) const bool GAMMA_CORRECTION = false;

void main() {
    gl_Position = vec4(vert.xy, 1.0, 1.0);
    tex_coord = vert.zw;
}

#[fragment]
#version 450
layout(location = 0) in vec2 tex_coord;
layout(set = 0, binding = 0) uniform sampler2D color_tex;
layout(location = 0) out vec4 out_color;

layout (constant_id = 0) const bool GAMMA_CORRECTION = false;

void main() {
    if (GAMMA_CORRECTION) {
        out_color = pow(texture(color_tex, tex_coord), vec4(1 / 2.2));
    } else {
        out_color = texture(color_tex, tex_coord);
    }
}

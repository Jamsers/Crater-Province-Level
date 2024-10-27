// Included in smaa*.glsl files.

struct SmaaSettings {
    vec4 SMAA_RT_METRICS;

    float threshold;
    float max_search_steps;
    float max_search_steps_diag;
    float corner_rounding;

    bool disable_diag_detection;
    bool disable_corner_detection;
    vec2 reserved;
};

layout(set = 0, binding = 0) uniform SmaaSettingsBlock{
    SmaaSettings settings;
} smaa;


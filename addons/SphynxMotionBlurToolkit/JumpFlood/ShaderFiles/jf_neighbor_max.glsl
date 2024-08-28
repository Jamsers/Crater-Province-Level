#[compute]
#version 450

#define FLT_MAX 3.402823466e+38
#define FLT_MIN 1.175494351e-38

layout(set = 0, binding = 0) uniform sampler2D tile_max;
layout(set = 0, binding = 1) uniform sampler2D tile_max_map;
layout(rgba16f, set = 0, binding = 2) uniform writeonly image2D neighbor_max;

layout(push_constant, std430) uniform Params 
{	
	float nan5;
	float nan6;
	float nan7;
	float nan8;
	int nan1;
	int nan2;
	int nan3;
	int nan4;
} params;

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;


void main() 
{
	ivec2 render_size = ivec2(textureSize(tile_max, 0));
	ivec2 uvi = ivec2(gl_GlobalInvocationID.xy);
	if ((uvi.x >= render_size.x) || (uvi.y >= render_size.y)) 
	{
		return;
	}

	vec2 uvn = (vec2(uvi) + vec2(0.5)) / render_size;

	vec2 best_sample_uv = vec2(uvn);

	float max_neighbor_velocity_length = -1;

	for(int i = -1; i < 2; i++)
	{
		for(int j = -1; j < 2; j++)
		{
			vec2 current_offset = vec2(1) / vec2(render_size) * vec2(i, j);
			vec2 current_uv = uvn + current_offset;
			if(current_uv.x < 0 || current_uv.x > 1 || current_uv.y < 0 || current_uv.y > 1)
			{
				continue;
			}

			vec2 velocity_map_sample = textureLod(tile_max_map, current_uv, 0.0).xy;

			vec4 velocity_sample = textureLod(tile_max, velocity_map_sample, 0.0);

			float current_velocity_length = dot(velocity_sample.xy, velocity_sample.xy);
			
			if(current_velocity_length > max_neighbor_velocity_length)
			{
				max_neighbor_velocity_length = current_velocity_length;
				best_sample_uv = velocity_map_sample;
			}
		}
	}

	imageStore(neighbor_max, uvi, vec4(best_sample_uv, 0, 1));
}
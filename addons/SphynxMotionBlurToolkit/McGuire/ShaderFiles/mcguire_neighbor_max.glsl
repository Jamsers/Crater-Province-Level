#[compute]
#version 450

#define FLT_MAX 3.402823466e+38
#define FLT_MIN 1.175494351e-38

layout(set = 0, binding = 0) uniform sampler2D tile_max;
layout(rgba16f, set = 0, binding = 1) uniform writeonly image2D neighbor_max;

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

	vec2 max_neighbor_velocity = vec2(0);

	float max_neighbor_velocity_length = 0;

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

			bool is_diagonal = (abs(i) + abs(j) == 2);

			vec2 current_neighbor_velocity = textureLod(tile_max, current_uv, 0.0).xy;

			bool facing_center = dot(current_neighbor_velocity, current_offset) > 0;

			if(is_diagonal && !facing_center)
			{
				continue;
			}

			float current_neighbor_velocity_length = dot(current_neighbor_velocity, current_neighbor_velocity);
			if(current_neighbor_velocity_length > max_neighbor_velocity_length)
			{
				max_neighbor_velocity_length = current_neighbor_velocity_length;
				max_neighbor_velocity = current_neighbor_velocity;
			}
		}
	}

	imageStore(neighbor_max, uvi, vec4(max_neighbor_velocity, 0, 1));
}
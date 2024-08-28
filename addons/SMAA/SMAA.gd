@tool
extends CompositorEffect
class_name SMAA

# Change this if you move the SMAA folder elsewhere in your project
const SMAA_dir : String = "res://addons/SMAA/"

enum QualityLevel{LOW, MEDIUM, HIGH, ULTRA}
# Depth detection is pretty much broken. We need an inverse projection matrix
# Not much of a loss, since luma and color are usually way better.
enum EdgeDetectionMethod {LUMA, COLOR, DEPTH}
@export_group("SMAA")
@export var quality : QualityLevel = QualityLevel.MEDIUM
@export var edge_detection_method : EdgeDetectionMethod = EdgeDetectionMethod.LUMA
var previous_quality : QualityLevel = quality
var previous_edge_detection_method : EdgeDetectionMethod = edge_detection_method

var smaa_threshold : float = 0.1
var smaa_max_search_steps : int = 8
var smaa_disable_diag_detection : bool = true
var smaa_max_search_steps_diag : int = 0
var smaa_disable_corner_detection : bool = true
var smaa_corner_rounding : int = 0

var rd : RenderingDevice

var edge_shader : RID
var edge_pipeline : RID

var weight_shader : RID
var weight_pipeline : RID

var blend_shader : RID
var blend_pipeline : RID

# The output layer doesn't support copy operations, so we have to manually copy with a shader
var blit_shader : RID
var blit_pipeline : RID
var blit_gamma_pipeline : RID

var edges_tex : RID
var blend_tex : RID
var edges_framebuffer : RID
var blend_framebuffer : RID
# edges_tex only has r + g channels
var rg_framebuffer_format : int

var copy_tex : RID
var copy_framebuffer : RID

var area_tex : RID
var search_tex : RID

var nearest_sampler : RID
var linear_sampler : RID

var framebuffers : Array[RID]
var framebuffer_size : Vector2i = Vector2i(0, 0)
# Confirms that the output texture hasn't changed
var framebuffer_tex : RID
var framebuffer_format : int

var vertex_buffer : RID
var vertex_array : RID

func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	rd = RenderingServer.get_rendering_device()
	RenderingServer.call_on_render_thread(_initiate_post_process)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Pipelines are cleaned up automatically by freeing their shader
		if edge_shader.is_valid():
			RenderingServer.free_rid(edge_shader)
		if weight_shader.is_valid():
			RenderingServer.free_rid(weight_shader)
		if blend_shader.is_valid():
			RenderingServer.free_rid(blend_shader)
		if blit_shader.is_valid():
			RenderingServer.free_rid(blit_shader)
		if area_tex.is_valid():
			RenderingServer.free_rid(area_tex)
		if search_tex.is_valid():
			RenderingServer.free_rid(search_tex)
		if edges_tex.is_valid():
			RenderingServer.free_rid(edges_tex)
		if blend_tex.is_valid():
			RenderingServer.free_rid(blend_tex)
		if copy_tex.is_valid():
			RenderingServer.free_rid(copy_tex)
		if nearest_sampler.is_valid():
			RenderingServer.free_rid(nearest_sampler)
		if linear_sampler.is_valid():
			RenderingServer.free_rid(linear_sampler)
		if vertex_buffer.is_valid():
			RenderingServer.free_rid(vertex_buffer)
		if vertex_array.is_valid():
			RenderingServer.free_rid(vertex_array)

# Based off of the SMAA developers quality settings
func _get_smaa_parameters() -> void:
	match quality:
		QualityLevel.LOW:
			smaa_threshold = 0.15
			smaa_max_search_steps = 4
			smaa_disable_diag_detection = true
			smaa_disable_corner_detection = true
		QualityLevel.MEDIUM:
			smaa_threshold = 0.1
			smaa_max_search_steps = 8
			smaa_disable_diag_detection = true
			smaa_disable_corner_detection = true
		QualityLevel.HIGH:
			smaa_threshold = 0.1
			smaa_max_search_steps = 16
			smaa_disable_diag_detection = false
			smaa_max_search_steps_diag = 8
			smaa_disable_corner_detection = false
			smaa_corner_rounding = 25
		QualityLevel.ULTRA:
			smaa_threshold = 0.05
			smaa_max_search_steps = 32
			smaa_disable_diag_detection = false
			smaa_max_search_steps_diag = 16
			smaa_disable_corner_detection = false
			smaa_corner_rounding = 25

func _create_pipelines() -> void:
	_get_smaa_parameters()
	var va := RDVertexAttribute.new()
	va.stride = 16
	va.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT

	var color_blend := RDPipelineColorBlendState.new()
	color_blend.attachments = [RDPipelineColorBlendStateAttachment.new()]

	# Edge detection shader's specialization constant
	var threshold_constant : RDPipelineSpecializationConstant = RDPipelineSpecializationConstant.new()
	threshold_constant.constant_id = 0
	threshold_constant.value = smaa_threshold

	# Weight calculation shader's specialization constants
	var max_search_constant : RDPipelineSpecializationConstant = RDPipelineSpecializationConstant.new()
	max_search_constant.constant_id = 0
	max_search_constant.value = smaa_max_search_steps
	var disable_diag_constant : RDPipelineSpecializationConstant = RDPipelineSpecializationConstant.new()
	disable_diag_constant.constant_id = 1
	disable_diag_constant.value = smaa_disable_diag_detection
	var max_search_diag_constant : RDPipelineSpecializationConstant = RDPipelineSpecializationConstant.new()
	max_search_diag_constant.constant_id = 2
	max_search_diag_constant.value = smaa_max_search_steps_diag
	var disable_corner_constant : RDPipelineSpecializationConstant = RDPipelineSpecializationConstant.new()
	threshold_constant.constant_id = 3
	threshold_constant.value = smaa_threshold
	var corner_rounding_constant : RDPipelineSpecializationConstant = RDPipelineSpecializationConstant.new()
	corner_rounding_constant.constant_id = 4
	corner_rounding_constant.value = smaa_corner_rounding

	var gamma_correction : RDPipelineSpecializationConstant = RDPipelineSpecializationConstant.new()
	gamma_correction.constant_id = 0

	if edge_shader.is_valid():
		edge_pipeline = rd.render_pipeline_create(edge_shader, rg_framebuffer_format,
			rd.vertex_format_create([va]), RenderingDevice.RENDER_PRIMITIVE_TRIANGLES, RDPipelineRasterizationState.new(),
			RDPipelineMultisampleState.new(), RDPipelineDepthStencilState.new(),
			color_blend, 0, 0, [threshold_constant]
		)
	if weight_shader.is_valid():
		weight_pipeline = rd.render_pipeline_create(weight_shader, framebuffer_format,
			rd.vertex_format_create([va]), RenderingDevice.RENDER_PRIMITIVE_TRIANGLES, RDPipelineRasterizationState.new(),
			RDPipelineMultisampleState.new(), RDPipelineDepthStencilState.new(),
			color_blend, 0, 0, [max_search_constant, disable_diag_constant, max_search_diag_constant, disable_corner_constant, corner_rounding_constant]
		)
	if blend_shader.is_valid():
		blend_pipeline = rd.render_pipeline_create(blend_shader, framebuffer_format,
			rd.vertex_format_create([va]), RenderingDevice.RENDER_PRIMITIVE_TRIANGLES, RDPipelineRasterizationState.new(),
			RDPipelineMultisampleState.new(), RDPipelineDepthStencilState.new(),
			color_blend
		)
	if blit_shader.is_valid():
		gamma_correction.value = false
		blit_pipeline = rd.render_pipeline_create(blit_shader, framebuffer_format,
			rd.vertex_format_create([va]), RenderingDevice.RENDER_PRIMITIVE_TRIANGLES, RDPipelineRasterizationState.new(),
			RDPipelineMultisampleState.new(), RDPipelineDepthStencilState.new(),
			color_blend, 0, 0, [gamma_correction]
		)
		gamma_correction.value = true
		blit_gamma_pipeline = rd.render_pipeline_create(blit_shader, framebuffer_format,
			rd.vertex_format_create([va]), RenderingDevice.RENDER_PRIMITIVE_TRIANGLES, RDPipelineRasterizationState.new(),
			RDPipelineMultisampleState.new(), RDPipelineDepthStencilState.new(),
			color_blend, 0, 0, [gamma_correction]
		)

func _clean_pipelines() -> void:
	if edge_pipeline.is_valid():
		RenderingServer.free_rid(edge_pipeline)
	if weight_pipeline.is_valid():
		RenderingServer.free_rid(weight_pipeline)
	if blend_pipeline.is_valid():
		RenderingServer.free_rid(blend_pipeline)
	if blit_pipeline.is_valid():
		RenderingServer.free_rid(blit_pipeline)
	if blit_gamma_pipeline.is_valid():
		RenderingServer.free_rid(blit_gamma_pipeline)

func _recreate_edge_pipeline() -> void:
	if edge_shader.is_valid():
		RenderingServer.free_rid(edge_shader)
	if edge_pipeline.is_valid():
		RenderingServer.free_rid(edge_pipeline)

	var shader_file
	match edge_detection_method:
		EdgeDetectionMethod.LUMA:
			shader_file = load(SMAA_dir + "smaa_edge_luma.glsl")
		EdgeDetectionMethod.COLOR:
			shader_file = load(SMAA_dir + "smaa_edge_color.glsl")
		EdgeDetectionMethod.DEPTH:
			shader_file = load(SMAA_dir + "smaa_edge_depth.glsl")
		_:
			shader_file = load(SMAA_dir + "smaa_edge_luma.glsl")
	var shader_spirv = shader_file.get_spirv()
	edge_shader = rd.shader_create_from_spirv(shader_spirv)

	var va := RDVertexAttribute.new()
	va.stride = 16
	va.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT

	var color_blend := RDPipelineColorBlendState.new()
	color_blend.attachments = [RDPipelineColorBlendStateAttachment.new()]

	var threshold_constant : RDPipelineSpecializationConstant = RDPipelineSpecializationConstant.new()
	threshold_constant.constant_id = 0
	threshold_constant.value = smaa_threshold

	if edge_shader.is_valid():
		edge_pipeline = rd.render_pipeline_create(edge_shader, rg_framebuffer_format,
			rd.vertex_format_create([va]), RenderingDevice.RENDER_PRIMITIVE_TRIANGLES, RDPipelineRasterizationState.new(),
			RDPipelineMultisampleState.new(), RDPipelineDepthStencilState.new(),
			color_blend, 0, 0, [threshold_constant]
		)

func _initiate_post_process() -> void:
	rd = RenderingServer.get_rendering_device()
	if not rd:
		return

	var shader_file
	match edge_detection_method:
		EdgeDetectionMethod.LUMA:
			shader_file = load(SMAA_dir + "smaa_edge_luma.glsl")
		EdgeDetectionMethod.COLOR:
			shader_file = load(SMAA_dir + "smaa_edge_color.glsl")
		EdgeDetectionMethod.DEPTH:
			shader_file = load(SMAA_dir + "smaa_edge_depth.glsl")
		_:
			shader_file = load(SMAA_dir + "smaa_edge_luma.glsl")
	var shader_spirv : RDShaderSPIRV = shader_file.get_spirv()
	edge_shader = rd.shader_create_from_spirv(shader_spirv)

	shader_file = load(SMAA_dir + "smaa_weight.glsl")
	shader_spirv = shader_file.get_spirv()
	weight_shader = rd.shader_create_from_spirv(shader_spirv)

	shader_file = load(SMAA_dir + "smaa_blend.glsl")
	shader_spirv = shader_file.get_spirv()
	blend_shader = rd.shader_create_from_spirv(shader_spirv)

	shader_file = load(SMAA_dir + "blit.glsl")
	shader_spirv = shader_file.get_spirv()
	blit_shader = rd.shader_create_from_spirv(shader_spirv)

	var smaa_tex = preload(SMAA_dir + "SearchTex.dds")
	var tf : RDTextureFormat = RDTextureFormat.new()
	tf.format = RenderingDevice.DATA_FORMAT_R8_UNORM
	tf.width = smaa_tex.get_width()
	tf.height = smaa_tex.get_height()
	tf.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	search_tex = rd.texture_create(tf, RDTextureView.new(), [smaa_tex.get_image().get_data()])

	# Needed to compress AreaTex(DX10) with BC5 to sample from it for some reason.
	# The difference should be unnoticeable
	smaa_tex = preload(SMAA_dir + "AreaTex.dds")
	tf.format = RenderingDevice.DATA_FORMAT_BC5_UNORM_BLOCK
	tf.width = smaa_tex.get_width()
	tf.height = smaa_tex.get_height()
	tf.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	area_tex = rd.texture_create(tf, RDTextureView.new(), [smaa_tex.get_image().get_data()])

	var verts := PackedFloat32Array([
		-1.0, -1.0, 0.0, 0.0,
		-1.0, 3.0, 0.0, 2.0,
		3.0, -1.0, 2.0, 0.0,
	])
	var va := RDVertexAttribute.new()
	va.stride = 16
	va.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT

	vertex_buffer = rd.vertex_buffer_create(verts.size() * 4, verts.to_byte_array(), true)
	vertex_array = rd.vertex_array_create(3, rd.vertex_format_create([va]), [vertex_buffer], [])

	var sampler_state := RDSamplerState.new()
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	nearest_sampler = rd.sampler_create(sampler_state)
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	linear_sampler = rd.sampler_create(sampler_state)

	var attachment_format : RDAttachmentFormat = RDAttachmentFormat.new()
	attachment_format.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	attachment_format.usage_flags = RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT
	framebuffer_format = rd.framebuffer_format_create([attachment_format])
	# edges_tex only has r + g channels, so we need a different framebuffer format
	attachment_format.format = RenderingDevice.DATA_FORMAT_R16G16_SFLOAT
	rg_framebuffer_format = rd.framebuffer_format_create([attachment_format])

	_create_pipelines()

func _create_textures(size: Vector2i) -> void:
	var tf : RDTextureFormat = RDTextureFormat.new()
	tf.format = RenderingDevice.DATA_FORMAT_R16G16_SFLOAT
	tf.width = size.x
	tf.height = size.y
	tf.usage_bits = (RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT |
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT)
	edges_tex = rd.texture_create(tf, RDTextureView.new())
	tf.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	blend_tex = rd.texture_create(tf, RDTextureView.new())
	copy_tex = rd.texture_create(tf, RDTextureView.new())

	edges_framebuffer = rd.framebuffer_create([edges_tex])
	blend_framebuffer = rd.framebuffer_create([blend_tex])
	copy_framebuffer = rd.framebuffer_create([copy_tex])

func _blit_pipeline_create_uniforms(source : RID) -> RID:
	var uniform : RDUniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	uniform.binding = 0
	uniform.clear_ids()
	uniform.add_id(linear_sampler)
	uniform.add_id(source)
	return UniformSetCacheRD.get_cache(blit_shader, 0, [uniform])

func _edge_pipeline_create_uniforms(source : RID) -> RID:
	var uniform : RDUniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	uniform.binding = 0
	uniform.add_id(nearest_sampler)
	uniform.add_id(source)
	return UniformSetCacheRD.get_cache(edge_shader, 0, [uniform])

func _weight_pipeline_create_uniforms() -> RID:
	var edges_tex_uniform : RDUniform = RDUniform.new()
	edges_tex_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	edges_tex_uniform.binding = 0
	edges_tex_uniform.add_id(linear_sampler)
	edges_tex_uniform.add_id(edges_tex)
	var area_tex_uniform : RDUniform = RDUniform.new()
	area_tex_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	area_tex_uniform.binding = 1
	area_tex_uniform.add_id(linear_sampler)
	area_tex_uniform.add_id(area_tex)
	var search_tex_uniform : RDUniform = RDUniform.new()
	search_tex_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	search_tex_uniform.binding = 2
	search_tex_uniform.add_id(linear_sampler)
	search_tex_uniform.add_id(search_tex)
	return UniformSetCacheRD.get_cache(weight_shader, 0, [edges_tex_uniform, area_tex_uniform, search_tex_uniform])

func _blend_pipeline_create_uniforms() -> RID:
	var color_tex_uniform : RDUniform = RDUniform.new()
	color_tex_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	color_tex_uniform.binding = 0
	color_tex_uniform.add_id(linear_sampler)
	color_tex_uniform.add_id(copy_tex)
	var blend_tex_uniform : RDUniform = RDUniform.new()
	blend_tex_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	blend_tex_uniform.binding = 1
	blend_tex_uniform.add_id(linear_sampler)
	blend_tex_uniform.add_id(blend_tex)
	return UniformSetCacheRD.get_cache(blend_shader, 0, [color_tex_uniform, blend_tex_uniform])

func _render_callback(p_effect_callback_type: int, p_render_data: RenderData) -> void:
	if rd and p_effect_callback_type == EFFECT_CALLBACK_TYPE_POST_TRANSPARENT and edge_shader.is_valid() and weight_shader.is_valid() and blend_shader.is_valid() and blit_shader.is_valid():
		var render_scene_buffers : RenderSceneBuffersRD = p_render_data.get_render_scene_buffers()
		if render_scene_buffers:
			var view_count = render_scene_buffers.get_view_count()
			var size : Vector2i = render_scene_buffers.get_internal_size()
			if size.x == 0 and size.y == 0:
				return

			# We now have a different number of views(?) or this is the first frame
			if view_count != framebuffers.size():
				framebuffer_tex = render_scene_buffers.get_color_layer(0)
				for view in framebuffers.size():
					if framebuffers[view].is_valid():
						RenderingServer.free_rid(framebuffers[view])
				framebuffers.resize(view_count)
				for view in view_count:
					framebuffers[view] = rd.framebuffer_create([render_scene_buffers.get_color_layer(view)])

			# Our window has resized
			if size != framebuffer_size:
				framebuffer_tex = render_scene_buffers.get_color_layer(0)
				framebuffer_size = size
				# Associated framebuffers are dependent on these textures
				# they should be freed with them
				if edges_tex.is_valid():
					RenderingServer.free_rid(edges_tex)
				if blend_tex.is_valid():
					RenderingServer.free_rid(blend_tex)
				if copy_tex.is_valid():
					RenderingServer.free_rid(blend_tex)
				for view in view_count:
					if framebuffers[view].is_valid():
						RenderingServer.free_rid(framebuffers[view])
					framebuffers[view] = rd.framebuffer_create([render_scene_buffers.get_color_layer(view)])
				_create_textures(size)

			# Output framebuffers are no longer valid
			if framebuffer_tex != render_scene_buffers.get_color_layer(0):
				framebuffer_tex = render_scene_buffers.get_color_layer(0)
				for view in view_count:
					framebuffers[view] = rd.framebuffer_create([render_scene_buffers.get_color_layer(view)])

			if previous_edge_detection_method != edge_detection_method:
				_recreate_edge_pipeline()
				previous_edge_detection_method = edge_detection_method

			if previous_quality != quality:
				_clean_pipelines()
				_create_pipelines()
				previous_quality = quality

			var push_constant : PackedFloat32Array = PackedFloat32Array([
					1.0 / size.x, 1.0 / size.y, size.x, size.y
			])
			rd.draw_command_begin_label("SMAA", Color.WHITE)
			for view in view_count:
				var color_image : RID = render_scene_buffers.get_color_layer(view)
				var depth_image : RID = render_scene_buffers.get_depth_layer(view)

				# First Pass: Edge Detection
				rd.draw_command_begin_label("SMAA Edge Detection" + str(view), Color.WHITE)
				var uniform_set : RID
				if (edge_detection_method != EdgeDetectionMethod.DEPTH):
					uniform_set = _edge_pipeline_create_uniforms(color_image)
				else:
					uniform_set = _edge_pipeline_create_uniforms(depth_image)
				var draw_list = rd.draw_list_begin(edges_framebuffer,
					RenderingDevice.INITIAL_ACTION_CLEAR,
					RenderingDevice.FINAL_ACTION_STORE,
					RenderingDevice.INITIAL_ACTION_DISCARD,
					RenderingDevice.FINAL_ACTION_DISCARD,
					PackedColorArray([Color(0.0, 0.0, 0.0, 0.0)])
				)
				rd.draw_list_bind_render_pipeline(draw_list, edge_pipeline)
				rd.draw_list_bind_uniform_set(draw_list, uniform_set, 0)
				rd.draw_list_set_push_constant(draw_list, push_constant.to_byte_array(), push_constant.size() * 4)
				rd.draw_list_bind_vertex_array(draw_list, vertex_array)
				rd.draw_list_draw(draw_list, false, 1)
				rd.draw_list_end()
				rd.draw_command_end_label()

				# Second Pass: Blending weight calculation
				rd.draw_command_begin_label("SMAA Blending Weight Calculation" + str(view), Color.WHITE)
				uniform_set = _weight_pipeline_create_uniforms()
				draw_list = rd.draw_list_begin(blend_framebuffer,
					RenderingDevice.INITIAL_ACTION_CLEAR,
					RenderingDevice.FINAL_ACTION_STORE,
					RenderingDevice.INITIAL_ACTION_DISCARD,
					RenderingDevice.FINAL_ACTION_DISCARD,
					PackedColorArray([Color(0.0, 0.0, 0.0, 0.0)])
				)
				rd.draw_list_bind_render_pipeline(draw_list, weight_pipeline)
				rd.draw_list_bind_uniform_set(draw_list, uniform_set, 0)
				rd.draw_list_set_push_constant(draw_list, push_constant.to_byte_array(), push_constant.size() * 4)
				rd.draw_list_bind_vertex_array(draw_list, vertex_array)
				rd.draw_list_draw(draw_list, false, 1)
				rd.draw_list_end()
				rd.draw_command_end_label()

				# Copy source image to copy buffer for input in 3rd pass
				# Note: color_image doesn't support any copy opperations, so we have to use a shader for this
				rd.draw_command_begin_label("SMAA Copy Source Image" + str(view), Color.WHITE)
				uniform_set = _blit_pipeline_create_uniforms(color_image)
				draw_list = rd.draw_list_begin(copy_framebuffer,
					RenderingDevice.INITIAL_ACTION_DISCARD,
					RenderingDevice.FINAL_ACTION_STORE,
					RenderingDevice.INITIAL_ACTION_DISCARD,
					RenderingDevice.FINAL_ACTION_DISCARD,
				)
				rd.draw_list_bind_render_pipeline(draw_list, blit_pipeline)
				rd.draw_list_bind_uniform_set(draw_list, uniform_set, 0)
				rd.draw_list_bind_vertex_array(draw_list, vertex_array)
				rd.draw_list_draw(draw_list, false, 1)
				rd.draw_list_end()
				rd.draw_command_end_label()

				# Third Pass: Neighborhood Blending
				rd.draw_command_begin_label("SMAA Neighborhood Blending" + str(view), Color.WHITE)
				uniform_set = _blend_pipeline_create_uniforms()
				draw_list = rd.draw_list_begin(framebuffers[view],
					RenderingDevice.INITIAL_ACTION_DISCARD,
					RenderingDevice.FINAL_ACTION_STORE,
					RenderingDevice.INITIAL_ACTION_DISCARD,
					RenderingDevice.FINAL_ACTION_DISCARD,
				)
				rd.draw_list_bind_render_pipeline(draw_list, blend_pipeline)
				rd.draw_list_bind_uniform_set(draw_list, uniform_set, 0)
				rd.draw_list_set_push_constant(draw_list, push_constant.to_byte_array(), push_constant.size() * 4)
				rd.draw_list_bind_vertex_array(draw_list, vertex_array)
				rd.draw_list_draw(draw_list, false, 1)
				rd.draw_list_end()
				rd.draw_command_end_label()

			rd.draw_command_end_label()

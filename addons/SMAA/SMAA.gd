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

var separate_shader : RID
var separate_pipeline : RID

var edges_tex : RID
var blend_tex : RID

var single_sample_tex : Array[RID]

var copy_tex : RID

var area_tex : RID
var search_tex : RID

var nearest_sampler : RID
var linear_sampler : RID

var framebuffer_size : Vector2i = Vector2i(0, 0)
var framebuffer_format : int
# edges_tex only has r + g channels
var rg_framebuffer_format : int

var S2x : bool = false

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
			rd.free_rid(edge_shader)
		if weight_shader.is_valid():
			rd.free_rid(weight_shader)
		if blend_shader.is_valid():
			rd.free_rid(blend_shader)
		if blit_shader.is_valid():
			rd.free_rid(blit_shader)
		if separate_shader.is_valid():
			rd.free_rid(separate_shader)
		# Can't use _clean_textures() here
		if edges_tex.is_valid():
			rd.free_rid(edges_tex)
		if blend_tex.is_valid():
			rd.free_rid(blend_tex)
		if copy_tex.is_valid():
			rd.free_rid(copy_tex)
		if single_sample_tex[0].is_valid():
			rd.free_rid(single_sample_tex[0])
		if single_sample_tex[1].is_valid():
			rd.free_rid(single_sample_tex[1])
		if nearest_sampler.is_valid():
			rd.free_rid(nearest_sampler)
		if linear_sampler.is_valid():
			rd.free_rid(linear_sampler)
		if vertex_buffer.is_valid():
			rd.free_rid(vertex_buffer)
		if vertex_array.is_valid():
			rd.free_rid(vertex_array)

# Based off of the SMAA developer's quality settings
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

	var no_blend := RDPipelineColorBlendState.new()
	no_blend.attachments = [RDPipelineColorBlendStateAttachment.new()]
	var blend_constant_alpha := RDPipelineColorBlendState.new()
	var blend_attachment := RDPipelineColorBlendStateAttachment.new()
	blend_attachment.enable_blend = true
	blend_attachment.color_blend_op = RenderingDevice.BLEND_OP_ADD
	blend_attachment.src_color_blend_factor = RenderingDevice.BLEND_FACTOR_CONSTANT_ALPHA
	blend_attachment.dst_color_blend_factor = RenderingDevice.BLEND_FACTOR_ONE_MINUS_CONSTANT_ALPHA
	blend_attachment.alpha_blend_op = RenderingDevice.BLEND_OP_ADD
	blend_attachment.src_alpha_blend_factor = RenderingDevice.BLEND_FACTOR_CONSTANT_ALPHA
	blend_attachment.dst_alpha_blend_factor = RenderingDevice.BLEND_FACTOR_ONE_MINUS_CONSTANT_ALPHA
	blend_constant_alpha.attachments = [blend_attachment]

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

	if edge_shader.is_valid():
		edge_pipeline = rd.render_pipeline_create(edge_shader, rg_framebuffer_format,
			rd.vertex_format_create([va]), RenderingDevice.RENDER_PRIMITIVE_TRIANGLES, RDPipelineRasterizationState.new(),
			RDPipelineMultisampleState.new(), RDPipelineDepthStencilState.new(),
			no_blend, 0, 0, [threshold_constant]
		)
	if weight_shader.is_valid():
		weight_pipeline = rd.render_pipeline_create(weight_shader, framebuffer_format,
			rd.vertex_format_create([va]), RenderingDevice.RENDER_PRIMITIVE_TRIANGLES, RDPipelineRasterizationState.new(),
			RDPipelineMultisampleState.new(), RDPipelineDepthStencilState.new(),
			no_blend, 0, 0, [max_search_constant, disable_diag_constant, max_search_diag_constant, disable_corner_constant, corner_rounding_constant]
		)
	if blend_shader.is_valid():
		blend_pipeline = rd.render_pipeline_create(blend_shader, framebuffer_format,
			rd.vertex_format_create([va]), RenderingDevice.RENDER_PRIMITIVE_TRIANGLES, RDPipelineRasterizationState.new(),
			RDPipelineMultisampleState.new(), RDPipelineDepthStencilState.new(),
			blend_constant_alpha, RenderingDevice.DYNAMIC_STATE_BLEND_CONSTANTS
		)

func _clean_pipelines() -> void:
	if edge_pipeline.is_valid():
		rd.free_rid(edge_pipeline)
	if weight_pipeline.is_valid():
		rd.free_rid(weight_pipeline)
	if blend_pipeline.is_valid():
		rd.free_rid(blend_pipeline)

func _clean_textures() -> void:
	# Associated framebuffers are dependent on these textures
	# they're freed with them
	if edges_tex.is_valid():
		rd.free_rid(edges_tex)
	if blend_tex.is_valid():
		rd.free_rid(blend_tex)
	if !S2x:
		if copy_tex.is_valid():
			rd.free_rid(copy_tex)
	else:
		if single_sample_tex[0].is_valid():
			rd.free_rid(single_sample_tex[0])
		if single_sample_tex[1].is_valid():
			rd.free_rid(single_sample_tex[1])

func _recreate_edge_pipeline() -> void:
	if edge_shader.is_valid():
		rd.free_rid(edge_shader)

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

	shader_file = load(SMAA_dir + "separate.glsl")
	shader_spirv = shader_file.get_spirv()
	separate_shader = rd.shader_create_from_spirv(shader_spirv)

	single_sample_tex.resize(2)

	var smaa_tex = preload(SMAA_dir + "SearchTex.dds")
	search_tex = RenderingServer.texture_get_rd_texture(smaa_tex.get_rid())

	# Needed to compress AreaTex(DX10) with BC5 to sample from it for some reason.
	# The difference should be unnoticeable
	smaa_tex = preload(SMAA_dir + "AreaTex.dds")
	area_tex = RenderingServer.texture_get_rd_texture(smaa_tex.get_rid())

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
	var dual_output_framebuffer_format = rd.framebuffer_format_create([attachment_format, attachment_format])
	# edges_tex only has r + g channels, so we need a different framebuffer format
	attachment_format.format = RenderingDevice.DATA_FORMAT_R16G16_SFLOAT
	rg_framebuffer_format = rd.framebuffer_format_create([attachment_format])

	var no_blend := RDPipelineColorBlendState.new()
	var color_attachment := RDPipelineColorBlendStateAttachment.new()
	no_blend.attachments = [color_attachment]
	var dual_color_blend := RDPipelineColorBlendState.new()
	dual_color_blend.attachments = [color_attachment, color_attachment]

	# These pipelines aren't configured with specialization constants, so make them here
	if blit_shader.is_valid():
		blit_pipeline = rd.render_pipeline_create(blit_shader, framebuffer_format,
			rd.vertex_format_create([va]), RenderingDevice.RENDER_PRIMITIVE_TRIANGLES, RDPipelineRasterizationState.new(),
			RDPipelineMultisampleState.new(), RDPipelineDepthStencilState.new(),
			no_blend
		)
	if separate_shader.is_valid():
		separate_pipeline = rd.render_pipeline_create(separate_shader, dual_output_framebuffer_format,
			rd.vertex_format_create([va]), RenderingDevice.RENDER_PRIMITIVE_TRIANGLES, RDPipelineRasterizationState.new(),
			RDPipelineMultisampleState.new(), RDPipelineDepthStencilState.new(),
			dual_color_blend
		)

	previous_quality = quality
	previous_edge_detection_method = edge_detection_method
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
	if !S2x:
		copy_tex = rd.texture_create(tf, RDTextureView.new())
	else:
		single_sample_tex[0] = rd.texture_create(tf, RDTextureView.new())
		single_sample_tex[1] = rd.texture_create(tf, RDTextureView.new())

func _toggle_S2x(size : Vector2i) -> void:
	var tf : RDTextureFormat = RDTextureFormat.new()
	tf.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	tf.width = size.x
	tf.height = size.y
	tf.usage_bits = (RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT |
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT)

	if !S2x:
		if copy_tex.is_valid():
			rd.free_rid(copy_tex)
	else:
		if single_sample_tex[0].is_valid():
			rd.free_rid(single_sample_tex[0])
		if single_sample_tex[1].is_valid():
			rd.free_rid(single_sample_tex[1])

	S2x = !S2x
	if !S2x:
		copy_tex = rd.texture_create(tf, RDTextureView.new())
	else:
		single_sample_tex[0] = rd.texture_create(tf, RDTextureView.new())
		single_sample_tex[1] = rd.texture_create(tf, RDTextureView.new())

func _blit_pipeline_create_uniforms(source : RID) -> RID:
	var uniform : RDUniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	uniform.binding = 0
	uniform.clear_ids()
	uniform.add_id(nearest_sampler)
	uniform.add_id(source)
	return UniformSetCacheRD.get_cache(blit_shader, 0, [uniform])

func _separate_pipeline_create_uniforms(source : RID) -> RID:
	var uniform : RDUniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	uniform.binding = 0
	uniform.clear_ids()
	uniform.add_id(nearest_sampler)
	uniform.add_id(source)
	return UniformSetCacheRD.get_cache(separate_shader, 0, [uniform])

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

func _blend_pipeline_create_uniforms(input : RID) -> RID:
	var color_tex_uniform : RDUniform = RDUniform.new()
	color_tex_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	color_tex_uniform.binding = 0
	color_tex_uniform.add_id(linear_sampler)
	color_tex_uniform.add_id(input)
	var blend_tex_uniform : RDUniform = RDUniform.new()
	blend_tex_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	blend_tex_uniform.binding = 1
	blend_tex_uniform.add_id(linear_sampler)
	blend_tex_uniform.add_id(blend_tex)
	return UniformSetCacheRD.get_cache(blend_shader, 0, [color_tex_uniform, blend_tex_uniform])

func _smaa_process(input : RID, edges_input : RID, output_framebuffer : RID, view : int, blend_alpha : float = 1.0) -> void:
	var edges_framebuffer = FramebufferCacheRD.get_cache_multipass([edges_tex], [], 1)
	var blend_framebuffer = FramebufferCacheRD.get_cache_multipass([blend_tex], [], 1)
	var push_constant : PackedFloat32Array = PackedFloat32Array([
		1.0 / framebuffer_size.x, 1.0 / framebuffer_size.y, framebuffer_size.x, framebuffer_size.y
	])
	# First Pass: Edge Detection
	rd.draw_command_begin_label("SMAA Edge Detection" + str(view), Color.WHITE)
	var uniform_set : RID
	uniform_set = _edge_pipeline_create_uniforms(edges_input)
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

	# We can't use subsample indices for S2x since we have no way of knowing
	# where the samples were taken from.
	push_constant.push_back(0.0)
	push_constant.push_back(0.0)
	push_constant.push_back(0.0)
	push_constant.push_back(0.0)
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


	push_constant.clear()
	push_constant.push_back(1.0 / framebuffer_size.x)
	push_constant.push_back(1.0 / framebuffer_size.y)
	push_constant.push_back(framebuffer_size.x)
	push_constant.push_back(framebuffer_size.y)
	# Third Pass: Neighborhood Blending
	rd.draw_command_begin_label("SMAA Neighborhood Blending" + str(view), Color.WHITE)
	uniform_set = _blend_pipeline_create_uniforms(input)
	draw_list = rd.draw_list_begin(output_framebuffer,
		RenderingDevice.INITIAL_ACTION_DISCARD,
		RenderingDevice.FINAL_ACTION_STORE,
		RenderingDevice.INITIAL_ACTION_DISCARD,
		RenderingDevice.FINAL_ACTION_DISCARD,
	)
	rd.draw_list_set_blend_constants(draw_list, Color(0.0, 0.0, 0.0, blend_alpha))
	rd.draw_list_bind_render_pipeline(draw_list, blend_pipeline)
	rd.draw_list_bind_uniform_set(draw_list, uniform_set, 0)
	rd.draw_list_set_push_constant(draw_list, push_constant.to_byte_array(), push_constant.size() * 4)
	rd.draw_list_bind_vertex_array(draw_list, vertex_array)
	rd.draw_list_draw(draw_list, false, 1)
	rd.draw_list_end()
	rd.draw_command_end_label()

func _render_callback(p_effect_callback_type: int, p_render_data: RenderData) -> void:
	if rd and p_effect_callback_type == EFFECT_CALLBACK_TYPE_POST_TRANSPARENT and edge_shader.is_valid() and weight_shader.is_valid() and blend_shader.is_valid() and blit_shader.is_valid():
		var render_scene_buffers : RenderSceneBuffersRD = p_render_data.get_render_scene_buffers()
		if render_scene_buffers:
			var view_count = render_scene_buffers.get_view_count()
			var size : Vector2i = render_scene_buffers.get_internal_size()
			if size.x == 0 and size.y == 0:
				return

			# Our window has resized
			if size != framebuffer_size:
				framebuffer_size = size
				_clean_textures()
				S2x = render_scene_buffers.get_msaa_3d() == RenderingServer.VIEWPORT_MSAA_2X
				_create_textures(size)

			if (S2x and render_scene_buffers.get_msaa_3d() != 1) or (!S2x and render_scene_buffers.get_msaa_3d() == 1):
				_toggle_S2x(size)

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
				var color_image : RID = render_scene_buffers.get_color_layer(view, S2x)
				var depth_image : RID
				if edge_detection_method == EdgeDetectionMethod.DEPTH:
					depth_image = render_scene_buffers.get_depth_layer(view, false)
				var copy_framebuffer = FramebufferCacheRD.get_cache_multipass([copy_tex], [], 1)
				var output_framebuffer = FramebufferCacheRD.get_cache_multipass([color_image], [], 1)

				if !S2x:
					# Copy source image to copy buffer for input in 3rd pass
					# Note: color_image doesn't support any copy opperations, so we have to use a shader for this
					rd.draw_command_begin_label("SMAA Copy Source Image" + str(view), Color.WHITE)
					var uniform_set = _blit_pipeline_create_uniforms(color_image)
					var draw_list = rd.draw_list_begin(copy_framebuffer,
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

					if edge_detection_method != EdgeDetectionMethod.DEPTH:
						_smaa_process(copy_tex, color_image, output_framebuffer, view)
					else:
						_smaa_process(copy_tex, depth_image, output_framebuffer, view)
				else:
					var single_sample_framebuffer = FramebufferCacheRD.get_cache_multipass(single_sample_tex, [], 1)
					rd.draw_command_begin_label("SMAA Separate MSAA" + str(view), Color.WHITE)
					var uniform_set = _separate_pipeline_create_uniforms(color_image)
					var draw_list = rd.draw_list_begin(single_sample_framebuffer,
						RenderingDevice.INITIAL_ACTION_DISCARD,
						RenderingDevice.FINAL_ACTION_STORE,
						RenderingDevice.INITIAL_ACTION_DISCARD,
						RenderingDevice.FINAL_ACTION_DISCARD,
					)
					rd.draw_list_bind_render_pipeline(draw_list, separate_pipeline)
					rd.draw_list_bind_uniform_set(draw_list, uniform_set, 0)
					rd.draw_list_set_push_constant(draw_list, push_constant.to_byte_array(), push_constant.size() * 4)
					rd.draw_list_bind_vertex_array(draw_list, vertex_array)
					rd.draw_list_draw(draw_list, false, 1)
					rd.draw_list_end()
					rd.draw_command_end_label()

					if edge_detection_method != EdgeDetectionMethod.DEPTH:
						_smaa_process(single_sample_tex[0], single_sample_tex[0], output_framebuffer, view, 1.0)
						_smaa_process(single_sample_tex[1], single_sample_tex[1], output_framebuffer, view, 0.5)
					else:
						_smaa_process(single_sample_tex[0], depth_image, output_framebuffer, view, 1.0)
						_smaa_process(single_sample_tex[1], depth_image, output_framebuffer, view, 0.5)

			rd.draw_command_end_label()

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
@export var quality : QualityLevel = QualityLevel.MEDIUM :
	set(new_quality):
		quality = new_quality
		settings_dirty = true
@export var edge_detection_method : EdgeDetectionMethod = EdgeDetectionMethod.LUMA :
	set(new_edge_detection_method):
		edge_detection_method = new_edge_detection_method
		edge_detection_method_dirty = true

var settings_dirty : bool = false
var edge_detection_method_dirty : bool = false

var smaa_threshold : float
var smaa_max_search_steps : int
var smaa_disable_diag_detection : bool
var smaa_max_search_steps_diag : int
var smaa_disable_corner_detection : bool
var smaa_corner_rounding : int

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

var stencil_buffer : RID
# Stencil buffer format support is hardware dependent
var stencil_buffer_format : RenderingDevice.DataFormat

var single_sample_tex : Array[RID]

var copy_tex : RID

var area_tex : RID
var search_tex : RID

var nearest_sampler : RID
var linear_sampler : RID

var framebuffer_size : Vector2i = Vector2i(0, 0)

var S2x : bool = false

var vertex_buffer : RID
var vertex_array : RID

var smaa_settings_ubo : RID
var scene_data_ubo : RID

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
		if stencil_buffer.is_valid():
			rd.free_rid(stencil_buffer)
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
		if smaa_settings_ubo.is_valid():
			rd.free_rid(smaa_settings_ubo)

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
	var va := RDVertexAttribute.new()
	va.stride = 16
	va.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT

	var no_blend_attachment := RDPipelineColorBlendStateAttachment.new()
	var blend_attachment := RDPipelineColorBlendStateAttachment.new()
	blend_attachment.enable_blend = true
	blend_attachment.color_blend_op = RenderingDevice.BLEND_OP_ADD
	blend_attachment.src_color_blend_factor = RenderingDevice.BLEND_FACTOR_CONSTANT_ALPHA
	blend_attachment.dst_color_blend_factor = RenderingDevice.BLEND_FACTOR_ONE_MINUS_CONSTANT_ALPHA
	blend_attachment.alpha_blend_op = RenderingDevice.BLEND_OP_ADD
	blend_attachment.src_alpha_blend_factor = RenderingDevice.BLEND_FACTOR_CONSTANT_ALPHA
	blend_attachment.dst_alpha_blend_factor = RenderingDevice.BLEND_FACTOR_ONE_MINUS_CONSTANT_ALPHA
	var no_blend := RDPipelineColorBlendState.new()
	no_blend.attachments = [no_blend_attachment]
	var dual_color_blend := RDPipelineColorBlendState.new()
	dual_color_blend.attachments = [no_blend_attachment, no_blend_attachment]
	var blend_constant_alpha := RDPipelineColorBlendState.new()
	blend_constant_alpha.attachments = [blend_attachment]

	var color_attachment_format : RDAttachmentFormat = RDAttachmentFormat.new()
	color_attachment_format.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	color_attachment_format.usage_flags = RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT
	var output_framebuffer_format = rd.framebuffer_format_create([color_attachment_format])
	var dual_output_framebuffer_format = rd.framebuffer_format_create([color_attachment_format, color_attachment_format])

	var stencil_attachment_format := RDAttachmentFormat.new()
	stencil_attachment_format.format = stencil_buffer_format
	stencil_attachment_format.usage_flags = RenderingDevice.TEXTURE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT
	color_attachment_format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	var blend_framebuffer_format = rd.framebuffer_format_create([color_attachment_format, stencil_attachment_format])
	# edges_tex only has r + g channels, so we need a different framebuffer format
	color_attachment_format.format = RenderingDevice.DATA_FORMAT_R8G8_UNORM
	var edge_framebuffer_format = rd.framebuffer_format_create([color_attachment_format, stencil_attachment_format])

	var stencil_state := RDPipelineDepthStencilState.new()
	stencil_state.enable_stencil = true
	stencil_state.back_op_reference = 0x01
	stencil_state.back_op_write_mask = 0xff
	stencil_state.back_op_compare_mask = 0xff
	stencil_state.back_op_pass = RenderingDevice.STENCIL_OP_REPLACE
	stencil_state.front_op_reference = 0x01
	stencil_state.front_op_write_mask = 0xff
	stencil_state.front_op_compare_mask = 0xff
	stencil_state.front_op_pass = RenderingDevice.STENCIL_OP_REPLACE

	if edge_shader.is_valid():
		edge_pipeline = rd.render_pipeline_create(edge_shader, edge_framebuffer_format,
			rd.vertex_format_create([va]), RenderingDevice.RENDER_PRIMITIVE_TRIANGLES, RDPipelineRasterizationState.new(),
			RDPipelineMultisampleState.new(), stencil_state,
			no_blend
		)
	if weight_shader.is_valid():
		stencil_state.back_op_compare = RenderingDevice.COMPARE_OP_EQUAL
		stencil_state.back_op_write_mask = 0
		stencil_state.front_op_compare = RenderingDevice.COMPARE_OP_EQUAL
		stencil_state.front_op_write_mask = 0
		weight_pipeline = rd.render_pipeline_create(weight_shader, blend_framebuffer_format,
			rd.vertex_format_create([va]), RenderingDevice.RENDER_PRIMITIVE_TRIANGLES, RDPipelineRasterizationState.new(),
			RDPipelineMultisampleState.new(), stencil_state,
			no_blend
		)
	if blend_shader.is_valid():
		blend_pipeline = rd.render_pipeline_create(blend_shader, output_framebuffer_format,
			rd.vertex_format_create([va]), RenderingDevice.RENDER_PRIMITIVE_TRIANGLES, RDPipelineRasterizationState.new(),
			RDPipelineMultisampleState.new(), RDPipelineDepthStencilState.new(),
			blend_constant_alpha, RenderingDevice.DYNAMIC_STATE_BLEND_CONSTANTS
		)
	if blit_shader.is_valid():
		blit_pipeline = rd.render_pipeline_create(blit_shader, output_framebuffer_format,
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

func _clean_textures() -> void:
	# Associated framebuffers are dependent on these textures
	# they're freed with them
	if edges_tex.is_valid():
		rd.free_rid(edges_tex)
		edges_tex = RID()
	if blend_tex.is_valid():
		rd.free_rid(blend_tex)
		blend_tex = RID()
	if stencil_buffer.is_valid():
		rd.free_rid(stencil_buffer)
		stencil_buffer = RID()
	if !S2x:
		if copy_tex.is_valid():
			rd.free_rid(copy_tex)
			copy_tex = RID()
	else:
		if single_sample_tex[0].is_valid():
			rd.free_rid(single_sample_tex[0])
			single_sample_tex[0] = RID()
		if single_sample_tex[1].is_valid():
			rd.free_rid(single_sample_tex[1])
			single_sample_tex[1] = RID()

func _recreate_edge_pipeline() -> void:
	if edge_shader.is_valid():
		rd.free_rid(edge_shader)
		edge_shader = RID()
		edge_pipeline = RID()

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

	var color_attachment_format : RDAttachmentFormat = RDAttachmentFormat.new()
	color_attachment_format.format = RenderingDevice.DATA_FORMAT_R8G8_UNORM
	color_attachment_format.usage_flags = RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT
	var stencil_attachment_format := RDAttachmentFormat.new()
	stencil_attachment_format.format = stencil_buffer_format
	stencil_attachment_format.usage_flags = RenderingDevice.TEXTURE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT
	var edge_framebuffer_format = rd.framebuffer_format_create([color_attachment_format, stencil_attachment_format])

	var stencil_state := RDPipelineDepthStencilState.new()
	stencil_state.enable_stencil = true
	stencil_state.back_op_reference = 0x01
	stencil_state.back_op_write_mask = 0xff
	stencil_state.back_op_compare_mask = 0xff
	stencil_state.back_op_pass = RenderingDevice.STENCIL_OP_REPLACE
	stencil_state.front_op_reference = 0x01
	stencil_state.front_op_write_mask = 0xff
	stencil_state.front_op_compare_mask = 0xff
	stencil_state.front_op_pass = RenderingDevice.STENCIL_OP_REPLACE

	if edge_shader.is_valid():
		edge_pipeline = rd.render_pipeline_create(edge_shader, edge_framebuffer_format,
			rd.vertex_format_create([va]), RenderingDevice.RENDER_PRIMITIVE_TRIANGLES, RDPipelineRasterizationState.new(),
			RDPipelineMultisampleState.new(), stencil_state,
			color_blend
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

	# Find the smallest supported depth+stencil buffer
	if rd.texture_is_format_supported_for_usage(RenderingDevice.DATA_FORMAT_D16_UNORM_S8_UINT,
			RenderingDevice.TEXTURE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT):
		stencil_buffer_format = RenderingDevice.DATA_FORMAT_D16_UNORM_S8_UINT
	elif rd.texture_is_format_supported_for_usage(RenderingDevice.DATA_FORMAT_D24_UNORM_S8_UINT,
			RenderingDevice.TEXTURE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT):
		stencil_buffer_format = RenderingDevice.DATA_FORMAT_D24_UNORM_S8_UINT
	elif rd.texture_is_format_supported_for_usage(RenderingDevice.DATA_FORMAT_D32_SFLOAT_S8_UINT,
			RenderingDevice.TEXTURE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT):
		stencil_buffer_format = RenderingDevice.DATA_FORMAT_D32_SFLOAT_S8_UINT

	_create_pipelines()

func _create_textures(size: Vector2i) -> void:
	var tf : RDTextureFormat = RDTextureFormat.new()
	tf.width = size.x
	tf.height = size.y
	tf.usage_bits = (RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT |
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT)

	tf.format = RenderingDevice.DATA_FORMAT_R8G8_UNORM
	edges_tex = rd.texture_create(tf, RDTextureView.new())
	tf.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	blend_tex = rd.texture_create(tf, RDTextureView.new())

	tf.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	if !S2x:
		copy_tex = rd.texture_create(tf, RDTextureView.new())
	else:
		single_sample_tex[0] = rd.texture_create(tf, RDTextureView.new())
		single_sample_tex[1] = rd.texture_create(tf, RDTextureView.new())

	tf.format = stencil_buffer_format
	tf.usage_bits = RenderingDevice.TEXTURE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT
	stencil_buffer = rd.texture_create(tf, RDTextureView.new())

func _create_buffer(size : Vector2i) -> void :
	if smaa_settings_ubo.is_valid():
		rd.free_rid(smaa_settings_ubo)

	_get_smaa_parameters()

	var data := PackedFloat32Array([
		1.0 / size.x,
		1.0 / size.y,
		size.x,
		size.y,

		smaa_threshold,
		smaa_max_search_steps,
		smaa_max_search_steps_diag,
		smaa_corner_rounding,

		smaa_disable_diag_detection,
		smaa_disable_corner_detection,
		0.0,
		0.0,
	])

	smaa_settings_ubo = rd.uniform_buffer_create(data.size() * 4, data.to_byte_array())

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
			copy_tex = RID()
	else:
		if single_sample_tex[0].is_valid():
			rd.free_rid(single_sample_tex[0])
			single_sample_tex[0] = RID()
		if single_sample_tex[1].is_valid():
			rd.free_rid(single_sample_tex[1])
			single_sample_tex[1] = RID()

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
	return UniformSetCacheRD.get_cache(edge_shader, 1, [uniform])

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
	return UniformSetCacheRD.get_cache(weight_shader, 1, [edges_tex_uniform, area_tex_uniform, search_tex_uniform])

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
	return UniformSetCacheRD.get_cache(blend_shader, 1, [color_tex_uniform, blend_tex_uniform])

func _smaa_process(input : RID, edges_input : RID, output_framebuffer : RID, view : int, blend_alpha : float = 1.0) -> void:
	var edges_framebuffer = FramebufferCacheRD.get_cache_multipass([edges_tex, stencil_buffer], [], 1)
	var blend_framebuffer = FramebufferCacheRD.get_cache_multipass([blend_tex, stencil_buffer], [], 1)
	var push_constant : PackedFloat32Array = PackedFloat32Array()
	# First Pass: Edge Detection
	rd.draw_command_begin_label("SMAA Edge Detection" + str(view), Color.WHITE)
	var settings_uniform : Array[RDUniform] = [RDUniform.new()]
	settings_uniform[0].uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	settings_uniform[0].binding = 0
	settings_uniform[0].add_id(smaa_settings_ubo)

	var uniform_set : RID = _edge_pipeline_create_uniforms(edges_input)
	var settings_uniform_set : RID = UniformSetCacheRD.get_cache(edge_shader, 0, settings_uniform)
	var draw_list = rd.draw_list_begin(edges_framebuffer,
		RenderingDevice.INITIAL_ACTION_CLEAR,
		RenderingDevice.FINAL_ACTION_STORE,
		RenderingDevice.INITIAL_ACTION_CLEAR,
		RenderingDevice.FINAL_ACTION_STORE,
		PackedColorArray([Color(0.0, 0.0, 0.0, 0.0)]),
		1.0, 0
	)
	rd.draw_list_bind_render_pipeline(draw_list, edge_pipeline)
	rd.draw_list_bind_uniform_set(draw_list, settings_uniform_set, 0)
	rd.draw_list_bind_uniform_set(draw_list, uniform_set, 1)
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
		RenderingDevice.INITIAL_ACTION_LOAD,
		RenderingDevice.FINAL_ACTION_DISCARD,
		PackedColorArray([Color(0.0, 0.0, 0.0, 0.0)])
	)
	rd.draw_list_bind_render_pipeline(draw_list, weight_pipeline)
	rd.draw_list_bind_uniform_set(draw_list, settings_uniform_set, 0)
	rd.draw_list_bind_uniform_set(draw_list, uniform_set, 1)
	rd.draw_list_set_push_constant(draw_list, push_constant.to_byte_array(), push_constant.size() * 4)
	rd.draw_list_bind_vertex_array(draw_list, vertex_array)
	rd.draw_list_draw(draw_list, false, 1)
	rd.draw_list_end()
	rd.draw_command_end_label()

	# Third Pass: Neighborhood Blending
	rd.draw_command_begin_label("SMAA Neighborhood Blending" + str(view), Color.WHITE)
	uniform_set = _blend_pipeline_create_uniforms(input)
	draw_list = rd.draw_list_begin(output_framebuffer,
		RenderingDevice.INITIAL_ACTION_DISCARD,
		RenderingDevice.FINAL_ACTION_STORE,
		RenderingDevice.INITIAL_ACTION_DISCARD,
		RenderingDevice.FINAL_ACTION_DISCARD,
	)
	rd.draw_list_bind_render_pipeline(draw_list, blend_pipeline)
	rd.draw_list_bind_uniform_set(draw_list, settings_uniform_set, 0)
	rd.draw_list_bind_uniform_set(draw_list, uniform_set, 1)
	rd.draw_list_bind_vertex_array(draw_list, vertex_array)
	rd.draw_list_set_blend_constants(draw_list, Color(blend_alpha, blend_alpha, blend_alpha, blend_alpha))
	rd.draw_list_draw(draw_list, false, 1)
	rd.draw_list_end()
	rd.draw_command_end_label()

func _render_callback(p_effect_callback_type: int, p_render_data: RenderData) -> void:
	if rd and p_effect_callback_type == EFFECT_CALLBACK_TYPE_POST_TRANSPARENT and edge_shader.is_valid() and weight_shader.is_valid() and blend_shader.is_valid() and blit_shader.is_valid():
		var render_scene_buffers : RenderSceneBuffersRD = p_render_data.get_render_scene_buffers()
		var render_scene_data : RenderSceneDataRD = p_render_data.get_render_scene_data()
		if render_scene_buffers:
			var view_count = render_scene_buffers.get_view_count()
			var size : Vector2i = render_scene_buffers.get_internal_size()
			if size.x == 0 and size.y == 0:
				return

			# Our window has resized
			if size != framebuffer_size:
				framebuffer_size = size
				_clean_textures()
				settings_dirty = true
				S2x = render_scene_buffers.get_msaa_3d() == RenderingServer.VIEWPORT_MSAA_2X
				_create_textures(size)

			if (S2x and render_scene_buffers.get_msaa_3d() != 1) or (!S2x and render_scene_buffers.get_msaa_3d() == 1):
				_toggle_S2x(size)

			if edge_detection_method_dirty:
				_recreate_edge_pipeline()
				edge_detection_method_dirty = false

			if settings_dirty:
				_create_buffer(size)
				settings_dirty = false

			var push_constant : PackedFloat32Array = PackedFloat32Array([
				1.0 / size.x, 1.0 / size.y, size.x, size.y
			])
			rd.draw_command_begin_label("SMAA", Color.WHITE)
			for view in view_count:
				var color_image : RID = render_scene_buffers.get_color_layer(view, S2x)
				var output_image : RID = render_scene_buffers.get_color_layer(view, false)
				var depth_image : RID
				if edge_detection_method == EdgeDetectionMethod.DEPTH:
					depth_image = render_scene_buffers.get_depth_layer(view, false)
				var output_framebuffer = FramebufferCacheRD.get_cache_multipass([output_image], [], 1)
				# Not currently used, but will be used for depth edge detection
				scene_data_ubo = render_scene_data.get_uniform_buffer()

				if !S2x:
					var copy_framebuffer = FramebufferCacheRD.get_cache_multipass([copy_tex], [], 1)
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

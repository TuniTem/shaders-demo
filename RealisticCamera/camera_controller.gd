@tool
extends TextureRect
class_name RealisticCamera

enum Mode {
	MANUAL,
	#SEMI_AUTOMATIC,
	#AUTO
}

enum Aspect {
	SQUARE,
	STANDARD,
	HIGH
}

const MAX_RENDER_DISTANCE = 4000.0
const APERATURE_DIAMETER = 450.0
const AUTO_FOCUS_SPEED = 1.0
const ASSUMED_FPS = 60.0
const MAX_MOTION_BLUR_AMOUNT = 0.3365

const ASPECT_TO_RATIO : Dictionary[Aspect, float] = {
	Aspect.SQUARE : 1.0,
	Aspect.STANDARD : 4.0 / 3.0,
	Aspect.HIGH : 16.0 / 9.0
}

## The location that photos will be saved, has to be in the user:// directory
## if you want someting outside the user dir you need to rewrite the verify_dir() function
@export var photo_save_location : String = "user://" 

## The name of the created file, you can use the tags 
## [year], [month], [day], [hour], [minute], [second] to insert a timestamp
@export var photo_save_name : String = "Photo [month]-[day]-[year]T[hour]-[minute]-[second]"
@export var viewport_size : Vector2 = Vector2(1920, 1080):
	set(val):
		viewport_size = val
		if not Engine.is_editor_hint(): await RenderingServer.frame_post_draw
		viewport.size = viewport_size

## How far into the frame the photo should be taken, enable [param draw_aspect_corners] to see the effect clearly
@export_range(0.0, 0.95, 0.001) var aspect_inset_amount : float

@export_category("Camera Settings")
## The focal point, aka where depth of feild is focused on
@export_range(0.01, MAX_RENDER_DISTANCE, 0.001, "exp", "suffix:m") var focal_distance : float = 1.0:
	set(val):
		focal_distance = val
		if not Engine.is_editor_hint(): await RenderingServer.frame_post_draw
		camera_attributes.frustum_focus_distance = focal_distance

## The angle of view (aka FOV) of the camera 
@export_range(1.0, 179.0, 0.001, "exp", "degrees") var zoom : float = 30.0:
	set(val):
		zoom = val
		if not Engine.is_editor_hint(): await RenderingServer.frame_post_draw
		camera.fov = zoom

## A smaller Fstop means a shallower depth of feild and a brighter image
@export_range(1.0, 32.0, 0.001, "exp") var fstop : float = 4.0:
	set(val):
		fstop = val
		if not Engine.is_editor_hint(): await RenderingServer.frame_post_draw
		shader.set_shader_parameter("fstop", fstop)
		camera_attributes.frustum_focal_length = APERATURE_DIAMETER / fstop

## A smaller shutter speed means a darker image and less motion blur
@export_range(1.0 / 60.0, 4.0, 0.00001, "exp", "suffix:s") var shutter_speed : float = 1.0 / 60.0:
	set(val):
		shutter_speed = val
		if not Engine.is_editor_hint(): await RenderingServer.frame_post_draw
		shader.set_shader_parameter("shutter_speed", shutter_speed)

## A smaller ISO means a darker image, which tends to lead to less grain
@export_range(100.0, 25600.0, 10.0, "exp") var iso : float = 400.0:
	set(val):
		iso = val
		if not Engine.is_editor_hint(): await RenderingServer.frame_post_draw
		shader.set_shader_parameter("iso", iso)

## The mode of the camera, currently only manual is supported as I was having issues with the others
@export var mode : Mode = Mode.MANUAL:
	set(val):
		mode = val
		if not Engine.is_editor_hint(): await RenderingServer.frame_post_draw
		match mode:
			#Mode.AUTO:
				#iso = 400
				#shutter_speed = 1.0 / 30.0
				#fstop = 1.5
				#camera_attributes.auto_exposure_enabled = true
				#auto_raycast.enabled = true
			#
			#Mode.SEMI_AUTOMATIC:
				#iso = 400
				#camera_attributes.auto_exposure_enabled = true
				#auto_raycast.enabled = false
			
			Mode.MANUAL:
				camera_attributes.auto_exposure_enabled = false

## The aspect ratio of the final shot, enable [param draw_aspect_corners] to see the effect clearly
@export var aspect_ratio : Aspect = Aspect.STANDARD

@export_category("Drawing")

## Draws the corners of the taken frame
@export var draw_aspect_corners : bool = true
@export var aspect_corners_color : Color = Color.WHITE
@export_range(0.0, 1.0, 0.001) var aspect_corners_length : float = 0.05

## Draws a rule of third guide
@export var draw_rule_of_thirds : bool = false
@export var rule_of_thirds_color : Color = Color.WHITE
@export_range(0.0, 1.0, 0.001) var rule_of_thirds_length : float = 0.05

## Draws a crosshair at the center of the camera
@export var draw_crosshair : bool = false
@export var crosshair_color : Color = Color.WHITE
@export_range(0.0, 128.0, 0.001) var crosshair_length : float = 20.0

## The line width of all draw calls
@export_range(-1.0, 16.0, 1.0) var line_width : int = 2

@export_category("Nodes")
## A node who's transform will be copied to the camera's transform. 
## Basically think about it as the object representing the realistic camera. 
@export var camera_transform_track : Node3D
## The camera in the subviewport
@export var camera : Camera3D
## The default camera of the game, enabled and disabled as the realistic camera is toggled
@export var default_camera : Camera3D
## The camera atributes thats used on the world enviroment node, doesn't need to be modified
@export var camera_attributes : CameraAttributesPhysical
## The screenspace effects shader placed on a color rect in the subviewport
@export var shader : ShaderMaterial
## The subviewport where the cameras output will be rendered
@export var viewport : SubViewport
## The world enviroment in the viewport
@export var environment : WorldEnvironment

## if a picture is currently being taken
var capturing : bool = false
## if the ui is shown
var active : bool = false

# multithreading 
const THREAD_TIMEOUT_TIME = 90.0

var _thread : Thread = Thread.new()
var _thread_timeout : float = 0.0
var _quit_thread_flag : int

func _ready() -> void:
	# Set the max render distance
	camera_attributes.frustum_far = MAX_RENDER_DISTANCE
	camera.far = MAX_RENDER_DISTANCE
	
	# set the subviewport's options
	viewport.use_taa = true
	viewport.use_debanding = true
	
	# make sure the output directory exists if the game is open
	if not Engine.is_editor_hint(): _verify_dir(photo_save_location)
	
	# disable the camera by default
	enable_visual(false)

func _process(delta: float) -> void:
	# copy the remote transform's global transform to the subviewport camera
	if camera_transform_track: camera.global_transform = camera_transform_track.global_transform
	queue_redraw()

func _draw() -> void:
	# some draw call magic
	if draw_crosshair:
		for line : Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_line(size / 2.0, size / 2.0 + line * crosshair_length, crosshair_color, line_width)
	
	if draw_aspect_corners or draw_rule_of_thirds:
		var aspect : float = ASPECT_TO_RATIO[aspect_ratio]
		var height : int = roundi(size.y * (1.0 - aspect_inset_amount))
		var width : int = roundi(height * aspect)
		var image_dimentions : Vector2 = Vector2(width, height)
		var center : Vector2 = size * 0.5
		var length : float = lerpf(0.0, width, aspect_corners_length)
		
		if draw_aspect_corners:
			for line : Vector2 in [Vector2(0.5, 0.5), Vector2(-0.5, 0.5), Vector2(-0.5, -0.5), Vector2(0.5, -0.5)]:
				var origin : Vector2 = center + image_dimentions * line
				draw_line(origin, origin + Vector2(-line.x, 0.0) * length, aspect_corners_color, line_width)
				draw_line(origin, origin + Vector2(0.0, -line.y) * length, aspect_corners_color, line_width)
		
		if draw_rule_of_thirds:
			length = lerpf(0.0, width, rule_of_thirds_length)
			var vertical_length : float = clamp(length, 0.0, image_dimentions.y / 3.0)
			length = clamp(length, 0.0, image_dimentions.x / 3.0) 
			var sixth : float = 1.0 / 6.0
			for line : Vector2 in [Vector2(sixth, sixth), Vector2(-sixth, sixth), Vector2(-sixth, -sixth), Vector2(sixth, -sixth)]:
				var origin : Vector2 = center + image_dimentions * line
				draw_line(origin - Vector2(line.x, 0.0).normalized() * length, origin + Vector2(line.x, 0.0).normalized() * length, rule_of_thirds_color, line_width)
				draw_line(origin - Vector2(0.0, line.y).normalized() * vertical_length, origin + Vector2(0.0, line.y).normalized() * vertical_length, rule_of_thirds_color, line_width)

## function used to queue threads for image processing and saving, so the main game doesnt freeze
func _queue_thread(callable : Callable, args : Array = [], custom_timeout : float = -1.0, priority : Thread.Priority = Thread.Priority.PRIORITY_NORMAL) -> Variant:
	while _thread.is_alive():
		await get_tree().process_frame
	
	_thread.start(callable.bindv(args), priority)
	_thread_timeout = THREAD_TIMEOUT_TIME if custom_timeout == -1.0 else custom_timeout 
	while _thread.is_alive() and _thread_timeout > 0.0: 
		_thread_timeout -= get_process_delta_time()
		await get_tree().process_frame
	
	if _thread_timeout <= 0.0: 
		printerr("Thread timed out: " + str(callable))
		_quit_thread_flag = callable.get_object().get_instance_id()
		return null
	else:
		return _thread.wait_to_finish()

## make sure the inputed directory exists, only check in user://
func _verify_dir(path : String):
	path = path.replace("user://", "")
	var dir = DirAccess.open("user://")
	if not dir.dir_exists(path):
		var files : Array = path.split("/")
		var curr_dir = files.pop_front()
		for file in files:
			dir.make_dir(curr_dir)
			curr_dir = curr_dir + "/" + file

## enable/disable the camera overlay
func enable_visual(on : bool):
	camera.current = on
	default_camera.current = !on
	visible = on
	active = on
	if on:
		environment.camera_attributes = camera_attributes
	else:
		environment.camera_attributes = null

## toggle the camera overlay
func toggle_visual():
	enable_visual(!active)

## capture a photo, and return an image object. If [param ignore_capture_check] is true,
## multiple pictures can be taken at once before previous ones have processed
func capture(ignore_capture_check : bool = false):
	if not capturing or ignore_capture_check:
		capturing = true
		var aspect : float = ASPECT_TO_RATIO[aspect_ratio]
		
		var height : int = roundi(viewport.size.y * (1.0 - aspect_inset_amount))
		var width : int = roundi(height * aspect)
		
		var output : Image
		var base_format : Image.Format
		var operation_format : Image.Format = Image.Format.FORMAT_RGBF
		var frame : int = roundi(ASSUMED_FPS * shutter_speed)
		var frames : Array[Image]
		
		if frame > 1: 
			shader.set_shader_parameter("motion_blur_enabled", true)
			camera.strength = MAX_MOTION_BLUR_AMOUNT
			
		for i in range(frame):
			await RenderingServer.frame_post_draw
			var img : Image = viewport.get_texture().get_image()
			if i == 0: base_format = img.get_format()
			frames.append(img)
		
		shader.set_shader_parameter("motion_blur_enabled", false)
		
		if frame > 0:
			output = await _queue_thread(_combine_frames, [frames, width, height, operation_format, viewport.size], 120.0, Thread.PRIORITY_HIGH)
			print("Combined image layers...")
			output.convert(base_format)
			capturing = false
			return output

## captures an image fromthe camera and saves it to a specifiecd path (or the default path if none is given)
## If [param ignore_capture_check] is true, multiple pictures can be taken at once before previous ones have processed
func capture_and_save(ignore_capture_check : bool = false, path : String = ""):
	if not capturing or ignore_capture_check:
		var image : Image = await capture(ignore_capture_check)
		capturing = true
		
		var time = Time.get_time_dict_from_system()
		var date = Time.get_date_dict_from_system()
		var file_name : String = photo_save_name
		for replace : Array in [["[month]", date.month], ["[day]", date.day], ["[year]", date.year], ["[hour]", time.hour], ["[minute]", time.minute], ["[second]", time.second]]:
			file_name = file_name.replace(replace[0], str(replace[1]))
		
		file_name += ".png"
		
		await _queue_thread(_save_photo.bindv([image, (photo_save_location if path == "" else path) + "/" + file_name]))
		print("Photo saved to ", ProjectSettings.globalize_path((photo_save_location if path == "" else path) + "/" + file_name))
		capturing = false

## Save the photo to the specified path, in a sperate func to be multithreaded
func _save_photo(image : Image, path : String):
	image.save_png(path)

## if the image has a large shutter speed, this layers multiple fromes on top of eachother to emulate that effect 
func _combine_frames(frames : Array[Image], width : int, height : int, format : Image.Format, viewport_size : Vector2i) -> Image:
	var output = Image.create_empty(width, height, false, format)
	output.fill(Color.BLACK)
	var frame : float = float(frames.size())
	for img : Image in frames:
		img.convert(format)
		var cropped : Image = Image.create_empty(width, height, false, format)
		cropped.blit_rect(img, Rect2i((Vector2(viewport_size) - Vector2(width, height)) * 0.5, Vector2(width, height)), Vector2i.ZERO)
		
		# TODO have image layers accumulate on the gpu in some way instead of iterating over pixels, multithreading it is a meh workaround
		# could use a subviewport on rendermode no clear and then stack transparent frames with that maybe? Or a accumulation shader
		# if you figure this out, open an issue/pr on the demo github or contact me: tunitem (discord)
		for x in range(width):
			if _quit_thread_flag == get_instance_id(): return
			for y in range(height):
				output.set_pixel(x, y, output.get_pixel(x, y) + cropped.get_pixel(x,y) / frame)
	
	return output

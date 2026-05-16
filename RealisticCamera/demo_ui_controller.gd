extends Node

## My implementation of the UI for your refrence

#enum Settings {
	#ISO,
	#SHUTTER,
	#FSTOP,
	#RATIO,
	#MODE
#}
#
#const SETTINGS_ORDER : Dictionary[RealisticCamera.Mode, Array] = {
	#RealisticCamera.Mode.MANUAL : [Settings.MODE, Settings.RATIO, Settings.FSTOP, Settings.SHUTTER, Settings.ISO],
	#RealisticCamera.Mode.SEMI_AUTOMATIC : [Settings.MODE, Settings.RATIO, Settings.FSTOP, Settings.SHUTTER],
	#RealisticCamera.Mode.AUTO : [Settings.MODE, Settings.RATIO]
#}
#
#const SETTINGS_OPTIONS : Dictionary[Settings, Array] = {
	#Settings.ISO : [100, 125, 160, 200, 300, 400, 500, 640, 800, 1000, 1600, 2000, 2500, 3200, 4000, 5000, 6400, 7200, 12800, 20000, 25600],
	#Settings.SHUTTER : ["1/60", "1/30", "1/15", "1/8", "1/4", "1/2", "1", "2", "4"],
	#Settings.RATIO : [RealisticCamera.Aspect.STANDARD, RealisticCamera.Aspect.SQUARE],
	#Settings.MODE : [RealisticCamera.Mode.MANUAL, RealisticCamera.Mode.SEMI_AUTOMATIC, RealisticCamera.Mode.AUTO]
#}
#
#const SHUTTER_NUMBERS : Dictionary[String, float] = {
	#"1/60" : 1.0 / 60.0,
	#"1/30" : 1.0 / 30.0, 
	#"1/15" : 1.0 / 15.0, 
	#"1/8" : 1.0 / 8.0,
	#"1/4" : 1.0 / 4.0,
	#"1/2" : 1.0 / 2.0,
	#"1" : 1.0,
	#"2" : 2.0,
	#"4" : 4.0
#}
#
#@onready var SETTINGS_NODES : Dictionary[Settings, HBoxContainer] = {
	#Settings.MODE : %ModeContainer, 
	#Settings.RATIO : %RatioContaimer, 
	#Settings.FSTOP : %FSTOPContainer, 
	#Settings.SHUTTER : %ShutterContainer, 
	#Settings.ISO : %ISOContainer
#}
#
#@onready var SETTINGS_TEXTURES : Dictionary[Settings, Dictionary] = {
	#Settings.MODE : {
		#RealisticCamera.Mode.MANUAL: preload("uid://3e0ues17btfu"),
		#RealisticCamera.Mode.SEMI_AUTOMATIC : preload("uid://2ibsy1dfbrne"),
		#RealisticCamera.Mode.AUTO : preload("uid://bkmot2xmdaa6q")
	#}, 
	#Settings.RATIO : {
		#RealisticCamera.Aspect.SQUARE: preload("uid://7wn8j4d6cvlo"),
		#RealisticCamera.Aspect.STANDARD : preload("uid://d2e4jhrybxk4b"),
		#RealisticCamera.Aspect.HIGH : preload("uid://o73wdd3oohls")
	#}, 
	#Settings.FSTOP : {
		#2.0: preload("uid://cup3bjos465cw"),
		#5.6: preload("uid://bqb2ffckhty82"),
		#13.0: preload("uid://csdl54vjbwk40"),
		#33.0: preload("uid://biq08h6dfwb2t")
	#}, 
	#Settings.SHUTTER : {
		#1.0 / 60.0: preload("uid://c8tbe4dakfjho"),
		#1.0 / 15.0: preload("uid://h63k4pn40xw8"),
		#1.0 / 2.0: preload("uid://cel2ykiry22a2"),
		#61.0 : preload("uid://dy4wo7lgcd4ji")
	#}, 
	#Settings.ISO : {
		#"image" : preload("uid://beirsuvn8336m")
	#}
#}
#
#const FSTOP_CHANGE_RATE = 0.5
#const MAX_FSTOP = 32.0
#const MIN_FSTOP = 1.0
#
#
#const ZOOM_CHANGE_MULT = 1.1
#const ZOOM_FINE_CHANGE_MULT = 1.02
#const ZOOM_SMOOTH = 10.0
#const MAX_ZOOM = 160.0
#const MIN_ZOOM = 2.0
#
#@onready var camera_move_animations: AnimationPlayer = %CameraMoveAnimations
#@onready var ui_animations: AnimationPlayer = %UIAnimations
#@onready var overlay: Control = %Overlay
#@onready var camera_controller: TextureRect = %CameraRect
#@onready var camera: Camera3D = %Camera3D
#@onready var model: Node3D = %Model
#@onready var camera_environment: WorldEnvironment = %CameraEnvironment
#@onready var aov: Label = %AOV
#@onready var sn: Label = %SN
#@onready var settings_hint: VBoxContainer = %SettingsHint
#@onready var scroll_hint: VBoxContainer = %ScrollHint
#
#var overlay_toggled : bool = false
#var private_photo_location : String
#var public_photo_location : String
#var animating : bool = false
#var queued_input : bool = false
#var target_zoom : float = 30.0
#
#var selected : Settings = Settings.MODE
##var mode : Mode = Mode.AUTOMATIC
#var settings : Dictionary[Settings, Variant] = {
	#Settings.MODE : RealisticCamera.Mode.AUTO, 
	#Settings.RATIO : RealisticCamera.Aspect.STANDARD, 
	#Settings.FSTOP : 3.4, 
	#Settings.SHUTTER : "1/30", 
	#Settings.ISO : 400
#}
#
#var current_order : Array:
	#get(): return SETTINGS_ORDER[settings[Settings.MODE]]
#
#func _ready() -> void:
	#private_photo_location = Global.get_save_directory() + "photos/"
	#File.verify_dir(private_photo_location)
	#
	#public_photo_location = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES) + "/Veil/" + Global.save_name + "/"
	#File.verify_dir(public_photo_location)
	#
	#overlay.hide()
	#set_camera_enviroment(false)
	#
	#if not self in Util.get_all_children(Global.player):
		#camera_move_animations.play("neutral")
	#
	#settings_hint.modulate.a = float(File.load_var("camera_settings_hint", true))
	#scroll_hint.modulate.a = float(File.load_var("camera_scroll_hint", true))
#
#func _process(delta: float) -> void:
	#camera.global_transform = Global.player.camera_tool_position.global_transform
	#if not visible : return
	#
	#camera.fov = lerp(camera.fov, target_zoom, delta * ZOOM_SMOOTH)
	#aov.text = "AOV - " + str(Util.round_to(camera.fov, 0.1)) + "°"
	#
	#var light_gathering : float = (1.0 / pow(camera_controller.fstop, 2)) * (camera_controller.shutter_speed)
	#var photon_noise_factor : float = sqrt(1.0 / max(light_gathering, 0.0001))
	#var read_noise_factor : float = sqrt(camera_controller.iso / 100.0)
	#var noise_amplifier : float = photon_noise_factor * read_noise_factor
	#var noise_val : float = camera_controller.shader.get_shader_parameter("noise_intensity") * min(noise_amplifier * 0.01, camera_controller.shader.get_shader_parameter("max_noise"));
	#
	#sn.text = "S/N - " + str(Util.round_to(remap(noise_val, 0.0, camera_controller.shader.get_shader_parameter("max_noise"), 60.0, 10.0), 0.1)) + " dB"
	#
	#if selected == Settings.FSTOP:
		#if Input.is_action_pressed("ui_right"):
			#settings[Settings.FSTOP] = clamp(settings[Settings.FSTOP] * (1.0 + FSTOP_CHANGE_RATE * delta), MIN_FSTOP, MAX_FSTOP)
		#
		#if Input.is_action_pressed("ui_left"):
			#settings[Settings.FSTOP] = clamp(settings[Settings.FSTOP] * (1.0 - FSTOP_CHANGE_RATE * delta), MIN_FSTOP, MAX_FSTOP)
		#
		#camera_controller.fstop = settings[Settings.FSTOP]
		#SETTINGS_NODES[Settings.FSTOP].get_node("Panel/Value").text = str(Util.round_to(settings[Settings.FSTOP], 0.1))
		#
#
#func _primary_action_pressed():
	#if overlay_toggled and not camera_controller.capturing:
		#var test_result = await camera_controller.capture()
		#if not test_result is Image: return
		#var photo : Image = test_result
		#var id : int = Net.create_new_id()
		#var time = Time.get_time_dict_from_system()
		#var date = Time.get_date_dict_from_system()
		## TODO make public file names increment if multiple pics are taken in the same second
		#var public_name : String = Global.save_name + " photo %02d-%02d-%02dT%02d-%02d-%02d" % [date.month, date.day, date.year, time.hour, time.minute, time.second]
		#
		#var private_location : String = private_photo_location + str(id) + ".png"
		#var public_location : String = public_photo_location + public_name + ".png"
		#
		#await Util.queue_thread(save_photo, [photo, private_location, public_location])
		#Debug.push("Photo saved to \"" + private_photo_location + str(id) + ".png\"")
#
#func _dropped():
	#Global.player.camera.current = true
#
#func save_photo(image : Image, private_location : String, public_location : String):
	#image.save_png(private_location) 
	#image.save_png(public_location) 
#
#func set_selected(to : Settings):
	#selected = to
	#for setting in SETTINGS_NODES.keys():
		#if setting == selected:
			#SETTINGS_NODES[setting].get_node("Panel/Arrows").show()
			#
			#if setting == Settings.FSTOP: 
				#SETTINGS_NODES[Settings.SHUTTER].get_node("Panel/Arrows").hide()
				#return
			#
			#var index : int = SETTINGS_OPTIONS[setting].find(settings[setting])
			#if index == 0: SETTINGS_NODES[setting].get_node("Panel/Arrows").text = "        >"
			#elif index == SETTINGS_OPTIONS[setting].size() - 1: SETTINGS_NODES[setting].get_node("Panel/Arrows").text = "<        "
			#else: SETTINGS_NODES[setting].get_node("Panel/Arrows").text = "<       >"
		#
		#else:
			#SETTINGS_NODES[setting].get_node("Panel/Arrows").hide()
#
#
#func incrament_setting(setting : Settings, up : bool):
	#if setting == Settings.FSTOP: return
	#
	#var index : int = SETTINGS_OPTIONS[setting].find(settings[setting])
	#
	## set internal value
	#if up and index < SETTINGS_OPTIONS[setting].size() - 1:  index += 1
	#elif not up and index > 0: index -= 1
	#
	#settings[setting] = SETTINGS_OPTIONS[setting][index]
	#
	## set arrows
	#if index == 0: SETTINGS_NODES[setting].get_node("Panel/Arrows").text = "        >"
	#elif index == SETTINGS_OPTIONS[setting].size() - 1: SETTINGS_NODES[setting].get_node("Panel/Arrows").text = "<        "
	#else: SETTINGS_NODES[setting].get_node("Panel/Arrows").text = "<       >"
	#
	## set camera_controller and set icon
	#match setting:
		#Settings.MODE:
			#for test_setting in SETTINGS_NODES.keys():
				#SETTINGS_NODES[test_setting].visible = test_setting in current_order
			#
			#set_selected(Settings.MODE)
			#camera_controller.mode = settings[setting]
			#SETTINGS_NODES[setting].get_node("Icon").texture = SETTINGS_TEXTURES[setting][settings[setting]]
		#
		#Settings.RATIO:
			#camera_controller.aspect_ratio = settings[setting]
			#SETTINGS_NODES[setting].get_node("Icon").texture = SETTINGS_TEXTURES[setting][settings[setting]]
		#
		#Settings.SHUTTER:
			#camera_controller.shutter_speed = SHUTTER_NUMBERS[settings[setting]]
			#var texture : Texture2D
			#for threshold : float in SETTINGS_TEXTURES[Settings.SHUTTER].keys():
				#if Util.fless_equal(camera_controller.shutter_speed, threshold, 2):
					#texture = SETTINGS_TEXTURES[Settings.SHUTTER][threshold]
					#break
			#
			#SETTINGS_NODES[setting].get_node("Icon").texture = texture
		#
		#Settings.ISO:
			#camera_controller.iso = settings[setting]
		#
	## update text
	#match setting:
		#Settings.MODE: SETTINGS_NODES[setting].get_node("Panel/Value").text = {RealisticCamera.Mode.MANUAL : "MANUAL", RealisticCamera.Mode.SEMI_AUTOMATIC : "SEMI", RealisticCamera.Mode.AUTO : "AUTO"}[settings[setting]]
		#Settings.RATIO:  SETTINGS_NODES[setting].get_node("Panel/Value").text = {RealisticCamera.Aspect.SQUARE : "1:1", RealisticCamera.Aspect.STANDARD : "4:3", RealisticCamera.Aspect.HIGH : "16:9"}[settings[setting]]
		#_: SETTINGS_NODES[setting].get_node("Panel/Value").text = str(settings[setting]) 
#
#func _secondary_action_pressed():
	#if animating: 
		#queued_input = true
		#return
	#
	#overlay_toggled = !overlay_toggled
	#animating = true
	#
	#if overlay_toggled:
		#UI.set_crosshair(false)
		#overlay.show()
		#camera_move_animations.play("focus", 0.1)
		#await Util.sleep(0.3)
		#if overlay_toggled:
			#ui_animations.play("show")
			#await Util.sleep(0.1)
			#Global.player.camera.current = false
			#set_camera_enviroment(true)
			#await Util.sleep(0.5)
	#
	#else:
		#ui_animations.play("hide")
		#await Util.sleep(0.4)
		#Global.player.camera.current = true
		#if not overlay_toggled:
			##await Util.sleep(0.175)
			#camera_move_animations.play("unfocus")
			#UI.set_crosshair(true)
			#await Util.sleep(0.125)
			#set_camera_enviroment(false)
			#await Util.sleep(0.8)
			#
			#overlay.hide()
	#
	#animating = false
	#if queued_input: 
		#queued_input = false
		#_secondary_action_pressed()
#
#func set_camera_enviroment(to : bool):
	#if to:
		#camera_environment.camera_attributes = camera_controller.camera_attributes
	#
	#else:
		#camera_environment.camera_attributes = null
#
#func _input(event: InputEvent) -> void:
	#if not overlay.visible: return
	#if event.is_action_pressed("camera_zoom_in"):
		#var temp : float = target_zoom
		#target_zoom = clamp(target_zoom / (ZOOM_FINE_CHANGE_MULT if Input.is_action_pressed("camera_zoom_fine") else ZOOM_CHANGE_MULT), MIN_ZOOM, MAX_ZOOM)
		#
		#if scroll_hint.modulate.a <= 0.0:
			#File.save_var("camera_scroll_hint", false)
		#elif temp != target_zoom: 
			#scroll_hint.modulate.a -= 0.05
	#
	#if event.is_action_pressed("camera_zoom_out"):
		#var temp : float = target_zoom
		#target_zoom = clamp(target_zoom * (ZOOM_FINE_CHANGE_MULT if Input.is_action_pressed("camera_zoom_fine") else ZOOM_CHANGE_MULT), MIN_ZOOM, MAX_ZOOM)
		#
		#if scroll_hint.modulate.a <= 0.0:
			#File.save_var("camera_scroll_hint", false)
		#elif temp != target_zoom: 
			#scroll_hint.modulate.a -= 0.05
			#
		#
	#if event.is_action_pressed("ui_up"):
		#var index : int = current_order.find(selected)
		#var temp : Settings = selected
		#set_selected(current_order[index + 1 if index < current_order.size() - 1 else 0] if index != -1 else Settings.MODE)
		#
		#if settings_hint.modulate.a <= 0.0:
			#File.save_var("camera_settings_hint", false)
			#
		#elif temp != selected: 
			#settings_hint.modulate.a -= 0.05
	#
	#if event.is_action_pressed("ui_down"):
		#var index : int = current_order.find(selected)
		#var temp : Settings = selected
		#set_selected(current_order[index - 1] if index != -1 else Settings.MODE)
		#
		#if settings_hint.modulate.a <= 0.0:
			#File.save_var("camera_settings_hint", false)
			#
		#elif temp != selected: 
			#settings_hint.modulate.a -= 0.05
	#
	#if event.is_action_pressed("ui_right"):
		#var temp : Variant = settings[selected]
		#incrament_setting(selected, true)
		#
		#if settings_hint.modulate.a <= 0.0:
			#File.save_var("camera_settings_hint", false)
			#
		#elif temp != settings[selected]: 
			#settings_hint.modulate.a -= 0.05
	#
	#if event.is_action_pressed("ui_left"):
		#var temp : Variant = settings[selected]
		#incrament_setting(selected, false)
		#
		#if settings_hint.modulate.a <= 0.0:
			#File.save_var("camera_settings_hint", false)
			#
		#elif temp != settings[selected]: 
			#settings_hint.modulate.a -= 0.05

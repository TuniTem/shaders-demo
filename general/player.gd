extends CharacterBody3D

# VOTV-like Character controller, feel free to use!

# Movement settings
enum Movement {
	IDLE,
	WALKING,
	RUNNING,
	CROUCH_WALK,
	CROUCH_IDLE
}

const SENSITIVITY = 1.0
const MAX_CROUCH_SPEED = 2.0
const MAX_WALK_SPEED = 4.0
const MAX_RUN_SPEED = 6.5
const ACCEL = 30.0
const GRAVITY = 30.0
const TERMINAL_VELOCITY = 30.0
const DRAG = 20.0
const DEADZOME = 0.1
const JUMP_HEIGHT = 10.0
const FOOTSTEP_TIME = 0.5

@export var held_look_transform: Node3D
@export var camera : Camera3D
@onready var footstep: AudioStreamPlayer = %Footstep
@onready var animations: AnimationPlayer = %Animations

var vel2D : Vector2 = Vector2.ZERO
var prev_pos : Vector3
var movement_state : Movement = Movement.IDLE
var look : Vector2 = Vector2.ZERO
var footstep_timer : float = 0.0
var crouch_toggled : bool = false:
	set(val):
		crouch_toggled = val
		animations.play("crouch" if crouch_toggled else "uncrouch")

# Camera settings 
const Y_CLAMP = [-PI / 2.0 - 0.1, PI / 2.0 - 0.1]
const LOOK_PULL = 10.0
const LOOK_TILT_STRENGTH = 0.1
const LOOK_ITEM_PULL_STRENGTH = 10.0
const LOOK_ITEM_PULL_AMOUNT = 0.3
const STRAFE_TILT_STRENGTH = 0.04
const FOV : float = 80.0
const RUN_LOOK_DOWN_AMMOUNT : float = 0.03

# Zoom
const ZOOM_AMMOUNT = 0.5
const ZOOM_SPEED = 7.0
var zoom : bool = false

# Headbob
const HEADBOB_STRENGTH = 0.1
const HEADBOB_TRANSITION_SPEED : float = 3.0

const IDLE_HEADBOB : Dictionary = {
		"amplitude" : Vector3(0.2, 0.1, 0.0),
		"wavelength" : Vector3(1.0 / 12.0, 1.0 / 6.0, 1.0 / 6.0)
	}
const HEADBOB_AMOUNT : Dictionary[Movement, Dictionary] = {
	Movement.IDLE : IDLE_HEADBOB,
	Movement.CROUCH_IDLE : IDLE_HEADBOB,
	Movement.WALKING : {
		"amplitude" : Vector3(0.15, 0.05, 0.03),
		"wavelength" : Vector3(1.0 / 1.2, 1.0 / 0.6, 1.0 / 0.6)
	},
	Movement.RUNNING : {
		"amplitude" : Vector3(0.20, 0.10, 0.1),
		"wavelength" : Vector3(1.0 / 0.7, 1.0 / 0.35, 1.0 / 0.35)
	},
	Movement.CROUCH_WALK : {
		"amplitude" : Vector3(0.15, 0.05, 0.03)* 2.0,
		"wavelength" : Vector3(1.0 / 1.5, 1.0 / 0.75, 1.0 / 0.75)
	},
}

var headbob_amplitude_target : Vector3 = HEADBOB_AMOUNT[Movement.IDLE]["amplitude"]
var headbob_wavelength_target : Vector3 = HEADBOB_AMOUNT[Movement.IDLE]["wavelength"]

# util
@onready var camera_tool_position: Marker3D = %CameraToolPosition

var TIME : float = 0.0
var mouse_captured : bool = true

func _ready() -> void:
	look.y = camera.rotation.x
	look.x = rotation.y
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera.current = true

func _process(delta: float) -> void:
	TIME += delta
	
	# Headbob
	headbob_amplitude_target = HEADBOB_AMOUNT[movement_state]["amplitude"] * HEADBOB_STRENGTH
	headbob_wavelength_target = HEADBOB_AMOUNT[movement_state]["wavelength"]
	
	var look_tilt : float = angle_difference(rotation.y, look.x) * LOOK_TILT_STRENGTH + (Input.get_action_strength("left") - Input.get_action_strength("right")) * STRAFE_TILT_STRENGTH * (float(movement_state == Movement.RUNNING) + 1)
	
	held_look_transform.position.x = lerp(held_look_transform.position.x, angle_difference(rotation.y, look.x) * LOOK_ITEM_PULL_AMOUNT, delta * LOOK_ITEM_PULL_STRENGTH)
	camera.rotation.y = lerp_angle(camera.rotation.y, breathe(headbob_wavelength_target.x, headbob_amplitude_target.x), HEADBOB_TRANSITION_SPEED * delta)
	camera.rotation.x = lerp_angle(camera.rotation.x, look.y + breathe(headbob_wavelength_target.y, headbob_amplitude_target.y), LOOK_PULL * delta)
	camera.rotation.z = lerp_angle(camera.rotation.z, look_tilt + breathe(headbob_wavelength_target.z, headbob_amplitude_target.z), HEADBOB_TRANSITION_SPEED * delta)
	rotation.y = lerp_angle(rotation.y, look.x, LOOK_PULL * delta)
	
	# Footstep audio
	if Input.get_action_strength("forward") - Input.get_action_strength("backward") > DEADZOME and is_on_floor():
		footstep_timer += delta
		if footstep_timer > 1.0 / HEADBOB_AMOUNT[movement_state]["wavelength"].y:
			footstep_timer -= 1.0 / HEADBOB_AMOUNT[movement_state]["wavelength"].y
			footstep.play()
		
	else: footstep_timer = 0.0
	
	# Zoom
	if zoom:
		camera.fov = lerpf(camera.fov, FOV * ZOOM_AMMOUNT, delta * ZOOM_SPEED)
	else:
		camera.fov = lerpf(camera.fov, FOV, delta * ZOOM_SPEED)


func _physics_process(delta: float) -> void:
	var dir = Vector2(Input.get_action_strength("forward") - Input.get_action_strength("backward"), Input.get_action_strength("left") - Input.get_action_strength("right")).normalized()
	
	var MAX_SPEED : float 
	match movement_state:
		Movement.RUNNING : MAX_SPEED = MAX_RUN_SPEED
		Movement.CROUCH_WALK: MAX_SPEED = MAX_CROUCH_SPEED
		_: MAX_SPEED = MAX_WALK_SPEED
		
		
	if dir.length() < DEADZOME: 
		vel2D = vel2D.normalized() * clamp(vel2D.length() - DRAG * delta, 0.0, MAX_SPEED)
	else: 
		vel2D += dir.rotated(rotation.y + PI) * delta * ACCEL
	
	if vel2D.length() > MAX_SPEED: 
		vel2D = vel2D.normalized() * MAX_SPEED
	
	velocity.z = vel2D.x
	velocity.x = vel2D.y
	velocity.y -= GRAVITY * delta * (1 + (velocity.y / TERMINAL_VELOCITY))
	match movement_state:
		Movement.IDLE:
			if vel2D.length() > DEADZOME:
				movement_state = Movement.WALKING if not Input.is_action_pressed("run") else Movement.RUNNING
			
			elif crouch_toggled:
				movement_state = Movement.CROUCH_IDLE
		
		Movement.WALKING:
			if vel2D.length() < DEADZOME:
				movement_state = Movement.IDLE
			elif Input.is_action_pressed("run"):
				movement_state = Movement.RUNNING
			elif crouch_toggled:
				movement_state = Movement.CROUCH_WALK
		
		Movement.RUNNING:
			if vel2D.length() > DEADZOME:
				if not Input.is_action_pressed("run"): 
					movement_state = Movement.WALKING
			else:
				movement_state = Movement.IDLE
			
			if crouch_toggled: movement_state = Movement.CROUCH_WALK
		
		Movement.CROUCH_IDLE:
			if not crouch_toggled: movement_state = Movement.IDLE
			elif vel2D.length() > DEADZOME: 
				movement_state = Movement.CROUCH_WALK
				if Input.is_action_just_pressed("run"): movement_state = Movement.RUNNING
		
		Movement.CROUCH_WALK:
			if Input.is_action_just_pressed("run"):
				movement_state = Movement.RUNNING
				crouch_toggled = false
			
			elif not crouch_toggled: movement_state = Movement.WALKING
			elif vel2D.length() < DEADZOME: movement_state = Movement.CROUCH_IDLE
			
	
	move_and_slide()
	prev_pos = position

func breathe(wavelength_seconds : float, amplitude : float, use_sin : bool = true, phase : float = 0.0) -> float:
	if use_sin:
		return sin((TIME - phase) * wavelength_seconds * TAU ) * amplitude
	else:
		return cos((TIME - phase) * wavelength_seconds * TAU) * amplitude

func jump():
	velocity.y = JUMP_HEIGHT

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and mouse_captured:
		var delta_look_dir = event.relative * SENSITIVITY * 0.005
		
		look.x += -delta_look_dir.x
		look.y = clamp(look.y-delta_look_dir.y, Y_CLAMP[0], Y_CLAMP[1])
	
	if event.is_action_pressed("run"):
		look.y -= RUN_LOOK_DOWN_AMMOUNT
	
	if event.is_action_released("run"):
		look.y += RUN_LOOK_DOWN_AMMOUNT
	
	if event.is_action_pressed("crouch"):
		crouch_toggled = !crouch_toggled
	
	if event.is_action_pressed("jump") and is_on_floor():
		jump()
	
	if event.is_action_pressed("zoom"):
		zoom = true
	
	if event.is_action_released("zoom"):
		zoom = false
	
	if event.is_action_pressed("escape"):
		mouse_captured = !mouse_captured
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if mouse_captured else Input.MOUSE_MODE_VISIBLE)
	
	# basic realistic camera implementation
	if event.is_action_pressed("camera"):
		realistic_camera.toggle_visual()
	
	if event.is_action_pressed("take_picture") and realistic_camera.active:
		realistic_camera.capture_and_save(true)

@onready var realistic_camera: RealisticCamera = %RealisticCamera

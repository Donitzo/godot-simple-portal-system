"""
    Asset: Godot Simple Portal System
    File: player.gd
    Description: Simple controllable player with raycaster.
    Repository: https://github.com/Donitzo/godot-simple-portal-system
    License: CC0 License
"""

extends MeshInstance3D

const _MOUSE_PAN_THRESHOLD:float = 0.4;
const _MOUSE_PAN_SPEED:float = 200

const _MOVE_SPEED:float = 4

var _mouse_look:Vector2

@onready var _line_renderer:LineRenderer = $"../LineRenderer"
@onready var _camera:Camera3D = $Camera
@onready var _pip_camera:Camera3D = $PipViewport1/Camera

@onready var _handle_raycast_callable:Callable = Callable(self, "_handle_raycast")

func _ready() -> void:
    set_layer_mask_value(1, false)
    set_layer_mask_value(2, true)

    _camera.set_cull_mask_value(2, false)

func _process(delta:float) -> void:
    var viewport:Viewport = get_viewport()
    var mouse_position:Vector2 = viewport.get_mouse_position()
    var viewport_size:Vector2i = viewport.size
    var normalized_mouse_position:Vector2 = mouse_position / Vector2(viewport_size)

    var horizontal_speed:float  = 0
    var vertical_speed:float = 0
    
    if normalized_mouse_position.x > 0 and normalized_mouse_position.x < 1 and\
        normalized_mouse_position.y > 0 and normalized_mouse_position.y < 1:
        if normalized_mouse_position.x < _MOUSE_PAN_THRESHOLD:
            horizontal_speed = lerp(0, 1, _MOUSE_PAN_THRESHOLD - normalized_mouse_position.x)
        elif normalized_mouse_position.x > 1 - _MOUSE_PAN_THRESHOLD:
            horizontal_speed = lerp(0, -1, normalized_mouse_position.x - (1.0 - _MOUSE_PAN_THRESHOLD))
        if normalized_mouse_position.y < _MOUSE_PAN_THRESHOLD:
            vertical_speed = lerp(0, 1, _MOUSE_PAN_THRESHOLD - normalized_mouse_position.y)
        elif normalized_mouse_position.y > 1 - _MOUSE_PAN_THRESHOLD:
            vertical_speed = lerp(0, -1, normalized_mouse_position.y - (1.0 - _MOUSE_PAN_THRESHOLD))

    _mouse_look.x = fmod(_mouse_look.x + horizontal_speed * _MOUSE_PAN_SPEED * delta + 360, 360)
    _mouse_look.y = clamp(_mouse_look.y + vertical_speed * _MOUSE_PAN_SPEED * delta, -80, 80)
    
    rotation_degrees = Vector3(0, _mouse_look.x, 0)
    _camera.rotation_degrees = Vector3(_mouse_look.y, 0, 0)
    
    var right:Vector3 = (global_transform.basis.x * Vector3(1, 0, 1)).normalized()
    var forward:Vector3 = (global_transform.basis.z * Vector3(1, 0, 1)).normalized()

    if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
        global_translate(-right * _MOVE_SPEED * delta)
    if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
        global_translate(right * _MOVE_SPEED * delta)
    if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
        global_translate(-forward * _MOVE_SPEED * delta)
    if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
        global_translate(forward * _MOVE_SPEED * delta)

    if abs(position.z) > 4.4:
        position.x = clamp(position.x, -0.75, 0.75)
        if abs(position.z) > 7.1:
            position.z -= 7.1 * 2 * sign(position.z)
    else:
        position.x = clamp(position.x, -3.8, 3.8)
        if abs(position.x) > 0.75:
            position.z = clamp(position.z, -3.8, 3.8)
    
    _pip_camera.global_position = _camera.to_global(Vector3(0, 1.5, 1.5))
    _pip_camera.global_rotation = _camera.global_rotation
    
    var origin:Vector3 = _camera.project_ray_origin(mouse_position)
    var end:Vector3 = origin + _camera.project_ray_normal(mouse_position) * 100

    _line_renderer.clear_lines()
    
    Portal.raycast(get_tree(), origin, (end - origin).normalized(), _handle_raycast_callable)

func _handle_raycast(from:Vector3, dir:Vector3, segment_distance:float, _recursive_distance:float, recursions:int) -> bool:
    var distance:float = min(100, segment_distance)
    var target:Vector3 = from + dir * distance

    _line_renderer.add_line(from, target, Color.GREEN)
    for i in 16:
        _line_renderer.add_line(target, target + Vector3(
            randf_range(-0.1, 0.1), 
            randf_range(-0.1, 0.1), 
            randf_range(-0.1, 0.1)), Color.RED)
        if recursions > 0:
            _line_renderer.add_line(from, from + Vector3(
                randf_range(-0.1, 0.1), 
                randf_range(-0.1, 0.1), 
                randf_range(-0.1, 0.1)), Color.BLUE)

    var space_state:PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
    var query:PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + dir * distance)
    var result:Dictionary = space_state.intersect_ray(query)
    if not result.is_empty() and result.collider is Hoverable:
        result.collider.hovered = true
        for i in 16:
            _line_renderer.add_line(result.position, result.position + Vector3(
                randf_range(-0.1, 0.1), 
                randf_range(-0.1, 0.1), 
                randf_range(-0.1, 0.1)), Color.GREEN)
        
        return true
        
    return false

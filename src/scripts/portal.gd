"""
    Asset: Godot Simple Portal System
    File: portal.gd
    Version: 1.0
    Description: A simple portal system for viewport-based portals in Godot 4.
    Instructions: For detailed documentation, see the README or visit: https://github.com/Donitzo/godot-simple-portal-system
    Repository: https://github.com/Donitzo/godot-simple-portal-system
    License: CC0 License
"""

extends MeshInstance3D
class_name Portal
## The portal represents a single portal mesh in a pair of portals.

## The delay between the main viewport changing size and the portal viewport resizing.
const _RESIZE_THROTTLE_SECONDS:float = 0.1

## The minimum camera near clipping distance.
const _EXIT_CAMERA_NEAR_MIN:float = 0.01

## The portal mesh's local bounding box.
@onready var _mesh_aabb:AABB = mesh.get_aabb()

## The vertical resolution of the viewport. The viewport covers the entire screen, not just the portal mesh.
@export var vertical_viewport_resolution:int = 512

## Disable viewport distance. Portals further away than this won't have their viewports rendered.
@export var disable_viewport_distance:float = 11
## The maximum fade-out distance.
@export var fade_out_distance_max:float = 10
## The minimum fade-out distance.
@export var fade_out_distance_min:float = 8
## The fade-out color.
@export var fade_out_color:Color = Color.WHITE

## The scale of the exit side of the portal. < 1 means the exit is smaller than the entrance.
@export var exit_scale:float = 1.0
## A value subtracted from the exit camera near clipping plane. Useful for handling clipping issues.
@export var exit_near_subtract:float

## The main camera. Leave unset to use the default 3D camera.
@export var main_camera:Camera3D

## An environment set for the exit camera. Leave unset to use the default environment.
@export var exit_environment:Environment = null

## The exit portal. Leave unset to use this portal as an exit only.
@export var exit_portal:Portal

# The viewport rendering the portal surface.
var _viewport:SubViewport

# The exit camera copies the main camera's position relative to the exit portal.
var _exit_camera:Camera3D

# The number of seconds until the viewport updates its size.
var _seconds_until_resize:float

func _ready() -> void:
    # An exit-free portal does not need anything
    if exit_portal == null:
        set_process(false)
        return

    # Non-uniform parent scaling can introduce skew which isn't compensated for
    if get_parent() != null:
        var parent_scale:Vector3 = get_parent().global_transform.basis.get_scale()
        if abs(parent_scale.x - parent_scale.y) > 0.01 or abs(parent_scale.x - parent_scale.z) > 0.01:
            push_warning("The parent of \"%s\" is not uniformly scaled. The portal will not work correctly." % name)

    # The portals should be updated last so the main camera has its final position
    process_priority = 1000

    # Used in raycasting
    add_to_group("portals")
    
    # Get the main camera
    if main_camera == null:
        main_camera = get_viewport().get_camera_3d()
    
    # Create the viewport for the portal surface
    _viewport = SubViewport.new()
    _viewport.name = "Viewport"
    _viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
    add_child(_viewport)
    _viewport.owner = self

    # Create the exit camera which renders the portal surface for the viewport
    _exit_camera = Camera3D.new()
    _exit_camera.name = "Camera"
    _exit_camera.environment = exit_environment
    _viewport.add_child(_exit_camera)
    _exit_camera.owner = _viewport

    # The portal shader renders the viewport on-top of the portal mesh in screen-space
    material_override = ShaderMaterial.new()
    material_override.shader = preload("res://shaders/portal.gdshader")
    material_override.set_shader_parameter("albedo", _viewport.get_texture())
    material_override.set_shader_parameter("fade_out_distance_max", fade_out_distance_max)
    material_override.set_shader_parameter("fade_out_distance_min", fade_out_distance_min)
    material_override.set_shader_parameter("fade_out_color", fade_out_color)   

    get_viewport().connect("size_changed", _handle_resize)

func _handle_resize() -> void:
    _seconds_until_resize = _RESIZE_THROTTLE_SECONDS

func _process(delta:float) -> void:
    # Don't process invisible portals
    if not is_visible_in_tree():
        # Ensure the viewport can resize the moment it becomes visible again
        if not is_nan(_seconds_until_resize):
            _seconds_until_resize = 0
        return

    # Throttle the viewport resizing for better performance
    if not is_nan(_seconds_until_resize):
        _seconds_until_resize -= delta
        if _seconds_until_resize <= 0:
            _seconds_until_resize = NAN

            # Resize the viewport with a fixed height and dynamic width
            var viewport_size:Vector2i = get_viewport().size
            var aspect_ratio:float = float(viewport_size.x) / viewport_size.y
            _viewport.size = Vector2i(vertical_viewport_resolution * aspect_ratio, vertical_viewport_resolution)

    # Disable viewport for portals further away than disable_viewport_distance
    _viewport.disable_3d = main_camera.global_position.distance_to(global_position) > disable_viewport_distance
    if _viewport.disable_3d:
        return

    # Move the exit camera relative to the exit portal based on the main camera's position relative to the entrance portal    
    _exit_camera.global_transform = real_to_exit_transform(main_camera.global_transform)

    # Copy the main camera's properties
    _exit_camera.far = main_camera.far
    _exit_camera.fov = main_camera.fov
    _exit_camera.keep_aspect = main_camera.keep_aspect

    # Calculate the distance from the exit camera to the nearest point on the exit portal's bounding box
    var distance_to_near_plane_center:float = exit_portal.get_nearest_aabb_distance(_exit_camera.global_position)

    # Determine the viewport's aspect ratio. The aspect ratio calculation is inverted based on keep_aspect.
    var aspect_ratio:float = float(_viewport.size.x) / _viewport.size.y \
        if _exit_camera.keep_aspect == 1 else float(_viewport.size.y) / _viewport.size.x

    # Using the camera's field of view, calculate the half dimensions of the near clipping plane
    var near_half_size_a:float = distance_to_near_plane_center * tan(deg_to_rad(_exit_camera.fov) / 2)
    var near_half_size_b:float = near_half_size_a * aspect_ratio
    var near_half_diagonal_length:float = sqrt(near_half_size_a ** 2 + near_half_size_b ** 2)

    # Calculate the distance from the camera to the corner of the near clipping plane
    var distance_to_near_plane_corner:float = sqrt(distance_to_near_plane_center ** 2 + near_half_diagonal_length ** 2)
    var corner_to_center_difference:float = distance_to_near_plane_corner - distance_to_near_plane_center

    # Adjust the near clipping plane distance to prevent the clipping plane's corners from intersecting the portal bounding box.
    # The offset hopefully minimizes rendering objects behind the portal.
    _exit_camera.near = max(_EXIT_CAMERA_NEAR_MIN, distance_to_near_plane_center - corner_to_center_difference - exit_near_subtract)

## Return a new Transform3D relative to the exit portal based on the real Transform3D relative to this portal.
func real_to_exit_transform(real:Transform3D) -> Transform3D:
    # Convert from global space to local space at the entrance (this) portal
    var local:Transform3D = global_transform.affine_inverse() * real
    # Compensate for any scale the entrance portal may have
    var unscaled:Transform3D = local.scaled(global_transform.basis.get_scale())
    # Flip it (the portal always flips the view 180 degrees)
    var flipped:Transform3D = unscaled.rotated(Vector3.UP, PI)
    # Apply any scale the exit portal may have (and apply custom exit scale)
    var exit_scale_vector:Vector3 = exit_portal.global_transform.basis.get_scale()
    var scaled_at_exit:Transform3D = flipped.scaled(Vector3.ONE / exit_scale_vector * exit_scale)
    # Convert from local space at the exit portal to global space
    var local_at_exit:Transform3D = exit_portal.global_transform * scaled_at_exit
    return local_at_exit

## Return a new position relative to the exit portal based on the real position relative to this portal.
func real_to_exit_position(real:Vector3) -> Vector3:
    # Convert from global space to local space at the entrance (this) portal
    var local:Vector3 = global_transform.affine_inverse() * real
    # Compensate for any scale the entrance portal may have
    var unscaled:Vector3 = local * global_transform.basis.get_scale()
    # Apply any scale the exit portal may have (and apply custom exit scale)
    var exit_scale_vector:Vector3 = Vector3(-1, 1, 1) * exit_portal.global_transform.basis.get_scale()
    var scaled_at_exit:Vector3 = unscaled / exit_scale_vector * exit_scale
    # Convert from local space at the exit portal to global space
    var local_at_exit:Vector3 = exit_portal.global_transform * scaled_at_exit
    return local_at_exit

## Return a new direction relative to the exit portal based on the real direction relative to this portal.
func real_to_exit_direction(real:Vector3) -> Vector3:
    # Convert from global to local space at the entrance (this) portal
    var local:Vector3 = global_transform.basis.inverse() * real
    # Compensate for any scale the entrance portal may have
    var unscaled:Vector3 = local * global_transform.basis.get_scale()
    # Flip it (the portal always flips the view 180 degrees)
    var flipped:Vector3 = unscaled.rotated(Vector3.UP, PI)
    # Apply any scale the exit portal may have (and apply custom exit scale)
    var exit_scale_vector:Vector3 = exit_portal.global_transform.basis.get_scale()
    var scaled_at_exit:Vector3 = flipped / exit_scale_vector * exit_scale
    # Convert from local space at the exit portal to global space
    var local_at_exit:Vector3 = exit_portal.global_transform.basis * scaled_at_exit
    return local_at_exit

## Get the nearest distance between a global position and the portal's bounding box.
func get_nearest_aabb_distance(target_position:Vector3) -> float:
    var local:Vector3 = to_local(target_position)
    var nearest:Vector3 = Vector3(
        clamp(local.x, _mesh_aabb.position.x, _mesh_aabb.position.x + _mesh_aabb.size.x),
        clamp(local.y, _mesh_aabb.position.y, _mesh_aabb.position.y + _mesh_aabb.size.y),
        clamp(local.z, _mesh_aabb.position.z, _mesh_aabb.position.z + _mesh_aabb.size.z))
    return to_global(nearest).distance_to(target_position)

## Raycast against portals (See instructions).
static func raycast(tree:SceneTree, from:Vector3, dir:Vector3, handle_raycast:Callable, 
    max_distance:float = INF, max_recursions:int = 2, ignore_backside:bool = true) -> void:
    var portals:Array = tree.get_nodes_in_group("portals")
    var ignore_portal:Portal = null
    var recursive_distance:float = 0
    
    for r in max_recursions + 1:
        var closest_hit:Vector3
        var closest_dir:Vector3
        var closest_portal:Portal
        var closest_distance_sqr:float = INF

        # Find the closest portal the ray intersects       
        for portal in portals:
            if portal != ignore_portal and portal.is_visible_in_tree():
                var local_from:Vector3 = portal.to_local(from)
                var local_dir:Vector3 = portal.global_transform.basis.inverse() * dir

                # Ray is parallel to the portal                
                if local_dir.z == 0:
                    continue
                
                # Ignore backside    
                if local_dir.z > 0 and ignore_backside:
                    continue

                # Get the intersection point of the ray with the Z axis
                var t:float = -local_from.z / local_dir.z
                if t <= 0:
                    continue
                    
                # Check if the ray hit inside the portal bounding box
                var local_hit:Vector3 = local_from + t * local_dir
                var aabb:AABB = portal._mesh_aabb
                if aabb.position.x <= local_hit.x and local_hit.x <= aabb.position.x + aabb.size.x and\
                    aabb.position.y <= local_hit.y and local_hit.y <= aabb.position.y + aabb.size.y:
                    var hit:Vector3 = portal.to_global(local_hit)
                        
                    # Check if this was the closest portal
                    var distance_sqr:float = hit.distance_squared_to(from)
                    if distance_sqr < closest_distance_sqr:
                        closest_hit = hit
                        closest_dir = dir
                        closest_distance_sqr = distance_sqr
                        closest_portal = portal

        # Calculate the ray distance
        var hit_distance:float = INF if is_inf(closest_distance_sqr) else sqrt(closest_distance_sqr)
        recursive_distance += hit_distance

        # Call the user-defined raycast function
        if handle_raycast.call(from, dir, hit_distance, recursive_distance, r):
            break
            
        # Was no portal hit or was the maximum raycast distance reached?
        if is_inf(closest_distance_sqr) or recursive_distance >= max_distance:
            break
        
        # Re-direct the ray through the portal
        from = closest_portal.real_to_exit_position(closest_hit)
        dir = closest_portal.real_to_exit_direction(closest_dir)
        ignore_portal = closest_portal.exit_portal

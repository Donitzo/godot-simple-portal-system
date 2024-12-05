"""
    Asset: Godot Simple Portal System
    File: collision_disable_area.gd
    Description: An area in which collisions are disabled for physics bodies based on the "disabled_collision_masks" metadata array.
    Instructions: For detailed documentation, see the README or visit: https://github.com/Donitzo/godot-simple-portal-system
    Repository: https://github.com/Donitzo/godot-simple-portal-system
    License: CC0 License
"""

extends Area3D
class_name CollisionDisableArea

## Seconds until collisions are re-enabled after the body leaves the area.
@export var re_enable_delay_seconds:float = 0.1

# Info about the disabled bodies
var _disables:Array = []

func _ready() -> void:
    connect("body_entered", _on_body_entered)
    connect("body_exited", _on_body_exited)

func _process(delta:float) -> void:
    for i in range(_disables.size() - 1, -1, -1):
        var disable_info:Dictionary = _disables[i]
        
        if not is_instance_valid(disable_info.body):
            # Body has been freed, remove disable info
            _disables.remove_at(i)
            continue
        
        if not disable_info.left:
            # The body has yet to leave the area
            continue

        # The body left the area, so reduce its timeout before removal
        disable_info.seconds_until_enable -= delta
        if disable_info.seconds_until_enable > 0:
            continue
        
        _disables.remove_at(i)
        
        # Re-enable collision masks
        for layer_number in disable_info.disabled_layers:
            # Only consider layers which were enabled to begin with
            if disable_info.disable_count.has(layer_number):
                # Decrement disables so only the final area actually disables the mask
                disable_info.disable_count[layer_number] -= 1
                if disable_info.disable_count[layer_number] == 0:
                    # Final disable, so re-enable the collision mask
                    disable_info.body.set_collision_mask_value(layer_number, true)
    
func _on_body_entered(body:PhysicsBody3D) -> void:
    if not body.has_meta("disabled_collision_masks"):
        return

    # Is the body already disabled by this area?
    for disable_info in _disables:
        if disable_info.body == body:
            # Reset left and timeout
            disable_info.left = false
            disable_info.seconds_until_enable = re_enable_delay_seconds
            return

    # Keep track of the number of times each collision mask is disabled in a meta field
    if not body.has_meta("collision_disable_count"):
        body.set_meta("collision_disable_count", {})
    var disable_count:Dictionary = body.get_meta("collision_disable_count")

    # Disable the collision masks specified in the "disabled_collision_masks" metadata array
    var disabled_layers:Array = body.get_meta("disabled_collision_masks")
    for layer_number in disabled_layers:
        # Only consider layers which were enabled to begin with
        if disable_count.has(layer_number) or body.get_collision_mask_value(layer_number):
            # Increment disables so only the first area actually disables the mask
            disable_count[layer_number] = 1 if not disable_count.has(layer_number) else disable_count[layer_number] + 1
            if disable_count[layer_number] == 1:
                # First disable, so disable the collision mask
                body.set_collision_mask_value(layer_number, false)
    
    # Keep a reference to all current disables in the area
    _disables.push_back({
        "body": body,
        "disabled_layers": disabled_layers,
        "disable_count": disable_count,
        "seconds_until_enable": re_enable_delay_seconds,
        "left": false,
    })

func _on_body_exited(body:PhysicsBody3D) -> void:
    if body.has_meta("disabled_collision_masks"):
        for disable_info in _disables:
            if disable_info.body == body:
                # Mark the body as having left the area
                disable_info.left = true

"""
    Asset: Godot Simple Portal System
    File: portal.gd
    Description: An area which teleports the player through the parent node's portal. Handles RigidBody3D physics as well.
    Instructions: For detailed documentation, see the README or visit: https://github.com/Donitzo/godot-simple-portal-system
    Repository: https://github.com/Donitzo/godot-simple-portal-system
    License: CC0 License
"""

extends Area3D
class_name PortalTeleport

## Checks if the node is moving TOWARDS the portal before teleporting it.
@export var velocity_check:bool = true
## An additional velocity push given to RigidBody3Ds exiting the portal.
@export var exit_push_velocity:float = 0

var _parent_portal:Portal

var _overlapping_nodes:Array = []

func _ready() -> void:
    _parent_portal = get_parent() as Portal
    if _parent_portal == null:
        push_error("The PortalTeleport \"%s\" is not a child of a Portal instance" % name)
    
    connect("area_entered", _on_area_entered)
    connect("area_exited", _on_area_exited)

func _process(_delta:float) -> void:
    var i = 0
    while i < _overlapping_nodes.size():
        var entry:Dictionary = _overlapping_nodes[i]
        
        # This may also be a good place to manage a fake replica of the node.
        # Simply put it at the _parent_portal.real_to_exit_transform(entry.root.global_transform) position.

        if _try_teleport(entry):
            _overlapping_nodes.remove_at(i)
        else:
            i += 1

# Try to teleport the node, and return false otherwise
func _try_teleport(entry:Dictionary) -> bool:
    var node:Node3D = entry.node
    var last_position = entry.position
    entry.position = _parent_portal.to_local(node.global_position)
    
    # Check if the node is moving towards the portal
    if velocity_check and (last_position == null or last_position.z <= entry.position.z):
        return false
    
    # Handle RigidBody3D physics    
    if node is RigidBody3D:
        # Rotate physics rotation and velocity
        var portal_rotation:Basis = _parent_portal.real_to_exit_transform(Transform3D.IDENTITY).basis
        node.linear_velocity *= portal_rotation
        node.angular_velocity *= portal_rotation

        # Additional push when exiting the portal
        if exit_push_velocity > 0:
            var exit_forward:Vector3 = _parent_portal.exit_portal.global_transform.basis.z.normalized()
            node.linear_velocity += exit_forward * exit_push_velocity

    # Transform the position and orientation
    node.global_transform = _parent_portal.real_to_exit_transform(node.global_transform)
    
    return true

func _on_area_entered(area:Area3D) -> void:
    if area.has_meta("teleportable_root"):
        # the node may not teleport immediately if it's not heading TOWARDS the portal,
        # so keep a reference to the root node and its last position
        var root:Node3D = area.get_node(area.get_meta("teleportable_root"))
        var entry:Dictionary = {
            "node": root, 
            "position": null,
        }
        if not _try_teleport(entry):
            _overlapping_nodes.push_back(entry)

func _on_area_exited(area:Area3D) -> void:
    if area.has_meta("teleportable_root"):
        var root:Node3D = area.get_node(area.get_meta("teleportable_root"))
        for entry in _overlapping_nodes:
            if entry.node == root:
                _overlapping_nodes.erase(entry)
                break

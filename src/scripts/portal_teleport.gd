"""
    Asset: Godot Simple Portal System
    File: portal_teleport.gd
    Description: An area which teleports a node through the parent node's portal. Checks entry velocity and handles RigidBody3D and CharacterBody3D physics. Can also handle a portal clone of the node if specified.
    Instructions: For detailed documentation, see the README or visit: https://github.com/Donitzo/godot-simple-portal-system
    Repository: https://github.com/Donitzo/godot-simple-portal-system
    License: CC0 License
"""

extends Area3D
class_name PortalTeleport

## Checks if the node is moving TOWARDS the portal before teleporting it.
@export var velocity_check:bool = true
## An additional velocity push given to RigidBody3Ds/CharacterBody3D exiting the portal.
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
        
        # Move the portal clone if it exists
        if entry.clone != null:
            entry.clone.global_transform = _parent_portal.real_to_exit_transform(entry.node.global_transform)

        if _try_teleport(entry):
            _overlapping_nodes.remove_at(i)
        else:
            i += 1

# Try to teleport the node, and return false otherwise
func _try_teleport(entry:Dictionary) -> bool:
    var node:Node3D = entry.node
    
    # Check if the node is moving towards the portal
    if velocity_check:
        if node is RigidBody3D:
            var local_velocity:Vector3 = _parent_portal.global_transform.basis.inverse() * node.linear_velocity
            if local_velocity.z >= 0:
                return false
        elif node is CharacterBody3D:
            var local_velocity:Vector3 = _parent_portal.global_transform.basis.inverse() * node.velocity
            if local_velocity.z >= 0:
                return false
        else:
            var last_position = entry.position
            entry.position = _parent_portal.to_local(node.global_position)
            if last_position == null or last_position.z <= entry.position.z:
                return false
    
    # Handle RigidBody3D physics    
    if node is RigidBody3D:
        # Rotate rotation and velocity
        var portal_rotation:Basis = _parent_portal.real_to_exit_transform(Transform3D.IDENTITY).basis
        node.linear_velocity *= portal_rotation
        node.angular_velocity *= portal_rotation

        # Additional push when exiting the portal
        if exit_push_velocity > 0:
            var exit_forward:Vector3 = _parent_portal.exit_portal.global_transform.basis.z.normalized()
            node.linear_velocity += exit_forward * exit_push_velocity
    
    # Handle CharacterBody3D physics
    elif node is CharacterBody3D:
        # Rotate velocity
        var portal_rotation:Basis = _parent_portal.real_to_exit_transform(Transform3D.IDENTITY).basis
        node.velocity *= portal_rotation

        # Additional push when exiting the portal
        if exit_push_velocity > 0:
            var exit_forward:Vector3 = _parent_portal.exit_portal.global_transform.basis.z.normalized()
            node.velocity += exit_forward * exit_push_velocity

    # Transform the position and orientation
    node.global_transform = _parent_portal.real_to_exit_transform(node.global_transform)
    
    return true

func _on_area_entered(area:Area3D) -> void:
    if area.has_meta("teleportable_root"):
        # The node may not teleport immediately if it's not heading TOWARDS the portal,
        # so keep a reference to the root node and its last position
        var root:Node3D = area.get_node(area.get_meta("teleportable_root"))
        var clone:Node3D = area.get_node(area.get_meta("portal_clone")) if area.has_meta("portal_clone") else null
        var entry:Dictionary = {
            "node": root, 
            "clone": clone,
            "position": null,
        }
        if not _try_teleport(entry):
            _overlapping_nodes.push_back(entry)
            if clone != null:
                clone.visible = true

func _on_area_exited(area:Area3D) -> void:
    if area.has_meta("teleportable_root"):
        var root:Node3D = area.get_node(area.get_meta("teleportable_root"))
        for entry in _overlapping_nodes:
            if entry.node == root:
                if entry.clone != null:
                    entry.clone.visible = false
                _overlapping_nodes.erase(entry)
                break

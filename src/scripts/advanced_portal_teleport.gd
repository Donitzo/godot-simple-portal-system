"""
    Asset: Godot Simple Portal System
    File: advanced_portal_teleport.gd
    Description: An area which teleports a node through the parent node's portal. Checks entry velocity and handles RigidBody3D and CharacterBody3D physics. Can also handle a portal clone of the node if specified.
    Instructions: For detailed documentation, see the README or visit: https://github.com/Donitzo/godot-simple-portal-system
    Repository: https://github.com/Donitzo/godot-simple-portal-system
    License: CC0 License
"""

extends Area3D
class_name AdvancedPortalTeleport

## Checks if the node is moving TOWARDS the portal before teleporting it.
@export var velocity_check:bool = true
## An additional velocity push given to RigidBody3Ds/CharacterBody3D exiting the portal.
@export var exit_push_velocity:float = 0
## Seconds to keep portal clones visible after the node leaves the teleporter.
@export var clone_keep_alive_seconds:float = 0.1

var _parent_portal:Portal

# Info about the nodes currently crossing the portal
var _crossing_nodes:Array = []

func _ready() -> void:
    _parent_portal = get_parent() as Portal
    if _parent_portal == null:
        push_error("The PortalTeleport \"%s\" is not a child of a Portal instance" % name)
    
    connect("area_entered", _on_area_entered)
    connect("area_exited", _on_area_exited)

func _process(delta:float) -> void:
    # Update nodes crossing the portal
    for i in range(_crossing_nodes.size() - 1, -1, -1):
        var crossing_node:Dictionary = _crossing_nodes[i]
    
        if not is_instance_valid(crossing_node.node):
            # Node has been freed, remove crossing_node
            _crossing_nodes.remove_at(i)
            continue
        
        # If the portal has yet to leave the enter portal area, try to teleport it
        if not crossing_node.left and _try_teleport(_crossing_nodes[i]):
            # Switch portals so that the portal clone is placed at the entrance portal instead
            crossing_node.clone_portal = _parent_portal.exit_portal
            crossing_node.left = true

        # Move the clone to the exit portal
        if crossing_node.clone != null and crossing_node.clone_portal != null:
            crossing_node.clone.global_transform = crossing_node.clone_portal.real_to_exit_transform(crossing_node.node.global_transform)

        # If the node has left the enter portal, keep it a bit longer before erasing it
        if crossing_node.left:
            crossing_node.keep_alive_seconds -= delta
        if crossing_node.keep_alive_seconds <= 0:
            # Hide portal clone
            if crossing_node.clone != null:
                crossing_node.clone.visible = false

            _crossing_nodes.remove_at(i)
    
# Try to teleport the crossing node, and return false otherwise
func _try_teleport(crossing_node:Dictionary) -> bool:
    var node:Node3D = crossing_node.node

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
            var last_position = crossing_node.position
            crossing_node.position = _parent_portal.to_local(node.global_position)
            if last_position == null or last_position.z <= crossing_node.position.z:
                return false

    # Handle RigidBody3D physics    
    if node is RigidBody3D:
        # Rotate rotation and velocity
        node.linear_velocity = _parent_portal.real_to_exit_direction(node.linear_velocity)
        node.angular_velocity *= _parent_portal.real_to_exit_transform(Transform3D.IDENTITY).basis.inverse()

        # Additional push when exiting the portal
        if exit_push_velocity > 0:
            var exit_forward:Vector3 = _parent_portal.exit_portal.global_transform.basis.z.normalized()
            node.linear_velocity += exit_forward * exit_push_velocity
    
    # Handle CharacterBody3D physics
    elif node is CharacterBody3D:
        # Rotate velocity
        node.velocity = _parent_portal.real_to_exit_direction(node.velocity)

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
        # so we keep a reference to it until it teleports or leaves.
        # This also allows us to hide its portal clone after it leaves.

        var root:Node3D = area.get_node(area.get_meta("teleportable_root"))

        var crossing_node:Dictionary
        if root.has_meta("crossing_node"):
            # Node is crossing another portal, erase it from that portal and start using this one instead
            crossing_node = root.get_meta("crossing_node")
            crossing_node.teleporter._crossing_nodes.erase(crossing_node)
        else:
            # First portal
            var clone:Node3D = area.get_node(area.get_meta("portal_clone")) if area.has_meta("portal_clone") else null
            crossing_node = {
                "node": root, 
                "clone": clone,
                "clone_portal": null,
                "teleporter": null,
                "left": false,
                "keep_alive_seconds": 0.0,
                "position": null,
            }
            root.set_meta("crossing_node", crossing_node)

        crossing_node.clone_portal = _parent_portal
        crossing_node.teleporter = self
        crossing_node.left = false
        crossing_node.keep_alive_seconds = clone_keep_alive_seconds
        crossing_node.position = null

        # Show portal clone if it exists
        if crossing_node.clone != null:
            crossing_node.clone.visible = true

        # Keep track of the node in this portal        
        _crossing_nodes.push_back(crossing_node)
        
        # Try an initial teleport
        if _try_teleport(crossing_node):
            crossing_node.clone_portal = _parent_portal.exit_portal
            crossing_node.left = true

func _on_area_exited(area:Area3D) -> void:
    if area.has_meta("teleportable_root"):
        var root:Node3D = area.get_node(area.get_meta("teleportable_root"))
        var crossing_node:Dictionary = root.get_meta("crossing_node")

        if crossing_node.teleporter == self:
            # The node left the enter portal without teleporting (but don't erase it yet)
            crossing_node.left = true

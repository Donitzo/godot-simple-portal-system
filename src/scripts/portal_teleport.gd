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

## Checks if RigidBody3Ds are moving TOWARDS the portal before teleporting.
@export var velocity_check:bool = true
## An additional velocity push given as the object exits the portal.
@export var exit_push_velocity:float = 0

var _parent_portal:Portal

var _overlapping_bodies:Array = []

func _ready() -> void:
    _parent_portal = get_parent() as Portal
    if _parent_portal == null:
        push_error("The PortalTeleport \"%s\" is not a child of a Portal instance" % name)
    
    connect("area_entered", _on_area_entered)
    connect("area_exited", _on_area_exited)

func _process(_delta:float) -> void:
    var i = 0
    while i < _overlapping_bodies.size():
        var body:RigidBody3D = _overlapping_bodies[i]

        # This may also be a good place to manage a fake replica of the object.
        # Simply put it at the _parent_portal.real_to_exit_transform(body.global_transform) position.

        _process_body(body)

func _process_body(body:RigidBody3D) -> void:
    # Check that the physics body is moving towards the portal
    var portal_forward:Vector3 = _parent_portal.global_transform.basis.z.normalized()
    if velocity_check and body.linear_velocity.dot(portal_forward) > 0:
        return
    
    # Rotate physics rotation and velocity
    var portal_rotation:Basis = _parent_portal.real_to_exit_transform(Transform3D.IDENTITY).basis
    body.linear_velocity *= portal_rotation
    body.angular_velocity *= portal_rotation

    # Additional push when exiting the portal
    if exit_push_velocity > 0:
        body.linear_velocity -= portal_forward * portal_rotation * exit_push_velocity

    # Transform the position and orientation
    body.global_transform = _parent_portal.real_to_exit_transform(body.global_transform)

func _on_area_entered(area:Area3D) -> void:
    if area.has_meta("teleportable_root"):
        var root:Node3D = area.get_node(area.get_meta("teleportable_root"))
        if root is RigidBody3D:
            # Physics bodies may overlap the trigger without teleporting immediately
            _overlapping_bodies.push_back(root)
            _process_body(root)
        else:
            # Other objects always teleport
            root.global_transform = _parent_portal.real_to_exit_transform(root.global_transform)

func _on_area_exited(area:Area3D) -> void:
    if area.has_meta("teleportable_root"):
        var root:Node3D = area.get_node(area.get_meta("teleportable_root"))
        if root is RigidBody3D:
            _overlapping_bodies.erase(root)

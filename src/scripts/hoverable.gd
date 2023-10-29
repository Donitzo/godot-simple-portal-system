"""
    Asset: Godot Simple Portal System
    File: hoverable.gd
    Description: A hoverable object.
    Repository: https://github.com/Donitzo/godot-simple-portal-system
    License: CC0 License
"""

extends RigidBody3D
class_name Hoverable

@onready var _mesh:MeshInstance3D = $Mesh

var hovered:bool

var _strength:float

func _ready() -> void:
    _mesh.material_override = _mesh.mesh.surface_get_material(0).duplicate()

func _process(delta:float) -> void:
    _strength = min(1, _strength + delta * 10) if hovered else max(0, _strength - delta * 10)
    
    _mesh.material_override.albedo_color = lerp(Color.WHITE, Color.RED, _strength)

    hovered = false

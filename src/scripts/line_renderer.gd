"""
    Asset: Godot Simple Portal System
    File: linerenderer.gd
    Description: Line drawing helper based on ImmediateMesh.
    Repository: https://github.com/Donitzo/godot-simple-portal-system
    License: CC0 License
"""

extends MeshInstance3D
class_name LineRenderer

@export var material:Material

var _lines:Array
var _dirty:bool

func _ready() -> void:
    mesh = ImmediateMesh.new()

func add_line(from:Vector3, to:Vector3, color:Color = Color.WHITE) -> void:
    _lines.push_back([from, to, color])
    _dirty = true

func clear_lines() -> void:
    _lines.clear()
    _dirty = true

func _process(_delta:float) -> void:
    if not _dirty:
        return
    _dirty = false

    mesh.clear_surfaces()

    mesh.surface_begin(PrimitiveMesh.PRIMITIVE_LINES, material)

    for line in _lines:
        mesh.surface_set_color(line[2])
        mesh.surface_add_vertex(to_local(line[0]))
        mesh.surface_add_vertex(to_local(line[1]))

    mesh.surface_end()

# Godot Simple Portal System

![Demo screenshot](https://github.com/Donitzo/godot-simple-portal-system/blob/main/images/screenshot.png)

## Description

A Simple Portal System for Godot 4 (and 3 with a little work). Portals hopefully need no introduction. Just think of the game Portal and you get the idea. Non-nested portals are deceptively simple to implement, and can be incredibly powerful as both a gameplay mechanic and as a convenience feature to move players around your level, or to provide countless other fun special effects.

This simple portal system is meant as an educational example on how you can create portals in Godot. Consider it a starting point, as the relevant portal code has been documented clearly.

![Demo animation](https://github.com/Donitzo/godot-simple-portal-system/blob/main/images/demo.gif)

## Theory

In essence, portals are an illusion created by placing a virtual "exit camera" behind the exit portal. This camera replicates the main player camera's relative position to the entrance portal. As a result, both the player and the exit camera view the entrance and exit portals as if they occupy the same screen space. The visuals seen by the exit camera are rendered onto a 'viewport' in Godot (a render target), which is then overlaid on the entrance portal through a screen-space shader. This gives the impression that what's in front of the exit portal is visible through the entrance portal.

![Portal theory](https://github.com/Donitzo/godot-simple-portal-system/blob/main/images/portals.png)

## About the code

This repository contains a small demo project which shows the portals in action. You can move around using WASD or the arrow keys, and look around using the mouse. A raycaster will show you which crates you hit as you move the mouse cursor.

If you want to use the portals in your own project, you only need these two files:

`src/shaders/portal.gdshader`
`src/scripts/portal.gd`

The shader is very simple and just renders a screen-space texture and handles fade-out.

The portal script handles the creation of viewports and virtual cameras in `_ready`. In `_process` the exit camera position is updated according to the main camera. In addition, the `_process` function handles adjusting the near clipping plane of the exit camera to find a compromise between not rendering objects behind the portal, and not cutting off the portal itself. This is done by simply projecting the four corners of the portal onto the camera forward vector to get the near clipping distance. The portal class also has functions for transforming between frames of reference and raycasting.

## About Modelling Portals

First you need to model some portal meshes, or just use a plane or a box.

- The portal model surface should face -Y in Blender and +Z in Godot.
- To make a portal face another way, rotate the model object, not the mesh.
- The raycasting works by treating the portal as a flat surface centered at Z=0 in Godot. Flat portals work best in raycasting.

![Mesh](https://github.com/Donitzo/godot-simple-portal-system/blob/main/images/mesh.png)

## Setup Instructions

> **Note**: Portals are expensive to render. Disable portals which are far away or use "disable_viewport_distance".

> **Note**: Ensure that the parent hierarchy of the portal is uniformly scaled. Non-uniform scaling in the parent hierarchy can introduce skewing effects, which may lead to unexpected or incorrect behavior of the portal. However, scaling the portal itself in a non-uniform way is okay since it is handled by the transformations.

1. Attach the `portal.gd` script to two `MeshInstance3D` nodes that represent your portal surfaces.
2. Establish a connection between the two portals: Assign one portal to the `exit_portal` property of the other portal. For a one-way portal, leave one portal disconnected.
3. Set your primary camera to the `main_camera` property. If left unset, the portal will default to the primary camera if one exists.
4. Set the `vertical_viewport_resolution` of the viewport rendering the portal (which covers the entire screen). Set to 0 to automatically use the real screen resolution.
5. Define the fading range for the portal using `fade_out_distance_max` and `fade_out_distance_min`. Fades to `fade_out_color`.
6. Define the `disable_viewport_distance` for portal rendering. Put the value slightly above `fade_out_distance_max` to ensure the portal fades out completely before disabling itself.
7. Define the `exit_scale` to adjust the exit portal's view scale. Imagine, for instance, a large door leading to a small door.
8. Adjust the `exit_near_subtract` if objects behind the exit portal get cut off. At 0 the portal exit is roughly cut at Z=0.
9. Set `exit_environment` to assign a specific environment to a portal. This is important if, for instance, you want to prevent environmental effects from being applied twice.

## Advanced Usage

These functions aid in transitioning between the portal entrance and exit frames of reference:

- `real_to_exit_transform(real:Transform3D) -> Transform3D`
- `real_to_exit_position(real:Vector3) -> Vector3`
- `real_to_exit_direction(real:Vector3) -> Vector3`

These are useful when you manipulate portal-associated objects. For instance, these functions would allow you to position a cloned spotlight at the exit portal:

```gd
clone_spotlight.global_transform = portal.real_to_exit_transform(real_spotlight.global_transform)
```

This code can also be used to teleport an object to the exit portal. Alternatively use `real_to_exit_position` if you only want to change the global position of your object.

> **Note**: Portals currently do not nest (ie, you can't see through two portals at once). To nest portals you'd have to update the exit_camera position in-between draw calls, or figure out a way to change the camera view matrix in-between rendering viewports. That is beyond the scope of this simple system, but if you got some nice ideas how to implement these things in godot, please [open an issue](https://github.com/Donitzo/godot-simple-portal-system/issues).

### Crossing a Portal

If the player in your game has a physical shape, such as hands or a body, having these parts cross the portal surface before teleporting the player to the exit will cause them to disappear. There are several solutions to this issue:

* Create a dummy player at the exit portal and move it using `real_to_exit_transform`. This stand-in will replace the missing player as it moves through the portal.
* Instead of a single portal, create two pairs of one-way portals with a buffer zone between them. This allows the player to fully enter the buffer zone before being teleported to the exit.
* With a single pair of portals, create a buffer zone by moving the mesh surface backward along the Z-axis (+Y in Blender). Note that since the exit camera's near clipping range calculations assume the mesh is at Z=0, you may need to adjust the near clipping range through `exit_near_subtract` or another method. Anecdotally, in my game, I prefer making the portals shaped like `/‾‾‾‾\` rather than `______`. This provides a buffer zone for the player to move their hand in while still occupying the same space as a flat portal.

## Raycasting

Raycasting through portals can be complex. To simplify this, a built-in raycasting function is provided.

Define a function with this signature, in which you do your own raycasting against non-portal objects:

```gd
func _handle_raycast(from:Vector3, dir:Vector3, segment_distance:float, recursive_distance:float, recursions:int) -> bool:
```

Declare a callable for your function:

```gd
var callable:Callable = Callable(self, "_handle_raycast")
```

Then, use the built-in raycasting function as follows:

```gd
Portal.raycast(get_tree(), from_position, direction, callable, [max_distance=INF], [max_recursions=2], [ignore_backside=true])
```

`_handle_raycast` is always invoked at least once for the original ray. The `segment_distance` is `INF` if no portal was hit, or the distance to the hit portal. The function is invoked once more each time the ray recursively passes through another portal. A ray can be prematurely interrupted if `_handle_raycast` returns true, or if it hits the `max_recursions` limit. Return true if for example the current ray segment (within `segment_distance`) was blocked by something.

If you want to manually raycast, you can adapt the code in the Portal.raycast function to suit your requirements. Assuming you know a ray hits the entrance portal, you can get the corresponding exit ray using:

```gd
exit_position = portal.real_to_exit_position(position)
exit_direction = portal.real_to_exit_direction(direction)
```

## Feedback & Bug Reports

If you find any bugs or have feedback, please [open an issue](https://github.com/Donitzo/godot-simple-portal-system/issues) in the GitHub repository.

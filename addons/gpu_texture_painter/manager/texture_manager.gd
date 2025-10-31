@tool
extends Node
class_name TextureManager

@export var overlay_material: Material = preload("uid://bdnbf5ol6km4a")
@export_tool_button("Apply Materials") var tmp = apply_materials

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func apply_materials() -> void:
	var mesh_instances :=  get_all_mesh_instances(get_parent())
	mesh_instances.pop_front()  # remove parent
	
	for mesh_instance in mesh_instances:
		mesh_instance.material_overlay = overlay_material
		print("set material")

func get_all_mesh_instances(node: Node, children_acc: Array[MeshInstance3D] = []) -> Array[MeshInstance3D]:
	if node is MeshInstance3D:
		children_acc.push_back(node)
		
	for child in node.get_children():
		children_acc = get_all_mesh_instances(child, children_acc)

	return children_acc

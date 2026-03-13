@tool
extends EditorPlugin

const OVERLAY_ATLAS_MENU_SCENE := preload("uid://ykobo4v8o4kg")

var overlay_atlas_menu: Node

# plugin gets enabled
func _enter_tree() -> void:
	overlay_atlas_menu = OVERLAY_ATLAS_MENU_SCENE.instantiate()
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, overlay_atlas_menu)
	overlay_atlas_menu.hide()

# plugin gets disabled
func _exit_tree() -> void:
	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, overlay_atlas_menu)
	overlay_atlas_menu.queue_free()



func _handles(object: Object) -> bool:
	if object is OverlayAtlasManager:
		return true
	else:
		return false

# overlay atlas manager gets selected -> show
func _make_visible(visible: bool) -> void:
	if visible:
		overlay_atlas_menu.show()
	else:
		overlay_atlas_menu.hide()


func _forward_3d_gui_input(camera, event):
	if overlay_atlas_menu.drawing:
		return EditorPlugin.AFTER_GUI_INPUT_CUSTOM
	else:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

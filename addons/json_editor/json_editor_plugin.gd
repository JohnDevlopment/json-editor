tool
extends EditorPlugin

var _json_editor

func _enter_tree() -> void:
	_add_custom_editor_view()
	_json_editor.editor_interface = get_editor_interface()
	get_editor_interface().get_editor_viewport().add_child(_json_editor)
	make_visible(false)

func _exit_tree() -> void:
	_remove_custom_editor_view()

func get_plugin_icon() -> Texture:
	return get_editor_interface().get_base_control().get_icon("Node", "EditorIcons")

func has_main_screen() -> bool: return true

func get_plugin_name() -> String: return "JSONEditor"

func make_visible(visible: bool) -> void:
	if _json_editor:
		_json_editor.visible = visible

func _add_custom_editor_view():
	_json_editor = preload('res://addons/json_editor/editor/json_editor.tscn').instance()
	_json_editor.is_in_editor = true
	(_json_editor as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL

func _remove_custom_editor_view():
	if _json_editor:
		remove_control_from_bottom_panel(_json_editor)
		_json_editor.queue_free()

tool
extends Control

const TextEditorScene = preload('res://addons/json_editor/editor/TextEditor.tscn')

enum FileMenuChoice {NEW, OPEN, SAVE, CLOSE}
enum FileDialogOption {NEW, OPEN}

var is_in_editor := false
var file_dialog_option := -1
var editor_interface: EditorInterface
onready var file_list = $EditorPanel/Editor/FileSplit/VBoxContainer/FileList
onready var file_dialog = $FileDialog
onready var tab_container = $EditorPanel/Editor/FileSplit/TabContainer

func _enter_tree() -> void:
	if is_in_editor:
		print('add items to File menu') # TODO: remove this
		var file_menu: PopupMenu = $EditorPanel/Editor/StatusBar/File.get_popup()
		file_menu.add_item("New File...", FileMenuChoice.NEW)
		file_menu.add_item("Open File...", FileMenuChoice.OPEN)
		file_menu.add_separator()
		file_menu.add_item("Save File", FileMenuChoice.SAVE)
		file_menu.add_separator()
		file_menu.add_item("Close File", FileMenuChoice.CLOSE)

func _ready() -> void:
	if is_in_editor:
		set_focus_mode(Control.FOCUS_ALL)
		$EditorPanel/Editor/StatusBar/GotoLineButton.connect('pressed', self, '_on_goto_line_button_pressed')
		file_list.connect('item_selected', self, '_on_file_selected')
		$EditorPanel/Editor/StatusBar/File.get_popup().connect('id_pressed', self, '_on_File_id_pressed')
		editor_interface.get_resource_filesystem().connect('filesystem_changed', self, '_on_filesystem_changed')
		
		_open_file('res://json_files/example.json')
		_open_file('res://json_files/another_example.json')
		call_deferred('_update_script_names')

# Internal functions to execute common actions of the editor

func _safe_get_child(parent: Node, idx: int):
	for i in parent.get_child_count():
		if i == idx:
			return parent.get_child(idx)

func _go_to_tab(idx: int) -> void:
	# TODO: _get_current_editor()
	var c: Control
	
	c = _safe_get_child(tab_container, idx)
	if not is_instance_valid(c):
		return
	
	tab_container.set_current_tab(idx)
	
	c = tab_container.get_current_tab_control()
	
	if c is TextEdit:
		if is_visible_in_tree():
			c.ensure_focus()
	
	_update_selected_editor_menu()

# TODO: this function is called when all files (tabs) are closed
func _update_selected_editor_menu() -> void:
	if tab_container.get_child_count() == 0:
		$EditorPanel/Editor/StatusBar/Edit.hide()
	else:
		$EditorPanel/Editor/StatusBar/Edit.show()

func _open_file(path: String):
	var text_editor = TextEditorScene.instance()
	tab_container.add_child(text_editor)
	text_editor.edit(path)

func _close_current_tab(save: bool) -> void:
	_close_tab(tab_container.current_tab, save)

func _close_tab(idx: int, save: bool) -> void:
	var selected := idx
	if selected < 0 or selected >= tab_container.get_child_count():
		print("selected = ", selected)
		push_warning(str("selected = ", selected))
		return
	var tab_selected: Control = tab_container.get_child(idx)
	
	# TODO: _history_back(): goes to last active tab
	
	# TODO: remove from history
	
	idx = tab_container.current_tab
#	tab_container.remove_child(tab_selected)
	tab_selected.queue_free()
	
	var count: int = tab_container.get_child_count() - 1
	if idx >= count:
		idx = count - 1
	if idx >= 0:
		pass
		# TODO: use the history to find the last active tab, if history is not empty
	else: # No items left on list
		_update_selected_editor_menu()
	
	_update_script_names()

# Signal callbacks

func _on_goto_line_button_pressed():
	var text_editor = tab_container.get_current_tab_control()
	$GotoLineDialog.popup_find_line(text_editor)

func _on_file_selected(index: int) -> void:
	_go_to_tab(file_list.get_item_metadata(index))

func _on_File_id_pressed(id: int):
	match id:
		FileMenuChoice.NEW:
			file_dialog.mode = FileDialog.MODE_SAVE_FILE
			file_dialog.access = FileDialog.ACCESS_FILESYSTEM
			file_dialog.popup_centered_clamped(Vector2(700, 500), 0.8)
			file_dialog.window_title = "New JSON File..."
			file_dialog_option = FileDialogOption.NEW
		FileMenuChoice.OPEN:
			file_dialog.mode = FileDialog.MODE_OPEN_FILE
			file_dialog.access = FileDialog.ACCESS_FILESYSTEM
			file_dialog.popup_centered_clamped(Vector2(700, 500), 0.8)
			file_dialog.window_title = "Open JSON File..."
			file_dialog_option = FileDialogOption.OPEN
		FileMenuChoice.SAVE:
			var text_editor = tab_container.get_current_tab_control()
			if text_editor:
				text_editor.save()
		FileMenuChoice.CLOSE:
			_close_current_tab(false)
		_:
			printerr("invalid id ", id)

func _on_FileDialog_file_selected(path: String) -> void:
	match file_dialog_option:
		FileDialogOption.NEW:
			var output := File.new()
			var err = output.open(path, File.WRITE)
			if err:
				push_warning("Error writing text file: " + path)
			else:
				output.store_string("\t")
				output.close()
				_open_file(path)
				_update_script_names()
				editor_interface.get_resource_filesystem().scan()
		FileDialogOption.OPEN:
			_open_file(path)
			_update_script_names()
	file_dialog_option = -1

func _on_filesystem_changed() -> void: _update_script_names()

# Functions that update the state of the editor

func _update_script_names() -> void:
	file_list.clear()
	var j := 0
	var offset := 0
	for i in tab_container.get_child_count():
		var text_editor: Control = tab_container.get_child(i)
		if text_editor.is_queued_for_deletion():
			offset += 1
			continue
		var file_name: String = text_editor.get_meta('edit_file_path')
		file_list.add_item(file_name.get_file())
		file_list.set_item_metadata(j, i - offset)
		j += 1
	_update_selected_editor_menu()

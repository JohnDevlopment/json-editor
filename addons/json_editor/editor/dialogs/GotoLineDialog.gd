tool
extends ConfirmationDialog

var _text_edit: TextEdit

func _ready() -> void:
	register_text_enter($VBoxContainer/LineEdit)
	connect('confirmed', self, '_on_OK_pressed')

func get_line() -> int:
	return $VBoxContainer/LineEdit.text.to_int()

func popup_find_line(edit: TextEdit) -> void:
	_text_edit = edit
	$VBoxContainer/LineEdit.text = str(_text_edit.cursor_get_line())
	popup_centered()
	$VBoxContainer/LineEdit.grab_focus()

func _on_OK_pressed() -> void:
	var i := get_line()
	if i < 1 or i > _text_edit.get_line_count():
		return
	_text_edit.unfold_line(i)
	_text_edit.cursor_set_line(i)
	_text_edit.grab_focus()
	hide()

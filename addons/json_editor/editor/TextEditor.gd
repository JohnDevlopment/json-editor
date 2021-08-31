tool
extends TextEdit

enum DelimiterType {STRING, COMMENT}

class Delimiter:
	var type: int
	var start: String
	var end: String
	var line_only: bool

class BracePair:
	var open: String
	var close: String

var _brace_pairs := []
var _delimiters := []

const UNICODE_SYMBOL_MAP := {
	'_': ord('_'),
	'!': ord('!'),
	'/': ord('/'),
	' ': ord(' '),
	':': ord(':'),
	'@': ord('@'),
	'[': ord('['),
	'`': ord('`'),
	'{': ord('{'),
	'~': ord('~'),
	"\t": ord("\t")
}

func _ready() -> void:
	var parent = get_node_or_null(@"/root/EditorView")
	if parent:
		add_auto_brace_completion_pair('[', ']')
		add_auto_brace_completion_pair('{', '}')
		add_auto_brace_completion_pair("\"", "\"")
		add_auto_brace_completion_pair("\'", "\'")
		_add_delimiter("\"", "\"", false, DelimiterType.STRING)
		_add_delimiter("\'", "\'", false, DelimiterType.STRING)

func _exit_tree() -> void:
	var parent = get_node_or_null(@"/root/EditorView")
	if parent:
		print("_exit_tree: save ", get_meta("edit_file_path")) # TODO: remove
		save()

func add_auto_brace_completion_pair(open: String, close: String) -> void:
	for c in open:
		if not is_symbol(c):
			push_error("%s is not a symbol" % open)
			return
	for c in close:
		if not is_symbol(c):
			push_error("%s is not a symbol" % close)
			return
	for pair in _brace_pairs:
		if pair.open == open:
			push_error("open brace '%s' already exists" % open)
			return
	var pair := BracePair.new()
	pair.open = open
	pair.close = close
	_brace_pairs.append(pair)

func add_string_delimiter(start_key: String, end_key: String, line_only: bool) -> void:
	_add_delimiter(start_key, end_key, line_only, DelimiterType.STRING)

func has_string_delimiter(c: String) -> bool:
	return _has_delimiter(c, DelimiterType.STRING)

func is_in_comment(line: int, column: int):
	pass

func is_symbol(s: String) -> bool:
	var i := ord(s)
	return i != UNICODE_SYMBOL_MAP['_'] and (
			(i >= UNICODE_SYMBOL_MAP['!'] and i <= UNICODE_SYMBOL_MAP['/']) or
			(i >= UNICODE_SYMBOL_MAP[':'] and i <= UNICODE_SYMBOL_MAP['@']) or
			(i >= UNICODE_SYMBOL_MAP['['] and i <= UNICODE_SYMBOL_MAP['`']) or
			(i >= UNICODE_SYMBOL_MAP['{'] and i <= UNICODE_SYMBOL_MAP['~']) or
			(i != UNICODE_SYMBOL_MAP[' '] and i != UNICODE_SYMBOL_MAP["\t"])
		)

func edit(path: String) -> void:
	var input := File.new()
	if input.open(path, File.READ):
		push_error("unable to open " + path)
		return
	text = input.get_as_text()
	input.close()
	set_meta('edit_file_path', path)
	name = path.get_file()

func ensure_focus() -> void:
	grab_focus()

func save() -> void:
	var output := File.new()
	output.open(get_meta('edit_file_path'), File.WRITE)
	output.store_string(text)
	output.close()

func _get_auto_brace_pair_close_at_pos(line: int, column: int) -> int:
	var cur_line := get_line(line)
	for i in range(_brace_pairs.size()):
		var close_key: String = _brace_pairs[i].close
		if (column + close_key.length()) > cur_line.length():
			continue
		
		var is_match := true
		for j in range(close_key.length()):
			if cur_line[column + j] != close_key[j]:
				is_match = false
				break
		
		if is_match:
			return i
	return -1

func _get_auto_brace_pair_open_at_pos(line: int, column: int) -> int:
	var cur_line := get_line(line)
	for i in range(_brace_pairs.size()):
		var open_key: String = _brace_pairs[i].open
		if (column - open_key.length()) < 0:
			continue
		
		var is_match := true
		for j in range(open_key.length()):
			if cur_line[(column - 1) - j] != open_key[(open_key.length() - 1) - j]:
				is_match = false
				break
		
		if is_match:
			return i
	return -1

func _is_char(c: String) -> bool: return ! is_symbol(c)

func _is_in_delimiter(line: int, column: int, delimiter_type: int) -> int:
	if _delimiters.size() == 0:
		return -1
	if line < 0 or line >= get_line_count():
		printerr("_is_in_delimiter(): invalid index %d, must be between 0 and %d"\
			% [line, get_line_count()-1])
		return 0
	
	return 0

func _handle_unicode_input(unicode_char: int):
	if readonly: return
	var was_selected := is_selection_active()
	if was_selected:
		cut()
	
	var cl := cursor_get_line()
	var cc := cursor_get_column()
	var cursor_move_offset := 1
	var post_brace_pair = _get_auto_brace_pair_close_at_pos(cl, cc) if (cc < get_line(cl).length()) else -1
	var ch := char(unicode_char)
	if has_string_delimiter(ch) and cc > 0 and _is_char(get_line(cl)[cc - 1]) && post_brace_pair == -1:
		pass
	elif cc < get_line(cl).length() and _is_char(get_line(cl)[cc]):
		pass
	elif post_brace_pair != -1 and _brace_pairs[post_brace_pair].close[0] == ch:
		cursor_move_offset = _brace_pairs[post_brace_pair].close.length()
	# TODO: is_in_comment() and is_in_string()
	else:
		yield(self, 'text_changed')
		var pre_brace_pair := _get_auto_brace_pair_open_at_pos(cl, cc + 1)
		if pre_brace_pair >= 0:
			insert_text_at_cursor(_brace_pairs[pre_brace_pair].close)
	cursor_set_column(cc + cursor_move_offset)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.scancode in [KEY_CONTROL, KEY_ALT, KEY_SHIFT, KEY_META]:
			return
		if not key.pressed or key.echo:
			return
		
		var allow_unicode: bool = not(key.control or key.alt or key.meta or key.command)
		if allow_unicode and not readonly and (key.unicode >= 32 or key.unicode == KEY_TAB):
			_handle_unicode_input(key.unicode)
			accept_event()

# Has delimiters

func _has_delimiter(start_key: String, delimiter_type: int) -> bool:
	for d in _delimiters:
		if d.start == start_key:
			return d.type == delimiter_type
	return false

# Add delimiters

func _add_delimiter(start_key: String, end_key: String, line_only: bool, delimiter_type: int) -> void:
	for c in start_key:
		if not is_symbol(c):
			push_error("%s is not a symbol" % start_key)
			return
	for c in end_key:
		if not is_symbol(c):
			push_error("%s is not a symbol" % end_key)
			return
	var at := 0
	for i in _delimiters.size():
		if (_delimiters[i] as Delimiter).start == start_key:
			push_error("delimiter with start key '%s' already exists" % start_key)
			return
		if start_key.length() < (_delimiters[i] as Delimiter).start.length():
			at += 1
	
	var d := Delimiter.new()
	d.type = delimiter_type
	d.start = start_key
	d.end = end_key
	d.line_only = line_only or end_key == ''
	_delimiters.insert(at, d)
	# TODO: if not setting delimiters, clear cache and update it


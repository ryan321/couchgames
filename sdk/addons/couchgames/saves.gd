extends RefCounted
## Bounded JSON files under COUCH_SAVE_DIR or user://giga-couch-saves. Not SQLite.

const MAX_BYTES := 256 * 1024
const DEFAULT_DIR := "user://giga-couch-saves"


static func save_data(slot: String, data: Variant) -> Dictionary:
	var slot_error := _slot_error(slot)
	if not slot_error.is_empty():
		return {"ok": false, "error": slot_error}
	if not _json_compatible(data):
		return {"ok": false, "error": "data must be JSON-compatible"}
	var encoded := JSON.stringify(data)
	if encoded.to_utf8_buffer().size() > MAX_BYTES:
		return {"ok": false, "error": "save exceeds 256 KiB"}
	var directory := _absolute_dir()
	var make := DirAccess.make_dir_recursive_absolute(directory)
	if make != OK and not DirAccess.dir_exists_absolute(directory):
		return {"ok": false, "error": "could not create save directory"}
	var destination := directory.path_join("%s.json" % slot)
	var temporary := destination + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "could not write save"}
	file.store_string(encoded)
	file.close()
	var renamed := DirAccess.rename_absolute(temporary, destination)
	if renamed != OK:
		DirAccess.remove_absolute(destination)
		renamed = DirAccess.rename_absolute(temporary, destination)
	if renamed != OK:
		DirAccess.remove_absolute(temporary)
		return {"ok": false, "error": "could not write save"}
	return {"ok": true}


static func load_data(slot: String) -> Dictionary:
	var slot_error := _slot_error(slot)
	if not slot_error.is_empty():
		return {"ok": false, "error": slot_error}
	var path := _absolute_dir().path_join("%s.json" % slot)
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "not found"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "could not read save"}
	if file.get_length() > MAX_BYTES:
		return {"ok": false, "error": "save exceeds 256 KiB"}
	var text := file.get_as_text()
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return {"ok": false, "error": "invalid save"}
	return {"ok": true, "data": parser.data}


static func _absolute_dir() -> String:
	var path := OS.get_environment("COUCH_SAVE_DIR")
	if not path.is_absolute_path():
		path = DEFAULT_DIR
	if path.begins_with("user://") or path.begins_with("res://"):
		return ProjectSettings.globalize_path(path)
	return path


static func _slot_error(slot: String) -> String:
	if slot.length() < 1 or slot.length() > 32:
		return "invalid slot"
	for i in slot.length():
		var ch := slot[i]
		var allowed := (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "-" or ch == "_"
		if not allowed:
			return "invalid slot"
	return ""


static func _json_compatible(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return true
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_ARRAY:
			for item in value:
				if not _json_compatible(item):
					return false
			return true
		TYPE_DICTIONARY:
			for key in value:
				if typeof(key) != TYPE_STRING or not _json_compatible(value[key]):
					return false
			return true
		_:
			return false

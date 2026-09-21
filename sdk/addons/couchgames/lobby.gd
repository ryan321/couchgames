extends CanvasLayer
## Join/ready overlay. Games own spawn; connect to match_started.

signal match_started
signal ready_changed

const NAVY := Color("192331")
const MINT := Color("8ce8be")
const INK := Color("f2f5f8")
const MUTED := Color("a0afbf")

var started := false
var ready_players: Dictionary = {}
var _list: VBoxContainer
var _hint: Label
var _input: Node


func _init() -> void:
	layer = 40
	name = "LobbyOverlay"


func _ready() -> void:
	var platform := get_parent()
	_input = platform.input if platform and platform.get("input") else get_node_or_null("/root/Platform").input
	_input.player_joined.connect(func(id: int): _set_ready(id, false); _refresh())
	_input.player_left.connect(func(id: int): ready_players.erase(id); _refresh())
	_input.roster_changed.connect(_refresh)
	_build()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if started or _input == null:
		return
	if event is InputEventJoypadButton and event.pressed:
		var id: int = _input.player_for_device(event.device)
		if id != 0 and _input.consume_jump(id):
			_set_ready(id, not ready_players.get(id, false))
			get_viewport().set_input_as_handled()


func all_ready() -> bool:
	if _input == null or _input.players.is_empty():
		return false
	for id in _input.players:
		if ready_players.get(int(id), false) != true:
			return false
	return true


func begin_match() -> void:
	if started:
		return
	started = true
	visible = false
	match_started.emit()


func _set_ready(id: int, value: bool) -> void:
	ready_players[id] = value
	ready_changed.emit()
	_refresh()
	if value and all_ready():
		begin_match()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color("101722cc")
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var box := PanelContainer.new()
	box.position = Vector2(420, 120)
	box.size = Vector2(760, 620)
	var style := StyleBoxFlat.new()
	style.bg_color = NAVY
	style.border_color = MINT
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(28)
	box.add_theme_stylebox_override("panel", style)
	root.add_child(box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	box.add_child(column)
	var title := Label.new()
	title.text = "Grab a controller"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", INK)
	column.add_child(title)
	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", MUTED)
	column.add_child(_hint)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	column.add_child(_list)


func _refresh() -> void:
	if _list == null or _input == null:
		return
	for child in _list.get_children():
		child.queue_free()
	if _input.players.is_empty():
		_hint.text = "Press A / Cross (or Enter) to join. Hold B / Circle to leave."
	elif all_ready():
		_hint.text = "Everyone is ready. Starting…"
		begin_match()
	else:
		_hint.text = "A / Cross readies up. When everyone is ready, the match starts."
	for id in _input.players.keys():
		var row := Label.new()
		var mark := "READY" if ready_players.get(id, false) else "JOINED"
		row.text = "Player %02d    %s" % [id, mark]
		row.add_theme_font_size_override("font_size", 22)
		row.add_theme_color_override("font_color", MINT if ready_players.get(id, false) else INK)
		_list.add_child(row)

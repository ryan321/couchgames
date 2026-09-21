extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func run() -> void:
	var directory := OS.get_cache_dir().path_join("couch-library-test-%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(directory)
	OS.unset_environment("COUCH_LIBRARY_CATALOG")
	OS.set_environment("COUCH_LIBRARY_SESSION",directory)
	var library = load("res://launcher/library.tscn").instantiate()
	root.add_child(library)
	current_scene = library
	library.set_process(false)
	OS.unset_environment("COUCH_LIBRARY_SESSION")
	expect(library.cards.size()==7,"All seven source games appear")
	expect(ResourceLoader.exists("res://launcher/mark.png"),"Library includes the Giga Couch mark")
	for game in library.games:
		expect(FileAccess.file_exists(game.scene),"Catalog scene exists")
	library.controller.select(0)
	library.cards[2].pressed.emit()
	var request: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("request.json")))
	expect(request.game=="pocket-rally" and request.action=="launch","Clicking card requests its exact game")
	expect(library.busy and library.cards[0].disabled,"Game request disables background launch controls")
	library.cards[0].pressed.emit()
	var unchanged := FileAccess.get_file_as_string(directory.path_join("request.json"))
	expect(JSON.parse_string(unchanged).game=="pocket-rally","Double launch cannot replace the requested game")
	library.apply_status({"phase":"idle","updated":Time.get_unix_time_from_system(),"message":"stale ack"})
	expect(library.busy,"Earlier host status cannot cancel pending request")
	library.apply_status({"phase":"running","updated":Time.get_unix_time_from_system(),"request_id":request.request_id,"message":"Playing"})
	expect(library.busy,"Running game keeps library input suspended")
	library.apply_status({"phase":"error","updated":Time.get_unix_time_from_system(),"message":"Try again"})
	library._process(1)
	expect(not library.busy and library.cards[2].has_focus(),"Crash returns focus to the selected game after cooldown")
	library.controller.select(1 if OS.get_name()=="macOS" else 0)
	library.cards[1].pressed.emit()
	request = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("request.json")))
	expect(request.game=="cloudbound","Retry can launch another game")
	library.apply_status({"phase":"error","updated":Time.get_unix_time_from_system(),"request_id":request.request_id,"message":"No reader"})
	library._process(1)
	expect(not library.busy and library.status.text=="No reader","Failed startup restores playable cards with reason")
	library.cards[4].grab_focus()
	await process_frame
	await process_frame
	var scroll_end: float = library.game_scroll.global_position.y + library.game_scroll.size.y
	expect(library.cards[4].get_global_rect().end.y<=scroll_end + 2,"The fifth game remains above the controller settings")
	library.cards[4].pressed.emit()
	request = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("request.json")))
	expect(request.game=="gauntlet","The fifth card launches Gauntlet")
	library.apply_status({"phase":"idle","updated":Time.get_unix_time_from_system(),"request_id":request.request_id,"message":"Ready"})
	library._process(1)
	library.cards[5].grab_focus()
	await process_frame
	await process_frame
	expect(library.cards[5].get_global_rect().end.y<=scroll_end + 2,"Sunbreak remains visible in the scrolling library")
	library.cards[5].pressed.emit()
	request = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("request.json")))
	expect(request.game=="sunbreak","The sixth card launches Sunbreak")
	library.apply_status({"phase":"idle","updated":Time.get_unix_time_from_system(),"request_id":request.request_id,"message":"Ready"})
	library._process(1)
	library.cards[6].grab_focus()
	await process_frame
	await process_frame
	expect(library.cards[6].get_global_rect().end.y<=scroll_end + 2,"Haymaker remains visible in the scrolling library")
	library.cards[6].pressed.emit()
	request = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("request.json")))
	expect(request.game=="haymaker","The seventh card launches Haymaker")
	library.apply_status({"phase":"idle","updated":Time.get_unix_time_from_system(),"request_id":request.request_id,"message":"Ready"})
	library._process(1)
	library.status.text = "Choose something to play."
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			await process_frame
			await RenderingServer.frame_post_draw
			expect(root.get_texture().get_image().save_png(argument.trim_prefix("--capture="))==OK,"Library screenshot saved")
	DirAccess.remove_absolute(directory.path_join("request.json"))
	DirAccess.remove_absolute(directory)
	if not failures:
		print("Library checks passed: %d UI/lifecycle assertions." % checks)
	quit(1 if failures else 0)

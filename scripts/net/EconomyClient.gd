extends RefCounted
## Refresh the last server catalog before displaying commercial UI on native clients.
static func refresh(parent: Node) -> bool:
	if OS.has_feature("web"): return PriceBook.ready()
	var http := HTTPRequest.new()
	http.timeout = 8.0
	parent.add_child(http)
	var error := http.request(Cloud.url + "/v1/economy/catalog")
	if error != OK:
		http.queue_free()
		return PriceBook.ready()
	var response: Array = await http.request_completed
	http.queue_free()
	if int(response[1]) != 200: return PriceBook.ready()
	var body = JSON.parse_string(response[3].get_string_from_utf8())
	if not body is Dictionary or not Replay.install_economy_catalog(body): return PriceBook.ready()
	var cache := FileAccess.open("user://economy-catalog.json", FileAccess.WRITE)
	if cache != null: cache.store_string(JSON.stringify(body)); cache.close()
	return true

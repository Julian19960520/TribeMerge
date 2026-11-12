extends RefCounted
## Paid purchases. The server prices the order, takes the payment and issues a grant;
## the client applies each grant once (Reducer.apply_grant records its id in replay_meta),
## uploads the save and then acknowledges it. Grants paid while the reply was lost, or
## before a crash, arrive through deliver() on the next boot.
## Products: amber:<k>, pass:vip, pass:super, offer:<kind>:<tier>, ufo, gift:<step> (server/app/catalog.py).

const OFFLINE := "需要联网才能购买，请连接网络后重试"
const PENDING := "支付已完成，奖励会在联网后自动到账"
const ATTEMPTS := 3
const UPLOAD_WAIT_MS := 15000
## True while a delivery pass runs; a second caller waits for it instead of fetching again.
static var _delivering := false
## Results of grants applied on this device, for the purchase that is waiting for them.
static var _results: Dictionary = {}

## Why purchases are impossible right now ("" = possible).
static func unavailable() -> String:
	if not Cloud.enabled: return "离线测试模式不能购买，请连接服务器后再试"
	if Cloud.kicked != "": return "登录已失效，请在 设置 → 账号与数据 重新登录后购买"
	if not Cloud.can_talk(): return OFFLINE
	return ""

## Buy one product. Returns {"ok", "amber", "rewards"} once the grant is applied to this
## save, or {"ok": false, "error", "message"} with a message the caller shows as a toast.
static func buy(product: String, detail: Dictionary = {}) -> Dictionary:
	var why := unavailable()
	if why != "": return {"ok": false, "error": "offline", "message": why}
	var created := await _retry("POST", "/v1/payments/orders", {"product": product, "detail": detail}, "buy-" + Cloud._uuid())
	if int(created[0]) != 200: return _fail(created)
	var paid := await _pay(created[1]["order"])
	if int(paid[0]) == 0:
		# The payment may have gone through; its grant stays on the server until delivered.
		return {"ok": false, "error": "pending", "message": PENDING}
	if int(paid[0]) != 200: return _fail(paid)
	var grant_id := str(paid[1]["grant"]["id"])
	await deliver()
	if not _results.has(grant_id): return {"ok": false, "error": "pending", "message": PENDING}
	var result: Dictionary = _results[grant_id]
	_results.erase(grant_id)
	return result

## Platform payment. Store SDKs plug in here and hand their receipt to
## POST /v1/payments/orders/{id}/confirm; development servers use the mock provider.
static func _pay(order: Dictionary) -> Array:
	return await _retry("POST", "/v1/payments/mock/pay", {"order_id": str(order["id"])})

## Apply every undelivered grant once, upload the save that contains them, then acknowledge.
static func deliver() -> void:
	if _delivering:
		var tree := Engine.get_main_loop() as SceneTree
		while _delivering: await tree.process_frame
		return
	if unavailable() != "": return
	_delivering = true
	var response: Array = await Cloud._call("GET", "/v1/payments/grants", null)
	var done: Array = []
	if int(response[0]) == 200:
		for grant in response[1].get("grants", []):
			var id := str(grant.get("id", ""))
			var result: Dictionary = Replay.perform("grant", {"id": id, "content": grant.get("content", {})})
			if result.get("ok", false):
				_results[id] = {"ok": true, "amber": int(result.get("amber", 0)), "rewards": result.get("rewards", [])}
				done.append(id)
			elif result.get("duplicate", false):
				done.append(id)
			else:
				push_warning("Grant %s not applied: %s" % [id, str(result.get("error", ""))])
	if not done.is_empty(): await _upload_and_ack(done)
	_delivering = false

static func _upload_and_ack(ids: Array) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var start := Time.get_ticks_msec()
	while (Cloud._busy or Replay.executing) and Time.get_ticks_msec() - start < UPLOAD_WAIT_MS:
		await tree.process_frame
	await Replay.upload()
	# The server only marks grants delivered that the stored save contains; if this
	# upload failed, the next successful upload delivers them instead.
	if Replay.needs_upload(): return
	await Cloud._call("POST", "/v1/payments/grants/ack", {"ids": ids})

static func _retry(method: String, path: String, body, key := "") -> Array:
	var response: Array = [0, {}]
	for attempt in ATTEMPTS:
		response = await Cloud._call(method, path, body, key)
		if int(response[0]) != 0: break
	return response

static func _fail(response: Array) -> Dictionary:
	if int(response[0]) == 0: return {"ok": false, "error": "offline", "message": OFFLINE}
	var data: Dictionary = response[1] if response[1] is Dictionary else {}
	return {"ok": false, "error": str(data.get("error", "failed")), "message": str(data.get("message", "没买成，请稍后再试"))}

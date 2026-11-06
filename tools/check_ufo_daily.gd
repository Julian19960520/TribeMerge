extends SceneTree
var failures := []
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func run() -> void:
	var g = root.get_node("G")
	var daily=load("res://scripts/events/DailyShop.gd")
	var ufo=load("res://scripts/events/UfoOffer.gd")
	var event=load("res://scripts/events/MergeEvent.gd")
	var race=load("res://scripts/net/Race.gd").inst()
	g.new_game();g.set_process(false);g.tutorial_on=false;g.seen_tutorial=true
	g.energy=0;g.amber=0;g.shells=300
	check(not event.available(event.current()) and not race.unlocked(),"activities locked at level one")
	g.gm_activities=true;g.save_game();g.gm_activities=false;g.load_game()
	check(g.gm_activities and g.level==1 and event.available(event.current()) and race.unlocked(),"GM persists both unlocks without level rewards")
	var local=load("res://scripts/events/LocalRace.gd")
	check((await race.join()).get("ok",false) and race.joined(),"GM unlock allows local banana match")
	race._on_order(["fruit_14"])
	check(float(race.me()["score"])>0,"local race progresses on delivered orders")
	g.local_race["current"]["group"]["end"]=g.now()-1
	local.tick();race.fetch()
	var result: Dictionary=race.pending_result().duplicate(true)
	var claim: Dictionary=await race.claim(result)
	check(claim.get("ok",false) and claim["rewards"].size()>0 and not (await race.claim(result)).get("ok",false),"local podium reward can be claimed only once")
	local.join()
	for m in g.local_race["current"]["group"]["members"]:
		if not m["me"]:m["rate"]=100000
	g.local_race["current"]["group"]["start"]=g.now()-10
	local.tick()
	check(g.local_race["results"][0]["me"]["place"]==5 and g.local_race["results"][0]["me"]["reward"].is_empty(),"local banana race awards only top three")
	g.local_race={};race.fetch()
	check(not (await daily.claim("deal_member_1")).get("ok",false),"non-member cannot claim amber")
	check(not (await daily.claim("deal_ad")).get("ok",false),"ad reward blocked without completed viewing")
	await daily.start_ad();daily.cancel_ad()
	check(not (await daily.claim("deal_ad")).get("ok",false),"cancelled ad gives nothing")
	await daily.start_ad()
	while Time.get_ticks_msec()-daily.ad_started < 5100: await process_frame
	var ad_result: Dictionary = await daily.claim("deal_ad")

	check(ad_result.get("ok",false) and g.energy==30,"completed ad gives exactly thirty energy")
	check((await daily.claim("deal_energybox")).get("ok",false) and g.shells==0 and g.stash==["energybox_1"],"three hundred shells buys physical energy chest")
	check(await g.open_chest("energybox_1")==["fire_5","fire_5","fire_5"],"energy chest contains only fire")
	g.pass_tier=1
	check((await daily.claim("deal_member_1")).get("ok",false) and g.amber==100,"first member item pays exactly one hundred")
	check(not (await daily.claim("deal_member_2")).get("ok",false) and g.amber==100,"second member item needs super VIP")
	g.pass_tier=2
	check((await daily.claim("deal_member_2")).get("ok",false) and g.amber==200,"second member item is independently claimable")
	check(not (await daily.claim("deal_member_1")).get("ok",false) and g.amber==200,"member reward cannot replay")
	check((await daily.claim("deal_2")).get("ok",false) and not g.has_free_daily(),"all free rewards clear red dot")
	g.deals_day="2000-01-01"
	check(g.has_free_daily(),"new day restores red dot")
	g.board=[{"id":"fruit_3","lock":0},{"id":"fruit_4","lock":3}];g.inv=[];g.stash=[]
	g.orders=[{"who":2,"rw":{},"items":["fruit_3","fruit_3","fruit_4"]},{"who":3,"rw":{},"items":["tool_3","tool_4","tool_5"]}]
	check(ufo.candidate()==["fruit_3","fruit_4","tool_3"],"UFO accounts for duplicates and ignores unpaid bubbles")
	g.ufo_offer={"next_at":0,"offer":{},"deliveries":{}}
	ufo.local_visit()
	var offer: Dictionary=g.ufo_offer["offer"].duplicate(true)
	var deadline: float=offer["expires_at"]
	ufo.local_visit()
	check(g.ufo_offer["offer"]["expires_at"]==deadline,"visits do not extend deadline")
	check((await ufo.buy(offer["id"])).get("ok",false) and g.stash==["fruit_3","fruit_4","tool_3"]+ufo.config()["bonus_items"],"UFO delivers missing physical items plus bonus")
	ufo._deliver()
	check(not (await ufo.buy(offer["id"])).get("ok",false) and g.stash.size()==3+ufo.config()["bonus_items"].size(),"receipt prevents double delivery")
	g.ufo_offer={"next_at":0,"offer":{},"deliveries":{}};ufo.local_visit()
	g.ufo_offer["offer"]["expires_at"]=g.now()-1
	check(not (await ufo.buy(g.ufo_offer["offer"]["id"])).get("ok",false),"expired offer cannot buy")
	# All UI scripts compile and construct with the current save.
	g._init_board();g.orders=[]
	var main=load("res://main.tscn").instantiate()
	root.add_child(main);main.show_screen("board",true)
	await process_frame
	check(main.board_screen._race_entry.position.y==main.board_screen._seven_entry.position.y and main.board_screen._seven_entry.position.y==main.board_screen._merge_event_entry.position.y,"all three activity entries share bottom alignment")
	main.open("store");await process_frame
	main.queue_free();await process_frame;g.main=null
	print("RESULT: ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

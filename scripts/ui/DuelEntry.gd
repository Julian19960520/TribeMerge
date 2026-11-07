extends Control
var btn: TButton
var clock:=0.0
func _ready() -> void:
	mouse_filter=MOUSE_FILTER_IGNORE
	btn=UI.hit(self,Rect2(Vector2.ZERO,size),func():
		if DuelRace.unlocked(): G.main.open("duel")
		else: G.main.toast("%d级解锁双人竞速"%int(DuelRace.config()["unlock_level"])))
	btn.name="duel_entry"
	btn.extra=_paint
func _process(delta: float) -> void:
	clock+=delta
	if clock>=1:
		clock=0
		DuelRace.tick()
		btn.queue_redraw()
func _paint(ci: CanvasItem, sz: Vector2) -> void:
	var m: Dictionary=DuelRace.state()["match"]
	var badge:={"text":"开赛","style":"teal"}
	if not DuelRace.unlocked(): badge={"text":"%d级"%int(DuelRace.config()["unlock_level"]),"style":"lock"}
	elif DuelRace.pending(): badge={"text":"领奖","style":"go"}
	elif not m.is_empty() and m["status"]=="running": badge={"text":"%d/%d"%[m["me"],m["target"]],"style":"num"}
	EventEntryArt.paint(ci,sz,"duel","双人竞速",badge,not DuelRace.unlocked(),DuelRace.pending())

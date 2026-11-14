extends Control
var btn: TButton
var clock:=0.0
func _ready() -> void:
	mouse_filter=MOUSE_FILTER_IGNORE
	btn=UI.hit(self,Rect2(Vector2.ZERO,size),func():
		if DuelRace.unlocked(): G.main.open("duel")
		else: G.main.toast(TextCatalog.source("notice.duelrace.2821c8ca32bd")%int(DuelRace.config()["unlock_level"])))
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
	var badge:={"text":TextCatalog.source("ui.duelentry.a75fb7376be1"),"style":"teal"}
	if not DuelRace.unlocked(): badge={"text":TextCatalog.source("ui.duelentry.e0cda514ecc2")%int(DuelRace.config()["unlock_level"]),"style":"lock"}
	elif DuelRace.pending(): badge={"text":TextCatalog.source("ui.duelentry.5375104054f0"),"style":"go"}
	elif not m.is_empty() and m["status"]=="running":
		var me:=int(m.get("me",0))
		var op:=int(m.get("opponent",0))
		badge={"text":"%d:%d"%[me,op],"style":"gold" if me>op else ("bronze" if me<op else "num")}
	EventEntryArt.paint(ci,sz,"duel",TextCatalog.source("notice.data.33c9c97e48ba"),badge,not DuelRace.unlocked(),DuelRace.pending())

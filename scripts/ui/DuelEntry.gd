extends Control
var btn: TButton
var clock:=0.0
## 活动积分飞进来时图片弹一下（ActivityPointsFx 设成 1）
var _bump:=0.0
func _ready() -> void:
	mouse_filter=MOUSE_FILTER_IGNORE
	btn=UI.hit(self,Rect2(Vector2.ZERO,size),func():
		if DuelRace.unlocked(): G.main.open("duel")
		else: G.main.toast(TextCatalog.fill(TextCatalog.source("notice.duelrace.2821c8ca32bd"), int(DuelRace.config()["unlock_level"]))))
	btn.name="duel_entry"
	btn.extra=_paint
func _process(delta: float) -> void:
	if _bump>0.0:
		_bump=maxf(0.0,_bump-delta*3.0)
		btn.queue_redraw()
	clock+=delta
	if clock>=1:
		clock=0
		DuelRace.tick()
		btn.queue_redraw()
func _paint(ci: CanvasItem, sz: Vector2) -> void:
	# 档期剩余时间；比赛中再画自己的进度，对手的分是条上的红刻度
	var m: Dictionary=DuelRace.state()["match"]
	var info:={}
	if not DuelRace.unlocked(): info={"lock":TextCatalog.fill(TextCatalog.source("ui.duelentry.e0cda514ecc2"), int(DuelRace.config()["unlock_level"]))}
	else:
		if ActivitySchedule.scheduled("duel"): info["left"]=ActivitySchedule.seconds_left("duel")
		if not m.is_empty() and m["status"]=="running":
			info.merge({"have":int(m.get("me",0)),"need":int(m.get("target",0)),"rival":int(m.get("opponent",0)),"icon":"banana"})
	EventEntryArt.paint(ci,sz,"duel",info,not DuelRace.unlocked(),DuelRace.pending(),_bump)

extends PopupBase
var label: Label
var claim_btn: TButton
var _started := false
var _last_second := -1
func _ready() -> void:
	Popups.frame(self,Rect2(70,470,580,510),"广告试玩",Art.TEAL)
	UI.icon(box,"fire_4",Vector2(360,638),140)
	UI.lbl(box,"看完领取 30 体力",Rect2(110,718,500,48),32,Art.INK)
	label=UI.lbl(box,"准备中…",Rect2(110,778,500,40),24,Art.INK)
	claim_btn=UI.btn(box,Rect2(200,850,320,76),"领取", "green",_claim,32)
	claim_btn.enabled=false
	on_close=DailyShop.cancel_ad
	_started=await DailyShop.start_ad()
	if not is_instance_valid(self): return
	if not _started: label.text="广告暂不可用"
func _process(_delta: float) -> void:
	if not _started or _closing: return
	var left:=maxi(0,5-int((Time.get_ticks_msec()-DailyShop.ad_started)/1000))
	if left==_last_second:return
	_last_second=left
	label.text="模拟广告 %d 秒 · 无真实广告" % left if left>0 else "观看完成"
	claim_btn.enabled=left==0
	claim_btn.queue_redraw()
func _claim() -> void:
	if DailyShop.busy or _closing:return
	claim_btn.enabled=false
	var result:=await DailyShop.claim("deal_ad")
	if not is_instance_valid(self):return
	if result.get("ok",false):close()
	else:G.main.toast(str(result.get("message","领取失败")))

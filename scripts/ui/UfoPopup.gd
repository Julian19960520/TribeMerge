extends PopupBase
var offer: Dictionary
var buy_btn: TButton
var clock: Label
var _tick := 0.0
var _busy := false
func _ready() -> void:
	offer=UfoOffer.state()["offer"].duplicate(true)
	Popups.frame(self,Rect2(44,350,632,800),"外星补给",Art.TEAL)
	var texture: Texture2D=load(str(UfoOffer.config()["icon"]))
	UI.box(box,Rect2(190,420,340,200),func(ci,sz):ci.draw_texture_rect(texture,Rect2(Vector2.ZERO,sz),false))
	var items: Array=offer.get("items",[])
	for k in items.size():
		var id := str(items[k])
		var x := 360.0+(k-(items.size()-1)/2.0)*174
		UI.box(box,Rect2(x-76,650,152,170),func(ci,sz):Art.fill(ci,Art.rrect(Rect2(Vector2.ZERO,sz),18,k+601,.4),Color("fff0cc"),2))
		UI.icon(box,id,Vector2(x,713),106)
		UI.lbl(box,Data.name_of(id),Rect2(x-74,773,148,36),21,Art.INK)
	clock=UI.lbl(box,"",Rect2(100,839,520,40),25,Color("a45032"))
	var original:=int(UfoOffer.config()["original_price_cny"])
	UI.lbl(box,"原价 ¥%d" % original,Rect2(190,896,180,48),27,Color("8a7560"))
	UI.box(box,Rect2(215,916,130,6),func(ci,sz):ci.draw_line(Vector2.ZERO,Vector2(sz.x,0),Color("a54b35"),3,true))
	var badge:=UI.box(box,Rect2(390,889,120,62),func(ci,sz):Art.fill(ci,Art.rrect(Rect2(Vector2.ZERO,sz),12,606,.4),Color("d95d36"),2))
	badge.rotation=-.07
	UI.lbl(badge,"5折",Rect2(0,0,120,62),33,Color.WHITE,HORIZONTAL_ALIGNMENT_CENTER,4,Art.INK,true)
	buy_btn=UI.btn(box,Rect2(190,974,340,90),"¥%d 购买" % int(UfoOffer.config()["price_cny"]),"green",_buy,40)
	UI.lbl(box,"试玩购买，不扣款",Rect2(160,1080,400,32),20,Color("8a7560"))
	_refresh()
func _process(delta: float) -> void:
	_tick+=delta
	if _tick>=1:_tick=0;_refresh()
func _refresh() -> void:
	var left:=maxi(0,int(ceil(float(offer.get("expires_at",0))-G.now())))
	clock.text="飞碟离开倒计时  %02d:%02d" % [left/60,left%60] if left>0 else "飞碟已离开"
	buy_btn.enabled=left>0 and not _busy and UfoOffer.active()
	buy_btn.queue_redraw()
func _buy() -> void:
	if _busy:return
	_busy=true;_refresh()
	var result:=await UfoOffer.buy(str(offer["id"]))
	if not is_instance_valid(self):return
	_busy=false
	if result.get("ok",false):close()
	else:
		G.main.toast(str(result.get("error","购买失败")))
		_refresh()

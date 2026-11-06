extends Control
var hit: TButton
var timer: Label
var _clock := 0.0
var _shown := false
var _motion: Tween
func _ready() -> void:
	position=Vector2(548,104);size=Vector2(144,144)
	mouse_filter=MOUSE_FILTER_IGNORE
	hit=UI.hit(self,Rect2(Vector2.ZERO,size),UfoOffer.open_panel)
	var texture: Texture2D=load(str(UfoOffer.config()["icon"]))
	hit.extra=func(ci,_sz):
		var center := Vector2(72,72)
		ci.draw_circle(center+Vector2(0,5),70,Color(0.10,0.16,0.17,0.35))
		ci.draw_circle(center,69,Art.INK)
		ci.draw_circle(center,65,Color("d7eee3"))
		ci.draw_circle(center,60,Color("41616a"))
		ci.draw_arc(center,58,3.55,4.65,24,Color("edf9ed"),3,true)
		ci.draw_texture_rect(texture,Rect2(4,6,136,90),false)
	timer=UI.lbl(hit,"",Rect2(22,98,100,30),22,Color.WHITE,HORIZONTAL_ALIGNMENT_CENTER,5,Art.INK,true)
	hit.visible=false
func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_clock+=delta
	if _clock<1: return
	_clock=0
	if G.tutorial_on:
		hit.visible = false
		_shown = false
		return
	UfoOffer.tick()
	var show_offer := UfoOffer.active() and not G.tutorial_on
	timer.text="%02d:%02d" % [UfoOffer.remaining()/60,UfoOffer.remaining()%60]
	if _shown==show_offer: return
	_shown=show_offer
	hit.visible=show_offer
	if _motion!=null and _motion.is_valid(): _motion.kill()
	if show_offer:
		hit.position=Vector2(190,0)
		_motion=create_tween()
		_motion.tween_property(hit,"position",Vector2.ZERO,.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_motion.tween_callback(_hover)
func _hover() -> void:
	_motion=create_tween().set_loops()
	_motion.tween_property(hit,"position",Vector2(-310,-5),3.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion.tween_property(hit,"position",Vector2(0,3),3.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

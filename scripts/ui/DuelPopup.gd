extends PopupBase
const Meme:=preload("res://scripts/Meme.gd")
const Banana:=preload("res://scripts/ui/Banana.gd")
const WIN_BAR:=Rect2(114,950,492,22)
const MATCH_MS:=3000
static var matching_until:=0
var body: Control
var bubble_layer: Control
var bubble_wins:=0
var clock:=0.0
var signature:=""
var working:=false
var phase:=""
var matching_art: Control

func _ready() -> void:
	on_tap=_hide_reward_bubble
	DuelRace.tick()
	_refresh()

func _phase() -> String:
	var m: Dictionary=DuelRace.state()["match"]
	var status:=str(m.get("status","idle"))
	if status in ["won","lost"] and not m.get("claimed",false): return "result"
	if status=="running": return "matching" if Time.get_ticks_msec()<matching_until else "progress"
	return "start"

func _process(delta: float) -> void:
	if _closing: return
	if phase=="matching":
		if is_instance_valid(matching_art): matching_art.queue_redraw()
		if _phase()!=phase: _refresh()
	clock+=delta
	if clock<1 or working: return
	clock=0
	if G.server_mode():
		working=true
		await DuelRace.act("refresh")
		working=false
		if not is_inside_tree() or _closing: return
	else: DuelRace.tick()
	_refresh()

func _action(action: String, at:=0) -> void:
	if working or _closing: return
	_hide_reward_bubble()
	working=true
	var button:=find_child("duel_action",true,false)
	if button: button.enabled=false
	var result: Dictionary=await DuelRace.act(action,at)
	working=false
	if not is_inside_tree() or _closing: return
	if result.has("error"): G.main.toast(str(result["error"]))
	elif action=="join": matching_until=Time.get_ticks_msec()+MATCH_MS
	signature=""
	_refresh()
	if not result.get("rewards",[]).is_empty(): G.main.present_rewards(result["rewards"],false)

func _new_panel(next: String) -> void:
	phase=next
	name="duel_"+phase
	bubble_wins=0
	matching_art=null
	for child in box.get_children(): box.remove_child(child); child.queue_free()
	var rect: Rect2={"start":Rect2(60,300,600,790),"matching":Rect2(60,410,600,590),"progress":Rect2(60,250,600,950),"result":Rect2(60,370,600,700)}[phase]
	var title: String={"start":"双人竞速","matching":"匹配对手","progress":"双人竞速","result":"比赛结算"}[phase]
	Popups.frame(self,rect,title,Art.CLAY)
	body=Control.new()
	body.mouse_filter=Control.MOUSE_FILTER_IGNORE
	box.add_child(body)
	bubble_layer=Control.new()
	bubble_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	box.add_child(bubble_layer)
	signature=""

func _refresh() -> void:
	if _closing: return
	var next:=_phase()
	if phase!=next: _new_panel(next)
	var s:=DuelRace.state()
	var m: Dictionary=s["match"]
	var sig:=str([phase,m.get("status","idle"),m.get("me",0),m.get("opponent",0),m.get("claimed",false),s["wins"],s["claimed"]])
	if sig==signature: return
	signature=sig
	for child in body.get_children(): body.remove_child(child); child.queue_free()
	match phase:
		"start": _start_panel(s)
		"matching": _matching_panel()
		"progress": _progress_panel(m)
		"result": _result_panel(m)

func _start_panel(s: Dictionary) -> void:
	var again:=int(s.get("rounds",0))>0
	var target:=int(DuelRace.config()["target"])
	UI.title(body,"再来一局！" if again else "比谁先收满香蕉！",Rect2(90,360,540,56),40,Art.CLAY)
	UI.box(body,Rect2(210,426,300,100),func(ci,sz):
		for i in 7:
			Banana.draw(ci,Vector2(sz.x*0.5+(i%4-1.5)*53,72-(i/4)*35),68,(i%4-1.5)*0.12),false)
	UI.lbl(body,"完成订单收集香蕉，先到 %d 根获胜"%target,Rect2(88,535,544,40),25,Art.INK)
	_reward_line("胜利奖励",DuelRace.config()["win_rewards"],600,Art.MOSS_D)
	_reward_line("参与奖励",DuelRace.config()["lose_rewards"],659,Color("8a7560"))
	var button:=UI.btn(body,Rect2(210,760,300,82),"匹配","green",func(): _action("join"),38)
	button.name="duel_action"
	Popups.section(body,"累计胜利  %d 次"%int(s["wins"]),872,Color("8a5a30"),360)
	var last:=_last_milestone()
	UI.box(body,WIN_BAR,func(ci,sz):
		Art.fill(ci,Art.rrect(Rect2(Vector2.ZERO,sz),11,931,0),Color("cbb68b"),2)
		var fill:=clampf(float(s["wins"])/last,0,1)
		if fill>0: ci.draw_colored_polygon(Art.rrect(Rect2(3,3,maxf(8,(sz.x-6)*fill),sz.y-6),8,932,0),Art.MOSS),false)
	for row in DuelRace.config()["milestones"]:
		var wins:=int(row["wins"])
		var got: bool=str(wins) in s["claimed"]
		var ready: bool=int(s["wins"])>=wins and not got
		var x:=_chest_x(wins)
		var hit:=UI.hit(body,Rect2(x-38,927,76,66),func(): _toggle_reward(wins))
		hit.name="duel_milestone_%d"%wins
		hit.extra=func(ci,sz):
			if ready: ci.draw_circle(sz*0.5,34,Color("ffe08a"))
			Art.item(ci,"chest_1",sz*0.5,64)
			if not ready and not got: ci.draw_circle(sz*0.5,29,Color(0.25,0.18,0.08,0.28))
			if got:
				ci.draw_circle(Vector2(60,49),13,Art.MOSS_D)
				ci.draw_polyline(PackedVector2Array([Vector2(53,49),Vector2(58,54),Vector2(67,44)]),Color.WHITE,3,true)
		UI.lbl(body,"%d 胜"%wins,Rect2(x-44,1004,88,34),23,Art.MOSS_D if ready else Art.INK)
	_render_reward_bubble()


func _matching_panel() -> void:
	UI.title(body,"正在寻找对手",Rect2(90,480,540,52),38,Art.CLAY)
	matching_art=UI.box(body,Rect2(95,560,530,260),func(ci,sz):
		var elapsed:=clampf(1.0-float(matching_until-Time.get_ticks_msec())/MATCH_MS,0,1)
		var found:=elapsed>0.8
		for side in 2:
			var c:=Vector2(120 if side==0 else sz.x-120,110)
			ci.draw_circle(c,76,Art.INK)
			ci.draw_circle(c,72,Color("ffe08a") if side==0 else Art.BONE)
			var avatar:=0 if side==0 else (1 if found else int(Time.get_ticks_msec()/110)%8)
			Meme.portrait(ci,avatar,c,132)
			if side==1 and not found: ci.draw_circle(c,69,Color(0.25,0.18,0.08,0.18)),false)
	matching_art.name="duel_matching_portraits"
	UI.lbl(body,"你",Rect2(130,790,170,40),26,Art.CLAY)
	UI.lbl(body,"对手",Rect2(420,790,170,40),26,Art.INK)
	UI.lbl(body,"匹配完成后自动开赛",Rect2(90,900,540,40),25,Color("8a7560"))

func _progress_panel(m: Dictionary) -> void:
	var target:=maxi(1,int(m.get("target",DuelRace.config()["target"])))
	UI.title(body,"先堆满 %d 根香蕉！"%target,Rect2(90,310,540,54),38,Art.CLAY)
	_reward_line("胜利奖励",DuelRace.config()["win_rewards"],380,Art.MOSS_D)
	for side in 2:
		var x:=210.0 if side==0 else 510.0
		var points:=clampi(int(m.get("me" if side==0 else "opponent",0)),0,target)
		var tint:=Art.MOSS if side==0 else Art.CLAY
		var pile:=UI.box(body,Rect2(x-67,470,134,350),func(ci,sz):
			Art.fill(ci,Art.rrect(Rect2(5,0,sz.x-10,sz.y),18,920+side,0),Color("e8d5ac"),2)
			for j in 5: ci.draw_line(Vector2(9+j*25,0),Vector2(22+j*25,0),tint,4,true)
			var count:=ceili(30.0*points/target)
			for j in count:
				var row:=j/2
				var c:=Vector2(43 if j%2==0 else 91,sz.y-20-row*22)
				Banana.draw(ci,c,70,(-0.19 if j%2==0 else 0.16)+sin(j*2.3)*0.06,true),false)
		pile.name="duel_banana_pile_%d"%side
		UI.title(body,"%d / %d"%[points,target],Rect2(x-100,838,200,40),29,tint)
		var portrait:=UI.box(body,Rect2(x-56,900,112,112),func(ci,sz):
			ci.draw_circle(sz*0.5,55,Art.INK)
			ci.draw_circle(sz*0.5,51,Art.BONE)
			Meme.portrait(ci,side,sz*0.5,94),false)
		portrait.name="duel_character_%d"%side
		UI.lbl(body,"你" if side==0 else "练习对手",Rect2(x-100,1018,200,32),24,Art.INK)
	UI.title(body,"VS",Rect2(315,625,90,50),36,Art.CLAY)
	var button:=UI.btn(body,Rect2(210,1080,300,76),"去完成订单","green",close,32)
	button.name="duel_action"

func _result_panel(m: Dictionary) -> void:
	var won:=str(m.get("status",""))=="won"
	UI.title(body,"你赢了！" if won else "这次慢了一步",Rect2(90,435,540,60),46,Art.MOSS_D if won else Art.CLAY)
	UI.box(body,Rect2(280,515,160,160),func(ci,sz):
		ci.draw_circle(sz*0.5,78,Color("ffe08a") if won else Art.BONE)
		Meme.portrait(ci,0 if won else 1,sz*0.5,140),false)
	UI.title(body,"%d  :  %d"%[int(m.get("me",0)),int(m.get("opponent",0))],Rect2(170,695,380,50),36,Art.INK)
	var prizes: Array=DuelRace.config()["win_rewards" if won else "lose_rewards"]
	Popups.section(body,"胜利奖励" if won else "参与奖励",770,Art.MOSS_D if won else Art.CLAY)
	for i in prizes.size():
		var x:=360+(float(i)-(prizes.size()-1)*0.5)*130
		UI.icon(body,str(prizes[i][0]),Vector2(x,860),76)
		UI.lbl(body,"×%d"%int(prizes[i][1]),Rect2(x-55,905,110,32),26,Color.WHITE,HORIZONTAL_ALIGNMENT_CENTER,5,Art.INK)
	var button:=UI.btn(body,Rect2(210,970,300,70),"领取奖励","green",func(): _action("claim"),34)
	button.name="duel_action"

func _last_milestone() -> int:
	var last:=1
	for row in DuelRace.config()["milestones"]: last=maxi(last,int(row["wins"]))
	return last

func _chest_x(wins: int) -> float:
	return WIN_BAR.position.x+WIN_BAR.size.x*float(wins)/_last_milestone()

func _toggle_reward(wins: int) -> void:
	bubble_wins=0 if bubble_wins==wins else wins
	_render_reward_bubble()

func _hide_reward_bubble() -> void:
	bubble_wins=0
	_render_reward_bubble()

func _render_reward_bubble() -> void:
	for child in bubble_layer.get_children(): bubble_layer.remove_child(child); child.queue_free()
	if bubble_wins==0: return
	var selected: Dictionary={}
	for row in DuelRace.config()["milestones"]:
		if int(row["wins"])==bubble_wins: selected=row; break
	if selected.is_empty(): return
	var s:=DuelRace.state()
	var got: bool=str(bubble_wins) in s["claimed"]
	var ready: bool=int(s["wins"])>=bubble_wins and not got
	var x:=clampf(_chest_x(bubble_wins)-155,84,326)
	var tip:=_chest_x(bubble_wins)-x
	var bubble:=UI.hit(bubble_layer,Rect2(x,730,310,184),func(): pass)
	bubble.name="duel_reward_bubble"
	bubble.extra=func(ci,sz):
		var pointer:=PackedVector2Array([Vector2(tip-15,sz.y-5),Vector2(tip,sz.y+15),Vector2(tip+15,sz.y-5)])
		Art.fill(ci,pointer,Art.BONE,2)
		Art.fill(ci,Art.rrect(Rect2(Vector2.ZERO,sz),18,940,0),Art.BONE,2)
	UI.lbl(bubble,"%d 胜奖励"%bubble_wins,Rect2(10,8,290,32),24,Art.INK)
	var prizes: Array=selected["rewards"]
	for j in prizes.size():
		var cx:=155+(float(j)-(prizes.size()-1)*0.5)*86
		UI.icon(bubble,str(prizes[j][0]),Vector2(cx,77),62)
		UI.lbl(bubble,"×%d"%int(prizes[j][1]),Rect2(cx-42,99,84,28),22,Color.WHITE,HORIZONTAL_ALIGNMENT_CENTER,5,Art.INK)
	if ready:
		var wins:=bubble_wins
		var claim:=UI.btn(bubble,Rect2(72,135,166,42),"领取","green",func(): _action("milestone",wins),25)
		claim.name="duel_claim_milestone"
	else:
		UI.lbl(bubble,"已领取" if got else "再赢 %d 场"%(bubble_wins-int(s["wins"])),Rect2(15,139,280,32),24,Art.MOSS_D if got else Art.INK)

func _reward_line(label: String, rw: Array, y: float, tint: Color) -> void:
	UI.lbl(body,label,Rect2(92,y,140,48),24,tint)
	for i in rw.size():
		var x:=258+i*120.0
		UI.icon(body,str(rw[i][0]),Vector2(x,y+24),46)
		UI.lbl(body,"×%d"%int(rw[i][1]),Rect2(x+23,y+5,72,40),21,Art.INK,HORIZONTAL_ALIGNMENT_LEFT)

extends PopupBase
const Meme:=preload("res://scripts/Meme.gd")
const Banana:=preload("res://scripts/ui/Banana.gd")
const WIN_BAR:=Rect2(114,950,492,22)
const MATCH_MS:=1500
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
	var rect: Rect2={"start":Rect2(60,262,600,828),"matching":Rect2(60,372,600,540),"progress":Rect2(60,236,600,964),"result":Rect2(60,320,600,750)}[phase]
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
	UI.title(body,"再来一局！" if again else "比谁先收满香蕉！",Rect2(90,322,540,56),38,Art.FIRE2)
	# 对阵擂台：你 VS 未知对手
	UI.box(body,Rect2(90,388,540,196),func(ci,sz):
		_card(ci,Rect2(Vector2.ZERO,sz),Color("f3dfb4"),951)
		_rays(ci,Vector2(sz.x*0.5,98),150,Color(1,0.85,0.4,0.28),12,0.0)
		for i in 5:
			Banana.draw(ci,Vector2(sz.x*0.5+(i-2)*22,156-absf(i-2)*6),46,(i-2)*0.32)
		for side in 2:
			var c:=Vector2(110 if side==0 else sz.x-110,92)
			_ring(ci,c,66,Art.MOSS if side==0 else Art.STONE)
			Meme.portrait(ci,side,c,112)
			if side==1: ci.draw_circle(c,59,Color(0.36,0.3,0.24,0.75))
		_vs(ci,Vector2(sz.x*0.5,82),38))
	UI.title(body,"?",Rect2(470,430,100,100),60,Art.BONE)
	_plate(Rect2(140,540,120,36),"你",Art.MOSS_D)
	_plate(Rect2(460,540,120,36),"对手",Art.STONE_D)
	UI.lbl(body,"完成订单收集香蕉，先到 %d 根获胜"%target,Rect2(80,594,560,36),23,Color("7a5a3a"))
	_reward_card(Rect2(90,640,266,124),"胜利奖励",DuelRace.config()["win_rewards"],Art.MOSS_D,Color("eef5d6"))
	_reward_card(Rect2(364,640,266,124),"参与奖励",DuelRace.config()["lose_rewards"],Art.LEATHER,Color("f6e7c8"))
	var button:=UI.btn(body,Rect2(200,782,320,84),"开始匹配","green",func(): _action("join"),38)
	button.name="duel_action"
	Popups.section(body,"累计胜利  %d 次"%int(s["wins"]),884,Color("8a5a30"),360)
	var last:=_last_milestone()
	var wins_now:=int(s["wins"])
	UI.box(body,WIN_BAR,func(ci,sz):
		var r:=Rect2(Vector2.ZERO,sz)
		ci.draw_colored_polygon(Art.rrect(r.grow(5),15,930,0),Art.WOOD_D)
		Art.fill(ci,Art.rrect(r,11,931,0),Color("6b4a2e"),2)
		var fill:=clampf(float(wins_now)/last,0,1)
		if fill>0:
			var fr:=Rect2(3,3,maxf(14,(sz.x-6)*fill),sz.y-6)
			ci.draw_colored_polygon(Art.rrect(fr,8,932,0),Art.MOSS)
			ci.draw_colored_polygon(Art.rrect(Rect2(fr.position.x+5,4,maxf(4,fr.size.x-10),5),3,933,0),Color(1,1,1,0.45))
		for w in range(1,last):
			var x: float=sz.x*float(w)/last
			ci.draw_line(Vector2(x,5),Vector2(x,sz.y-5),Color(0,0,0,0.18),2),false)
	for row in DuelRace.config()["milestones"]:
		var wins:=int(row["wins"])
		var got: bool=str(wins) in s["claimed"]
		var ready: bool=wins_now>=wins and not got
		var x:=_chest_x(wins)
		var hit:=UI.hit(body,Rect2(x-38,927,76,66),func(): _toggle_reward(wins))
		hit.name="duel_milestone_%d"%wins
		hit.extra=func(ci,sz):
			var c:Vector2=sz*0.5
			if ready:
				_rays(ci,c,46,Color(1,0.85,0.3,0.55),10,0.2)
				ci.draw_circle(c,30,Color("ffe08a"))
			else: ci.draw_circle(c+Vector2(0,4),28,Color(0,0,0,0.15))
			Art.item(ci,"chest_1",c,70 if ready else 60)
			if not ready and not got: ci.draw_circle(c,27,Color(0.25,0.18,0.08,0.32))
			if got:
				ci.draw_circle(Vector2(58,50),13,Art.INK)
				ci.draw_circle(Vector2(58,50),11,Art.MOSS_D)
				ci.draw_polyline(PackedVector2Array([Vector2(52,50),Vector2(57,55),Vector2(65,45)]),Color.WHITE,3,true)
		UI.lbl(body,"%d 胜"%wins,Rect2(x-44,1000,88,34),22,Color.WHITE if ready else Art.INK,HORIZONTAL_ALIGNMENT_CENTER,6 if ready else 0,Art.MOSS_D)
	_render_reward_bubble()


func _matching_panel() -> void:
	UI.title(body,"正在寻找对手",Rect2(90,452,540,52),38,Art.FIRE2)
	matching_art=UI.box(body,Rect2(90,515,540,300),func(ci,sz):
		var t:=Time.get_ticks_msec()/1000.0
		var elapsed:=clampf(1.0-float(matching_until-Time.get_ticks_msec())/MATCH_MS,0,1)
		var found:=elapsed>0.8
		_card(ci,Rect2(Vector2.ZERO,sz),Color("f3dfb4"),961)
		_rays(ci,Vector2(sz.x*0.5,130),190,Color(1,0.85,0.4,0.22),14,t*0.3)
		for side in 2:
			var c:=Vector2(120 if side==0 else sz.x-120,130)
			if side==1 and not found:
				for k in 3:
					var ph:=fmod(t*0.9+k/3.0,1.0)
					ci.draw_arc(c,70+ph*40,0,TAU,48,Color(Art.CLAY,0.55*(1-ph)),4,true)
			_ring(ci,c,74,Art.MOSS if side==0 else (Art.CLAY if found else Art.STONE))
			var avatar:=0 if side==0 else (1 if found else int(Time.get_ticks_msec()/110)%8)
			Meme.portrait(ci,avatar,c,124)
			if side==1 and not found: ci.draw_circle(c,64,Color(0.25,0.18,0.08,0.2))
		_vs(ci,Vector2(sz.x*0.5,124),40)
		var bar:=Rect2(70,256,sz.x-140,20)
		Art.fill(ci,Art.rrect(bar,10,962,0),Color("6b4a2e"),2)
		ci.draw_colored_polygon(Art.rrect(Rect2(bar.position+Vector2(3,3),Vector2(maxf(12,(bar.size.x-6)*elapsed),bar.size.y-6)),7,963,0),Art.FIRE2),false)
	matching_art.name="duel_matching_portraits"
	_plate(Rect2(150,724,120,36),"你",Art.MOSS_D)
	_plate(Rect2(450,724,120,36),"对手",Art.CLAY)
	UI.lbl(body,"匹配完成后自动开赛",Rect2(90,836,540,40),24,Color("8a7560"))

func _progress_panel(m: Dictionary) -> void:
	var target:=maxi(1,int(m.get("target",DuelRace.config()["target"])))
	var scores:=[clampi(int(m.get("me",0)),0,target),clampi(int(m.get("opponent",0)),0,target)]
	var lead:=0 if scores[0]>scores[1] else (1 if scores[1]>scores[0] else -1)
	UI.title(body,"先堆满 %d 根香蕉！"%target,Rect2(90,288,540,54),36,Art.FIRE2)
	# 顶部对阵条：头像 VS 头像，比分在头像下
	UI.box(body,Rect2(90,352,540,190),func(ci,sz):
		_card(ci,Rect2(Vector2.ZERO,sz),Color("f3dfb4"),970)
		if lead>=0: _rays(ci,Vector2(110 if lead==0 else sz.x-110,80),110,Color(1,0.85,0.35,0.35),12,0.0)
		_vs(ci,Vector2(sz.x*0.5,80),36),false)
	for side in 2:
		var x:=200.0 if side==0 else 520.0
		var tint:=Art.MOSS if side==0 else Art.CLAY
		var tint_d:=Art.MOSS_D if side==0 else Color("9b3518")
		var portrait:=UI.box(body,Rect2(x-58,374,116,116),func(ci,sz):
			_ring(ci,sz*0.5,56,tint)
			Meme.portrait(ci,side,sz*0.5,96)
			if lead==side: _crown(ci,Vector2(sz.x*0.5,-4),34),false)
		portrait.name="duel_character_%d"%side
		UI.box(body,Rect2(x-70,490,140,42),func(ci,sz): _card(ci,Rect2(Vector2.ZERO,sz),tint,980+side),false)
		UI.lbl(body,"%s  %d"%["你" if side==0 else "对手",scores[side]],Rect2(x-70,490,140,42),24,Color.WHITE,HORIZONTAL_ALIGNMENT_CENTER,6,tint_d)
	# 奖励归属：按当前比分，领先方拿胜利奖励，落后方拿参与奖励
	var owner_text:="平局中，先到 %d 根的拿胜利奖励"%target
	if lead==0: owner_text="照现在的比分，胜利奖励归你！"
	elif lead==1: owner_text="对手领先，追上去抢回胜利奖励！"
	UI.lbl(body,owner_text,Rect2(90,548,540,34),22,Art.MOSS_D if lead==0 else (Color("9b3518") if lead==1 else Color("7a5a3a")))
	for side in 2:
		var x:=200.0 if side==0 else 520.0
		var win: bool=lead==side
		var rw: Array=DuelRace.config()["win_rewards" if (win or lead<0) else "lose_rewards"]
		UI.box(body,Rect2(x-128,586,256,64),func(ci,sz):
			_card(ci,Rect2(Vector2.ZERO,sz),Color("fff1b8") if win else Color("efe4cc"),990+side)
			if win: Art.outline(ci,Art.rrect(Rect2(4,4,sz.x-8,sz.y-8),12,992+side,0),3,Art.FIRE2),false)
		UI.lbl(body,"胜利" if (win or lead<0) else "参与",Rect2(x-124,586,50,64),19,Art.MOSS_D if win else Color("8a7560"))
		for i in rw.size():
			var ix:=x-48+i*62.0
			UI.icon(body,str(rw[i][0]),Vector2(ix,610),36)
			UI.lbl(body,"×%d"%int(rw[i][1]),Rect2(ix-30,620,60,26),16,Color.WHITE,HORIZONTAL_ALIGNMENT_CENTER,4,Art.INK)
	# 两堆锥形香蕉：底宽顶尖，堆满就是一座完整的香蕉山
	for side in 2:
		var x:=200.0 if side==0 else 520.0
		var points: int=scores[side]
		var pile:=UI.box(body,Rect2(x-140,670,280,330),func(ci,sz):
			var base_y: float=sz.y-30
			var apex: Vector2=Vector2(sz.x*0.5,46)
			# 地面土堆
			Sprites.draw(ci,"ev_duel_mound",Rect2(sz.x*0.5-130,base_y-12,260,40))
			# 目标轮廓：虚线锥形 + 顶上的小旗
			var cone:=PackedVector2Array([Vector2(16,base_y),apex,Vector2(sz.x-16,base_y),Vector2(16,base_y)])
			Art.dashed(ci,cone,10,7,Color(0.48,0.3,0.13,0.45),2.5)
			Sprites.draw(ci,"ev_duel_flag_%d"%side,Rect2(apex+Vector2(-4,-38),Vector2(34,42)))
			# 由下往上一层层堆，越往上越窄
			var rows:=[8,7,6,5,4,3,2,1]
			var total:=36
			var count:=ceili(float(total)*points/target)
			var row_h: float=(base_y-apex.y-20)/rows.size()
			var placed:=0
			for r in rows.size():
				var n: int=rows[r]
				var y: float=base_y-16-r*row_h
				var half: float=lerpf(sz.x*0.5-36,0,float(r)/(rows.size()-1))
				for j in n:
					if placed>=count: break
					var u:=0.5 if n==1 else float(j)/(n-1)
					var c: Vector2=Vector2(sz.x*0.5-half+u*half*2,y+sin(j*1.7+r)*3)
					Banana.draw(ci,c,62,sin(j*2.3+r*1.1)*0.35,true)
					placed+=1
			,false)
		pile.name="duel_banana_pile_%d"%side
		UI.lbl(body,"%d / %d"%[points,target],Rect2(x-80,1004,160,34),24,Color.WHITE,HORIZONTAL_ALIGNMENT_CENTER,6,Art.INK)
	var button:=UI.btn(body,Rect2(200,1084,320,80),"去完成订单","green",close,34)
	button.name="duel_action"

func _result_panel(m: Dictionary) -> void:
	var won:=str(m.get("status",""))=="won"
	UI.box(body,Rect2(200,400,320,250),func(ci,sz):
		var c:=Vector2(sz.x*0.5,140)
		if won:
			_rays(ci,c,170,Color(1,0.82,0.3,0.45),16,0.1)
			ci.draw_circle(c,92,Color(1,0.9,0.5,0.6))
		_ring(ci,c,80,Art.FIRE2 if won else Art.STONE)
		Meme.portrait(ci,0,c,140)
		if won: _crown(ci,c+Vector2(0,-112),44),false)
	UI.title(body,"你赢了！" if won else "这次慢了一步",Rect2(90,648,540,62),46,Art.FIRE2 if won else Color("e8d5ac"))
	UI.box(body,Rect2(190,718,340,62),func(ci,sz): _card(ci,Rect2(Vector2.ZERO,sz),Color("6b4a2e"),990),false)
	UI.lbl(body,"你",Rect2(204,718,60,62),24,Color("e8d5ac"))
	UI.lbl(body,"%d  :  %d"%[int(m.get("me",0)),int(m.get("opponent",0))],Rect2(250,718,220,62),36,Color.WHITE,HORIZONTAL_ALIGNMENT_CENTER,6,Art.INK)
	UI.lbl(body,"对手",Rect2(452,718,70,62),24,Color("e8d5ac"))
	var prizes: Array=DuelRace.config()["win_rewards" if won else "lose_rewards"]
	Popups.section(body,"胜利奖励" if won else "参与奖励",796,Art.MOSS_D if won else Art.LEATHER)
	for i in prizes.size():
		var x:=360+(float(i)-(prizes.size()-1)*0.5)*136
		UI.box(body,Rect2(x-58,844,116,104),func(ci,sz): _card(ci,Rect2(Vector2.ZERO,sz),Art.BONE,995+i),false)
		UI.icon(body,str(prizes[i][0]),Vector2(x,884),66)
		UI.lbl(body,"×%d"%int(prizes[i][1]),Rect2(x-55,910,110,34),25,Color.WHITE,HORIZONTAL_ALIGNMENT_CENTER,6,Art.INK)
	var button:=UI.btn(body,Rect2(200,972,320,80),"领取奖励","green",func(): _action("claim"),36)
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

func _reward_card(r: Rect2, label: String, rw: Array, tint: Color, bg: Color) -> void:
	UI.box(body,r,func(ci,sz):
		_card(ci,Rect2(Vector2.ZERO,sz),bg,int(r.position.x))
		ci.draw_colored_polygon(Art.rrect(Rect2(10,8,sz.x-20,34),12,int(r.position.x)+1,0),tint),false)
	UI.lbl(body,label,Rect2(r.position.x,r.position.y+8,r.size.x,34),22,Color.WHITE)
	for i in rw.size():
		var x:=r.get_center().x+(float(i)-(rw.size()-1)*0.5)*80
		UI.icon(body,str(rw[i][0]),Vector2(x,r.position.y+74),46)
		UI.lbl(body,"×%d"%int(rw[i][1]),Rect2(x-40,r.position.y+88,80,30),20,Color.WHITE,HORIZONTAL_ALIGNMENT_CENTER,5,Art.INK)

## 带阴影和墨线的圆角卡片
func _card(ci: CanvasItem, r: Rect2, col: Color, seed: int) -> void:
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position+Vector2(0,5),r.size),16,seed,0),Color(0.3,0.18,0.08,0.18))
	Art.fill(ci,Art.rrect(r.grow(-2),16,seed,0),col,2.5)

## 头像底座：墨线圆 + 彩色环 + 骨白底
func _ring(ci: CanvasItem, c: Vector2, r: float, tint: Color) -> void:
	ci.draw_circle(c+Vector2(0,5),r+2,Color(0,0,0,0.18))
	ci.draw_circle(c,r+2,Art.INK)
	ci.draw_circle(c,r-1,tint)
	ci.draw_circle(c,r-8,Art.BONE)

func _rays(ci: CanvasItem, c: Vector2, r: float, col: Color, n: int, rot: float) -> void:
	for i in n:
		var a:=rot+TAU*i/n
		var w:=PI/n*0.55
		ci.draw_colored_polygon(PackedVector2Array([c,c+Vector2.from_angle(a-w)*r,c+Vector2.from_angle(a+w)*r]),col)

func _vs(ci: CanvasItem, c: Vector2, r: float) -> void:
	# 星章底是预生成贴图（按 r=40 画的）
	var k:=r/40.0
	Sprites.at(ci,"ev_duel_vs",c+Vector2(0,2)*k,k)
	var f: Font=G.font_title if G.font_title else ThemeDB.fallback_font
	var fs:=int(r*0.85)
	var tw:=f.get_string_size("VS",HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
	var p:=c+Vector2(-tw*0.5,fs*0.36)
	ci.draw_string_outline(f,p,"VS",HORIZONTAL_ALIGNMENT_LEFT,-1,fs,8,Art.INK)
	ci.draw_string(f,p,"VS",HORIZONTAL_ALIGNMENT_LEFT,-1,fs,Color.WHITE)

func _crown(ci: CanvasItem, c: Vector2, w: float) -> void:
	var h:=w*0.62
	var pts:=PackedVector2Array([c+Vector2(-w*0.5,h*0.5),c+Vector2(-w*0.5,-h*0.3),c+Vector2(-w*0.25,h*0.05),c+Vector2(0,-h*0.5),c+Vector2(w*0.25,h*0.05),c+Vector2(w*0.5,-h*0.3),c+Vector2(w*0.5,h*0.5)])
	Art.fill(ci,pts,Art.FIRE2,2.5)
	ci.draw_circle(c+Vector2(0,h*0.2),w*0.08,Art.CLAY)

func _plate(r: Rect2, text: String, col: Color) -> void:
	UI.box(body,r,func(ci,sz): _card(ci,Rect2(Vector2.ZERO,sz),col,int(r.position.x)+7),false)
	UI.lbl(body,text,r,22,Color.WHITE)

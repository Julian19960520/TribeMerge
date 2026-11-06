class_name EventEntryArt
extends RefCounted
static func paint(ci: CanvasItem, sz: Vector2, icon: String, title: String, status: String, detail := "", locked := false, badge := false) -> void:
	var bottom := sz.y - 15.0
	ci.draw_texture_rect(MergeEvent.texture(icon),Rect2(0,bottom-190,sz.x,130),false,Color(.72,.72,.72) if locked else Color.WHITE)
	text(ci,title,Vector2(sz.x/2,bottom-48),19,Color("fff0c5"))
	if detail != "":text(ci,detail,Vector2(sz.x/2,bottom-25),17,Color.WHITE)
	text(ci,status,Vector2(sz.x/2,bottom),19,Color("ffe9a4"))
	if locked:Paint.glyph(ci,"lock",Vector2(sz.x/2,bottom-98),.65)
	if badge:Paint.badge_num(ci,Vector2(sz.x-13,bottom-174),8,8)
static func text(ci: CanvasItem, s: String, center: Vector2, fs: int, color: Color) -> void:
	var f: Font=G.font_title
	var p:=center-Vector2(f.get_string_size(s,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x/2,0)
	ci.draw_string_outline(f,p,s,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,5,Art.INK)
	ci.draw_string(f,p,s,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,color)

shader_type canvas_item;
// 全屏压暗，只在 holes 里露出来；洞是圆角矩形，边缘羽化（不画描边）。

uniform vec4 holes[8];
uniform int hole_count = 0;
uniform vec2 screen_px = vec2(720.0, 1480.0);
uniform float dim_a = 0.76;
uniform float feather = 5.0;
uniform float corner = 18.0;

float rbox(vec2 p, vec4 r) {
	vec2 c = r.xy + r.zw * 0.5;
	vec2 h = r.zw * 0.5 - vec2(corner);
	vec2 q = abs(p - c) - h;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - corner;
}

void fragment() {
	vec2 p = UV * screen_px;
	float d = 1e6;
	for (int i = 0; i < 8; i++) {
		if (i < hole_count && holes[i].z > 1.0 && holes[i].w > 1.0) {
			d = min(d, rbox(p, holes[i]));
		}
	}
	// 洞内 d<0 全亮；往外 feather 像素内渐渐压暗
	float a = dim_a * smoothstep(0.0, feather, d);
	COLOR = vec4(0.0, 0.0, 0.0, a);
}

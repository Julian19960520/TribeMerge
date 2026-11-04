shader_type canvas_item;

uniform vec4 holes[8];
uniform int hole_count = 0;
uniform vec2 screen_px = vec2(720.0, 1480.0);
uniform float dim_a = 0.76;

void fragment() {
	vec2 p = UV * screen_px;
	float a = dim_a;
	for (int i = 0; i < 8; i++) {
		if (i < hole_count && holes[i].z > 1.0 && holes[i].w > 1.0) {
			if (p.x >= holes[i].x && p.y >= holes[i].y && p.x <= holes[i].x + holes[i].z && p.y <= holes[i].y + holes[i].w) {
				a = 0.0;
			}
		}
	}
	COLOR = vec4(0.0, 0.0, 0.0, a);
}

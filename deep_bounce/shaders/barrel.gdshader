shader_type canvas_item;
// The barrel is painted flat (albedo) with a normal map; light comes from the same fixed top-left
// direction as in every painted asset, so the barrel stays correctly lit at any aim angle.
uniform sampler2D normal_map : filter_linear;
uniform float rot = 1.5708;
uniform vec3 light_dir = vec3(-0.52, -0.72, 0.86);
uniform vec3 spec_color : source_color = vec3(1.0, 0.86, 0.62);
uniform float heat = 0.0;
uniform vec3 heat_color : source_color = vec3(1.0, 0.75, 0.4);
varying vec4 v_mod;

void vertex() {
	v_mod = COLOR;
}

void fragment() {
	vec4 alb = texture(TEXTURE, UV);
	vec4 nm = texture(normal_map, UV);
	vec3 n = nm.rgb * 2.0 - 1.0;
	float c = cos(rot);
	float s = sin(rot);
	vec3 nw = normalize(vec3(c * n.x - s * n.y, s * n.x + c * n.y, n.z));
	vec3 L = normalize(light_dir);
	float dif = max(dot(nw, L), 0.0);
	vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));
	float sp = pow(max(dot(nw, H), 0.0), 26.0) * nm.a;
	vec3 col = alb.rgb * (0.24 + 1.0 * dif) + spec_color * sp * 0.8;
	// warm light spilling along the barrel just after a shot, strongest at the mouth
	col += heat_color * heat * smoothstep(0.55, 1.0, UV.x) * 0.55;
	COLOR = vec4(col, alb.a) * v_mod;
}

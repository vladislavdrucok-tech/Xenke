shader_type canvas_item;
// Full-screen gouache pass over the painted world: uneven brush edges,
// pigment gathering along shape edges, paper grain and a warm vignette.
// The interface is drawn above this layer and stays crisp.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform float wobble = 1.5;
uniform float grain = 0.08;
uniform float edge_dark = 0.3;
uniform float vignette = 0.42;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	float n1 = texture(noise_tex, uv * vec2(3.1, 5.7)).r - 0.5;
	float n2 = texture(noise_tex, uv * vec2(5.3, 2.9) + vec2(0.37, 0.11)).r - 0.5;
	vec2 duv = uv + vec2(n1, n2) * px * wobble * 2.0;
	vec3 c = texture(screen_tex, duv).rgb;
	vec3 cx = texture(screen_tex, duv + vec2(px.x * 2.0, 0.0)).rgb;
	vec3 cy = texture(screen_tex, duv + vec2(0.0, px.y * 2.0)).rgb;
	float edge = length(c - cx) + length(c - cy);
	c *= 1.0 - clamp(edge * edge_dark, 0.0, 0.16);
	float p = texture(noise_tex, FRAGCOORD.xy / 150.0).r;
	float p2 = texture(noise_tex, FRAGCOORD.xy / 37.0).r;
	c *= 1.0 - grain * 0.5 + grain * (p * 0.6 + p2 * 0.4);
	// slight pigment saturation
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, 1.08);
	vec2 q = uv - 0.5;
	float v = clamp(1.0 - dot(q, q) * vignette * 2.0, 0.0, 1.0);
	c *= mix(vec3(0.78, 0.7, 0.64), vec3(1.0), v);
	COLOR = vec4(c, 1.0);
}

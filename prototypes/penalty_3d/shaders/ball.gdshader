shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 panel_color = vec3(0.96, 0.97, 0.89);
uniform vec3 seam_color = vec3(0.035, 0.09, 0.10);
uniform float glow = 0.0;

varying vec3 local_point;

void vertex() {
	local_point = VERTEX;
}

void fragment() {
	vec3 n = normalize(local_point);
	vec3 absolute_n = abs(n);
	vec2 p;
	if (absolute_n.x > absolute_n.y && absolute_n.x > absolute_n.z) {
		p = n.yz / absolute_n.x;
	} else if (absolute_n.y > absolute_n.z) {
		p = n.xz / absolute_n.y;
	} else {
		p = n.xy / absolute_n.z;
	}
	float sector = 6.2831853 / 5.0;
	float angle = atan(p.x, p.y);
	float edge = cos(floor(0.5 + angle / sector) * sector - angle) * length(p);
	float panel = smoothstep(0.34, 0.37, edge);
	ALBEDO = mix(seam_color, panel_color, panel);
	EMISSION = panel_color * glow;
	ROUGHNESS = 0.68;
}

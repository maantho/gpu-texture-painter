shader_type spatial;

uniform sampler2D overlay_texture : hint_default_transparent;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	ALBEDO = vec3(UV2.xy, 0); 
	ALPHA = texture(overlay_texture, UV2.xy).a;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}

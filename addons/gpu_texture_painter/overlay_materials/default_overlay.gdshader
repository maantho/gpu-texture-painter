shader_type spatial;

uniform sampler2D overlay_texture;
uniform vec2 position_in_atlas;
uniform vec2 size_in_atlas;
//uniform int index_in_atlas;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	vec2 atlas_uv = UV2 * size_in_atlas + position_in_atlas;

	//if cull mask layer 21 is enabled, the camera acts as a brush
	bool brush = (CAMERA_VISIBLE_LAYERS & (1u << uint(20))) != 0u;

    if(brush){
		// display brush UVs in emission
        EMISSION = vec3(atlas_uv, 0);
        ALBEDO = vec3(0);
    }
	else{
		vec4 atlas_color = texture(overlay_texture, atlas_uv);
		ALBEDO = atlas_color.rgb;
		ALPHA = atlas_color.a;
	}
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}

shader_type spatial;

uniform sampler2D overlay_texture;
uniform vec2 position_in_atlas;
uniform vec2 size_in_atlas;
uniform uint atlas_index;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	vec2 atlas_uv = UV2 * size_in_atlas + position_in_atlas;

	bool is_camera_brush = (CAMERA_VISIBLE_LAYERS & (1u << uint(20))) != 0u;
    if(is_camera_brush){
		// This code is executed if the mesh is rendered by a camera brush. See default_overlay.gdshader
		uint exponential_bit = 1u << 30u;
		float distance = -VERTEX.z;
		uint distance_bits = (packHalf2x16(vec2(distance, 0)) & 0xFFE0u) << uint(13 - 5);
		uint index_sign_bit = (atlas_index & 0x4u) << uint(31 - 2);
		uint index_exp_bits = (atlas_index & 0x3u) << 24u;
		float b = uintBitsToFloat(exponential_bit | distance_bits | index_sign_bit | index_exp_bits);
		ALBEDO = vec3(atlas_uv, b);
    }
	else{
		// This code is executed for normal cameras.
		// Insert your code here!
		
	}
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}

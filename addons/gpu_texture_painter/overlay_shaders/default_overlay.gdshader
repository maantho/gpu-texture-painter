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

	// if cull mask layer 21 is enabled, the camera acts as a brush
	bool is_camera_brush = (CAMERA_VISIBLE_LAYERS & (1u << uint(20))) != 0u;
    if(is_camera_brush){
		// store UV in R and G channels
		// store distance and index in B channel
		// distance and index are packed into a 32 bit float as follows,
		// to survive 16bit floatconversion:
		// unchanged bit ids: 31(sign), 23-25(exponent), 13-22(mantissa)

		// needs to be in exponent form to survive 16bit float conversion
		uint exponential_bit = 1u << 30u;

		// save distance in 13-23 -> 11 bits truncated
		float distance = -VERTEX.z;
		uint distance_bits = (packHalf2x16(vec2(distance, 0)) & 0xFFE0u) << uint(13 - 5);

		// save index in sign bit and exponent bits
		uint index_sign_bit = (atlas_index & 0x4u) << uint(31 - 2); // in sign bit 31
		uint index_exp_bits = (atlas_index & 0x3u) << 24u; // in exponent bits 24-25

		// combine bits into B Channel
		float b = uintBitsToFloat(exponential_bit | distance_bits | index_sign_bit | index_exp_bits);

		// display as EMISSION to avoid shading
		ALBEDO = vec3(0.0);
		SPECULAR = 0.0;
		EMISSION = vec3(atlas_uv - vec2(0.5), b);
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

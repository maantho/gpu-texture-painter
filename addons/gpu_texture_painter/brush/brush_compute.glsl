#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform restrict readonly image2D brush_texture;

layout(rgba32f, set = 1, binding = 0) uniform restrict readonly image2D brush_shape;

layout(push_constant, std430) uniform Params {
	vec4 brush_color;
    float delta;
    float max_distance;
    float start_distance_fade;
    float min_bleed;
    float max_bleed;
} params;

layout(rgba32f, set = 2, binding = 0) uniform restrict image2D overlay_texture_0;
layout(rgba32f, set = 2, binding = 1) uniform restrict image2D overlay_texture_1;
layout(rgba32f, set = 2, binding = 2) uniform restrict image2D overlay_texture_2;
layout(rgba32f, set = 2, binding = 3) uniform restrict image2D overlay_texture_3;
layout(rgba32f, set = 2, binding = 4) uniform restrict image2D overlay_texture_4;
layout(rgba32f, set = 2, binding = 5) uniform restrict image2D overlay_texture_5;
layout(rgba32f, set = 2, binding = 6) uniform restrict image2D overlay_texture_6;
layout(rgba32f, set = 2, binding = 7) uniform restrict image2D overlay_texture_7;


// The code we want to execute in each invocation
void main() {
    // gl_GlobalInvocationID.x uniquely identifies this invocation across all work groups
    ivec2 brush_texture_coords = ivec2(gl_GlobalInvocationID.xy);

    if ((brush_texture_coords.x > imageSize(brush_texture).x) || (brush_texture_coords.y > imageSize(brush_texture).y)) {
		return;
	}

    vec4 brush_texture_color = imageLoad(brush_texture, brush_texture_coords);
    
    uint b_bits = floatBitsToUint(brush_texture_color.b);
    // get distance in 13-23 -> 11 bits truncated
    float distance = unpackHalf2x16(b_bits >> uint(13 - 5) & 0xFFE0u).x;
    float distance_value = clamp(abs(distance) / params.max_distance, 0.0f, 1.0f);

    //distance fade
    float distance_fade = 1.0f;
    if (params.start_distance_fade < 1.0f) {
        if (distance_value >= params.start_distance_fade) {
            distance_fade = 1.0f - ((distance_value - params.start_distance_fade) / (1.0f - params.start_distance_fade));
        }
    }

    //distance bleed
    int bleed = int(params.max_bleed);
    if (params.max_bleed > 0.0f && params.min_bleed < params.max_bleed) {
        bleed = int(mix(params.min_bleed, params.max_bleed, distance_value));
    }

    ivec2 brush_shape_coords = ivec2(vec2(brush_texture_coords) / vec2(imageSize(brush_texture)) * vec2(imageSize(brush_shape)));
    vec4 brush_color = vec4(params.brush_color.rgb, imageLoad(brush_shape, brush_shape_coords).r * params.delta * params.brush_color.a * distance_fade);

#define PROCESS_TEXTURE(tex) { \
    ivec2 overlay_texture_coords = ivec2(brush_texture_color.xy * vec2(imageSize(tex))); \
    for (int y = -bleed; y <= bleed; y++) { \
        for (int x = -bleed; x <= bleed; x++) { \
            ivec2 bleed_coords = overlay_texture_coords + ivec2(x, y); \
            vec4 existing_color = imageLoad(tex, bleed_coords); \
            float out_alpha = brush_color.a + existing_color.a * (1.0f - brush_color.a); \
            vec3 out_color = (out_alpha > 0.0f) ? \
                (brush_color.rgb * brush_color.a + existing_color.rgb * existing_color.a * (1.0f - brush_color.a)) / out_alpha : \
                vec3(brush_color.rgb); \
            imageStore(tex, bleed_coords, vec4(out_color, out_alpha)); \
        } \
    } } 

    // get index in bit 24-25 and bit 31
    uint atlas_index = (b_bits >> uint(31 - 2) & 0x4u) | (b_bits >> uint(24) & 0x3u);
    switch (atlas_index) {
        case 0: PROCESS_TEXTURE(overlay_texture_0) break;
        case 1: PROCESS_TEXTURE(overlay_texture_1) break;
        case 2: PROCESS_TEXTURE(overlay_texture_2) break;
        case 3: PROCESS_TEXTURE(overlay_texture_3) break;
        case 4: PROCESS_TEXTURE(overlay_texture_4) break;
        case 5: PROCESS_TEXTURE(overlay_texture_5) break;
        case 6: PROCESS_TEXTURE(overlay_texture_6) break;
        case 7: PROCESS_TEXTURE(overlay_texture_7) break;
    }

}
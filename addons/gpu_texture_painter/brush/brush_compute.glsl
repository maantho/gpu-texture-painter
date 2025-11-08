#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform restrict readonly image2D brush_texture;

layout(rgba32f, set = 0, binding = 1) uniform restrict readonly image2D brush_shape;

layout(push_constant, std430) uniform Params {
	vec4 brush_color;
    float delta;
    float max_distance;
    float start_distance_fade;
    float bleed;
    float start_bleed_fade;
} params;

layout(rgba32f, set = 0, binding = 2) uniform restrict image2D overlay_texture;

// The code we want to execute in each invocation
void main() {
    // gl_GlobalInvocationID.x uniquely identifies this invocation across all work groups
    ivec2 brush_texture_coords = ivec2(gl_GlobalInvocationID.xy);

    if ((brush_texture_coords.x > imageSize(brush_texture).x) || (brush_texture_coords.y > imageSize(brush_texture).y)) {
		return;
	}

    vec4 brush_texture_color = imageLoad(brush_texture, brush_texture_coords);

    //distance fade
    float distance_fade = 1.0f;
    if (params.start_distance_fade < 1.0f) {
        float distance_value = clamp(abs(brush_texture_color.b) / params.max_distance, 0.0f, 1.0f);
        if (distance_value >= params.start_distance_fade) {
            distance_fade = 1.0f - ((distance_value - params.start_distance_fade) / (1.0f - params.start_distance_fade));
        }
    }

    //distance bleed
    int distance_bleed = int(params.bleed);
    if (params.bleed > 0.0f && params.start_bleed_fade < 1.0f) {
        float distance_value = clamp(abs(brush_texture_color.b) / params.max_distance, 0.0f, 1.0f);
        if (distance_value >= params.start_bleed_fade) {
            float bleed_factor = (distance_value - params.start_bleed_fade) / (1.0f - params.start_bleed_fade);
            distance_bleed = int(params.bleed * bleed_factor);
        }
        else {
            distance_bleed = 0;
        }
    }

    ivec2 brush_shape_coords = ivec2(vec2(brush_texture_coords) / vec2(imageSize(brush_texture)) * vec2(imageSize(brush_shape)));
    vec4 brush_color = vec4(params.brush_color.rgb, imageLoad(brush_shape, brush_shape_coords).r * params.delta * params.brush_color.a * distance_fade);

    ivec2 overlay_texture_coords = ivec2(brush_texture_color.xy * vec2(imageSize(overlay_texture)));

    for (int y = -distance_bleed; y <= distance_bleed; y++) {
        for (int x = -distance_bleed; x <= distance_bleed; x++) {
            ivec2 bleed_coords = overlay_texture_coords + ivec2(x, y);
            vec4 existing_color = imageLoad(overlay_texture, bleed_coords);
            float out_alpha = brush_color.a + existing_color.a * (1.0f - brush_color.a);
            vec3 out_color;
            if (out_alpha > 0.0f) {
                out_color = (brush_color.rgb * brush_color.a + existing_color.rgb * existing_color.a * (1.0f - brush_color.a)) / out_alpha;
            }
            else {
                out_color = vec3(0.0f);
            }
            imageStore(overlay_texture, bleed_coords, vec4(out_color, out_alpha));
        }
    }

    /*
    vec4 existing_color = imageLoad(overlay_texture, overlay_texture_coords);
    float out_alpha = brush_color.a + existing_color.a * (1.0f - brush_color.a);
    vec3 out_color;
    if (out_alpha > 0.0f) {
        out_color = (brush_color.rgb * brush_color.a + existing_color.rgb * existing_color.a * (1.0f - brush_color.a)) / out_alpha;
    }
    else {
        out_color = vec3(0.0f);
    }
    imageStore(overlay_texture, overlay_texture_coords, vec4(out_color, out_alpha));
    */
}
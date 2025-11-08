#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform restrict readonly image2D brush_texture;

layout(rgba32f, set = 0, binding = 1) uniform restrict readonly image2D brush_shape;

layout(push_constant, std430) uniform Params {
	vec4 brush_color;
    float delta;
    float start_distance_fade;
    float max_distance;
} params;

layout(rgba32f, set = 0, binding = 2) uniform restrict image2D overlay_texture;

// The code we want to execute in each invocation
void main() {
    // gl_GlobalInvocationID.x uniquely identifies this invocation across all work groups
    ivec2 brush_texture_coords = ivec2(gl_GlobalInvocationID.xy);

    if ((brush_texture_coords.x > imageSize(brush_texture).x) || (brush_texture_coords.y > imageSize(brush_texture).y)) {
		return;
	}

    vec4 overlay_texture_uv = imageLoad(brush_texture, brush_texture_coords);
    ivec2 overlay_texture_coords = ivec2(overlay_texture_uv.xy * vec2(imageSize(overlay_texture)));
    vec4 existing_color = imageLoad(overlay_texture, overlay_texture_coords);

    float distance_fade = 1.0f;
    if (params.start_distance_fade < 1.0f) {
        float distance_value = clamp(abs(overlay_texture_uv.b) / params.max_distance, 0.0f, 1.0f);
        if (distance_value >= params.start_distance_fade) {
            distance_fade = 1.0f - ((distance_value - params.start_distance_fade) / (1.0f - params.start_distance_fade));
        }
    }

    ivec2 brush_shape_coords = ivec2(vec2(brush_texture_coords) / vec2(imageSize(brush_texture)) * vec2(imageSize(brush_shape)));
    vec4 brush_color = vec4(params.brush_color.rgb, imageLoad(brush_shape, brush_shape_coords).r * params.delta * params.brush_color.a * distance_fade);

    float out_alpha = brush_color.a + existing_color.a * (1.0f - brush_color.a);
    vec3 out_color;
    if (out_alpha > 0.0f) {
        out_color = (brush_color.rgb * brush_color.a + existing_color.rgb * existing_color.a * (1.0f - brush_color.a)) / out_alpha;
    }
    else {
        out_color = vec3(0.0f);
    }
    imageStore(overlay_texture, overlay_texture_coords, vec4(out_color, out_alpha));
}
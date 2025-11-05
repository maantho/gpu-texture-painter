#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform restrict readonly image2D brush_texture;

layout(rgba32f, set = 0, binding = 1) uniform restrict writeonly image2D overlay_texture;

// The code we want to execute in each invocation
void main() {
    // gl_GlobalInvocationID.x uniquely identifies this invocation across all work groups
    ivec2 brush_texture_coords = ivec2(gl_GlobalInvocationID.xy);

    if ((brush_texture_coords.x > imageSize(brush_texture).x) || (brush_texture_coords.y > imageSize(brush_texture).y)) {
		return;
	}

    vec4 overlay_texture_uv = imageLoad(brush_texture, brush_texture_coords);
    ivec2 overlay_texture_coords = ivec2(overlay_texture_uv.xy * vec2(imageSize(overlay_texture)));

    imageStore(overlay_texture, overlay_texture_coords, vec4(1.0, 1.0, 1.0, 1.0));
}
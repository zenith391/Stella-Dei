#version 330 core
uniform vec3 viewPos;
uniform float planetRadius;
uniform sampler2D screenTexture;

in vec2 texCoords;

out vec4 fragColor;

// Returns vector (dstToSphere, dstThroughSphere)
vec2 raySphere(float sphereRadius, vec3 rayOrigin, vec3 rayDir) {
	vec3 offset = rayOrigin;
	float a = 1;
	float b = 2 * dot(offset, rayDir);
	float c = dot(offset, offset) - sphereRadius * sphereRadius;
	float d = b * b - 4 * a * c;
	
	if (d > 0) {
		float s = sqrt(d);
		float dstNear = max(0, (-b - s) / (2 * a));
		float dstFar = (-b + s) / (2 * a);
		if (dstFar >= 0) {
			return vec2(dstNear, dstFar - dstNear);
		}
	}
	
	// TODO: vec2(infinity, 0)
	return vec2(100000, 0);
}

void main() {
	// Post-process
	// TODO: do this in a separate shader using framebuffers
	vec3 color = texture(screenTexture, texCoords).rgb;
	
	vec3 rayDir = normalize(-viewPos);
	float atmosphereRadius = planetRadius + 10;
	vec2 hitInfo = raySphere(atmosphereRadius, viewPos, rayDir);
	
	//float factor = hitInfo.y / (hitInfo.x * 2);
	//fragColor = vec4(factor, factor, factor, 1.0f);

	// HDR
	float gamma = 1.0; // 2.2
	float exposure = 1.0;
	fragColor = vec4(pow(vec3(1.0) - exp(-color * exposure), vec3(1.0 / gamma)), 1.0f);
}


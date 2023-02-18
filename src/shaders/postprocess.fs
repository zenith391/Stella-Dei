#version 330 core
uniform vec3 viewPos;
uniform vec3 lightDir;
uniform float lightIntensity;
uniform float planetRadius;
uniform float atmosphereRadius;
uniform sampler2D screenTexture;
uniform sampler2D screenDepth;
uniform mat4 projMatrix;
uniform mat4 viewMatrix;
uniform bool enableAtmosphere;

in vec2 texCoords;

out vec4 fragColor;

const float pos_infinity = uintBitsToFloat(0x7F800000U);

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
	return vec2(pos_infinity, 0);
}

float densityAtPoint(vec3 point) {
	float radius = planetRadius;
	float height = length(point) - radius;
	float heightScaled = height / (atmosphereRadius - radius);
	float densityFalloff = 3.00; // TODO: variable depending on composition?
	float localDensity = exp(-heightScaled * densityFalloff) * (1 - heightScaled);
	return localDensity;
}

// TODO: optimise by storing in a LUT
float opticalDepth(vec3 rayOrigin, vec3 rayDir, float rayLength) {
	vec3 point = rayOrigin;
	int numOpticalDepthPoints = 10;
	float stepSize = rayLength / (numOpticalDepthPoints);
	float opticalDepth = 0;
	
	for (int i = 0; i < numOpticalDepthPoints; i++) {
		float localDensity = densityAtPoint(point);
		opticalDepth += localDensity * stepSize;
		point += rayDir * stepSize;
	}
	return opticalDepth;
}

vec3 calculateLight(vec3 rayOrigin, vec3 rayDir, float rayLength, vec3 originalColor) {
	int numInScatteringPoints = 10; // TODO: configurable quality level
	
	vec3 inScatterPoint = rayOrigin;
	float stepSize = rayLength / (numInScatteringPoints);
	vec3 inScatteredLight = vec3(0);
	vec3 dirToSun = lightDir;
	
	vec3 wavelengths = vec3(700, 530, 440);
	vec3 scatteringCoefficients = pow(400 / wavelengths, vec3(4));
	float scatteringStrength = 1;
	scatteringCoefficients *= scatteringStrength;
	float viewRayOpticalDepth;
	
	for (int i = 0; i < numInScatteringPoints; i++) {
		float sunRayLength = raySphere(atmosphereRadius, inScatterPoint, dirToSun).y;
		float sunRayOpticalDepth = opticalDepth(inScatterPoint, dirToSun, sunRayLength);
		viewRayOpticalDepth = opticalDepth(inScatterPoint, -rayDir, stepSize * i);
		//sunRayOpticalDepth = 0;
		vec3 transmittance = exp(-(sunRayOpticalDepth + viewRayOpticalDepth) * scatteringCoefficients);
		float localDensity = densityAtPoint(inScatterPoint);
		
		inScatteredLight += localDensity * transmittance * scatteringCoefficients * stepSize;
		inScatterPoint += rayDir * stepSize;
	}
	
	//float originalColorTransmittance = exp(-viewRayOpticalDepth);
	float originalColorTransmittance = 1.0;
	return originalColor * originalColorTransmittance + inScatteredLight * lightIntensity;
}

float linearizeDepth(float d, float zNear, float zFar) {
	float z_n = 2.0 * d - 1.0;
	return 2.0 * zNear * zFar / (zFar + zNear - z_n * (zFar - zNear));
}

void main() {
	// Post-process
	vec3 color = texture(screenTexture, texCoords).rgb;
	float depth = texture(screenDepth, texCoords).r;
	
	mat4 projViewMatrix = projMatrix * viewMatrix;
	
	float zFar = planetRadius * 5;
	float zNear = zFar / 10000;
	
	vec4 fragNear = inverse(projViewMatrix) * vec4((texCoords.xy - vec2(0.5, 0.5))*2, 0.0, 1.0);
	vec4 fragFar = fragNear + inverse(projViewMatrix)[2];
	fragNear.xyz /= fragNear.w;
	fragFar.xyz /= fragFar.w;
	vec4 fragDir = fragFar - fragNear;
	
	vec3 rayDir = normalize(fragDir.xyz);
	vec2 hitInfo = raySphere(atmosphereRadius, viewPos, rayDir);
	
	float dstToAtmosphere = hitInfo.x;
	//float dstToSurface = linearizeDepth(depth, zNear, zFar); // TODO: make it work
	float dstToSurface = dstToAtmosphere + 500;
	float dstThroughAtmosphere = min(hitInfo.y, dstToSurface - dstToAtmosphere);
	if (depth == 1) {
		dstToSurface = dstToAtmosphere + 500;
	}
	
	float factor = dstThroughAtmosphere / atmosphereRadius / 2;
	vec3 result;
	if (dstThroughAtmosphere > 0 && enableAtmosphere) {
		vec3 pointInAtmosphere = viewPos + rayDir * dstToAtmosphere;
		if (depth == 1 && false) { // skybox
			color = vec3(0);
		}
		vec3 light = calculateLight(pointInAtmosphere, rayDir, dstThroughAtmosphere, color);
		result = light;
		//result = pointInAtmosphere / vec3(10000);

	} else {
		result = color;
	}
	//result = mix(result, vec3((dstToSurface - dstToAtmosphere - 500)), 0.9);

	// HDR
	float gamma = 1.0; // 2.2
	float exposure = 1.0;
	fragColor = vec4(pow(vec3(1.0) - exp(-result * exposure), vec3(1.0 / gamma)), 1.0f);
}


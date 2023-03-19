#version 330 core
#define M_PI 3.1415926535897932384626433832795

// Parameters
uniform vec3 viewPos;
uniform vec3 lightDir;
uniform float lightIntensity;
uniform float planetRadius;
uniform float atmosphereRadius;
uniform mat4 projMatrix;
uniform mat4 viewMatrix;
uniform bool enableAtmosphere;

// Samplers
uniform sampler2D screenTexture;
uniform sampler2D bloomTexture;
uniform sampler2D screenDepth;

// Operations
uniform bool doBrightTexture;
uniform bool doBlurring;
uniform bool horizontalBlurring;

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
	float radius = planetRadius - 100;
	float height = length(point) - radius;
	float heightScaled = height / (atmosphereRadius - radius);
	float densityFalloff = 4.00; // TODO: variable depending on composition?
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

void drawBrightTexture() {
	vec3 color = texture(screenTexture, texCoords).rgb;
	float brightness = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
	if (brightness > 1.0) {
		fragColor = vec4(color.rgb, 1.0);
	} else {
		fragColor = vec4(0, 0, 0, 1.0);
	}
}

void drawBlurredTexture() {
	float weight[16] = float[] (
		0.11764705882353,
		0.10382316500995,
		0.071356548201486,
		0.038194407924512,
		0.015921798027837,
		0.0051690510145185,
		0.001306940769205,
		0.00025735189625681,
		3.9466191517943e-05,
		4.7135643991707e-06,
		4.3842978495043e-07,
		3.1759747098388e-08,
		1.7917623229074e-09,
		7.8724542250503e-11,
		2.6938057007595e-12,
		7.1787490324768e-14
	);
	//for (int i = 0; i < 16; i++) {
	//	float w = cos(i * M_PI / 16.0) * 0.5 + 0.5;
	//	weight[i] = w / (7.5 * 2 + 1);
	//}
	
	float sampleDistance = 1.5;
	vec2 tex_offset = 1.0 / textureSize(screenTexture, 0); // gets size of single texel
    vec3 result = texture(screenTexture, texCoords).rgb * weight[0]; // current fragment's contribution
    if (horizontalBlurring) {
        for (int i = 1; i < 16; i++) {
            result += texture(screenTexture, texCoords + vec2(tex_offset.x * i * sampleDistance, 0.0)).rgb * weight[i];
            result += texture(screenTexture, texCoords - vec2(tex_offset.x * i * sampleDistance, 0.0)).rgb * weight[i];
        }
    } else {
        for (int i = 1; i < 16; i++) {
            result += texture(screenTexture, texCoords + vec2(0.0, tex_offset.y * i * sampleDistance)).rgb * weight[i];
            result += texture(screenTexture, texCoords - vec2(0.0, tex_offset.y * i * sampleDistance)).rgb * weight[i];
        }
    }
    fragColor = vec4(result, 1.0);
}

void main() {
	// Post-process
	if (doBrightTexture) {
		drawBrightTexture();
		return;
	} else if (doBlurring) {
		drawBlurredTexture();
		return;
	}
	
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
		if (depth == 1) { // skybox
			color = vec3(0);
		}
		vec3 light = calculateLight(pointInAtmosphere, rayDir, dstThroughAtmosphere, color);
		result = light;
		//result = pointInAtmosphere / vec3(10000);
	} else {
		result = color;
	}
	//result = mix(result, vec3((dstToSurface - dstToAtmosphere - 500) / 10), 0.9);
	// result = vec3(dstThroughAtmosphere / (planetRadius * 2));

	// Apply bloom
	vec3 bloomColor = texture(bloomTexture, texCoords).rgb;
	result += bloomColor;
	
	// HDR
	float gamma = 1.0; // 2.2
	float exposure = 1.0;
	fragColor = vec4(pow(vec3(1.0) - exp(-result * exposure), vec3(1.0 / gamma)), 1.0f);
}


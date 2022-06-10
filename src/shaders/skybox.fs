#version 330 core

uniform samplerCube skyboxCubemap;

in vec3 texCoord;
out vec4 fragColor;

void main() {
	fragColor = texture(skyboxCubemap, texCoord);
}

#version 330 core

in vec2 texCoord;
in vec4 vertexColor;

uniform bool useTexture;
uniform sampler2D uTexture;

out vec4 fragColor;

void main() {
	if (useTexture) {
		fragColor = texture(uTexture, texCoord) * vertexColor;
	} else {
		fragColor = vertexColor;
	}
}

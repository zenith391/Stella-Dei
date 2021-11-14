#version 330 core

out vec4 fragColor;
in vec2 texCoord;

uniform sampler2D uTexture;

void main() {
	fragColor = texture(uTexture, texCoord);
	if (fragColor.w == 0) {
		discard;
	}
}

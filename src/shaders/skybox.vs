#version 330 core
layout (location = 0) in vec3 aPos;

uniform mat4 projMatrix;
uniform mat4 viewMatrix;

out vec3 texCoord;

void main()
{
	gl_Position = projMatrix * viewMatrix * vec4(aPos, 1);
	texCoord = aPos;
}

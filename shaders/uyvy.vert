#version 440

// Passthrough vertex stage for the UYVY video quad: standard Qt scene
// graph transform, texture coordinate handed to the fragment stage.

layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;

layout(location = 0) out vec2 vTexCoord;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float texWidth; // video width in luma pixels
} ubuf;

out gl_PerVertex { vec4 gl_Position; };

void main()
{
    vTexCoord = qt_MultiTexCoord0;
    gl_Position = ubuf.qt_Matrix * qt_Vertex;
}

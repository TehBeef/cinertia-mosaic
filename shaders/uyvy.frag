#version 440

// UYVY 4:2:2 → RGB on the GPU. The packed frame is uploaded untouched as
// an RGBA texture of width/2: one texel holds two pixels as (U, Y0, V, Y1).
// The NDI library previously converted every frame to BGRA on the CPU —
// this shader replaces that per-frame CPU work with a few GPU fetches.
//
// Sampling: the texture uses LINEAR filtering, which is correct vertically
// (same byte lanes blend) but would corrupt luma horizontally (Y0/Y1 of
// neighboring pairs would mix). So horizontal samples are taken at exact
// texel centers and blended manually, parity-aware for luma.

layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float texWidth; // video width in luma pixels
} ubuf;

layout(binding = 1) uniform sampler2D src;

float lumaAt(float x, float y, float texels)
{
    float t = floor(x * 0.5);
    vec4 s = texture(src, vec2((t + 0.5) / texels, y));
    return (mod(x, 2.0) < 0.5) ? s.g : s.a;
}

void main()
{
    float w = ubuf.texWidth;
    float texels = w * 0.5;

    // Luma: manual horizontal bilinear between the two nearest pixels.
    float px = clamp(vTexCoord.x * w - 0.5, 0.0, w - 1.0);
    float x0 = floor(px);
    float f = px - x0;
    float y0 = lumaAt(x0, vTexCoord.y, texels);
    float y1 = lumaAt(min(x0 + 1.0, w - 1.0), vTexCoord.y, texels);
    float Y = mix(y0, y1, f);

    // Chroma: half horizontal resolution, blended the same way.
    float cpx = clamp(vTexCoord.x * texels - 0.5, 0.0, texels - 1.0);
    float cx0 = floor(cpx);
    float cf = cpx - cx0;
    vec2 c0 = texture(src, vec2((cx0 + 0.5) / texels, vTexCoord.y)).rb;
    vec2 c1 = texture(src, vec2((min(cx0 + 1.0, texels - 1.0) + 0.5) / texels, vTexCoord.y)).rb;
    vec2 C = mix(c0, c1, cf);

    // BT.709 video range → full-range RGB.
    float yl = (Y - 16.0 / 255.0) * (255.0 / 219.0);
    float u = (C.x - 128.0 / 255.0) * (255.0 / 224.0);
    float v = (C.y - 128.0 / 255.0) * (255.0 / 224.0);
    vec3 rgb = vec3(yl + 1.5748 * v,
                    yl - 0.18732 * u - 0.46812 * v,
                    yl + 1.8556 * u);
    fragColor = vec4(clamp(rgb, 0.0, 1.0), 1.0) * ubuf.qt_Opacity;
}

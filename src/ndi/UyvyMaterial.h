#pragma once

#include <QSGMaterial>
#include <QSGTexture>

// Scene graph material that renders a packed UYVY 4:2:2 frame (uploaded
// untouched as an RGBA texture of width/2) and converts it to RGB in the
// fragment shader — see shaders/uyvy.frag. Owns its texture.
class UyvyMaterial : public QSGMaterial
{
public:
    UyvyMaterial();
    ~UyvyMaterial() override;

    QSGMaterialType *type() const override;
    QSGMaterialShader *createShader(
        QSGRendererInterface::RenderMode) const override;
    int compare(const QSGMaterial *other) const override;

    // Replaces the frame texture, deleting the previous one.
    void setTexture(QSGTexture *texture, int videoWidthPixels);

    QSGTexture *texture() const { return m_texture; }
    float videoWidth() const { return m_videoWidth; }

private:
    QSGTexture *m_texture = nullptr;
    float m_videoWidth = 0.0f; // luma pixels (texture is half this wide)
};

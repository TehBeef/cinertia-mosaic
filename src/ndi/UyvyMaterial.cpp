#include "UyvyMaterial.h"

#include <QSGMaterialShader>

#include <cstring>

namespace {

class UyvyShader : public QSGMaterialShader
{
public:
    UyvyShader()
    {
        setShaderFileName(VertexStage,
                          QStringLiteral(":/shaders/uyvy.vert.qsb"));
        setShaderFileName(FragmentStage,
                          QStringLiteral(":/shaders/uyvy.frag.qsb"));
    }

    bool updateUniformData(RenderState &state, QSGMaterial *newMaterial,
                           QSGMaterial *) override
    {
        // std140 layout: mat4 at 0 (64 bytes), opacity at 64, width at 68.
        QByteArray *buf = state.uniformData();
        bool changed = false;
        if (state.isMatrixDirty()) {
            std::memcpy(buf->data(), state.combinedMatrix().constData(), 64);
            changed = true;
        }
        if (state.isOpacityDirty()) {
            const float opacity = state.opacity();
            std::memcpy(buf->data() + 64, &opacity, 4);
            changed = true;
        }
        const float width =
            static_cast<UyvyMaterial *>(newMaterial)->videoWidth();
        std::memcpy(buf->data() + 68, &width, 4);
        return true || changed;
    }

    void updateSampledImage(RenderState &state, int binding,
                            QSGTexture **texture, QSGMaterial *newMaterial,
                            QSGMaterial *) override
    {
        if (binding != 1)
            return;
        auto *mat = static_cast<UyvyMaterial *>(newMaterial);
        if (mat->texture()) {
            mat->texture()->commitTextureOperations(
                state.rhi(), state.resourceUpdateBatch());
            *texture = mat->texture();
        }
    }
};

} // namespace

UyvyMaterial::UyvyMaterial()
{
    setFlag(Blending, false);
}

UyvyMaterial::~UyvyMaterial()
{
    delete m_texture;
}

QSGMaterialType *UyvyMaterial::type() const
{
    static QSGMaterialType type;
    return &type;
}

QSGMaterialShader *UyvyMaterial::createShader(
    QSGRendererInterface::RenderMode) const
{
    return new UyvyShader;
}

int UyvyMaterial::compare(const QSGMaterial *other) const
{
    const auto *o = static_cast<const UyvyMaterial *>(other);
    if (m_texture == o->m_texture)
        return 0;
    return m_texture < o->m_texture ? -1 : 1;
}

void UyvyMaterial::setTexture(QSGTexture *texture, int videoWidthPixels)
{
    if (m_texture != texture)
        delete m_texture;
    m_texture = texture;
    m_videoWidth = float(videoWidthPixels);
    if (m_texture)
        m_texture->setFiltering(QSGTexture::Linear);
}

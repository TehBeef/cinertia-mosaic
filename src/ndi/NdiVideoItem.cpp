#include "NdiVideoItem.h"

#include <QMouseEvent>
#include <QQuickWindow>
#include <QSGSimpleTextureNode>
#include <QSGTransformNode>
#include <QTimer>
#include <QTransform>
#include <QWheelEvent>

#include <Processing.NDI.Lib.h>

#include <cmath>

namespace {
constexpr qreal kMinZoom = 0.1;
constexpr qreal kMaxZoom = 32.0;
constexpr qreal kZoomStepFactor = 1.15; // per wheel notch
constexpr qreal kRotateStepDeg = 2.0;   // per wheel notch with Ctrl
constexpr qreal kMinCropSize = 0.01;    // normalized
}

// ---------------------------------------------------------------- worker

void NdiReceiveWorker::start(const QString &sourceName)
{
    shutdown();

    setStatus(QStringLiteral("Connecting…"));

    const QByteArray nameUtf8 = sourceName.toUtf8();
    NDIlib_source_t source;
    source.p_ndi_name = nameUtf8.constData();
    source.p_url_address = nullptr;

    NDIlib_recv_create_v3_t desc;
    desc.source_to_connect_to = source;
    desc.color_format = NDIlib_recv_color_format_BGRX_BGRA;
    desc.bandwidth = NDIlib_recv_bandwidth_highest;
    desc.allow_video_fields = false;
    desc.p_ndi_recv_name = nullptr;

    m_recv = NDIlib_recv_create_v3(&desc);
    if (!m_recv) {
        setStatus(QStringLiteral("Failed to create receiver"));
        return;
    }

    m_framesync = NDIlib_framesync_create(
        static_cast<NDIlib_recv_instance_t>(m_recv));

    // The frame sync resamples the source clock; we pull at ~60 Hz which
    // matches the display. Runs on this worker thread.
    m_timer = new QTimer(this);
    m_timer->setTimerType(Qt::PreciseTimer);
    connect(m_timer, &QTimer::timeout, this, &NdiReceiveWorker::poll);
    m_timer->start(16);
}

void NdiReceiveWorker::shutdown()
{
    if (m_timer) {
        m_timer->stop();
        m_timer->deleteLater();
        m_timer = nullptr;
    }
    if (m_framesync) {
        NDIlib_framesync_destroy(
            static_cast<NDIlib_framesync_instance_t>(m_framesync));
        m_framesync = nullptr;
    }
    if (m_recv) {
        NDIlib_recv_destroy(static_cast<NDIlib_recv_instance_t>(m_recv));
        m_recv = nullptr;
    }
    m_streamInfo.clear();
}

void NdiReceiveWorker::poll()
{
    if (!m_framesync)
        return;

    NDIlib_video_frame_v2_t frame;
    NDIlib_framesync_capture_video(
        static_cast<NDIlib_framesync_instance_t>(m_framesync), &frame,
        NDIlib_frame_format_type_progressive);

    if (!frame.p_data) {
        NDIlib_framesync_free_video(
            static_cast<NDIlib_framesync_instance_t>(m_framesync), &frame);
        setStatus(QStringLiteral("Connecting…"));
        return;
    }

    // BGRA maps onto QImage ARGB32 byte-for-byte on little-endian.
    // BGRX means the alpha byte is undefined, so treat it as opaque RGB32.
    const QImage::Format format = (frame.FourCC == NDIlib_FourCC_video_type_BGRA)
        ? QImage::Format_ARGB32
        : QImage::Format_RGB32;

    const QImage wrapped(reinterpret_cast<const uchar *>(frame.p_data),
                         frame.xres, frame.yres, frame.line_stride_in_bytes,
                         format);
    emit frameReady(wrapped.copy());

    const double fps = frame.frame_rate_D
        ? double(frame.frame_rate_N) / double(frame.frame_rate_D)
        : 0.0;
    const QString info = QStringLiteral("%1×%2 @ %3 fps")
        .arg(frame.xres)
        .arg(frame.yres)
        .arg(fps, 0, 'f', 2);

    NDIlib_framesync_free_video(
        static_cast<NDIlib_framesync_instance_t>(m_framesync), &frame);

    if (info != m_streamInfo) {
        m_streamInfo = info;
        setStatus(info);
    }
}

void NdiReceiveWorker::setStatus(const QString &status)
{
    if (status == m_status)
        return;
    m_status = status;
    emit statusChanged(status);
}

// ------------------------------------------------------------------ item

NdiVideoItem::NdiVideoItem()
{
    setFlag(ItemHasContents, true);
    setAcceptedMouseButtons(Qt::LeftButton);

    m_worker = new NdiReceiveWorker;
    m_worker->moveToThread(&m_thread);
    connect(&m_thread, &QThread::finished, m_worker, &QObject::deleteLater);
    connect(m_worker, &NdiReceiveWorker::frameReady,
            this, &NdiVideoItem::onFrame, Qt::QueuedConnection);
    connect(m_worker, &NdiReceiveWorker::statusChanged,
            this, &NdiVideoItem::onStatus, Qt::QueuedConnection);
    m_thread.start();
}

NdiVideoItem::~NdiVideoItem()
{
    QMetaObject::invokeMethod(m_worker, &NdiReceiveWorker::shutdown,
                              Qt::BlockingQueuedConnection);
    m_thread.quit();
    m_thread.wait();
}

void NdiVideoItem::setSourceName(const QString &name)
{
    if (name == m_sourceName)
        return;
    m_sourceName = name;

    if (name.isEmpty()) {
        QMetaObject::invokeMethod(m_worker, &NdiReceiveWorker::shutdown);
        onStatus(QString());
    } else {
        QMetaObject::invokeMethod(
            m_worker, [worker = m_worker, name] { worker->start(name); });
    }

    // Drop the last frame of the previous source and start the view fresh.
    m_pendingFrame = QImage();
    m_frameDirty = true;
    resetView();

    emit sourceNameChanged();
}

void NdiVideoItem::resetView()
{
    m_zoom = 1.0;
    m_pan = QPointF();
    m_rotation = 0.0;
    m_crop = QRectF(0, 0, 1, 1);
    viewUpdated();
}

void NdiVideoItem::resetZoomPan()
{
    m_zoom = 1.0;
    m_pan = QPointF();
    viewUpdated();
}

void NdiVideoItem::rotateBy(qreal degrees)
{
    m_rotation = std::fmod(m_rotation + degrees, 360.0);
    viewUpdated();
}

void NdiVideoItem::applyCropFromItemRect(const QRectF &itemRect)
{
    const QRectF fit = fitRect();
    if (fit.isEmpty() || itemRect.isEmpty())
        return;

    // Item coords -> quad coords at zoom 1 (bounding box if rotated),
    // then -> normalized position inside the currently displayed region,
    // then composed with the existing crop so crops stack naturally.
    const QRectF base = viewTransform().inverted().mapRect(itemRect);
    const qreal nx = (base.x() - fit.x()) / fit.width();
    const qreal ny = (base.y() - fit.y()) / fit.height();
    const qreal nw = base.width() / fit.width();
    const qreal nh = base.height() / fit.height();

    QRectF crop(m_crop.x() + nx * m_crop.width(),
                m_crop.y() + ny * m_crop.height(),
                nw * m_crop.width(),
                nh * m_crop.height());
    crop = crop.intersected(QRectF(0, 0, 1, 1));
    if (crop.width() < kMinCropSize || crop.height() < kMinCropSize)
        return;

    m_crop = crop;
    m_zoom = 1.0;
    m_pan = QPointF();
    viewUpdated();
}

void NdiVideoItem::clearCrop()
{
    m_crop = QRectF(0, 0, 1, 1);
    m_zoom = 1.0;
    m_pan = QPointF();
    viewUpdated();
}

void NdiVideoItem::viewUpdated()
{
    emit viewChanged();
    update();
}

QRectF NdiVideoItem::fitRect() const
{
    if (m_textureSize.isEmpty())
        return QRectF(0, 0, width(), height());

    const QSizeF content(m_textureSize.width() * m_crop.width(),
                         m_textureSize.height() * m_crop.height());
    const qreal scale = qMin(width() / content.width(),
                             height() / content.height());
    const qreal w = content.width() * scale;
    const qreal h = content.height() * scale;
    return QRectF((width() - w) / 2, (height() - h) / 2, w, h);
}

QTransform NdiVideoItem::viewTransform() const
{
    // Must mirror the QMatrix4x4 built in updatePaintNode.
    const QPointF c(width() / 2, height() / 2);
    QTransform t;
    t.translate(m_pan.x() + c.x(), m_pan.y() + c.y());
    t.rotate(m_rotation);
    t.scale(m_zoom, m_zoom);
    t.translate(-c.x(), -c.y());
    return t;
}

void NdiVideoItem::setZoomAt(qreal newZoom, const QPointF &anchor)
{
    newZoom = qBound(kMinZoom, newZoom, kMaxZoom);
    if (qFuzzyCompare(newZoom, m_zoom))
        return;

    // Keep the content point under the cursor fixed while zooming.
    const QPointF base = viewTransform().inverted().map(anchor);
    m_zoom = newZoom;

    const QPointF c(width() / 2, height() / 2);
    QTransform noPan;
    noPan.translate(c.x(), c.y());
    noPan.rotate(m_rotation);
    noPan.scale(m_zoom, m_zoom);
    noPan.translate(-c.x(), -c.y());
    m_pan = anchor - noPan.map(base);
}

void NdiVideoItem::wheelEvent(QWheelEvent *event)
{
    const qreal notches = event->angleDelta().y() / 120.0;
    if (notches == 0.0)
        return;

    if (event->modifiers() & Qt::ControlModifier)
        m_rotation = std::fmod(m_rotation + notches * kRotateStepDeg, 360.0);
    else
        setZoomAt(m_zoom * std::pow(kZoomStepFactor, notches),
                  event->position());

    viewUpdated();
    event->accept();
}

void NdiVideoItem::mousePressEvent(QMouseEvent *event)
{
    m_panning = true;
    m_lastMousePos = event->position();
    setCursor(Qt::ClosedHandCursor);
    event->accept();
}

void NdiVideoItem::mouseMoveEvent(QMouseEvent *event)
{
    if (!m_panning)
        return;
    m_pan += event->position() - m_lastMousePos;
    m_lastMousePos = event->position();
    viewUpdated();
}

void NdiVideoItem::mouseReleaseEvent(QMouseEvent *event)
{
    m_panning = false;
    unsetCursor();
    event->accept();
}

void NdiVideoItem::mouseDoubleClickEvent(QMouseEvent *event)
{
    resetZoomPan();
    event->accept();
}

void NdiVideoItem::geometryChange(const QRectF &newGeometry,
                                  const QRectF &oldGeometry)
{
    QQuickItem::geometryChange(newGeometry, oldGeometry);
    update();
}

void NdiVideoItem::onFrame(const QImage &frame)
{
    m_pendingFrame = frame;
    m_frameDirty = true;
    update();
}

void NdiVideoItem::onStatus(const QString &status)
{
    if (status == m_status)
        return;
    m_status = status;
    emit statusChanged();
}

QSGNode *NdiVideoItem::updatePaintNode(QSGNode *oldNode, UpdatePaintNodeData *)
{
    auto *root = static_cast<QSGTransformNode *>(oldNode);
    auto *texNode = root
        ? static_cast<QSGSimpleTextureNode *>(root->firstChild())
        : nullptr;

    if (m_frameDirty) {
        m_frameDirty = false;
        if (m_pendingFrame.isNull()) {
            delete root;
            return nullptr;
        }
        if (!root) {
            root = new QSGTransformNode;
            texNode = new QSGSimpleTextureNode;
            texNode->setOwnsTexture(true);
            texNode->setFiltering(QSGTexture::Linear);
            root->appendChildNode(texNode);
        }
        texNode->setTexture(window()->createTextureFromImage(m_pendingFrame));
        m_textureSize = m_pendingFrame.size();
    }

    if (!root || m_textureSize.isEmpty())
        return root;

    // Crop = UV window into the texture (source rect is in texture pixels).
    texNode->setSourceRect(QRectF(m_crop.x() * m_textureSize.width(),
                                  m_crop.y() * m_textureSize.height(),
                                  m_crop.width() * m_textureSize.width(),
                                  m_crop.height() * m_textureSize.height()));
    texNode->setRect(fitRect());

    // Zoom/pan/rotate = one matrix on the quad; the GPU does the rest.
    const QPointF c(width() / 2, height() / 2);
    QMatrix4x4 m;
    m.translate(float(m_pan.x() + c.x()), float(m_pan.y() + c.y()));
    m.rotate(float(m_rotation), 0, 0, 1);
    m.scale(float(m_zoom));
    m.translate(float(-c.x()), float(-c.y()));
    root->setMatrix(m);

    return root;
}

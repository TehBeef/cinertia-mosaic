#include "NdiVideoItem.h"

#include <QQuickWindow>
#include <QSGSimpleTextureNode>
#include <QTimer>

#include <Processing.NDI.Lib.h>

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

    // Drop the last frame of the previous source.
    m_pendingFrame = QImage();
    m_frameDirty = true;
    update();

    emit sourceNameChanged();
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
    auto *node = static_cast<QSGSimpleTextureNode *>(oldNode);

    if (m_frameDirty) {
        m_frameDirty = false;
        if (m_pendingFrame.isNull()) {
            delete node;
            return nullptr;
        }
        if (!node) {
            node = new QSGSimpleTextureNode;
            node->setOwnsTexture(true);
            node->setFiltering(QSGTexture::Linear);
        }
        node->setTexture(window()->createTextureFromImage(m_pendingFrame));
        m_textureSize = m_pendingFrame.size();
    }

    if (!node)
        return nullptr;

    // Letterbox: largest rect with the video's aspect ratio that fits us.
    QRectF fit(0, 0, width(), height());
    if (!m_textureSize.isEmpty()) {
        const qreal scale = qMin(width() / m_textureSize.width(),
                                 height() / m_textureSize.height());
        const qreal w = m_textureSize.width() * scale;
        const qreal h = m_textureSize.height() * scale;
        fit = QRectF((width() - w) / 2, (height() - h) / 2, w, h);
    }
    node->setRect(fit);

    return node;
}

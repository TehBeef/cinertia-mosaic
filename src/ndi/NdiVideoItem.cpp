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

void NdiReceiveWorker::start(const QString &sourceName, bool lowBandwidth,
                             bool lowLatency)
{
    shutdown();

    m_lowLatency = lowLatency;
    setStatus(QStringLiteral("Connecting…"));

    const QByteArray nameUtf8 = sourceName.toUtf8();
    NDIlib_source_t source;
    source.p_ndi_name = nameUtf8.constData();
    source.p_url_address = nullptr;

    NDIlib_recv_create_v3_t desc;
    desc.source_to_connect_to = source;
    desc.color_format = NDIlib_recv_color_format_BGRX_BGRA;
    desc.bandwidth = lowBandwidth ? NDIlib_recv_bandwidth_lowest
                                  : NDIlib_recv_bandwidth_highest;
    desc.allow_video_fields = false;
    desc.p_ndi_recv_name = nullptr;

    m_recv = NDIlib_recv_create_v3(&desc);
    if (!m_recv) {
        setStatus(QStringLiteral("Failed to create receiver"));
        return;
    }

    // Normal mode: frame sync resamples the source clock for smooth
    // timing, polled at ~60 Hz. Low latency: no frame sync — poll the
    // receiver directly every 2 ms and show frames the moment they land.
    if (!m_lowLatency) {
        m_framesync = NDIlib_framesync_create(
            static_cast<NDIlib_recv_instance_t>(m_recv));
    }

    m_timer = new QTimer(this);
    m_timer->setTimerType(Qt::PreciseTimer);
    connect(m_timer, &QTimer::timeout, this, &NdiReceiveWorker::poll);
    m_timer->start(m_lowLatency ? 2 : 16);
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
    m_lastTimestamp = 0;
    m_levelLeft = 0.0f;
    m_levelRight = 0.0f;
}

void NdiReceiveWorker::setCaptureAudio(bool enabled)
{
    m_captureAudio = enabled;
    if (!enabled) {
        m_levelLeft = 0.0f;
        m_levelRight = 0.0f;
    }
}

void NdiReceiveWorker::poll()
{
    if (m_lowLatency) {
        pollDirect();
        return;
    }

    if (!m_framesync)
        return;

    if (m_captureAudio)
        pollAudio();

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

    // The frame sync always returns the LATEST frame — polled at 60 Hz,
    // that's the same frame again for any source below 60 fps (and forever
    // for a static picture). Repeats are skipped before the copy and the
    // GPU upload, which is where nearly all the per-tile CPU goes.
    if (frame.timestamp != 0 && frame.timestamp != INT64_MAX
            && frame.timestamp == m_lastTimestamp) {
        NDIlib_framesync_free_video(
            static_cast<NDIlib_framesync_instance_t>(m_framesync), &frame);
        return;
    }
    m_lastTimestamp = frame.timestamp;

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

void NdiReceiveWorker::pollDirect()
{
    if (!m_recv)
        return;

    const auto recv = static_cast<NDIlib_recv_instance_t>(m_recv);

    // Drain whatever arrived since the last tick (a few frames at most).
    for (int i = 0; i < 4; ++i) {
        NDIlib_video_frame_v2_t video;
        NDIlib_audio_frame_v3_t audio;
        const NDIlib_frame_type_e type = NDIlib_recv_capture_v3(
            recv, &video, m_captureAudio ? &audio : nullptr, nullptr, 0);

        if (type == NDIlib_frame_type_video) {
            const QImage::Format format =
                (video.FourCC == NDIlib_FourCC_video_type_BGRA)
                    ? QImage::Format_ARGB32
                    : QImage::Format_RGB32;
            const QImage wrapped(
                reinterpret_cast<const uchar *>(video.p_data),
                video.xres, video.yres, video.line_stride_in_bytes, format);
            emit frameReady(wrapped.copy());

            const double fps = video.frame_rate_D
                ? double(video.frame_rate_N) / double(video.frame_rate_D)
                : 0.0;
            const QString info = QStringLiteral("%1×%2 @ %3 fps · low latency")
                .arg(video.xres)
                .arg(video.yres)
                .arg(fps, 0, 'f', 2);
            NDIlib_recv_free_video_v2(recv, &video);
            if (info != m_streamInfo) {
                m_streamInfo = info;
                setStatus(info);
            }
        } else if (type == NDIlib_frame_type_audio) {
            float peakL = 0.0f;
            float peakR = 0.0f;
            if (audio.p_data && audio.no_samples > 0) {
                const int channels = qMin(2, audio.no_channels);
                for (int c = 0; c < channels; ++c) {
                    const float *samples = reinterpret_cast<const float *>(
                        reinterpret_cast<const quint8 *>(audio.p_data)
                        + c * audio.channel_stride_in_bytes);
                    float peak = 0.0f;
                    for (int s = 0; s < audio.no_samples; ++s)
                        peak = qMax(peak, qAbs(samples[s]));
                    if (c == 0)
                        peakL = peak;
                    else
                        peakR = peak;
                }
                if (channels == 1)
                    peakR = peakL;
            }
            NDIlib_recv_free_audio_v3(recv, &audio);
            updateLevels(peakL, peakR);
        } else {
            break; // nothing waiting
        }
    }
}

void NdiReceiveWorker::pollAudio()
{
    // Pull ~one tick of audio; the frame sync resamples for us. Peak per
    // channel is mapped to 0..1 over a -60..0 dBFS range with a decay so
    // the meter falls smoothly.
    NDIlib_audio_frame_v2_t frame;
    NDIlib_framesync_capture_audio(
        static_cast<NDIlib_framesync_instance_t>(m_framesync), &frame,
        48000, 2, 800);

    float peakL = 0.0f;
    float peakR = 0.0f;
    if (frame.p_data && frame.no_samples > 0) {
        const int channels = qMin(2, frame.no_channels);
        for (int c = 0; c < channels; ++c) {
            const float *samples = reinterpret_cast<const float *>(
                reinterpret_cast<const quint8 *>(frame.p_data)
                + c * frame.channel_stride_in_bytes);
            float peak = 0.0f;
            for (int i = 0; i < frame.no_samples; ++i)
                peak = qMax(peak, qAbs(samples[i]));
            if (c == 0)
                peakL = peak;
            else
                peakR = peak;
        }
        if (channels == 1)
            peakR = peakL;
    }
    NDIlib_framesync_free_audio(
        static_cast<NDIlib_framesync_instance_t>(m_framesync), &frame);

    updateLevels(peakL, peakR);
}

void NdiReceiveWorker::updateLevels(float peakL, float peakR)
{
    const auto toNorm = [](float peak) -> float {
        if (peak <= 0.001f)
            return 0.0f;
        const double db = 20.0 * std::log10(double(peak));
        return float(qBound(0.0, 1.0 + db / 60.0, 1.0));
    };
    m_levelLeft = qMax(toNorm(peakL), m_levelLeft * 0.85f);
    m_levelRight = qMax(toNorm(peakR), m_levelRight * 0.85f);
    emit audioLevels(m_levelLeft, m_levelRight);
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
    connect(m_worker, &NdiReceiveWorker::audioLevels,
            this, &NdiVideoItem::onAudioLevels, Qt::QueuedConnection);
    m_thread.start();

    // Auto low bandwidth reacts to size changes only after they settle,
    // so dragging a resize never causes a burst of reconnects.
    m_autoSizeTimer = new QTimer(this);
    m_autoSizeTimer->setSingleShot(true);
    m_autoSizeTimer->setInterval(1500);
    connect(m_autoSizeTimer, &QTimer::timeout,
            this, &NdiVideoItem::evaluateAutoLow);
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
        updateConnection(true);
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

QVariantMap NdiVideoItem::viewState() const
{
    return {
        { QStringLiteral("zoom"), m_zoom },
        { QStringLiteral("panX"), m_pan.x() },
        { QStringLiteral("panY"), m_pan.y() },
        { QStringLiteral("rotation"), m_rotation },
        { QStringLiteral("cropX"), m_crop.x() },
        { QStringLiteral("cropY"), m_crop.y() },
        { QStringLiteral("cropW"), m_crop.width() },
        { QStringLiteral("cropH"), m_crop.height() },
    };
}

void NdiVideoItem::setViewState(const QVariantMap &state)
{
    m_zoom = qBound(kMinZoom, state.value(QStringLiteral("zoom"), 1.0).toReal(),
                    kMaxZoom);
    m_pan = QPointF(state.value(QStringLiteral("panX"), 0.0).toReal(),
                    state.value(QStringLiteral("panY"), 0.0).toReal());
    m_rotation = state.value(QStringLiteral("rotation"), 0.0).toReal();

    QRectF crop(state.value(QStringLiteral("cropX"), 0.0).toReal(),
                state.value(QStringLiteral("cropY"), 0.0).toReal(),
                state.value(QStringLiteral("cropW"), 1.0).toReal(),
                state.value(QStringLiteral("cropH"), 1.0).toReal());
    crop = crop.intersected(QRectF(0, 0, 1, 1));
    m_crop = (crop.width() < kMinCropSize || crop.height() < kMinCropSize)
        ? QRectF(0, 0, 1, 1)
        : crop;

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
    // Some platforms report the wheel on the other axis while Alt is held.
    const QPoint delta = event->angleDelta();
    const qreal notches = (delta.y() != 0 ? delta.y() : delta.x()) / 120.0;
    if (notches == 0.0)
        return;

    // Alt+scroll rotates (Ctrl is reserved for snapping on the canvas, and
    // trackpad pinch arrives as Ctrl+scroll — that must zoom).
    if (m_wheelRotateEnabled && (event->modifiers() & Qt::AltModifier))
        m_rotation = std::fmod(m_rotation + notches * kRotateStepDeg, 360.0);
    else
        setZoomAt(m_zoom * std::pow(kZoomStepFactor, notches),
                  event->position());

    viewUpdated();
    event->accept();
}

void NdiVideoItem::setWheelRotateEnabled(bool enabled)
{
    if (enabled == m_wheelRotateEnabled)
        return;
    m_wheelRotateEnabled = enabled;
    emit wheelRotateEnabledChanged();
}

// Bandwidth and latency are receiver creation parameters — applying them
// means reconnecting. Only reconnect when the effective result changes.
void NdiVideoItem::updateConnection(bool force)
{
    if (m_sourceName.isEmpty())
        return;
    const bool low = m_lowBandwidth || (m_autoLowBandwidth && m_autoEngaged);
    if (!force && low == m_appliedLow && m_lowLatency == m_appliedLat)
        return;
    m_appliedLow = low;
    m_appliedLat = m_lowLatency;
    QMetaObject::invokeMethod(
        m_worker, [worker = m_worker, name = m_sourceName, low,
                   lat = m_lowLatency] {
            worker->start(name, low, lat);
        });
}

// The NDI proxy stream is ~640 px wide: an item rendered at or below that
// loses nothing by switching to it. Hysteresis (600 on / 720 off) keeps a
// tile hovering near the threshold from flapping between streams.
void NdiVideoItem::evaluateAutoLow()
{
    if (!m_autoLowBandwidth) {
        m_autoEngaged = false;
        updateConnection(false);
        return;
    }
    const qreal w = width();
    if (w <= 0)
        return;
    if (!m_autoEngaged && w < 600)
        m_autoEngaged = true;
    else if (m_autoEngaged && w > 720)
        m_autoEngaged = false;
    updateConnection(false);
}

void NdiVideoItem::setAutoLowBandwidth(bool enabled)
{
    if (enabled == m_autoLowBandwidth)
        return;
    m_autoLowBandwidth = enabled;
    emit autoLowBandwidthChanged();
    evaluateAutoLow();
}

void NdiVideoItem::setLowBandwidth(bool enabled)
{
    if (enabled == m_lowBandwidth)
        return;
    m_lowBandwidth = enabled;
    emit lowBandwidthChanged();
    updateConnection(false);
}

void NdiVideoItem::setLowLatency(bool enabled)
{
    if (enabled == m_lowLatency)
        return;
    m_lowLatency = enabled;
    emit lowLatencyChanged();
    updateConnection(false);
}

void NdiVideoItem::setMeterEnabled(bool enabled)
{
    if (enabled == m_meterEnabled)
        return;
    m_meterEnabled = enabled;
    emit meterEnabledChanged();
    QMetaObject::invokeMethod(
        m_worker, [worker = m_worker, enabled] {
            worker->setCaptureAudio(enabled);
        });
    if (!enabled) {
        m_audioLeft = 0.0;
        m_audioRight = 0.0;
        emit audioLevelsChanged();
    }
}

void NdiVideoItem::onAudioLevels(qreal left, qreal right)
{
    m_audioLeft = left;
    m_audioRight = right;
    emit audioLevelsChanged();
}

void NdiVideoItem::mousePressEvent(QMouseEvent *event)
{
    emit interacted();
    // Shift+drag repositions the picture inside its tile at any zoom.
    // Without Shift, a drag at fit zoom has nothing to pan — let the press
    // fall through so the tile underneath can use the drag to move itself.
    const bool shiftPan = event->modifiers() & Qt::ShiftModifier;
    if (m_zoom <= 1.001 && !shiftPan) {
        event->ignore();
        return;
    }
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
    if (m_autoLowBandwidth && newGeometry.size() != oldGeometry.size())
        m_autoSizeTimer->start(); // (re)evaluate once the resize settles
    update();
}

void NdiVideoItem::onFrame(const QImage &frame)
{
    m_pendingFrame = frame;
    m_frameDirty = true;
    if (frame.size() != m_videoSize) {
        m_videoSize = frame.size();
        emit videoSizeChanged();
    }
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

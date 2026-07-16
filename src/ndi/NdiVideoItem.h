#pragma once

#include <QElapsedTimer>
#include <QImage>
#include <QPointF>
#include <QQuickItem>
#include <QRectF>
#include <QThread>
#include <QtQml/qqmlregistration.h>

class QTimer;

// Runs on its own thread. Owns the NDI receiver and frame sync for one
// source, pulls video frames at display rate, and hands them to the GUI
// thread as QImages (implicitly shared, so cross-thread handoff is cheap).
class NdiReceiveWorker : public QObject
{
    Q_OBJECT

public slots:
    void start(const QString &sourceName, bool lowBandwidth, bool lowLatency);
    void shutdown();
    void setCaptureAudio(bool enabled);

signals:
    // uyvyWidth > 0: `frame` carries packed UYVY bytes as an RGBA image of
    // width/2 (converted to RGB on the GPU); 0: a regular BGRA image.
    void frameReady(const QImage &frame, int uyvyWidth);
    void statusChanged(const QString &status);
    // 0 = healthy (connected to a sender), 2 = down (no connection, or
    // nothing received yet). Tied to the connection, not picture motion, so
    // a static source stays healthy. (1 = stalling is no longer emitted.)
    void healthChanged(int health);
    void audioLevels(qreal left, qreal right);

private:
    void poll();
    void pollDirect(); // low-latency path: no frame sync buffering
    void updateHealth();
    void pollAudio();
    void updateLevels(float peakL, float peakR);
    void setStatus(const QString &status);

    void *m_recv = nullptr;      // NDIlib_recv_instance_t
    void *m_framesync = nullptr; // NDIlib_framesync_instance_t
    QTimer *m_timer = nullptr;
    // Timestamp of the last frame handed to the GUI: the frame sync is
    // polled faster than most sources produce frames, so repeats are
    // detected here and never copied or uploaded again.
    qint64 m_lastTimestamp = 0;
    // Stream health bookkeeping (see healthChanged).
    QElapsedTimer m_aliveClock;
    qint64 m_lastFrameMs = 0;     // 0 = nothing received yet
    qint64 m_lastConnCheckMs = -10000;
    int m_connections = 0;
    int m_health = -1;
    QString m_status;
    QString m_streamInfo;
    bool m_captureAudio = false;
    bool m_lowLatency = false;
    float m_levelLeft = 0.0f;
    float m_levelRight = 0.0f;
};

// QML type "VideoView": displays one NDI source with GPU view transforms.
// The frame lives in a texture; zoom/pan/rotate only change the transform
// matrix on the quad, and crop only changes the texture source rect (UV
// window) — nothing is re-decoded or re-uploaded for a view change.
//
// Interactions handled here: scroll = zoom at cursor, drag = pan,
// Ctrl+scroll = fine rotate, double-click = reset zoom/pan.
class NdiVideoItem : public QQuickItem
{
    Q_OBJECT
    QML_NAMED_ELEMENT(VideoView)
    Q_PROPERTY(QString sourceName READ sourceName WRITE setSourceName NOTIFY sourceNameChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QSize videoSize READ videoSize NOTIFY videoSizeChanged)
    Q_PROPERTY(qreal zoomLevel READ zoomLevel NOTIFY viewChanged)
    // Stream health for the tile's status indicator: 0 = healthy
    // (connected), 2 = down (no connection / still connecting). Based on the
    // NDI connection, so a static picture stays healthy.
    Q_PROPERTY(int health READ health NOTIFY healthChanged)
    Q_PROPERTY(qreal viewRotation READ viewRotation NOTIFY viewChanged)
    Q_PROPERTY(bool cropped READ cropped NOTIFY viewChanged)
    // Alt+scroll rotation. On by default; the future settings menu gets a
    // toggle. Ctrl is reserved for canvas snapping per Max's request.
    Q_PROPERTY(bool wheelRotateEnabled READ wheelRotateEnabled WRITE setWheelRotateEnabled NOTIFY wheelRotateEnabledChanged)
    // Low-bandwidth (proxy) receive for tiles rendered small.
    Q_PROPERTY(bool lowBandwidth READ lowBandwidth WRITE setLowBandwidth NOTIFY lowBandwidthChanged)
    // Automatic proxy for small tiles: when enabled and the item is
    // rendered at/below proxy resolution, the receiver switches to the
    // low-bandwidth stream by itself (manual lowBandwidth still forces it).
    Q_PROPERTY(bool autoLowBandwidth READ autoLowBandwidth WRITE setAutoLowBandwidth NOTIFY autoLowBandwidthChanged)
    // Low latency: bypass the frame sync and show frames as they arrive
    // (slightly less smooth, roughly a frame less delay).
    Q_PROPERTY(bool lowLatency READ lowLatency WRITE setLowLatency NOTIFY lowLatencyChanged)
    // Audio metering: only captures audio while a meter is shown.
    Q_PROPERTY(bool meterEnabled READ meterEnabled WRITE setMeterEnabled NOTIFY meterEnabledChanged)
    Q_PROPERTY(qreal audioLeft READ audioLeft NOTIFY audioLevelsChanged)
    Q_PROPERTY(qreal audioRight READ audioRight NOTIFY audioLevelsChanged)

public:
    NdiVideoItem();
    ~NdiVideoItem() override;

    QString sourceName() const { return m_sourceName; }
    void setSourceName(const QString &name);
    QString status() const { return m_status; }
    int health() const { return m_health; }
    QSize videoSize() const { return m_videoSize; }
    qreal zoomLevel() const { return m_zoom; }
    qreal viewRotation() const { return m_rotation; }
    bool cropped() const { return m_crop != QRectF(0, 0, 1, 1); }
    bool wheelRotateEnabled() const { return m_wheelRotateEnabled; }
    void setWheelRotateEnabled(bool enabled);
    bool lowBandwidth() const { return m_lowBandwidth; }
    void setLowBandwidth(bool enabled);
    bool autoLowBandwidth() const { return m_autoLowBandwidth; }
    void setAutoLowBandwidth(bool enabled);
    bool lowLatency() const { return m_lowLatency; }
    void setLowLatency(bool enabled);
    bool meterEnabled() const { return m_meterEnabled; }
    void setMeterEnabled(bool enabled);
    qreal audioLeft() const { return m_audioLeft; }
    qreal audioRight() const { return m_audioRight; }

    // Zoom 1 always means "the picture, at its current rotation, fits the
    // tile" (see rotationFitScale), so Fit and double-click are both just
    // a zoom/pan reset.
    Q_INVOKABLE void resetView();    // zoom, pan, rotation and crop
    Q_INVOKABLE void resetZoomPan(); // Fit / double-click: keep rotation/crop
    Q_INVOKABLE void rotateBy(qreal degrees);
    Q_INVOKABLE void applyCropFromItemRect(const QRectF &itemRect);
    Q_INVOKABLE void clearCrop();

    // Snapshot/restore of the whole view for profiles and session restore.
    Q_INVOKABLE QVariantMap viewState() const;
    Q_INVOKABLE void setViewState(const QVariantMap &state);

signals:
    void sourceNameChanged();
    void statusChanged();
    void healthChanged();
    void viewChanged();
    void wheelRotateEnabledChanged();
    void videoSizeChanged();
    void lowBandwidthChanged();
    void autoLowBandwidthChanged();
    void lowLatencyChanged();
    void meterEnabledChanged();
    void audioLevelsChanged();
    void interacted(); // any click/scroll on the video — used to select tiles

protected:
    QSGNode *updatePaintNode(QSGNode *oldNode, UpdatePaintNodeData *) override;
    void wheelEvent(QWheelEvent *event) override;
    void mousePressEvent(QMouseEvent *event) override;
    void mouseMoveEvent(QMouseEvent *event) override;
    void mouseReleaseEvent(QMouseEvent *event) override;
    void mouseDoubleClickEvent(QMouseEvent *event) override;
    void geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry) override;

private:
    void onFrame(const QImage &frame, int uyvyWidth);
    void onStatus(const QString &status);
    void onHealth(int health);
    void onAudioLevels(qreal left, qreal right);
    QRectF fitRect() const;          // letterboxed quad, unrotated
    qreal rotationFitScale() const;  // rescales the rotated quad to fit
    QTransform viewTransform() const;
    void setZoomAt(qreal newZoom, const QPointF &anchor);
    void viewUpdated();
    // Effective connection = manual low-bandwidth OR auto-engaged proxy.
    // (Re)connects the receiver only when the result actually changes.
    void updateConnection(bool force);
    void evaluateAutoLow();

    QThread m_thread;
    NdiReceiveWorker *m_worker = nullptr;
    QString m_sourceName;
    QString m_status;
    int m_health = 2; // down until the first frame arrives
    QImage m_pendingFrame;
    int m_pendingUyvyWidth = 0;  // 0 = BGRA frame
    bool m_nodeIsUyvy = false;   // which node type the scene graph holds
    bool m_frameDirty = false;
    QSize m_textureSize;
    QSize m_videoSize;

    qreal m_zoom = 1.0;
    QPointF m_pan;
    qreal m_rotation = 0.0;
    QRectF m_crop{0, 0, 1, 1}; // normalized UV window into the frame
    QPointF m_lastMousePos;
    bool m_panning = false;
    bool m_wheelRotateEnabled = true;
    bool m_lowBandwidth = false;
    bool m_autoLowBandwidth = false;
    // True while the auto mode has the proxy stream engaged (hysteresis:
    // engages below 600 px, disengages above 720 px).
    bool m_autoEngaged = false;
    // Connection parameters last sent to the worker, so toggles that
    // don't change the effective result never cause a reconnect.
    bool m_appliedLow = false;
    bool m_appliedLat = false;
    // Debounces size changes: resizing evaluates 1.5 s after it settles.
    QTimer *m_autoSizeTimer = nullptr;
    bool m_lowLatency = false;
    bool m_meterEnabled = false;
    qreal m_audioLeft = 0.0;
    qreal m_audioRight = 0.0;
};

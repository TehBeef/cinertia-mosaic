#pragma once

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
    void start(const QString &sourceName);
    void shutdown();

signals:
    void frameReady(const QImage &frame);
    void statusChanged(const QString &status);

private:
    void poll();
    void setStatus(const QString &status);

    void *m_recv = nullptr;      // NDIlib_recv_instance_t
    void *m_framesync = nullptr; // NDIlib_framesync_instance_t
    QTimer *m_timer = nullptr;
    QString m_status;
    QString m_streamInfo;
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
    Q_PROPERTY(qreal zoomLevel READ zoomLevel NOTIFY viewChanged)
    Q_PROPERTY(qreal viewRotation READ viewRotation NOTIFY viewChanged)
    Q_PROPERTY(bool cropped READ cropped NOTIFY viewChanged)
    // Alt+scroll rotation. On by default; the future settings menu gets a
    // toggle. Ctrl is reserved for canvas snapping per Max's request.
    Q_PROPERTY(bool wheelRotateEnabled READ wheelRotateEnabled WRITE setWheelRotateEnabled NOTIFY wheelRotateEnabledChanged)

public:
    NdiVideoItem();
    ~NdiVideoItem() override;

    QString sourceName() const { return m_sourceName; }
    void setSourceName(const QString &name);
    QString status() const { return m_status; }
    qreal zoomLevel() const { return m_zoom; }
    qreal viewRotation() const { return m_rotation; }
    bool cropped() const { return m_crop != QRectF(0, 0, 1, 1); }
    bool wheelRotateEnabled() const { return m_wheelRotateEnabled; }
    void setWheelRotateEnabled(bool enabled);

    Q_INVOKABLE void resetView();    // zoom, pan, rotation and crop
    Q_INVOKABLE void resetZoomPan(); // double-click: keep rotation/crop
    Q_INVOKABLE void rotateBy(qreal degrees);
    Q_INVOKABLE void applyCropFromItemRect(const QRectF &itemRect);
    Q_INVOKABLE void clearCrop();

signals:
    void sourceNameChanged();
    void statusChanged();
    void viewChanged();
    void wheelRotateEnabledChanged();
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
    void onFrame(const QImage &frame);
    void onStatus(const QString &status);
    QRectF fitRect() const;          // letterboxed quad at zoom 1
    QTransform viewTransform() const;
    void setZoomAt(qreal newZoom, const QPointF &anchor);
    void viewUpdated();

    QThread m_thread;
    NdiReceiveWorker *m_worker = nullptr;
    QString m_sourceName;
    QString m_status;
    QImage m_pendingFrame;
    bool m_frameDirty = false;
    QSize m_textureSize;

    qreal m_zoom = 1.0;
    QPointF m_pan;
    qreal m_rotation = 0.0;
    QRectF m_crop{0, 0, 1, 1}; // normalized UV window into the frame
    QPointF m_lastMousePos;
    bool m_panning = false;
    bool m_wheelRotateEnabled = true;
};

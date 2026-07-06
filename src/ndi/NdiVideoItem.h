#pragma once

#include <QImage>
#include <QQuickItem>
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

// QML type "VideoView": displays one NDI source, letterboxed to keep the
// correct aspect ratio. Set sourceName to connect; clear it to disconnect.
class NdiVideoItem : public QQuickItem
{
    Q_OBJECT
    QML_NAMED_ELEMENT(VideoView)
    Q_PROPERTY(QString sourceName READ sourceName WRITE setSourceName NOTIFY sourceNameChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)

public:
    NdiVideoItem();
    ~NdiVideoItem() override;

    QString sourceName() const { return m_sourceName; }
    void setSourceName(const QString &name);
    QString status() const { return m_status; }

signals:
    void sourceNameChanged();
    void statusChanged();

protected:
    QSGNode *updatePaintNode(QSGNode *oldNode, UpdatePaintNodeData *) override;

private:
    void onFrame(const QImage &frame);
    void onStatus(const QString &status);

    QThread m_thread;
    NdiReceiveWorker *m_worker = nullptr;
    QString m_sourceName;
    QString m_status;
    QImage m_pendingFrame;
    bool m_frameDirty = false;
    QSize m_textureSize;
};

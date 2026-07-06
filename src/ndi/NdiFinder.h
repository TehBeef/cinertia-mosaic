#pragma once

#include <QObject>
#include <QStringList>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

// Discovers NDI sources on the network and exposes them to QML as a
// string list. Polling NDIlib_find_get_current_sources is non-blocking,
// so this can safely live on the GUI thread.
class NdiFinder : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QStringList sources READ sources NOTIFY sourcesChanged)

public:
    explicit NdiFinder(QObject *parent = nullptr);
    ~NdiFinder() override;

    QStringList sources() const { return m_sources; }

signals:
    void sourcesChanged();

private:
    void poll();

    void *m_finder = nullptr; // NDIlib_find_instance_t
    QTimer m_timer;
    QStringList m_sources;
};

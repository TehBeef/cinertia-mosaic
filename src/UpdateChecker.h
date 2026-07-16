#pragma once

#include <QObject>
#include <QString>
#include <QtQml/qqmlregistration.h>

class QNetworkAccessManager;

// Checks GitHub for a newer release and reports it — nothing more. The
// check is a single small request to the releases API, runs once shortly
// after startup (when enabled in settings), and fails silently: show
// machines are often offline and an update must never interrupt anything.
// Installing stays a deliberate, manual act via the releases page.
class UpdateChecker : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool updateAvailable READ updateAvailable NOTIFY resultChanged)
    Q_PROPERTY(QString latestVersion READ latestVersion NOTIFY resultChanged)
    Q_PROPERTY(QString releaseUrl READ releaseUrl NOTIFY resultChanged)

public:
    explicit UpdateChecker(QObject *parent = nullptr);

    bool updateAvailable() const { return m_updateAvailable; }
    QString latestVersion() const { return m_latestVersion; }
    QString releaseUrl() const { return m_releaseUrl; }

    Q_INVOKABLE void check();

signals:
    void resultChanged();

private:
    void handleReply(const QByteArray &body);
    static bool isNewer(const QString &remote, const QString &local);

    QNetworkAccessManager *m_net = nullptr;
    bool m_checked = false;
    bool m_updateAvailable = false;
    QString m_latestVersion;
    QString m_releaseUrl;
};

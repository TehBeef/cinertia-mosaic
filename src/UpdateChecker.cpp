#include "UpdateChecker.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>
#include <QVersionNumber>

namespace {
const QUrl kLatestReleaseUrl(QStringLiteral(
    "https://api.github.com/repos/MaxDeRoin/cinertia-mosaic/releases/latest"));
}

UpdateChecker::UpdateChecker(QObject *parent)
    : QObject(parent)
{
}

void UpdateChecker::check()
{
    if (m_checked) // one check per run is plenty
        return;
    m_checked = true;

    if (!m_net) {
        m_net = new QNetworkAccessManager(this);
        m_net->setTransferTimeout(10000);
    }

    QNetworkRequest req(kLatestReleaseUrl);
    // GitHub's API rejects requests without a User-Agent.
    req.setHeader(QNetworkRequest::UserAgentHeader,
                  QStringLiteral("Mosaic/") + QStringLiteral(MOSAIC_VERSION));
    req.setRawHeader("Accept", "application/vnd.github+json");

    QNetworkReply *reply = m_net->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        if (reply->error() == QNetworkReply::NoError)
            handleReply(reply->readAll());
        reply->deleteLater(); // errors (offline, rate limit) stay silent
    });
}

void UpdateChecker::handleReply(const QByteArray &body)
{
    const QJsonObject release = QJsonDocument::fromJson(body).object();

    // tag_name is "v0.6.5"; html_url is the human release page. Only ever
    // send the user to the repo's own releases — ignore anything else.
    QString tag = release.value(QStringLiteral("tag_name")).toString();
    if (tag.startsWith(QLatin1Char('v')))
        tag.remove(0, 1);
    const QString url = release.value(QStringLiteral("html_url")).toString();
    if (tag.isEmpty()
        || !url.startsWith(
            QStringLiteral("https://github.com/MaxDeRoin/cinertia-mosaic/")))
        return;

    if (isNewer(tag, QStringLiteral(MOSAIC_VERSION))) {
        m_updateAvailable = true;
        m_latestVersion = tag;
        m_releaseUrl = url;
        emit resultChanged();
    }
}

bool UpdateChecker::isNewer(const QString &remote, const QString &local)
{
    const QVersionNumber r = QVersionNumber::fromString(remote);
    const QVersionNumber l = QVersionNumber::fromString(local);
    return !r.isNull() && !l.isNull() && r > l;
}

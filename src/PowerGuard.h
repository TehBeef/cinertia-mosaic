#pragma once

#include <QObject>
#include <QtQml/qqmlregistration.h>

// Keeps the display (and system) awake while enabled — multiviewers run
// unattended on show days and the monitor must not blank. Platform code
// is isolated in the .cpp; on non-Windows this is currently a no-op.
class PowerGuard : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool keepAwake READ keepAwake WRITE setKeepAwake NOTIFY keepAwakeChanged)

public:
    explicit PowerGuard(QObject *parent = nullptr);
    ~PowerGuard() override;

    bool keepAwake() const { return m_keepAwake; }
    void setKeepAwake(bool enabled);

signals:
    void keepAwakeChanged();

private:
    void apply();

    bool m_keepAwake = false;
#ifdef Q_OS_MACOS
    // Holds the active IOKit power assertion (IOPMAssertionID) while awake;
    // 0 means none. Kept as a plain int so the header needs no IOKit include.
    unsigned int m_assertionId = 0;
#endif
};

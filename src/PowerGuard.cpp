#include "PowerGuard.h"

#ifdef Q_OS_WIN
#include <windows.h>
#endif

#ifdef Q_OS_MACOS
#include <IOKit/pwr_mgt/IOPMLib.h>
#endif

PowerGuard::PowerGuard(QObject *parent)
    : QObject(parent)
{
}

PowerGuard::~PowerGuard()
{
    if (m_keepAwake) {
        m_keepAwake = false;
        apply();
    }
}

void PowerGuard::setKeepAwake(bool enabled)
{
    if (enabled == m_keepAwake)
        return;
    m_keepAwake = enabled;
    apply();
    emit keepAwakeChanged();
}

void PowerGuard::apply()
{
#ifdef Q_OS_WIN
    if (m_keepAwake) {
        SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED
                                | ES_DISPLAY_REQUIRED);
    } else {
        SetThreadExecutionState(ES_CONTINUOUS);
    }
#elif defined(Q_OS_MACOS)
    // IOKit power assertion — the macOS equivalent of ES_DISPLAY_REQUIRED.
    // Preventing display idle sleep also keeps the system awake, matching the
    // Windows behavior. The assertion is held until released or the process
    // exits (macOS cleans it up on crash too).
    if (m_keepAwake && m_assertionId == 0) {
        IOPMAssertionID id = 0;
        if (IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep,
                kIOPMAssertionLevelOn,
                CFSTR("Mosaic multiviewer — keep display awake"),
                &id) == kIOReturnSuccess) {
            m_assertionId = id;
        }
    } else if (!m_keepAwake && m_assertionId != 0) {
        IOPMAssertionRelease(m_assertionId);
        m_assertionId = 0;
    }
#endif
}

#include "CursorGuard.h"

#include <QCursor>
#include <QGuiApplication>
#include <QTimer>

namespace {
constexpr int kIdleMs = 3000;
}

CursorGuard::CursorGuard(QObject *parent)
    : QObject(parent)
{
    m_timer = new QTimer(this);
    m_timer->setSingleShot(true);
    m_timer->setInterval(kIdleMs);
    connect(m_timer, &QTimer::timeout, this, &CursorGuard::hideCursor);
}

CursorGuard::~CursorGuard()
{
    showCursor(); // never leave the app with an invisible cursor
}

void CursorGuard::setEnabled(bool enabled)
{
    if (enabled == m_enabled)
        return;
    m_enabled = enabled;
    emit enabledChanged();
    if (enabled && m_hovering) {
        m_timer->start();
    } else {
        m_timer->stop();
        showCursor();
    }
}

void CursorGuard::poke()
{
    showCursor();
    if (m_enabled && m_hovering)
        m_timer->start();
}

void CursorGuard::setHovering(bool hovering)
{
    if (hovering == m_hovering)
        return;
    m_hovering = hovering;
    if (m_enabled && m_hovering) {
        m_timer->start();
    } else {
        m_timer->stop();
        showCursor();
    }
}

void CursorGuard::hideCursor()
{
    // Override cursors only affect this application's windows — the
    // cursor stays visible over other apps and the desktop.
    if (!m_hidden) {
        QGuiApplication::setOverrideCursor(QCursor(Qt::BlankCursor));
        m_hidden = true;
    }
}

void CursorGuard::showCursor()
{
    if (m_hidden) {
        QGuiApplication::restoreOverrideCursor();
        m_hidden = false;
    }
}

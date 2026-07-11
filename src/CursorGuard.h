#pragma once

#include <QObject>
#include <QtQml/qqmlregistration.h>

class QTimer;

// Hides the mouse cursor over the app's windows after a few seconds of
// inactivity so it never sits on top of video. QML calls poke() on every
// mouse movement; the cursor reappears instantly on the next move.
// Controlled by the "Hide mouse when idle" setting.
class CursorGuard : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)

public:
    explicit CursorGuard(QObject *parent = nullptr);
    ~CursorGuard() override;

    bool enabled() const { return m_enabled; }
    void setEnabled(bool enabled);

    Q_INVOKABLE void poke();
    // Canvases report when the pointer enters/leaves them; the cursor
    // only ever hides while it is over a canvas (never over the
    // sidebar, menus, or other chrome).
    Q_INVOKABLE void setHovering(bool hovering);

signals:
    void enabledChanged();

private:
    void hideCursor();
    void showCursor();

    bool m_enabled = false;
    bool m_hovering = false;
    bool m_hidden = false;
    QTimer *m_timer = nullptr;
};

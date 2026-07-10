// Dark-theme hello-world for the macOS port (milestone 8).
// Mirrors the real app's startup shape (QGuiApplication + QQmlApplicationEngine)
// minus NDI, and exposes a couple of environment facts to QML so we can confirm
// the Qt version and the RHI graphics backend (Metal on macOS) on screen.
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QLibraryInfo>
#include <cstdlib>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName("Mosaic (hello)");
    QGuiApplication::setOrganizationName("Cinertia Systems");

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(
        "qtVersion", QLibraryInfo::version().toString());
    // Dev aid: MOSAIC_ONTOP=1 raises the window above other apps so it can be
    // screenshotted cleanly from a terminal session. Off by default.
    engine.rootContext()->setContextProperty(
        "stayOnTop", std::getenv("MOSAIC_ONTOP") != nullptr);

    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed,
        &app, []() { QCoreApplication::exit(1); },
        Qt::QueuedConnection);
    engine.loadFromModule("MosaicHello", "Main");

    return app.exec();
}

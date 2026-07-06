#include <QGuiApplication>
#include <QQmlApplicationEngine>

#include <Processing.NDI.Lib.h>

#include <cstdio>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName("Mosaic");
    QGuiApplication::setOrganizationName("Cinertia Systems");

    if (!NDIlib_initialize()) {
        std::fprintf(stderr, "NDI runtime failed to initialize.\n");
        return 1;
    }

    int result = 1;
    {
        QQmlApplicationEngine engine;
        QObject::connect(
            &engine, &QQmlApplicationEngine::objectCreationFailed,
            &app, []() { QCoreApplication::exit(1); },
            Qt::QueuedConnection);
        engine.loadFromModule("Mosaic", "Main");

        result = app.exec();
    } // engine (and all NDI objects) destroyed before the library shuts down

    NDIlib_destroy();
    return result;
}

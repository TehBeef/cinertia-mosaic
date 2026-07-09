# Standalone dark-theme hello-world for the macOS port (milestone 8).
# This is intentionally isolated from the main Mosaic build: it needs NO NDI
# SDK, so it validates the Mac toolchain (CMake + Qt 6 + Metal/RHI + the dark
# shell) before we wire NDI in. It never touches the Windows build.
cmake_minimum_required(VERSION 3.21)
project(MosaicHello VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Quick)

qt_standard_project_setup(REQUIRES 6.5)
qt_policy(SET QTP0004 NEW)

qt_add_executable(MosaicHello src/main.cpp)

# On macOS the executable has no extension, so a bare "MosaicHello" binary
# collides with the "MosaicHello/" QML module directory Qt generates (same
# name). Building an .app bundle is the correct macOS packaging anyway and
# sidesteps the clash. The real Mosaic port will need this too.
set_target_properties(MosaicHello PROPERTIES MACOSX_BUNDLE TRUE)

qt_add_qml_module(MosaicHello
    URI MosaicHello
    VERSION 1.0
    QML_FILES
        qml/Main.qml
)

target_link_libraries(MosaicHello PRIVATE Qt6::Quick)

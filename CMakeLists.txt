cmake_minimum_required(VERSION 3.21)

# "Mosaic" is a codename only — the product must not ship with "NDI" in its
# name without approval from the NDI team (NDI SDK license terms).
project(Mosaic VERSION 0.6.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Quick Network ShaderTools)

qt_standard_project_setup(REQUIRES 6.5)
qt_policy(SET QTP0004 NEW)

# ------------------------------------------------------------------ NDI SDK
# Platform-specific paths are isolated here. Each platform sets NDI_SDK_INCLUDE
# and NDI_SDK_LIB. Windows also sets NDI_SDK_DLL to ship beside the .exe; macOS
# bundles the dylib into the .app (see the POST_BUILD step below).
if(WIN32)
    set(NDI_SDK_DIR "C:/Program Files/NDI/NDI 6 SDK" CACHE PATH "NDI SDK location")
    set(NDI_SDK_INCLUDE "${NDI_SDK_DIR}/Include")
    set(NDI_SDK_LIB "${NDI_SDK_DIR}/Lib/x64/Processing.NDI.Lib.x64.lib")
    set(NDI_SDK_DLL "${NDI_SDK_DIR}/Bin/x64/Processing.NDI.Lib.x64.dll")
elseif(APPLE)
    # The macOS build uses a copy of the NDI SDK for Apple kept on the external
    # drive alongside the repo (headers + the universal libndi.dylib), so nothing
    # lands on the near-full internal drive. Override with -DNDI_SDK_DIR=… .
    set(NDI_SDK_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../NDI SDK for Apple" CACHE PATH "NDI SDK location")
    set(NDI_SDK_INCLUDE "${NDI_SDK_DIR}/include")
    set(NDI_SDK_LIB "${NDI_SDK_DIR}/lib/macOS/libndi.dylib")
endif()
if(NOT EXISTS "${NDI_SDK_INCLUDE}/Processing.NDI.Lib.h")
    message(FATAL_ERROR "NDI SDK not found at ${NDI_SDK_DIR}")
endif()

# ---------------------------------------------------------------------- app
qt_add_executable(Mosaic
    src/main.cpp
)
if(WIN32)
    target_sources(Mosaic PRIVATE resources/mosaic.rc)
elseif(APPLE)
    # App icon: bundle the .icns into the .app and point Info.plist's
    # CFBundleIconFile at it (the macOS counterpart of the Windows .rc icon).
    set(MOSAIC_ICNS "${CMAKE_CURRENT_SOURCE_DIR}/resources/mosaic.icns")
    target_sources(Mosaic PRIVATE "${MOSAIC_ICNS}")
    set_source_files_properties("${MOSAIC_ICNS}" PROPERTIES
        MACOSX_PACKAGE_LOCATION Resources)
    # Bundle identity/version. A stable CFBundleIdentifier also makes macOS
    # privacy grants (Local Network, removable volume) stick across builds.
    set_target_properties(Mosaic PROPERTIES
        MACOSX_BUNDLE_ICON_FILE "mosaic.icns"
        MACOSX_BUNDLE_GUI_IDENTIFIER "com.cinertiasystems.mosaic"
        MACOSX_BUNDLE_BUNDLE_NAME "Mosaic"
        MACOSX_BUNDLE_BUNDLE_VERSION "${PROJECT_VERSION}"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
        MACOSX_BUNDLE_COPYRIGHT "© 2026 Cinertia Systems. NDI® is a registered trademark of Vizrt NDI AB.")
    # Custom Info.plist template: adds NSLocalNetworkUsageDescription (the
    # explanation shown in the "find devices on local networks?" dialog) and
    # the NDI Bonjour service type on top of CMake's standard bundle keys.
    set_target_properties(Mosaic PROPERTIES
        MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/resources/Info.plist.in")
endif()

qt_add_qml_module(Mosaic
    URI Mosaic
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/Tile.qml
        qml/TileCanvas.qml
        qml/OutputWindow.qml
    RESOURCES
        resources/mosaic-logo.png
    SOURCES
        src/Storage.h
        src/Storage.cpp
        src/PowerGuard.h
        src/PowerGuard.cpp
        src/RemoteControl.h
        src/RemoteControl.cpp
        src/ndi/NdiFinder.h
        src/ndi/NdiFinder.cpp
        src/ndi/NdiVideoItem.h
        src/ndi/NdiVideoItem.cpp
        src/ndi/UyvyMaterial.h
        src/ndi/UyvyMaterial.cpp
        src/CursorGuard.h
        src/CursorGuard.cpp
        src/UpdateChecker.h
        src/UpdateChecker.cpp
)

# The update checker compares the running version against the newest
# GitHub release tag.
target_compile_definitions(Mosaic PRIVATE MOSAIC_VERSION="${PROJECT_VERSION}")

# UYVY→RGB conversion shaders, compiled by Qt's shader tools for every
# graphics backend (D3D on Windows, Metal on macOS).
qt6_add_shaders(Mosaic "mosaic_shaders"
    BATCHABLE # Qt Quick materials need the batchable vertex variant
    PREFIX "/"
    FILES shaders/uyvy.vert shaders/uyvy.frag
)

target_include_directories(Mosaic PRIVATE "${NDI_SDK_INCLUDE}" src src/ndi)
target_link_libraries(Mosaic PRIVATE Qt6::Quick Qt6::Network "${NDI_SDK_LIB}")

# macOS never-sleep (PowerGuard) uses IOKit power assertions.
if(APPLE)
    target_link_libraries(Mosaic PRIVATE "-framework IOKit" "-framework CoreFoundation")
endif()

# The NDI runtime ships inside the app — never the system path (license terms).
if(WIN32)
    # Windows: copy the DLL next to the .exe.
    add_custom_command(TARGET Mosaic POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${NDI_SDK_DLL}" "$<TARGET_FILE_DIR:Mosaic>"
    )
elseif(APPLE)
    # macOS: bundle libndi.dylib into Mosaic.app/Contents/Frameworks. The dylib's
    # install name is @rpath/libndi.dylib, so we add an rpath into the bundle's
    # Frameworks folder and the loader finds it — the .app stays self-contained.
    target_link_options(Mosaic PRIVATE "-Wl,-rpath,@executable_path/../Frameworks")
    add_custom_command(TARGET Mosaic POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E make_directory
            "$<TARGET_BUNDLE_CONTENT_DIR:Mosaic>/Frameworks"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${NDI_SDK_LIB}" "$<TARGET_BUNDLE_CONTENT_DIR:Mosaic>/Frameworks/"
    )
endif()

# WIN32_EXECUTABLE hides the console window on Windows (ignored elsewhere).
# MACOSX_BUNDLE builds a .app on macOS (ignored elsewhere) — required so the
# executable name doesn't collide with the generated QML module directory.
set_target_properties(Mosaic PROPERTIES WIN32_EXECUTABLE TRUE MACOSX_BUNDLE TRUE)

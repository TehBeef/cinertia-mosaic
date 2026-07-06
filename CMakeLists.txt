cmake_minimum_required(VERSION 3.21)

# "Mosaic" is a codename only — the product must not ship with "NDI" in its
# name without approval from the NDI team (see CLAUDE.md license section).
project(Mosaic VERSION 0.2.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Quick Network)

qt_standard_project_setup(REQUIRES 6.5)
qt_policy(SET QTP0004 NEW)

# ------------------------------------------------------------------ NDI SDK
# Platform-specific paths are isolated here so a macOS build later only
# needs a new branch in this block.
if(WIN32)
    set(NDI_SDK_DIR "C:/Program Files/NDI/NDI 6 SDK" CACHE PATH "NDI SDK location")
    set(NDI_SDK_LIB "${NDI_SDK_DIR}/Lib/x64/Processing.NDI.Lib.x64.lib")
    set(NDI_SDK_DLL "${NDI_SDK_DIR}/Bin/x64/Processing.NDI.Lib.x64.dll")
endif()
if(NOT EXISTS "${NDI_SDK_DIR}/Include/Processing.NDI.Lib.h")
    message(FATAL_ERROR "NDI SDK not found at ${NDI_SDK_DIR}")
endif()

# ---------------------------------------------------------------------- app
qt_add_executable(Mosaic
    src/main.cpp
)
if(WIN32)
    target_sources(Mosaic PRIVATE resources/mosaic.rc)
endif()

qt_add_qml_module(Mosaic
    URI Mosaic
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/Tile.qml
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
)

target_include_directories(Mosaic PRIVATE "${NDI_SDK_DIR}/Include" src src/ndi)
target_link_libraries(Mosaic PRIVATE Qt6::Quick Qt6::Network "${NDI_SDK_LIB}")

# The NDI DLL ships in the app folder — never the system path (license terms).
if(WIN32)
    add_custom_command(TARGET Mosaic POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${NDI_SDK_DLL}" "$<TARGET_FILE_DIR:Mosaic>"
    )
endif()

# WIN32_EXECUTABLE hides the console window on Windows. Debug output can
# still be captured by redirecting stderr when launching from a shell.
set_target_properties(Mosaic PROPERTIES WIN32_EXECUTABLE TRUE)

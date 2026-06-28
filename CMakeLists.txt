cmake_minimum_required(VERSION 3.10)
project(LumixorQt LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# Add QML/Quick modules
find_package(Qt5 COMPONENTS Widgets Multimedia MultimediaWidgets Quick Qml QuickControls2 REQUIRED)

set(SRC
    src/main.cpp
    src/util/Application.cpp
    src/util/AppConfig.cpp
    src/core/MediaManager.cpp
    src/core/PlaybackController.cpp
    src/core/SlideshowController.cpp
    src/ui/OutputWindow.cpp
    src/ui/ControlBridge.cpp
    src/ui/ExifImageProvider.cpp
    src/ui/PreferencesController.cpp
    src/audio/AudioAnalyzer.cpp
)

set(HDR
    src/util/Application.h
    src/util/AppConfig.h
    src/core/MediaItem.h
    src/core/MediaManager.h
    src/core/PlaybackController.h
    src/core/SlideshowController.h
    src/ui/OutputWindow.h
    src/ui/ControlBridge.h
    src/ui/ExifImageProvider.h
    src/ui/PreferencesController.h
    src/audio/AudioAnalyzer.h
)

# QML resources
set(RESOURCES
    src/ui/qml/qml.qrc
    resources/resources.qrc
)

add_executable(lumixor-qt
    ${SRC}
    ${HDR}
    ${RESOURCES}
)

target_link_libraries(lumixor-qt
    Qt5::Widgets
    Qt5::Multimedia
    Qt5::MultimediaWidgets
    Qt5::Quick
    Qt5::Qml
    Qt5::QuickControls2
)

# Installation rules for user-scope installation
include(GNUInstallDirs)

# Install the executable to user's local bin directory
install(TARGETS lumixor-qt
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

# Install desktop entry
install(FILES resources/lumixor.desktop
    DESTINATION ${CMAKE_INSTALL_DATADIR}/applications
)

# Install icon
install(FILES resources/lumixor.svg
    DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps
)

# === Unit tests (off by default; `make test` enables them) ===
option(BUILD_TESTS "Build unit tests" OFF)
if(BUILD_TESTS)
    enable_testing()
    find_package(Qt5 COMPONENTS Test REQUIRED)

    add_executable(tst_mediamanager
        tests/tst_mediamanager.cpp
        src/core/MediaManager.cpp
    )
    target_include_directories(tst_mediamanager PRIVATE src/core)
    target_link_libraries(tst_mediamanager Qt5::Core Qt5::Test)
    add_test(NAME mediamanager COMMAND tst_mediamanager)
endif()
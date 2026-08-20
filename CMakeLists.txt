cmake_minimum_required(VERSION 3.10)
project(LumixorQt LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# Add QML/Quick modules
find_package(Qt5 COMPONENTS Widgets Multimedia MultimediaWidgets Quick Qml QuickControls2 REQUIRED)

# === Core library (GUI-free; linked by both the app and the unit tests) ===
add_library(lumixor_core STATIC
    src/core/MediaManager.cpp
    src/core/MediaTypes.cpp
    src/core/PlaybackController.cpp
    src/core/SlideshowController.cpp
    src/util/AppConfig.cpp
    src/audio/SpectrumAnalyzer.cpp
    src/core/MediaItem.h
    src/core/MediaManager.h
    src/core/MediaTypes.h
    src/core/PlaybackController.h
    src/core/SlideshowController.h
    src/util/AppConfig.h
    src/audio/SpectrumAnalyzer.h
)
target_include_directories(lumixor_core PUBLIC src src/core src/util src/audio)
# SlideshowController reads its playlist out of a QML ListModel, so the core library
# needs QtQml. QtQml itself has no GUI dependency, so the tests still run headless.
target_link_libraries(lumixor_core PUBLIC Qt5::Core Qt5::Qml)

set(SRC
    src/util/Application.cpp
    src/ui/OutputBridge.cpp
    src/ui/ControlBridge.cpp
    src/ui/ExifImageProvider.cpp
    src/ui/PreferencesController.cpp
    src/ui/ScreenManager.cpp
    src/audio/AudioAnalyzer.cpp
)

set(HDR
    src/util/Application.h
    src/ui/OutputBridge.h
    src/ui/ControlBridge.h
    src/ui/ExifImageProvider.h
    src/ui/PreferencesController.h
    src/ui/ScreenManager.h
    src/audio/AudioAnalyzer.h
)

# QML resources
set(RESOURCES
    src/ui/qml/qml.qrc
    resources/resources.qrc
)

add_executable(lumixor-qt
    src/main.cpp
    ${SRC}
    ${HDR}
    ${RESOURCES}
)

target_link_libraries(lumixor-qt
    lumixor_core
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

# === Unit tests ===
option(BUILD_TESTS "Build unit tests" ON)
if(BUILD_TESTS)
    enable_testing()
    find_package(Qt5 COMPONENTS Test REQUIRED)

    foreach(test_name mediamanager appconfig slideshow spectrum)
        add_executable(tst_${test_name} tests/tst_${test_name}.cpp)
        target_link_libraries(tst_${test_name} lumixor_core Qt5::Test)
        add_test(NAME ${test_name} COMMAND tst_${test_name})
    endforeach()

    # Static check of the QML wiring; needs the source tree, not the built resources.
    add_executable(tst_qmlresources tests/tst_qmlresources.cpp)
    target_link_libraries(tst_qmlresources Qt5::Core Qt5::Test)
    target_compile_definitions(tst_qmlresources PRIVATE
        SOURCE_QML_DIR="${CMAKE_CURRENT_SOURCE_DIR}/src/ui/qml")
    add_test(NAME qmlresources COMMAND tst_qmlresources)

    # Drives the real QML against the real controllers, so it needs the same sources
    # and resources as the application itself.
    add_executable(tst_controlwindow tests/tst_controlwindow.cpp ${SRC} ${HDR} ${RESOURCES})
    target_include_directories(tst_controlwindow PRIVATE src)
    target_link_libraries(tst_controlwindow
        lumixor_core
        Qt5::Test
        Qt5::Widgets
        Qt5::Multimedia
        Qt5::MultimediaWidgets
        Qt5::Quick
        Qt5::Qml
        Qt5::QuickControls2
    )
    add_test(NAME controlwindow COMMAND tst_controlwindow)
    set_tests_properties(controlwindow PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
endif()

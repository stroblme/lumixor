cmake_minimum_required(VERSION 3.10)
project(LumixorQt LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt5 COMPONENTS Widgets Multimedia MultimediaWidgets REQUIRED)

set(SRC
    src/main.cpp
    src/util/Application.cpp
    src/core/MediaManager.cpp
    src/core/PlaybackController.cpp
    src/core/SlideshowController.cpp
    src/ui/OutputWindow.cpp
    src/ui/ControlWindow.cpp
    )
    
    set(HDR
    src/util/Application.h
    src/core/MediaItem.h
    src/core/MediaManager.h
    src/core/PlaybackController.h
    src/core/SlideshowController.h
    src/ui/OutputWindow.h
    src/ui/ControlWindow.h
)

# UI files (Qt Designer)
set(UI
    src/ui/forms/ControlWindow.ui
    src/ui/forms/OutputWindow.ui
)

add_executable(lumixor-qt
    ${SRC}
    ${HDR}
    ${UI}
)

target_link_libraries(lumixor-qt
    Qt5::Widgets
    Qt5::Multimedia
    Qt5::MultimediaWidgets
)
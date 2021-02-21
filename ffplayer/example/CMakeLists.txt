cmake_minimum_required(VERSION 3.10)

project("media_player_example")

set(EXAMPLE_BIN_NAME ${PROJECT_NAME})

aux_source_directory(${CMAKE_CURRENT_SOURCE_DIR} EXAMPLE_SOURCES)

find_library(LIBSDL2MAIN SDL2main REQUIRED)

add_executable(${EXAMPLE_BIN_NAME} ${EXAMPLE_SOURCES})

target_include_directories(${EXAMPLE_BIN_NAME} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

target_link_libraries(${EXAMPLE_BIN_NAME} PUBLIC media_player ${LIBSDL2MAIN})

if (WIN32)
    if (CMAKE_FLUTTER_WINDOWS)
        set_property(TARGET ${EXAMPLE_BIN_NAME} APPEND PROPERTY LINK_FLAGS "/NODEFAULTLIB:MSVCRT")
    endif ()
endif ()
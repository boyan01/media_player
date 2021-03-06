cmake_minimum_required(VERSION 3.15)
set(PROJECT_NAME "lychee_player")
project(${PROJECT_NAME} LANGUAGES CXX)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "lychee_player_plugin")


set(CMAKE_FLUTTER_MEDIA "1")
set(CMAKE_FLUTTER_MEDIA_WINDOWS "1")
set(MEDIA_USE_SDL "1")

add_compile_definitions(_FLUTTER_MEDIA_)
add_compile_definitions(_FLUTTER_MEDIA_WINDOWS)
add_subdirectory(../ffplayer media_framework)

add_library(${PLUGIN_NAME} SHARED
        "lychee_player_plugin.cpp"
        )
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES
        CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
        "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin media_flutter)

# List of absolute paths to libraries that should be bundled with the plugin
set(lychee_player_bundled_libraries
        "$<TARGET_FILE:media_flutter>"
        "$<TARGET_FILE:SDL2>"
        "$<TARGET_FILE:avutil>"
        "$<TARGET_FILE:avcodec>"
        "$<TARGET_FILE:avformat>"
        "$<TARGET_FILE:swresample>"
        "$<TARGET_FILE:swscale>"
        PARENT_SCOPE
        )

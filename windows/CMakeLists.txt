cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "fox_utils")
project(${PROJECT_NAME} LANGUAGES CXX)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "fox_utils_plugin")

add_library(${PLUGIN_NAME} SHARED
        "fox_utils_plugin.cpp"
        "pasteboard_plugin.cpp"
        "desktop_drop_plugin.cpp"
        )
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES
        CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
        "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

# GdiPlus doesn't compile with /W4 (the template's level): all sources use
# /W3, one option per list entry ("/W3 /WX" in one entry reaches cl.exe as a
# single bad argument, D8021). No warnings-as-errors: a newer MSVC's new
# warning must not break app releases.
set_source_files_properties("fox_utils_plugin.cpp" "pasteboard_plugin.cpp" "desktop_drop_plugin.cpp"
        PROPERTIES COMPILE_OPTIONS "/W3")

# List of absolute paths to libraries that should be bundled with the plugin
set(fox_utils_bundled_libraries
        ""
        PARENT_SCOPE
        )

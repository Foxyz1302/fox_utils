#ifndef FLUTTER_PLUGIN_FOX_UTILS_PLUGIN_H_
#define FLUTTER_PLUGIN_FOX_UTILS_PLUGIN_H_

#include <flutter_plugin_registrar.h>

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FLUTTER_PLUGIN_EXPORT __declspec(dllimport)
#endif

#if defined(__cplusplus)
extern "C" {
#endif

// Single native registration entry for the fox_utils package on Windows.
// The generated plugin registrant calls this function; it in turn registers
// every vendored engine in this package (pasteboard, desktop_drop).
FLUTTER_PLUGIN_EXPORT void FoxUtilsPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

#if defined(__cplusplus)
}  // extern "C"
#endif

#endif  // FLUTTER_PLUGIN_FOX_UTILS_PLUGIN_H_
#ifndef FLUTTER_PLUGIN_FOX_UTILS_PLUGIN_H_
#define FLUTTER_PLUGIN_FOX_UTILS_PLUGIN_H_

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __attribute__((visibility("default")))
#else
#define FLUTTER_PLUGIN_EXPORT
#endif

// Single native registration entry for the fox_utils package on Linux.
// The generated plugin registrant calls this function; it in turn registers
// every vendored engine in this package (pasteboard, desktop_drop).
FLUTTER_PLUGIN_EXPORT void fox_utils_plugin_register_with_registrar(
    FlPluginRegistrar* registrar);

G_END_DECLS

#endif  // FLUTTER_PLUGIN_FOX_UTILS_PLUGIN_H_
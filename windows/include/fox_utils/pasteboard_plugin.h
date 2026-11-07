// Modified from MixinNetwork's pasteboard v0.5.0 (Apache-2.0, Copyright Mixin Network; see LICENSE).
#ifndef FLUTTER_PLUGIN_PASTEBOARD_PLUGIN_H_
#define FLUTTER_PLUGIN_PASTEBOARD_PLUGIN_H_

#include <flutter_plugin_registrar.h>

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FLUTTER_PLUGIN_EXPORT __declspec(dllimport)
#endif

#if defined(__cplusplus)
extern "C" {
#endif

FLUTTER_PLUGIN_EXPORT void PasteboardPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

#if defined(__cplusplus)
}  // extern "C"
#endif

#endif  // FLUTTER_PLUGIN_PASTEBOARD_PLUGIN_H_

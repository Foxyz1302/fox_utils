// Debug builds only: keeps a Flutter hot restart from crashing apps that use
// media_kit on Linux. Hot restart frees the old isolate's NativeCallables
// while mpv handles stay alive; media_kit then "quit"s the leftovers and mpv
// calls a dead wakeup callback (SIGSEGV on mpv's "core" thread). On the
// engine's on-pre-engine-restart signal this clears every live handle's
// wakeup callback (found through media_kit's NativeReferenceHolder file).
// Does nothing without media_kit/libmpv, and nothing in release builds.
#ifndef FOX_UTILS_MEDIA_KIT_RESTART_GUARD_H_
#define FOX_UTILS_MEDIA_KIT_RESTART_GUARD_H_

#include <flutter_linux/flutter_linux.h>

void media_kit_restart_guard_register_with_registrar(FlPluginRegistrar* registrar);

#endif

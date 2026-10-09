#include "include/fox_utils/fox_utils_plugin.h"
#include "include/fox_utils/pasteboard_plugin.h"
#include "include/fox_utils/desktop_drop_plugin.h"

void FoxUtilsPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  PasteboardPluginRegisterWithRegistrar(registrar);
  DesktopDropPluginRegisterWithRegistrar(registrar);
}
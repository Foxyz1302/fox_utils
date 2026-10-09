#include "include/fox_utils/fox_utils_plugin.h"
#include "include/fox_utils/pasteboard_plugin.h"
#include "include/fox_utils/desktop_drop_plugin.h"

void fox_utils_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  pasteboard_plugin_register_with_registrar(registrar);
  desktop_drop_plugin_register_with_registrar(registrar);
}
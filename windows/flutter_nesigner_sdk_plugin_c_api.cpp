#include "include/flutter_nesigner_sdk/flutter_nesigner_sdk_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_nesigner_sdk_plugin.h"

void FlutterNesignerSdkPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_nesigner_sdk::FlutterNesignerSdkPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}

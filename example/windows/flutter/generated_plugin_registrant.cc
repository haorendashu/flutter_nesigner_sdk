//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <flutter_libserialport/flutter_libserialport_plugin.h>
#include <flutter_nesigner_sdk/flutter_nesigner_sdk_plugin_c_api.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  FlutterLibserialportPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterLibserialportPlugin"));
  FlutterNesignerSdkPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterNesignerSdkPluginCApi"));
}

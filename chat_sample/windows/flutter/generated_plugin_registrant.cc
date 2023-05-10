//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <connectivity_plus_windows/connectivity_plus_windows_plugin.h>
#include <emoji_picker_flutter/emoji_picker_flutter_plugin_c_api.h>
#include <flutter_webrtc/flutter_web_r_t_c_plugin.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  ConnectivityPlusWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("ConnectivityPlusWindowsPlugin"));
  EmojiPickerFlutterPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("EmojiPickerFlutterPluginCApi"));
  FlutterWebRTCPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterWebRTCPlugin"));
}

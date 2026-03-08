//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <audio_analyzer/audio_analyzer_plugin.h>
#include <audioplayers_linux/audioplayers_linux_plugin.h>
#include <file_selector_linux/file_selector_plugin.h>
#include <flutter_onnxruntime/flutter_onnxruntime_plugin.h>
#include <flutter_volume_controller/flutter_volume_controller_plugin.h>
#include <screen_retriever_linux/screen_retriever_linux_plugin.h>
#include <supertonic_flutter/supertonic_flutter_plugin.h>
#include <window_manager/window_manager_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) audio_analyzer_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "AudioAnalyzerPlugin");
  audio_analyzer_plugin_register_with_registrar(audio_analyzer_registrar);
  g_autoptr(FlPluginRegistrar) audioplayers_linux_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "AudioplayersLinuxPlugin");
  audioplayers_linux_plugin_register_with_registrar(audioplayers_linux_registrar);
  g_autoptr(FlPluginRegistrar) file_selector_linux_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "FileSelectorPlugin");
  file_selector_plugin_register_with_registrar(file_selector_linux_registrar);
  g_autoptr(FlPluginRegistrar) flutter_onnxruntime_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "FlutterOnnxruntimePlugin");
  flutter_onnxruntime_plugin_register_with_registrar(flutter_onnxruntime_registrar);
  g_autoptr(FlPluginRegistrar) flutter_volume_controller_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "FlutterVolumeControllerPlugin");
  flutter_volume_controller_plugin_register_with_registrar(flutter_volume_controller_registrar);
  g_autoptr(FlPluginRegistrar) screen_retriever_linux_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "ScreenRetrieverLinuxPlugin");
  screen_retriever_linux_plugin_register_with_registrar(screen_retriever_linux_registrar);
  g_autoptr(FlPluginRegistrar) supertonic_flutter_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "SupertonicFlutterPlugin");
  supertonic_flutter_plugin_register_with_registrar(supertonic_flutter_registrar);
  g_autoptr(FlPluginRegistrar) window_manager_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "WindowManagerPlugin");
  window_manager_plugin_register_with_registrar(window_manager_registrar);
}

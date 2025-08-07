//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <open_file_linux/open_file_linux_plugin.h>
#include <simple_torrent/simple_torrent_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) open_file_linux_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "OpenFileLinuxPlugin");
  open_file_linux_plugin_register_with_registrar(open_file_linux_registrar);
  g_autoptr(FlPluginRegistrar) simple_torrent_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "SimpleTorrentPlugin");
  simple_torrent_plugin_register_with_registrar(simple_torrent_registrar);
}

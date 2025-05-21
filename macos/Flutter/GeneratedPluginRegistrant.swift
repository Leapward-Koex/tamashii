//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import file_picker
import path_provider_foundation
import shared_preferences_foundation
import simple_torrent
import sqflite_darwin

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  FilePickerPlugin.register(with: registry.registrar(forPlugin: "FilePickerPlugin"))
  PathProviderPlugin.register(with: registry.registrar(forPlugin: "PathProviderPlugin"))
  SharedPreferencesPlugin.register(with: registry.registrar(forPlugin: "SharedPreferencesPlugin"))
  SimpleTorrentPlugin.register(with: registry.registrar(forPlugin: "SimpleTorrentPlugin"))
  SqflitePlugin.register(with: registry.registrar(forPlugin: "SqflitePlugin"))
}

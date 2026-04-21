import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class LiveKitPersistedConfig {
  const LiveKitPersistedConfig({
    required this.tokenServiceUrl,
    required this.roomName,
    required this.identity,
  });

  final String tokenServiceUrl;
  final String roomName;
  final String identity;

  Map<String, dynamic> toJson() {
    return {
      'tokenServiceUrl': tokenServiceUrl,
      'roomName': roomName,
      'identity': identity,
    };
  }

  factory LiveKitPersistedConfig.fromJson(Map<String, dynamic> json) {
    return LiveKitPersistedConfig(
      tokenServiceUrl: (json['tokenServiceUrl'] as String?)?.trim() ?? '',
      roomName: (json['roomName'] as String?)?.trim() ?? '',
      identity: (json['identity'] as String?)?.trim() ?? '',
    );
  }
}

class LiveKitConnectionStorage {
  const LiveKitConnectionStorage();

  Future<LiveKitPersistedConfig?> load() async {
    try {
      final file = await _configFile();
      if (!await file.exists()) {
        return null;
      }

      final rawText = await file.readAsString();
      final decoded = jsonDecode(rawText);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final config = LiveKitPersistedConfig.fromJson(decoded);
      if (config.tokenServiceUrl.isEmpty ||
          config.roomName.isEmpty ||
          config.identity.isEmpty) {
        return null;
      }
      return config;
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  Future<void> save(LiveKitPersistedConfig config) async {
    final file = await _configFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(config.toJson()));
  }

  Future<File> _configFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/livekit_connection_config.json');
  }
}

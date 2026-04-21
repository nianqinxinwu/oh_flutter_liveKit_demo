import 'package:flutter/material.dart';

class LiveKitConnectionConfig {
  const LiveKitConnectionConfig({
    required this.tokenServiceUrl,
    required this.roomName,
    required this.identity,
    this.directWsUrl,
    this.directToken,
    this.persistSelection = true,
  });

  final String tokenServiceUrl;
  final String roomName;
  final String identity;
  final String? directWsUrl;
  final String? directToken;
  final bool persistSelection;

  bool get usesDirectCredentials {
    return (directWsUrl?.isNotEmpty ?? false) && (directToken?.isNotEmpty ?? false);
  }
}

const _testEnvironmentName = '测试环境测试';

class _TestEnvironmentPreset {
  const _TestEnvironmentPreset({
    required this.label,
    required this.wsUrl,
    required this.roomName,
    required this.identity,
    required this.token,
  });

  final String label;
  final String wsUrl;
  final String roomName;
  final String identity;
  final String token;
}

const _testEnvironmentPresets = <_TestEnvironmentPreset>[
  _TestEnvironmentPreset(
    label: 'Token1',
    wsUrl: 'wss://wss.vip-class.top',
    roomName: 'my-first-roo',
    identity: 'user99',
    token:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
        'eyJleHAiOjE3NzY4MjY5ODQsImlzcyI6IkFQSTlXZHNMVWFleFdVUCIsIm5hbWUiOiJ1c2VyOTkiLCJuYmYiOjE3NzY3NDA1ODQsInN1YiI6InVzZXI5OSIsInZpZGVvIjp7InJvb20iOiJteS1maXJzdC1yb28iLCJyb29tSm9pbiI6dHJ1ZX19.'
        'Z_3ThQP6u-jh6eUP5dj4dxjeP-wZ7b1t70t_zRCjIQ8',
  ),
  _TestEnvironmentPreset(
    label: 'Token2',
    wsUrl: 'wss://wss.vip-class.top',
    roomName: 'my-first-roo',
    identity: 'user9',
    token:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
        'eyJleHAiOjE3NzY4Mjg3MTMsImlzcyI6IkFQSTlXZHNMVWFleFdVUCIsIm5hbWUiOiJ1c2VyOSIsIm5iZiI6MTc3Njc0MjMxMywic3ViIjoidXNlcjkiLCJ2aWRlbyI6eyJyb29tIjoibXktZmlyc3Qtcm9vIiwicm9vbUpvaW4iOnRydWV9fQ.'
        '3whhQikfGunUchBLJYbVYZxrIHKwo93zLSV2TaZ3rSc',
  ),
];

class LiveKitConfigPage extends StatefulWidget {
  const LiveKitConfigPage({
    super.key,
    required this.initialTokenServiceUrl,
    required this.initialRoomName,
    required this.initialIdentity,
  });

  final String initialTokenServiceUrl;
  final String initialRoomName;
  final String initialIdentity;

  @override
  State<LiveKitConfigPage> createState() => _LiveKitConfigPageState();
}

class _LiveKitConfigPageState extends State<LiveKitConfigPage> {
  late final TextEditingController _tokenServiceUrlController;
  late final TextEditingController _roomNameController;
  late final TextEditingController _identityController;

  @override
  void initState() {
    super.initState();
    _tokenServiceUrlController = TextEditingController(
      text: widget.initialTokenServiceUrl,
    );
    _roomNameController = TextEditingController(text: widget.initialRoomName);
    _identityController = TextEditingController(text: widget.initialIdentity);
  }

  @override
  void dispose() {
    _tokenServiceUrlController.dispose();
    _roomNameController.dispose();
    _identityController.dispose();
    super.dispose();
  }

  void _submit() {
    final tokenServiceUrl = _tokenServiceUrlController.text.trim();
    final roomName = _roomNameController.text.trim();
    final identity = _identityController.text.trim();

    if (tokenServiceUrl.isEmpty || roomName.isEmpty || identity.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请完整填写 Token 服务地址、房间号和身份标识')),
      );
      return;
    }

    Navigator.of(context).pop(
      LiveKitConnectionConfig(
        tokenServiceUrl: tokenServiceUrl,
        roomName: roomName,
        identity: identity,
      ),
    );
  }

  Future<void> _showTestEnvironmentPicker() async {
    final selectedPreset = await showModalBottomSheet<_TestEnvironmentPreset>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _testEnvironmentName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '请选择要使用的预置连接参数。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                for (final preset in _testEnvironmentPresets) ...[
                  FilledButton.tonal(
                    onPressed: () => Navigator.of(context).pop(preset),
                    child: Text(preset.label),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selectedPreset == null) {
      return;
    }

    Navigator.of(context).pop(
      LiveKitConnectionConfig(
        tokenServiceUrl: _tokenServiceUrlController.text.trim(),
        roomName: selectedPreset.roomName,
        identity: selectedPreset.identity,
        directWsUrl: selectedPreset.wsUrl,
        directToken: selectedPreset.token,
        persistSelection: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('参数配置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '页面会先请求 Go Token 服务，再自动使用服务端返回的 wsUrl 和 token 连接房间。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '当前填写内容会自动保存，下次打开页面会直接带出。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _testEnvironmentName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '点击后可选择 Token1 或 Token2，并直接使用对应预置参数连接 LiveKit。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: _showTestEnvironmentPicker,
                    child: const Text(_testEnvironmentName),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _tokenServiceUrlController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Token 服务地址',
              hintText: 'http://172.20.10.8:8091',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _roomNameController,
            decoration: const InputDecoration(
              labelText: '房间号',
              hintText: 'demo-room',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _identityController,
            decoration: const InputDecoration(
              labelText: '身份标识',
              hintText: 'ohos-device-01',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _submit, child: const Text('获取 Token 并连接')),
        ],
      ),
    );
  }
}

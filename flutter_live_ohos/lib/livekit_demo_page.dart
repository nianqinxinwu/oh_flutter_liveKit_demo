import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';

import 'livekit_config_page.dart';
import 'livekit_connection_storage.dart';
import 'livekit_preview_widget.dart';
import 'livekit_tab_bar_widget.dart';

const _defaultTokenServiceUrl = 'http://172.20.10.8:8091';

class LiveKitDemoPage extends StatefulWidget {
  const LiveKitDemoPage({super.key});

  @override
  State<LiveKitDemoPage> createState() => _LiveKitDemoPageState();
}

class _LiveKitDemoPageState extends State<LiveKitDemoPage>
    with WidgetsBindingObserver {
  final LiveKitConnectionStorage _storage = const LiveKitConnectionStorage();

  String _tokenServiceUrl = _defaultTokenServiceUrl;
  String _roomName = 'demo-room';
  late String _identity;
  String _liveKitUrl = '';

  Room? _room;
  EventsListener<RoomEvent>? _roomListener;
  bool _isConnecting = false;
  bool _shouldReconnectOnResume = false;
  bool _didManualDisconnect = false;
  bool _cameraEnabled = false;
  bool _microphoneEnabled = false;
  bool _audioPlaybackReady = false;
  String _status = '未连接';
  rtc.RTCVideoValue? _localVideoValue;

  bool get _isConnected => _room != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _identity = 'ohos-${DateTime.now().millisecondsSinceEpoch}';
    _loadPersistedConfig();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeRoom();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(_handleAppBackgrounded());
        break;
    }
  }

  Future<void> _openConfigPage() async {
    final config = await Navigator.of(context).push<LiveKitConnectionConfig>(
      MaterialPageRoute(
        builder: (_) => LiveKitConfigPage(
          initialTokenServiceUrl: _tokenServiceUrl,
          initialRoomName: _roomName,
          initialIdentity: _identity,
        ),
      ),
    );

    if (config == null) {
      return;
    }

    _tokenServiceUrl = config.tokenServiceUrl;
    _roomName = config.roomName;
    _identity = config.identity;
    _didManualDisconnect = false;
    if (config.persistSelection) {
      await _savePersistedConfig();
    }
    await _connect(
      overrideCredentials: config.usesDirectCredentials
          ? _LiveKitJoinCredentials(
              wsUrl: config.directWsUrl!,
              token: config.directToken!,
            )
          : null,
    );
  }

  Future<void> _loadPersistedConfig() async {
    final savedConfig = await _storage.load();
    if (!mounted || savedConfig == null) {
      return;
    }

    setState(() {
      _tokenServiceUrl = savedConfig.tokenServiceUrl;
      _roomName = savedConfig.roomName;
      _identity = savedConfig.identity;
      _status = '已加载本地配置';
    });
  }

  Future<void> _savePersistedConfig() async {
    try {
      await _storage.save(
        LiveKitPersistedConfig(
          tokenServiceUrl: _tokenServiceUrl,
          roomName: _roomName,
          identity: _identity,
        ),
      );
    } on FileSystemException catch (error) {
      if (mounted) {
        _showMessage('保存配置失败：$error');
      }
    }
  }

  Future<void> _connect({_LiveKitJoinCredentials? overrideCredentials}) async {
    final usesDirectCredentials = overrideCredentials != null;
    if ((!usesDirectCredentials && _tokenServiceUrl.isEmpty) ||
        _roomName.isEmpty ||
        _identity.isEmpty) {
      _showMessage(
        usesDirectCredentials
            ? '测试环境缺少房间号或身份标识，无法连接'
            : '请先完成 Token 服务地址、房间号和身份标识配置',
      );
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isConnecting = true;
      _audioPlaybackReady = false;
      _status = usesDirectCredentials ? '载入测试环境凭据中...' : '获取 Token 中...';
    });

    try {
      final credentials = overrideCredentials ?? await _fetchJoinCredentials();

      if (!mounted) {
        return;
      }

      setState(() {
        _liveKitUrl = credentials.wsUrl;
        _status = '连接中...';
      });

      await _disposeRoom();

      final room = Room();
      final listener = room.createListener();
      _bindRoomEvents(room, listener);

      await room.connect(
        credentials.wsUrl,
        credentials.token,
        roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
      );

      _room = room;
      _roomListener = listener;
      _syncTrackState();
      _didManualDisconnect = false;
      _shouldReconnectOnResume = false;

      await _setCameraEnabled(true, silent: true);
      await _setMicrophoneEnabled(true, silent: true);
      await _prepareAudio(room);

      if (!mounted) {
        return;
      }

      setState(() {
        _status = _participantCount > 1 ? '已连接到 $_roomName' : '已连接，等待远端加入';
      });
    } catch (error) {
      await _disposeRoom();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = '连接失败';
      });
      _showMessage('连接 LiveKit 失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  Future<_LiveKitJoinCredentials> _fetchJoinCredentials() async {
    final normalizedBaseUrl = _tokenServiceUrl.trim().replaceFirst(
      RegExp(r'/$'),
      '',
    );
    final requestUri = Uri.parse('$normalizedBaseUrl/livekit/token');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);

    try {
      final request = await client.postUrl(requestUri);
      request.headers.contentType = ContentType.json;
      request.add(
        utf8.encode(jsonEncode({'room': _roomName, 'identity': _identity})),
      );

      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final responseBody = await utf8.decodeStream(response);
      final decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Token 服务返回格式不正确');
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final errorMessage = (decoded['error'] as String?)?.trim();
        throw HttpException(
          errorMessage?.isNotEmpty == true ? errorMessage! : 'Token 服务请求失败',
        );
      }

      final wsUrl = (decoded['wsUrl'] as String?)?.trim() ?? '';
      final token = (decoded['token'] as String?)?.trim() ?? '';
      if (wsUrl.isEmpty || token.isEmpty) {
        throw const FormatException('Token 服务未返回有效的 wsUrl 或 token');
      }

      return _LiveKitJoinCredentials(wsUrl: wsUrl, token: token);
    } on SocketException catch (error) {
      throw Exception('无法连接 Token 服务（$normalizedBaseUrl）：$error');
    } on TimeoutException {
      throw Exception('请求 Token 服务超时（$normalizedBaseUrl），请检查当前电脑 IP、热点网络和 /status 页面');
    } on FormatException catch (error) {
      throw Exception('Token 服务返回异常：${error.message}');
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _disconnect() async {
    _didManualDisconnect = true;
    _shouldReconnectOnResume = false;
    await _disposeRoom();
    if (!mounted) {
      return;
    }
    setState(() {
      _status = '已断开';
      _cameraEnabled = false;
      _microphoneEnabled = false;
      _audioPlaybackReady = false;
      _localVideoValue = null;
    });
  }

  Future<void> _disposeRoom() async {
    final listener = _roomListener;
    final room = _room;
    _roomListener = null;
    _room = null;
    _localVideoValue = null;

    await listener?.dispose();
    room?.removeListener(_handleRoomChanged);
    await room?.dispose();
  }

  void _handleLocalVideoValueChanged(rtc.RTCVideoValue value) {
    if (!mounted) {
      return;
    }

    if (_localVideoValue?.width == value.width &&
        _localVideoValue?.height == value.height &&
        _localVideoValue?.rotation == value.rotation &&
        _localVideoValue?.renderVideo == value.renderVideo) {
      return;
    }

    setState(() {
      _localVideoValue = value;
    });
  }

  void _bindRoomEvents(Room room, EventsListener<RoomEvent> listener) {
    listener
      ..on<RoomConnectedEvent>((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _status = '房间连接成功';
        });
      })
      ..on<RoomDisconnectedEvent>((event) async {
        if (!mounted) {
          return;
        }
        setState(() {
          _status = event.reason == null ? '房间已断开' : '房间已断开: ${event.reason}';
          _cameraEnabled = false;
          _microphoneEnabled = false;
          _audioPlaybackReady = false;
        });
      })
      ..on<ParticipantConnectedEvent>((_) {
        _handleRoomChanged();
        if (mounted) {
          setState(() {
            _status = '远端已加入，音视频同步中';
          });
        }
      })
      ..on<ParticipantDisconnectedEvent>((_) => _handleRoomChanged())
      ..on<TrackSubscribedEvent>((event) async {
        _handleRoomChanged();
        if (event.track is RemoteAudioTrack) {
          await _prepareAudio(room);
          if (mounted) {
            setState(() {
              _status = '远端音频已接入';
            });
          }
        }
      })
      ..on<AudioPlaybackStatusChanged>((event) {
        if (!mounted) {
          return;
        }
        setState(() {
          _audioPlaybackReady = event.isPlaying;
          if (event.isPlaying && _participantCount > 1) {
            _status = '音频播放链路已就绪';
          }
        });
      })
      ..on<ParticipantEvent>((_) => _handleRoomChanged())
      ..on<LocalTrackPublishedEvent>((_) => _handleRoomChanged())
      ..on<LocalTrackUnpublishedEvent>((_) => _handleRoomChanged());
  }

  Future<void> _prepareAudio(Room room) async {
    try {
      await room.setSpeakerOn(true);
    } catch (_) {}

    try {
      await room.startAudio();
    } catch (_) {}

    if (!mounted) {
      return;
    }

    setState(() {
      _audioPlaybackReady = true;
    });
  }

  Future<void> _handleAppBackgrounded() async {
    if (_isConnecting || !_isConnected || _didManualDisconnect) {
      return;
    }

    _shouldReconnectOnResume = true;
    await _disposeRoom();
    if (!mounted) {
      return;
    }

    setState(() {
      _status = '应用已挂起，连接暂停';
      _cameraEnabled = false;
      _microphoneEnabled = false;
      _audioPlaybackReady = false;
    });
  }

  void _handleAppResumed() {
    if (!_shouldReconnectOnResume || _didManualDisconnect || _isConnecting) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted ||
          !_isPreviewRouteCurrent ||
          _isConnected ||
          _isConnecting) {
        return;
      }
      setState(() {
        _status = '应用恢复，尝试重连...';
      });
      await _connect();
    });
  }

  bool get _isPreviewRouteCurrent => ModalRoute.of(context)?.isCurrent ?? true;

  void _handleRoomChanged() {
    if (!mounted) {
      return;
    }
    setState(_syncTrackState);
  }

  void _syncTrackState() {
    final participant = _room?.localParticipant;
    if (participant == null) {
      _cameraEnabled = false;
      _microphoneEnabled = false;
      return;
    }

    _cameraEnabled = false;
    for (final publication in participant.videoTrackPublications) {
      if (!publication.isScreenShare && publication.track != null) {
        _cameraEnabled = !publication.muted;
        break;
      }
    }

    _microphoneEnabled = false;
    for (final publication in participant.audioTrackPublications) {
      if (publication.track != null) {
        _microphoneEnabled = !publication.muted;
        break;
      }
    }
  }

  Future<void> _setCameraEnabled(bool enabled, {bool silent = false}) async {
    final participant = _room?.localParticipant;
    if (participant == null) {
      if (!silent) {
        _showMessage('请先连接房间');
      }
      return;
    }

    try {
      await participant.setCameraEnabled(enabled);
      if (!mounted) {
        return;
      }
      setState(() {
        _cameraEnabled = enabled;
      });
    } catch (error) {
      if (!silent) {
        _showMessage('切换摄像头失败：$error');
      }
    }
  }

  Future<void> _setMicrophoneEnabled(
    bool enabled, {
    bool silent = false,
  }) async {
    final participant = _room?.localParticipant;
    if (participant == null) {
      if (!silent) {
        _showMessage('请先连接房间');
      }
      return;
    }

    try {
      await participant.setMicrophoneEnabled(enabled);
      if (!mounted) {
        return;
      }
      setState(() {
        _microphoneEnabled = enabled;
      });
    } catch (error) {
      if (!silent) {
        _showMessage('切换麦克风失败：$error');
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  LocalVideoTrack? get _localVideoTrack {
    final participant = _room?.localParticipant;
    if (participant == null) {
      return null;
    }

    for (final publication in participant.videoTrackPublications) {
      final track = publication.track;
      if (!publication.isScreenShare && track != null) {
        return track;
      }
    }
    return null;
  }

  int get _participantCount {
    if (!_isConnected) {
      return 0;
    }
    return (_room?.remoteParticipants.length ?? 0) + 1;
  }

  String get _displayStatus {
    final suffix = _liveKitUrl.isEmpty ? '' : ' · $_roomName';
    if (_participantCount <= 1 && _audioPlaybackReady) {
      return '$_status · 音频链路就绪$suffix';
    }
    return '$_status$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final statusText = _displayStatus;

    return Scaffold(
      appBar: AppBar(title: const Text('LiveKit OHOS Demo')),
      body: Column(
        children: [
          Expanded(
            child: LiveKitPreviewWidget(
              videoTrack: _localVideoTrack,
              isConnected: _isConnected,
              status: statusText,
              diagnosticValue: _localVideoValue,
              onVideoValueChanged: _handleLocalVideoValueChanged,
            ),
          ),
          LiveKitTabBarWidget(
            status: statusText,
            participantCount: _participantCount,
            cameraEnabled: _cameraEnabled,
            microphoneEnabled: _microphoneEnabled,
            onConfigPressed: _openConfigPage,
            onDisconnectPressed: _disconnect,
            disconnectEnabled: _isConnected,
            isConnecting: _isConnecting,
          ),
        ],
      ),
    );
  }
}

class _LiveKitJoinCredentials {
  const _LiveKitJoinCredentials({required this.wsUrl, required this.token});

  final String wsUrl;
  final String token;
}

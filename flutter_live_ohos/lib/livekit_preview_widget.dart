import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';

class LiveKitPreviewWidget extends StatelessWidget {
  const LiveKitPreviewWidget({
    super.key,
    required this.videoTrack,
    required this.isConnected,
    required this.status,
    required this.diagnosticValue,
    required this.onVideoValueChanged,
  });

  final LocalVideoTrack? videoTrack;
  final bool isConnected;
  final String status;
  final rtc.RTCVideoValue? diagnosticValue;
  final ValueChanged<rtc.RTCVideoValue> onVideoValueChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [Color(0xFF052E2B), Color(0xFF0F766E), Color(0xFF9BD8D2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (videoTrack != null)
                DecoratedBox(
                  decoration: const BoxDecoration(color: Colors.black),
                  child: SizedBox.expand(
                    child: VideoTrackRenderer(
                      videoTrack!,
                      onVideoValueChanged: onVideoValueChanged,
                    ),
                  ),
                )
              else
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.videocam_off_rounded,
                            size: 64,
                            color: Colors.white.withValues(alpha: 0.88),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isConnected ? '已连接，等待本地预览画面' : '预览视图',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isConnected ? status : '点击下方“参数配置”进入配置页并连接房间',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.86),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 16,
                top: 16,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.36),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      status,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: _DiagnosticOverlay(
                  diagnosticValue: diagnosticValue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiagnosticOverlay extends StatelessWidget {
  const _DiagnosticOverlay({required this.diagnosticValue});

  final rtc.RTCVideoValue? diagnosticValue;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        final viewportHeight = constraints.maxHeight;
        final viewportPortrait = viewportHeight >= viewportWidth;
        final metrics = diagnosticValue;

        String formatDouble(double value) {
          if (!value.isFinite) {
            return '-';
          }
          return value.toStringAsFixed(2);
        }

        final frameWidth = metrics?.width ?? 0;
        final frameHeight = metrics?.height ?? 0;
        final frameAspectRatio = frameWidth > 0 && frameHeight > 0
            ? frameWidth / frameHeight
            : 1.0;
        final rotatedAspectRatio = metrics?.aspectRatio ?? 1.0;
        final displayAspectRatio = _resolvedDisplayAspectRatio(
          constraints: constraints,
          value: metrics,
        );

        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: DefaultTextStyle(
              style: Theme.of(context).textTheme.labelSmall!.copyWith(
                color: Colors.white,
                fontFamily: 'monospace',
                height: 1.35,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('渲染诊断'),
                  const SizedBox(height: 4),
                  Text(
                    'viewport: ${viewportWidth.toStringAsFixed(0)} x ${viewportHeight.toStringAsFixed(0)}'
                    ' (${viewportPortrait ? 'portrait' : 'landscape'})',
                  ),
                  Text(
                    'frame: ${frameWidth.toStringAsFixed(0)} x ${frameHeight.toStringAsFixed(0)}'
                    ' | rot=${metrics?.rotation ?? 0}',
                  ),
                  Text(
                    'frameAR=${formatDouble(frameAspectRatio)}'
                    ' rotatedAR=${formatDouble(rotatedAspectRatio)}',
                  ),
                  Text('displayAR=${formatDouble(displayAspectRatio)}'),
                  Text('renderVideo=${metrics?.renderVideo ?? false}'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  double _resolvedDisplayAspectRatio({
    required BoxConstraints constraints,
    required rtc.RTCVideoValue? value,
  }) {
    if (value == null || value.width <= 0 || value.height <= 0) {
      return 1.0;
    }

    final rotatedAspectRatio = value.aspectRatio;
    final frameAspectRatio = value.width / value.height;

    if (!rtc.WebRTC.platformIsOhos) {
      return rotatedAspectRatio;
    }

    final viewportIsPortrait = constraints.maxHeight >= constraints.maxWidth;
    final rotatedIsPortrait = rotatedAspectRatio < 1;
    final frameIsPortrait = frameAspectRatio < 1;

    if (rotatedIsPortrait != frameIsPortrait) {
      if (rotatedIsPortrait == viewportIsPortrait) {
        return rotatedAspectRatio;
      }
      if (frameIsPortrait == viewportIsPortrait) {
        return frameAspectRatio;
      }
    }

    return rotatedAspectRatio;
  }
}

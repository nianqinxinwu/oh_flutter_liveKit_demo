import 'package:flutter/material.dart';

class LiveKitTabBarWidget extends StatelessWidget {
  const LiveKitTabBarWidget({
    super.key,
    required this.status,
    required this.participantCount,
    required this.cameraEnabled,
    required this.microphoneEnabled,
    required this.onConfigPressed,
    required this.onDisconnectPressed,
    required this.disconnectEnabled,
    required this.isConnecting,
  });

  final String status;
  final int participantCount;
  final bool cameraEnabled;
  final bool microphoneEnabled;
  final VoidCallback onConfigPressed;
  final VoidCallback onDisconnectPressed;
  final bool disconnectEnabled;
  final bool isConnecting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.outlineVariant,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: isConnecting ? null : onConfigPressed,
                      child: Text(isConnecting ? '连接中...' : '参数配置'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: disconnectEnabled ? onDisconnectPressed : null,
                      child: const Text('断开连接'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusChip(
                    label: '状态',
                    value: status,
                  ),
                  _StatusChip(
                    label: '参与者',
                    value: '$participantCount',
                  ),
                  _StatusChip(
                    label: '摄像头',
                    value: cameraEnabled ? '开启' : '关闭',
                    highlighted: cameraEnabled,
                  ),
                  _StatusChip(
                    label: '麦克风',
                    value: microphoneEnabled ? '开启' : '关闭',
                    highlighted: microphoneEnabled,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  final String label;
  final String value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: highlighted
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: RichText(
          text: TextSpan(
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurface,
            ),
            children: [
              TextSpan(
                text: '$label: ',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              TextSpan(text: value),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/talq_controller.dart';
import '../theme/talq_theme.dart';
import 'rooms_list_view.dart';
import 'shared_widgets.dart';

/// Wraps a child widget and shows a slide-down notification banner
/// when a new agent message arrives and the chat view isn't open.
///
/// Place this below [TalqSdkScope] in the widget tree — it's automatically
/// included when you use [TalqSdkScope].
class TalqInAppNotification extends StatefulWidget {
  final Widget child;

  const TalqInAppNotification({super.key, required this.child});

  @override
  State<TalqInAppNotification> createState() => _TalqInAppNotificationState();
}

class _TalqInAppNotificationState extends State<TalqInAppNotification>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  TalqMessage? _currentMessage;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeIn,
    ));
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onTap(BuildContext context, TalqController controller) {
    controller.dismissNotification();
    _animController.reverse();

    final theme = controller.theme;
    final roomId = _currentMessage?.roomId;

    if (roomId != null) {
      controller.fetchMessages(roomId: roomId);
    }

    // Navigate to chat — use the nearest Navigator (from MaterialApp)
    final navigator = Navigator.maybeOf(context);
    if (navigator != null) {
      navigator.push(
        TalqPageRoute(
          builder: (context) => RoomsListView(theme: theme),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          widget.child,
          Consumer<TalqController>(
            builder: (context, controller, _) {
              final notification = controller.pendingNotification;

              if (notification != null && notification != _currentMessage) {
                _currentMessage = notification;
                _animController.forward(from: 0);
              } else if (notification == null && _currentMessage != null) {
                _animController.reverse().then((_) {
                  if (mounted) {
                    setState(() => _currentMessage = null);
                  }
                });
              }

              if (_currentMessage == null) return const SizedBox.shrink();

              final theme = controller.theme;

              return Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: _NotificationBanner(
                    message: _currentMessage!,
                    theme: theme,
                    senderName: _currentMessage!.senderName,
                    onTap: () => _onTap(context, controller),
                    onDismiss: () {
                      controller.dismissNotification();
                      _animController.reverse();
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NotificationBanner extends StatelessWidget {
  final TalqMessage message;
  final TalqTheme theme;
  final String? senderName;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationBanner({
    required this.message,
    required this.theme,
    required this.senderName,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.maybePaddingOf(context)?.top ?? 44;

    return GestureDetector(
      onTap: onTap,
      onVerticalDragEnd: (details) {
        if (details.velocity.pixelsPerSecond.dy < -100) {
          onDismiss();
        }
      },
      child: Container(
        padding: EdgeInsets.only(top: topPadding + 8, bottom: 12),
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: theme.surfaceColor,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    _getInitial(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      senderName ?? 'Support',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        package: 'talq_sdk',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.titleStyle.color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _previewText(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        package: 'talq_sdk',
                        fontSize: 13,
                        color: theme.subtitleStyle.color,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Close
              GestureDetector(
                onTap: onDismiss,
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: theme.subtitleStyle.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getInitial() {
    if (senderName != null && senderName!.isNotEmpty) {
      return senderName![0].toUpperCase();
    }
    return 'S';
  }

  String _previewText() {
    if (message.contentType == ContentType.image) return '📷 Photo';
    if (message.contentType == ContentType.pdf) return '📎 Document';
    return message.content;
  }
}

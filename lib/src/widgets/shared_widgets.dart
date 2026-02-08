import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/livechat_theme.dart';

class LivechatAvatar extends StatelessWidget {
  final String? imageUrl;
  final SenderType senderType;
  final double radius;
  final bool isFaded;

  const LivechatAvatar({
    super.key,
    this.imageUrl,
    this.senderType = SenderType.agent,
    this.radius = 16,
    this.isFaded = false,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null) {
      IconData icon;
      switch (senderType) {
        case SenderType.bot:
          icon = Icons.smart_toy_outlined;
          break;
        case SenderType.agent:
          icon = Icons.person;
          break;
        case SenderType.system:
          icon = Icons.info_outline;
          break;
        default:
          icon = Icons.person;
      }

      return CircleAvatar(
        radius: radius,
        backgroundColor: isFaded ? Colors.grey[100] : Colors.grey[200],
        child: Icon(
          icon,
          size: radius * 0.9,
          color: isFaded ? Colors.grey[300] : Colors.grey[400],
        ),
      );
    }

    return ClipOval(
      child: Opacity(
        opacity: isFaded ? 0.5 : 1.0,
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: radius * 2,
            height: radius * 2,
            color: Colors.grey[200],
            child: Icon(
              senderType == SenderType.bot
                  ? Icons.smart_toy_outlined
                  : Icons.support_agent,
              size: radius * 0.9,
              color: Colors.grey[400],
            ),
          ),
          errorWidget: (context, url, error) {
            return Container(
              width: radius * 2,
              height: radius * 2,
              color: Colors.grey[200],
              child: Icon(
                senderType == SenderType.bot
                    ? Icons.smart_toy_outlined
                    : Icons.support_agent,
                size: radius * 0.9,
                color: Colors.grey[400],
              ),
            );
          },
        ),
      ),
    );
  }
}

class MessageStatusTicks extends StatelessWidget {
  final bool isRead;
  final bool isDelivered;
  final double size;
  final LivechatTheme theme;

  const MessageStatusTicks({
    super.key,
    required this.isRead,
    required this.isDelivered,
    this.size = 14,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (isRead) {
      return Icon(Icons.done_all, size: size, color: theme.readTickColor);
    } else if (isDelivered) {
      return Icon(Icons.done_all, size: size, color: theme.deliveredTickColor);
    } else {
      return Icon(Icons.done, size: size, color: theme.sentTickColor);
    }
  }
}

class StatusBadge extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final Color textColor;

  const StatusBadge({
    super.key,
    required this.text,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}

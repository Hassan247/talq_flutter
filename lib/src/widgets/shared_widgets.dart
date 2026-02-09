import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/models.dart';
import '../theme/livechat_theme.dart';

class LivechatAvatar extends StatelessWidget {
  final String? imageUrl;
  final SenderType senderType;
  final double radius;
  final bool isFaded;
  final LivechatTheme theme;
  final Color? borderColor;
  final double borderWidth;

  const LivechatAvatar({
    super.key,
    this.imageUrl,
    this.senderType = SenderType.agent,
    this.radius = 16,
    this.isFaded = false,
    this.theme = const LivechatTheme(),
    this.borderColor,
    this.borderWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    Widget avatar;
    if (imageUrl == null) {
      if (senderType == SenderType.bot) {
        avatar = Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            color: theme.avatarBackgroundColor,
            shape: BoxShape.circle,
          ),
          clipBehavior: Clip.antiAlias,
          child: SvgPicture.asset(
            'assets/icons/bot-avatar.svg',
            package: 'livechat_sdk',
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
          ),
        );
      } else {
        IconData icon;
        switch (senderType) {
          case SenderType.agent:
            icon = Icons.person;
            break;
          case SenderType.system:
            icon = Icons.info_outline;
            break;
          default:
            icon = Icons.person;
        }

        avatar = CircleAvatar(
          radius: radius,
          backgroundColor: theme.avatarBackgroundColor,
          child: Icon(icon, size: radius * 0.9, color: theme.avatarIconColor),
        );
      }
    } else {
      avatar = ClipOval(
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
              color: theme.avatarBackgroundColor,
              child: senderType == SenderType.bot
                  ? SvgPicture.asset(
                      'assets/icons/bot-avatar.svg',
                      package: 'livechat_sdk',
                      width: radius * 2,
                      height: radius * 2,
                      fit: BoxFit.cover,
                    )
                  : Icon(
                      Icons.support_agent,
                      size: radius * 0.9,
                      color: theme.avatarIconColor,
                    ),
            ),
            errorWidget: (context, url, error) {
              return Container(
                width: radius * 2,
                height: radius * 2,
                color: theme.avatarBackgroundColor,
                child: senderType == SenderType.bot
                    ? SvgPicture.asset(
                        'assets/icons/bot-avatar.svg',
                        package: 'livechat_sdk',
                        width: radius * 2,
                        height: radius * 2,
                        fit: BoxFit.cover,
                      )
                    : Icon(
                        Icons.support_agent,
                        size: radius * 0.9,
                        color: theme.avatarIconColor,
                      ),
              );
            },
          ),
        ),
      );
    }

    if (borderColor != null) {
      return Container(
        padding: EdgeInsets.all(borderWidth),
        decoration: BoxDecoration(color: borderColor, shape: BoxShape.circle),
        child: avatar,
      );
    }

    return avatar;
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

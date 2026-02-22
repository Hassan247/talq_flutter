import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/livechat_controller.dart';
import '../theme/livechat_theme.dart';
import 'chat_view.dart';
import 'shared_widgets.dart';

class MessagesListView extends StatelessWidget {
  final LivechatTheme? theme;

  const MessagesListView({super.key, this.theme});

  @override
  Widget build(BuildContext context) {
    return Consumer<LivechatController>(
      builder: (context, controller, child) {
        // use controller's reactive theme, fall back to provided theme
        final activeTheme = theme ?? controller.theme;

        return Scaffold(
          backgroundColor: activeTheme.backgroundColor,
          appBar: AppBar(
            systemOverlayStyle: SystemUiOverlayStyle.dark,
            backgroundColor: activeTheme.backgroundColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: SvgPicture.asset(
                'assets/icons/arrow-left.svg',
                package: 'livechat_sdk',
                colorFilter: ColorFilter.mode(
                  activeTheme.titleStyle.color!,
                  BlendMode.srcIn,
                ),
                width: 20, // Slightly larger for better touch target
                height: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            centerTitle: true,
            title: Text(
              'Messages',
              style: activeTheme.titleStyle.copyWith(
                fontSize: 17, // Standard iOS-like header size
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          body: Builder(
            builder: (context) {
              if (controller.isLoading && controller.rooms.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (controller.rooms.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 48,
                        color: activeTheme.subtitleStyle.color?.withOpacity(
                          0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No messages yet',
                        style: activeTheme.subtitleStyle.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount: controller.rooms.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final room = controller.rooms[index];
                  return _MessageCard(
                    room: room,
                    workspace: controller.workspace,
                    theme: activeTheme,
                    onTap: () async {
                      await controller.fetchMessages(roomId: room.id);
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LivechatView(),
                          ),
                        );
                      }
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _MessageCard extends StatelessWidget {
  final LivechatRoom room;
  final LivechatWorkspace? workspace;
  final LivechatTheme theme;
  final VoidCallback onTap;

  const _MessageCard({
    required this.room,
    this.workspace,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final lastMsg = room.lastMessage;
    final hasUnread = room.visitorUnreadCount > 0;

    final isMe = lastMsg?.senderType == SenderType.visitor;
    final isBot = lastMsg?.senderType == SenderType.bot;
    final displayName = isBot
        ? 'Assistant'
        : (room.assigneeName ?? workspace?.name ?? 'Support Team');
    final avatarUrl = isBot
        ? null
        : (room.assigneeAvatarUrl ?? workspace?.logoUrl);

    final timeStr = room.lastMessageAt != null
        ? DateFormat('jm').format(room.lastMessageAt!)
        : '';

    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(20), // Slightly clearer radius
        border: Border.all(
          color: theme.cardShadowColor.withOpacity(0.08), // Subtle border
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.cardShadowColor.withOpacity(
              0.04,
            ), // Very subtle shadow
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar Area
                _buildAvatar(displayName, avatarUrl, hasUnread),
                const SizedBox(width: 16),

                // Content Area
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Header Row: Message Content (Primary)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: _buildMessageTitle(lastMsg, hasUnread),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Subtitle Row: Name • Time
                      Row(
                        children: [
                          if (isMe && lastMsg != null) ...[
                            _buildTicks(lastMsg),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${isMe ? 'You' : displayName} • ',
                                    style: theme.subtitleStyle.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: theme.subtitleStyle.color,
                                    ),
                                  ),
                                  TextSpan(
                                    text: timeStr,
                                    style: theme.subtitleStyle.copyWith(
                                      color: hasUnread
                                          ? theme.primaryColor
                                          : theme.subtitleStyle.color,
                                      fontWeight: hasUnread
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (room.status == RoomStatus.resolved)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.resolvedBackgroundColor
                                      .withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: theme.resolvedTextColor.withOpacity(
                                      0.1,
                                    ),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  'Resolved',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: theme.resolvedTextColor.withOpacity(
                                      0.8,
                                    ),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String name, String? url, bool hasUnread) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.surfaceColor, // seamless blend
              width: 0,
            ),
          ),
          child: LivechatAvatar(
            imageUrl: url,
            senderType: SenderType.agent, // Default to agent style for the list
            radius: 24, // Slightly larger avatar
            theme: theme,
          ),
        ),
        if (hasUnread)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              height: 22,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              constraints: const BoxConstraints(minWidth: 22),
              decoration: BoxDecoration(
                color: theme.primaryColor,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: theme.surfaceColor, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  room.visitorUnreadCount > 9
                      ? '9+'
                      : '${room.visitorUnreadCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMessageTitle(LivechatMessage? msg, bool hasUnread) {
    if (msg == null) {
      return Text(
        'New Conversation',
        style: theme.titleStyle.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: theme.titleStyle.color,
        ),
      );
    }

    final style = theme.titleStyle.copyWith(
      fontSize: 16,
      fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600,
      color: hasUnread
          ? theme.titleStyle.color
          : theme.titleStyle.color?.withOpacity(0.85),
      letterSpacing: -0.4,
      height: 1.2,
    );

    IconData? icon;
    String label = '';
    String content = msg.content;

    if (msg.contentType == ContentType.image) {
      icon = Icons.photo_camera_outlined;
      label = 'Photo';
    } else if (msg.contentType == ContentType.pdf) {
      icon = Icons.description_outlined;
      label = 'Document';
    } else if (msg.content.contains('.m4a') ||
        msg.content.contains('.mp3') ||
        msg.content.contains('.wav')) {
      icon = Icons.mic_none_outlined;
      label = 'Voice note';
      if (content.startsWith('Sent an audio:')) content = '';
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: hasUnread ? theme.primaryColor : theme.titleStyle.color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: style.copyWith(
              fontStyle: FontStyle.italic,
              color: hasUnread ? theme.primaryColor : null,
            ),
          ),
          if (content.isNotEmpty) ...[
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          ],
        ],
      );
    }

    return Text(
      content,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }

  Widget _buildTicks(LivechatMessage message) {
    // ticks are small, keep them subtle
    Color iconColor = theme.sentTickColor;
    IconData icon = Icons.check;

    if (message.isRead) {
      icon = Icons.done_all;
      iconColor = theme.readTickColor;
    } else if (message.isDelivered) {
      icon = Icons.done_all;
      iconColor = theme.deliveredTickColor;
    }

    return Icon(icon, size: 16, color: iconColor);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/livechat_controller.dart';
import '../theme/livechat_theme.dart';
import 'chat_view.dart';

class MessagesListView extends StatelessWidget {
  final LivechatTheme theme;

  const MessagesListView({super.key, this.theme = const LivechatTheme()});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        backgroundColor: theme.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: theme.titleStyle.color,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text('Message', style: theme.titleStyle.copyWith(fontSize: 18)),
      ),
      body: Consumer<LivechatController>(
        builder: (context, controller, child) {
          if (controller.isLoading && controller.rooms.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.rooms.isEmpty) {
            return Center(
              child: Text(
                'No messages yet',
                style: theme.subtitleStyle.copyWith(fontSize: 16),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: controller.rooms.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final room = controller.rooms[index];
              return _MessageCard(
                room: room,
                workspace: controller.workspace,
                theme: theme,
                onTap: () async {
                  await controller.fetchMessages(roomId: room.id);
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LivechatView(theme: theme),
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
    final displayName = room.assigneeName ?? workspace?.name ?? 'Support Team';
    final avatarUrl = room.assigneeAvatarUrl ?? workspace?.logoUrl;

    final timeStr = room.lastMessageAt != null
        ? DateFormat('jm').format(room.lastMessageAt!)
        : '';

    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[200],
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: avatarUrl != null
                      ? Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Icon(
                                Icons.person,
                                color: Colors.grey[400],
                                size: 24,
                              ),
                            );
                          },
                        )
                      : Center(
                          child: Icon(
                            Icons.person,
                            color: Colors.grey[400],
                            size: 24,
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(child: _buildMessagePreview(lastMsg)),
                              ],
                            ),
                          ),
                          if (hasUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: theme.primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                room.visitorUnreadCount > 9
                                    ? '9+'
                                    : '${room.visitorUnreadCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
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
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: hasUnread
                                          ? Colors.black
                                          : theme.subtitleStyle.color,
                                    ),
                                  ),
                                  TextSpan(
                                    text: timeStr,
                                    style: theme.subtitleStyle.copyWith(
                                      color: hasUnread
                                          ? Colors.black87
                                          : theme.subtitleStyle.color,
                                    ),
                                  ),
                                ],
                              ),
                              style: TextStyle(fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (room.status == RoomStatus.resolved)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Resolved',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.green,
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

  Widget _buildMessagePreview(LivechatMessage? msg) {
    if (msg == null) return Text('No messages', style: theme.subtitleStyle);

    final hasUnread = room.visitorUnreadCount > 0;
    final style = theme.titleStyle.copyWith(
      fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
      fontSize: 16,
    );

    IconData? icon;
    String label = '';
    String content = msg.content;

    if (msg.contentType == ContentType.image) {
      icon = Icons.camera_alt;
      label = 'Photo';
      if (content.startsWith('Sent an image:')) content = '';
    } else if (msg.contentType == ContentType.pdf) {
      icon = Icons.insert_drive_file;
      label = 'Document';
      if (content.startsWith('Sent a file:')) content = '';
    } else if (msg.content.contains('.m4a') ||
        msg.content.contains('.mp3') ||
        msg.content.contains('.wav')) {
      icon = Icons.mic;
      label = 'Voice note';
      if (content.startsWith('Sent an audio:')) content = '';
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.subtitleStyle.color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.subtitleStyle.copyWith(
              color: theme.subtitleStyle.color,
              fontSize: 15,
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
    if (message.isRead) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(Icons.done_all, size: 16, color: theme.readTickColor)],
      );
    } else if (message.isDelivered) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.done_all, size: 16, color: theme.deliveredTickColor),
        ],
      );
    } else {
      return Icon(Icons.done, size: 16, color: theme.sentTickColor);
    }
  }
}

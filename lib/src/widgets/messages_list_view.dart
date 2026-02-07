import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/livechat_controller.dart';
import 'chat_view.dart';

class MessagesListView extends StatelessWidget {
  final Color primaryColor;

  const MessagesListView({super.key, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Light grey background
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Message',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
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
                style: TextStyle(color: Colors.grey[400]),
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
                primaryColor: primaryColor,
                onTap: () async {
                  await controller.fetchMessages(roomId: room.id);
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            LivechatView(primaryColor: primaryColor),
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
  final Color primaryColor;
  final VoidCallback onTap;

  const _MessageCard({
    required this.room,
    this.workspace,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final lastMsg = room.lastMessage;
    final hasUnread = room.visitorUnreadCount > 0;

    // Determine sender name and avatar logic
    // If it's the visitor (me), show "YOU".
    // If it's agent, show Agent Name.
    // BUT the prototype shows "Hassan Abdulganiyu", "Yusuf Gani", "YOU".
    // This implies we show the name of the last sender? Or the name of the Agent assigned to the room?
    // Usually a rooms list shows the "other side" (The Agent).
    // However, the prototype has "YOU" as a sender name for some cards.
    // This looks like it might be showing the *Last Message* sender?
    // Wait, standard chat list logic: Show the Room Name (Agent Name) and last message content.
    // If I look at the prototype closely:
    // 1. "Hassan Abdulganiyu" (Avatar) - Msg content...
    // 2. "Yusuf Gani" (Avatar) - Msg content...
    // 3. "YOU" (No Avatar/Placeholder) - Msg content...
    // This strongly suggests it displays the *Sender of the last message*.
    // Which is a bit unusual for a rooms list (usually you want to know who the chat is *with*).
    // But I will follow the prototype "100% exactly".

    final isMe = lastMsg?.senderType == SenderType.visitor;
    final displayName = room.assigneeName ?? workspace?.name ?? 'Support Team';
    final avatarUrl = room.assigneeAvatarUrl ?? workspace?.logoUrl;

    final timeStr = room.lastMessageAt != null
        ? DateFormat('jm').format(room.lastMessageAt!)
        : '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          24,
        ), // Highly rounded corners as per prototype
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
                    image: avatarUrl != null
                        ? DecorationImage(
                            image: NetworkImage(avatarUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: avatarUrl == null
                      ? Icon(Icons.person, color: Colors.grey[400], size: 24)
                      : null,
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
                                if (isMe && lastMsg != null) ...[
                                  _buildTicks(lastMsg),
                                  const SizedBox(width: 4),
                                ],
                                Expanded(
                                  child: Text(
                                    lastMsg?.content ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: hasUnread
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      fontSize: 16,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (hasUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(
                                color: Colors.black,
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
                          Expanded(
                            child: Text(
                              '${isMe ? 'You' : displayName} • $timeStr',
                              style: TextStyle(
                                fontSize: 13,
                                color: hasUnread
                                    ? Colors.black87
                                    : Colors.grey[500],
                              ),
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
                              child: Text(
                                'Resolved',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.green[700],
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

  Widget _buildTicks(LivechatMessage message) {
    if (message.isRead) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: const [Icon(Icons.done_all, size: 16, color: Colors.blue)],
      );
    } else if (message.isDelivered) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: const [Icon(Icons.done_all, size: 16, color: Colors.grey)],
      );
    } else {
      return const Icon(Icons.done, size: 16, color: Colors.grey);
    }
  }
}

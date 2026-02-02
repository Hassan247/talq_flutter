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
  final Color primaryColor;
  final VoidCallback onTap;

  const _MessageCard({
    required this.room,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final lastMsg = room.lastMessage;
    final hasUnread = room.unreadCount > 0;

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
    final senderName = room.assigneeName ?? 'Support Team';
    final avatarUrl = lastMsg?.senderAvatarUrl;

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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[200],
                    image: (avatarUrl != null && !isMe)
                        ? DecorationImage(
                            image: NetworkImage(avatarUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: (isMe || avatarUrl == null)
                      ? Icon(Icons.person, color: Colors.grey[400], size: 30)
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
                        children: [
                          Text(
                            senderName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lastMsg?.content ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ),
                          if (hasUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color:
                                    Colors.black, // Prototype shows black dot
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
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
}

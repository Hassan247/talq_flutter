import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/livechat_controller.dart';
import 'chat_view.dart';

class RoomsListView extends StatefulWidget {
  final Color primaryColor;

  const RoomsListView({super.key, this.primaryColor = Colors.blueAccent});

  @override
  State<RoomsListView> createState() => _RoomsListViewState();
}

class _RoomsListViewState extends State<RoomsListView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LivechatController>().fetchRooms();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: () => context.read<LivechatController>().fetchRooms(),
        child: CustomScrollView(
          slivers: [
            _buildAppBar(context),
            SliverToBoxAdapter(child: _buildNewChatSection(context)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: Consumer<LivechatController>(
                builder: (context, controller, child) {
                  if (controller.isLoading && controller.rooms.isEmpty) {
                    return const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (controller.rooms.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: widget.primaryColor.withOpacity(0.1),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No conversations yet',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final room = controller.rooms[index];
                      return _ConversationListItem(
                        room: room,
                        primaryColor: widget.primaryColor,
                        onTap: () async {
                          await controller.fetchMessages(roomId: room.id);
                          if (mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LivechatView(
                                  primaryColor: widget.primaryColor,
                                ),
                              ),
                            );
                          }
                        },
                      );
                    }, childCount: controller.rooms.length),
                  );
                },
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      backgroundColor: widget.primaryColor,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Messages',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            Consumer<LivechatController>(
              builder: (context, controller, child) {
                final ws = controller.workspace;
                if (ws?.responseTime == null) return const SizedBox.shrink();
                return Text(
                  'We typically reply in ${ws!.responseTime}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.normal,
                  ),
                );
              },
            ),
          ],
        ),
        titlePadding: const EdgeInsetsDirectional.only(start: 56, bottom: 16),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                widget.primaryColor,
                widget.primaryColor.withOpacity(0.8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNewChatSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final controller = context.read<LivechatController>();
            await controller.startNewConversation();
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      LivechatView(primaryColor: widget.primaryColor),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: widget.primaryColor.withOpacity(0.1),
                  child: Icon(Icons.send, color: widget.primaryColor, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Send us a message',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Consumer<LivechatController>(
                        builder: (context, controller, child) {
                          final ws = controller.workspace;
                          return Text(
                            ws?.responseTime != null
                                ? 'We typically reply in ${ws!.responseTime}'
                                : 'We typically reply in minutes',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationListItem extends StatelessWidget {
  final LivechatRoom room;
  final Color primaryColor;
  final VoidCallback onTap;

  const _ConversationListItem({
    required this.room,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = room.unreadCount > 0;
    final lastMsg = room.lastMessage;
    final timeStr = room.lastMessageAt != null
        ? _formatDateTime(room.lastMessageAt!)
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: hasUnread ? primaryColor.withOpacity(0.1) : Colors.transparent,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              _buildAvatar(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Support Team',
                            style: TextStyle(
                              fontWeight: hasUnread
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 12,
                            color: hasUnread ? primaryColor : Colors.grey[400],
                            fontWeight: hasUnread
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lastMsg?.content ?? 'No messages yet',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: hasUnread
                                  ? Colors.black87
                                  : Colors.grey[600],
                              fontSize: 13,
                              fontWeight: hasUnread
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (hasUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              room.unreadCount.toString(),
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final lastMsg = room.lastMessage;
    final isAgent = lastMsg?.senderType == SenderType.agent;
    final avatarUrl = lastMsg?.senderAvatarUrl;

    return Stack(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Colors.grey[100],
          backgroundImage: (isAgent && avatarUrl != null)
              ? NetworkImage(avatarUrl)
              : null,
          child: (!isAgent || avatarUrl == null)
              ? Icon(
                  isAgent ? Icons.support_agent : Icons.person_outline,
                  color: Colors.grey[400],
                  size: 28,
                )
              : null,
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color:
                  room.status == RoomStatus.open ||
                      room.status == RoomStatus.assigned
                  ? Colors.green
                  : Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    if (now.day == dt.day && now.month == dt.month && now.year == dt.year) {
      return DateFormat('jm').format(dt);
    }
    return DateFormat('MMM d').format(dt);
  }
}

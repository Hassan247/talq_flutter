import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/talq_controller.dart';
import '../theme/talq_theme.dart';
import 'chat_view.dart';
import 'live_pull_to_refresh.dart';
import 'shared_widgets.dart';
import 'shimmer_skeleton.dart';

class MessagesListView extends StatefulWidget {
  final TalqTheme? theme;

  const MessagesListView({super.key, this.theme});

  @override
  State<MessagesListView> createState() => _MessagesListViewState();
}

class _MessagesListViewState extends State<MessagesListView> {
  final ScrollController _scrollController = ScrollController();
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = context.read<TalqController>();
      if (controller.rooms.isEmpty && !controller.isLoading) {
        controller.fetchRooms(resetVisibleWindow: true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 240;
    if (_scrollController.position.pixels < threshold) return;

    final controller = context.read<TalqController>();
    if (!controller.isFetchingMoreRooms) {
      controller.fetchMoreRooms();
    }
  }

  Future<void> _handleRefresh(TalqController controller) async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await controller.fetchRooms(resetVisibleWindow: true);
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _openRoom(TalqController controller, TalqRoom room) {
    controller.fetchMessages(roomId: room.id);
    Navigator.push(context, TalqPageRoute(builder: (_) => const TalqView()));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: 'Inter', package: 'talq_sdk'),
      child: Consumer<TalqController>(
        builder: (context, controller, child) {
          final activeTheme = widget.theme ?? controller.theme;
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Scaffold(
            backgroundColor: activeTheme.backgroundColor,
            appBar: AppBar(
              systemOverlayStyle: SystemUiOverlayStyle.dark,
              backgroundColor: activeTheme.backgroundColor,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: BackButton(color: activeTheme.titleStyle.color),
              centerTitle: true,
              title: Text(
                'Messages',
                style: activeTheme.titleStyle.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.25,
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.add_rounded,
                    color: activeTheme.titleStyle.color,
                  ),
                  onPressed: () {
                    controller.prepareNewConversation();
                    Navigator.push(
                      context,
                      TalqPageRoute(builder: (_) => const TalqView()),
                    );
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: Stack(
              children: [
                if (controller.isLoading && controller.rooms.isEmpty)
                  Expanded(
                    child: MessagesListSkeleton(
                      baseColor: activeTheme.primaryColor.withValues(
                        alpha: 0.06,
                      ),
                      highlightColor: activeTheme.primaryColor.withValues(
                        alpha: 0.12,
                      ),
                    ),
                  )
                else if (controller.rooms.isEmpty)
                  _buildEmptyState(activeTheme)
                else
                  LivePullToRefresh(
                    isDark: isDark,
                    isRefreshing: _isRefreshing,
                    progressColor: activeTheme.primaryColor,
                    onRefresh: () => _handleRefresh(controller),
                    child: _buildList(activeTheme, controller),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildList(TalqTheme theme, TalqController controller) {
    final rooms = controller.visibleRooms;
    final showBottomLoader = controller.isFetchingMoreRooms;
    final totalItems = rooms.length + (showBottomLoader ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      physics: LivePullToRefresh.cappedScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      itemCount: totalItems,
      itemBuilder: (context, index) {
        final roomIndex = index;
        if (roomIndex < rooms.length) {
          final room = rooms[roomIndex];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MessageCard(
              room: room,
              workspace: controller.workspace,
              theme: theme,
              onTap: () => _openRoom(controller, room),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: theme.primaryColor,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(TalqTheme theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 46,
                color: theme.primaryColor.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'No conversations yet',
              style: theme.titleStyle.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your messages will appear here.',
              textAlign: TextAlign.center,
              style: theme.subtitleStyle.copyWith(
                fontSize: 14,
                color: theme.subtitleStyle.color?.withValues(alpha: 0.78),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final TalqRoom room;
  final TalqWorkspace? workspace;
  final TalqTheme theme;
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

    // Avatar priority: last agent who messaged → assigned agent → workspace logo
    final String displayName;
    final String? avatarUrl;
    if (isBot) {
      displayName = 'Assistant';
      avatarUrl = null;
    } else if (lastMsg?.senderType == SenderType.agent) {
      displayName =
          lastMsg?.senderName ??
          room.assigneeName ??
          workspace?.name ??
          'Support Team';
      avatarUrl =
          lastMsg?.senderAvatarUrl ??
          room.assigneeAvatarUrl ??
          workspace?.logoUrl;
    } else {
      displayName = room.assigneeName ?? workspace?.name ?? 'Support Team';
      avatarUrl = room.assigneeAvatarUrl ?? workspace?.logoUrl;
    }
    final timeStr = room.lastMessageAt != null
        ? DateFormat('jm').format(room.lastMessageAt!.toLocal())
        : '';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.surfaceColor,
            Color.lerp(theme.surfaceColor, theme.primaryColor, 0.035)!,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.cardShadowColor.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.cardShadowColor.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildAvatar(avatarUrl, hasUnread),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildMessageTitle(lastMsg, hasUnread),
                          ),
                          if (room.status == RoomStatus.resolved)
                            _buildResolvedChip(),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    '${isMe ? 'You' : displayName}${timeStr.isNotEmpty ? ' • $timeStr' : ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.subtitleStyle.copyWith(
                                      fontSize: 13,
                                      fontWeight: hasUnread
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: hasUnread
                                          ? theme.primaryColor
                                          : theme.subtitleStyle.color
                                                ?.withValues(alpha: 0.85),
                                    ),
                                  ),
                                ),
                                if (isMe && lastMsg != null) ...[
                                  const SizedBox(width: 4),
                                  _buildTicks(lastMsg),
                                ],
                              ],
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

  Widget _buildAvatar(String? url, bool hasUnread) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        TalqAvatar(
          imageUrl: url,
          senderType: SenderType.agent,
          radius: 25,
          theme: theme,
        ),
        if (hasUnread)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: theme.primaryColor,
                shape: BoxShape.circle,
                border: Border.all(color: theme.surfaceColor, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildResolvedChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.resolvedBackgroundColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.resolvedTextColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Text(
        'Resolved',
        style: TextStyle(
          fontFamily: 'Inter',
          package: 'talq_sdk',
          color: theme.resolvedTextColor.withValues(alpha: 0.85),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildMessageTitle(TalqMessage? msg, bool hasUnread) {
    if (msg == null) {
      return Text(
        'New Conversation',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.titleStyle.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.45,
        ),
      );
    }

    final baseStyle = theme.titleStyle.copyWith(
      fontSize: 17,
      fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w700,
      color: hasUnread
          ? theme.titleStyle.color
          : theme.titleStyle.color?.withValues(alpha: 0.88),
      letterSpacing: -0.45,
      height: 1.2,
    );

    if (msg.contentType == ContentType.image) {
      return Row(
        children: [
          Icon(
            Icons.photo_camera_outlined,
            size: 16,
            color: theme.primaryColor,
          ),
          const SizedBox(width: 5),
          Text('Photo', style: baseStyle.copyWith(fontStyle: FontStyle.italic)),
        ],
      );
    }

    if (msg.contentType == ContentType.pdf) {
      return Row(
        children: [
          Icon(Icons.description_outlined, size: 16, color: theme.primaryColor),
          const SizedBox(width: 5),
          Text(
            'Document',
            style: baseStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      );
    }

    return Text(
      msg.content,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: baseStyle,
    );
  }

  Widget _buildTicks(TalqMessage message) {
    var icon = Icons.check_rounded;
    var iconColor = theme.sentTickColor;

    if (message.isRead) {
      icon = Icons.done_all_rounded;
      iconColor = theme.readTickColor;
    } else if (message.isDelivered) {
      icon = Icons.done_all_rounded;
      iconColor = theme.deliveredTickColor;
    }

    return Icon(icon, size: 16, color: iconColor);
  }
}

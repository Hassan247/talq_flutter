import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
    final position = _scrollController.position;

    if (position.maxScrollExtent <= 0) return;

    if (position.userScrollDirection == ScrollDirection.idle) return;

    if (position.pixels < position.maxScrollExtent - 240) return;

    final controller = context.read<TalqController>();
    if (controller.isFetchingMoreRooms) return;

    controller.fetchMoreRooms();
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
    Navigator.push(
      context,
      TalqPageRoute(builder: (_) => const TalqView()),
    ).then((_) {
      if (mounted) controller.fetchRooms();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: 'Inter', package: 'talq_flutter'),
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
                    ).then((_) {
                      if (mounted) controller.fetchRooms();
                    });
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
    final isResolved = room.status == RoomStatus.resolved;

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
          workspace?.avatarUrl;
    } else {
      displayName = room.assigneeName ?? workspace?.name ?? 'Support Team';
      avatarUrl = room.assigneeAvatarUrl ?? workspace?.avatarUrl;
    }

    final timeStr = _formatRelativeTime(room.lastMessageAt);

    final titleColor = theme.titleStyle.color ?? Colors.black87;
    final subtitleColor =
        theme.subtitleStyle.color?.withValues(alpha: 0.78) ??
        Colors.grey.shade600;

    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.cardShadowColor.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.cardShadowColor.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                TalqAvatar(
                  imageUrl: avatarUrl,
                  senderType: SenderType.agent,
                  radius: 26,
                  theme: theme,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.titleStyle.copyWith(
                                fontSize: 16,
                                fontWeight: hasUnread
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                                letterSpacing: -0.3,
                                color: titleColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (timeStr.isNotEmpty)
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                package: 'talq_flutter',
                                fontSize: 12,
                                fontWeight: hasUnread
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: hasUnread
                                    ? theme.primaryColor
                                    : subtitleColor,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildPreview(
                              lastMsg,
                              isMe,
                              hasUnread,
                              subtitleColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildTrailingBadge(
                            hasUnread: hasUnread,
                            isResolved: isResolved,
                            unreadCount: room.visitorUnreadCount,
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

  /// WhatsApp-style relative time:
  /// - today → "10:17 PM"
  /// - yesterday → "Yesterday"
  /// - this week → "Monday"
  /// - older → "06/05/26"
  String _formatRelativeTime(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(local.year, local.month, local.day);
    final diffDays = today.difference(that).inDays;

    if (diffDays == 0) return DateFormat('jm').format(local);
    if (diffDays == 1) return 'Yesterday';
    if (diffDays < 7) return DateFormat('EEEE').format(local);
    return DateFormat('dd/MM/yy').format(local);
  }

  /// Builds the message preview line. For attachments, shows an icon + label.
  /// Voice and photos color the icon based on read state (WhatsApp style:
  /// unread/un-played voice notes use the accent colour; opened ones use
  /// the muted subtitle colour).
  Widget _buildPreview(
    TalqMessage? msg,
    bool isMe,
    bool hasUnread,
    Color subtitleColor,
  ) {
    final baseStyle = TextStyle(
      fontFamily: 'Inter',
      package: 'talq_flutter',
      fontSize: 14,
      height: 1.3,
      fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w500,
      color: hasUnread
          ? (theme.titleStyle.color ?? Colors.black87).withValues(alpha: 0.92)
          : subtitleColor,
    );

    if (msg == null) {
      return Text(
        'New conversation',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: baseStyle,
      );
    }

    final accent = hasUnread ? theme.primaryColor : subtitleColor;

    Widget? leadingIcon;
    String? attachmentLabel;

    switch (msg.contentType) {
      case ContentType.image:
        leadingIcon = Icon(Icons.photo_camera_rounded, size: 16, color: accent);
        attachmentLabel = msg.content.trim().isNotEmpty ? msg.content : 'Photo';
        break;
      case ContentType.audio:
        leadingIcon = Icon(Icons.mic_rounded, size: 16, color: accent);
        attachmentLabel = 'Voice message';
        break;
      case ContentType.pdf:
        leadingIcon = Icon(
          Icons.insert_drive_file_rounded,
          size: 16,
          color: accent,
        );
        attachmentLabel = msg.fileName ?? 'Document';
        break;
      default:
        break;
    }

    Widget? ticks;
    if (isMe && msg.contentType == ContentType.text) {
      ticks = _buildTicks(msg);
    }

    if (leadingIcon != null && attachmentLabel != null) {
      return Row(
        children: [
          if (isMe) ...[_buildTicks(msg), const SizedBox(width: 4)],
          leadingIcon,
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              attachmentLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: baseStyle.copyWith(
                color: hasUnread ? accent : subtitleColor,
                fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    }

    if (ticks != null) {
      return Text.rich(
        TextSpan(
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ticks,
              ),
            ),
            TextSpan(text: msg.content),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: baseStyle,
      );
    }
    return Text(
      msg.content,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: baseStyle,
    );
  }

  /// Right-side trailing badge:
  /// - Resolved chip when the room is resolved.
  /// - Green unread count bubble when there are unread messages.
  /// - Empty otherwise.
  Widget _buildTrailingBadge({
    required bool hasUnread,
    required bool isResolved,
    required int unreadCount,
  }) {
    if (isResolved) {
      return _buildResolvedChip();
    }
    if (hasUnread) {
      return Container(
        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: theme.primaryColor,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          unreadCount > 99 ? '99+' : '$unreadCount',
          style: const TextStyle(
            fontFamily: 'Inter',
            package: 'talq_flutter',
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
      );
    }
    return const SizedBox(width: 0, height: 22);
  }

  Widget _buildResolvedChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.resolvedBackgroundColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Resolved',
        style: TextStyle(
          fontFamily: 'Inter',
          package: 'talq_flutter',
          color: theme.resolvedTextColor.withValues(alpha: 0.85),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
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

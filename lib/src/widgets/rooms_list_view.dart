import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../state/livechat_controller.dart';
import '../theme/livechat_theme.dart';
import 'chat_view.dart';
import 'faq_views.dart';
import 'messages_list_view.dart';

class RoomsListView extends StatefulWidget {
  final LivechatTheme theme;

  const RoomsListView({super.key, this.theme = const LivechatTheme()});

  @override
  State<RoomsListView> createState() => _RoomsListViewState();
}

class _RoomsListViewState extends State<RoomsListView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<LivechatController>().fetchRooms();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LivechatController>();
    final theme = controller.theme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: theme.backgroundColor,
        body: Stack(
          children: [
            // 1. Dark Header Background
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).padding.top + 280, // Adjust height
              child: Container(
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(22),
                    bottomRight: Radius.circular(22),
                  ),
                ),
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 24,
                  right: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo + Close Icon Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Logo fallback: livechatLogoUrl ?? logoUrl
                        (controller.workspace?.livechatLogoUrl ??
                                    controller.workspace?.logoUrl) !=
                                null
                            ? Image.network(
                                controller.workspace?.livechatLogoUrl ??
                                    controller.workspace!.logoUrl!,
                                height: 32,
                                errorBuilder: (context, error, stackTrace) =>
                                    SvgPicture.asset(
                                      'assets/images/monosend_logo.svg',
                                      package: 'livechat_sdk',
                                      height: 32,
                                      colorFilter: const ColorFilter.mode(
                                        Colors.white,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                              )
                            : SvgPicture.asset(
                                'assets/images/monosend_logo.svg',
                                package: 'livechat_sdk',
                                height: 32,
                                colorFilter: const ColorFilter.mode(
                                  Colors.white,
                                  BlendMode.srcIn,
                                ),
                              ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    // Title
                    Text(
                      controller.workspace?.welcomeMessage ??
                          'Hello there How can we\nhelp you today?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Scrollable Content overlapping the header
            Positioned.fill(
              top: MediaQuery.of(context).padding.top + 180,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    // Start Conversation Card
                    _buildStartConversationCard(context, theme),
                    const SizedBox(height: 20),
                    // Messages Section
                    _buildMessagesSection(context, theme),
                    const SizedBox(height: 24),
                    _buildHelpResources(context, theme),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartConversationCard(
    BuildContext context,
    LivechatTheme theme,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: widget.theme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Start a conversation',
            style: widget.theme.titleStyle.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Avatar Stack
              SizedBox(
                width: 90,
                height: 40,
                child: Consumer<LivechatController>(
                  builder: (context, controller, _) {
                    final avatars = controller.workspace?.agentAvatars ?? [];
                    return Stack(
                      children: [
                        _buildAvatar(
                          0,
                          imageUrl: avatars.isNotEmpty ? avatars[0] : null,
                          isFaded: avatars.isEmpty,
                        ),
                        _buildAvatar(
                          25,
                          imageUrl: avatars.length > 1 ? avatars[1] : null,
                          isFaded: avatars.length < 2,
                        ),
                        _buildAvatar(
                          50,
                          imageUrl: avatars.length > 2 ? avatars[2] : null,
                          isFaded: avatars.length < 3,
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Consumer<LivechatController>(
                  builder: (context, controller, _) {
                    // hide response time section if toggle is off
                    if (controller.workspace?.showResponseTime != true) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Our usual reply time',
                          style: widget.theme.subtitleStyle.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_filled,
                              size: 16,
                              color: widget.theme.titleStyle.color,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                controller.workspace?.responseTime ??
                                    'A few minutes',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: widget.theme.titleStyle.copyWith(
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // CTA Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                final controller = context.read<LivechatController>();
                controller.prepareNewConversation();
                // defer navigation to next frame to ensure state has propagated
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LivechatView(
                          theme: widget.theme,
                          isNewConversation: true,
                        ),
                      ),
                    );
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send_rounded, size: 18),
                  SizedBox(width: 12),
                  Text(
                    'Start new conversation',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(double left, {String? imageUrl, bool isFaded = false}) {
    return Positioned(
      left: left,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: widget.theme.surfaceColor,
          shape: BoxShape.circle,
        ),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: isFaded ? Colors.grey[100] : Colors.grey[300],
          backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
          child: imageUrl == null
              ? Icon(
                  Icons.person,
                  size: 20,
                  color: isFaded ? Colors.grey[300] : Colors.grey[500],
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildMessagesSection(BuildContext context, LivechatTheme theme) {
    return Container(
      decoration: BoxDecoration(
        color: widget.theme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MessagesListView(theme: widget.theme),
              ),
            );
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.primaryColor,
                  radius: 20,
                  child: const Icon(
                    Icons.chat_bubble,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Messages',
                    style: widget.theme.titleStyle.copyWith(fontSize: 16),
                  ),
                ),
                Consumer<LivechatController>(
                  builder: (context, controller, _) {
                    final unreadTotal = controller.rooms.fold<int>(
                      0,
                      (sum, room) => sum + room.visitorUnreadCount,
                    );

                    if (unreadTotal == 0) return const SizedBox.shrink();

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBECEB), // Light red bg
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$unreadTotal unread',
                        style: const TextStyle(
                          color: Color(0xFFD3453D), // Red text
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHelpResources(BuildContext context, LivechatTheme theme) {
    return Consumer<LivechatController>(
      builder: (context, controller, _) {
        final faqs = controller.faqs;
        if (faqs.isEmpty) {
          return const SizedBox.shrink();
        }
        final displayFaqs = faqs.take(4).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Help & Resources',
              style: widget.theme.titleStyle.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: widget.theme.surfaceColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  ...displayFaqs.asMap().entries.map((entry) {
                    final index = entry.key;
                    final faq = entry.value;
                    return Column(
                      children: [
                        if (index > 0)
                          const Divider(
                            height: 1,
                            indent: 20,
                            endIndent: 20,
                            color: Color(0xFFEEEEEE),
                          ),
                        _buildResourceItem(
                          faq.question,
                          Icons.description_outlined,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FAQDetailView(
                                  faq: faq,
                                  theme: widget.theme,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  }),
                  if (faqs.length > 4) ...[
                    const Divider(
                      height: 1,
                      indent: 20,
                      endIndent: 20,
                      color: Color(0xFFEEEEEE),
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      title: Text(
                        'See more articles',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: theme.primaryColor,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: theme.primaryColor,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FAQListView(theme: widget.theme),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildResourceItem(
    String title,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: widget.theme.subtitleStyle.color, size: 20),
      ),
      title: Text(
        title,
        style: widget.theme.bodyStyle.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}

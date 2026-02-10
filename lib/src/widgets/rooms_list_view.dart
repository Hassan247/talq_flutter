import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../state/livechat_controller.dart';
import '../theme/livechat_theme.dart';
import 'faq_list_section.dart';
import 'messages_list_view.dart';
import 'start_conversation_card.dart';

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
              height: MediaQuery.of(context).padding.top + 320,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.primaryColor,
                      Color.lerp(theme.primaryColor, Colors.black, 0.15)!,
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 4,
                  left: 24,
                  right: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        (controller.workspace?.livechatLogoUrl ??
                                    controller.workspace?.logoUrl) !=
                                null
                            ? CachedNetworkImage(
                                imageUrl:
                                    controller.workspace?.livechatLogoUrl ??
                                    controller.workspace!.logoUrl!,
                                height: 36,
                                errorWidget: (context, url, error) =>
                                    SvgPicture.asset(
                                      'assets/images/monosend_logo.svg',
                                      package: 'livechat_sdk',
                                      height: 36,
                                      colorFilter: const ColorFilter.mode(
                                        Colors.white,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.forum_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Glint',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),
                    Builder(
                      builder: (context) {
                        final welcome = controller.workspace?.welcomeMessage;
                        final hasWelcome =
                            welcome != null && welcome.isNotEmpty;
                        final text = hasWelcome
                            ? welcome
                            : 'Hello there!\nHow can we help today?';

                        final parts = text.split('\n');
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              parts[0],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                                letterSpacing: -0.8,
                              ),
                            ),
                            if (parts.length > 1)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  parts.sublist(1).join('\n'),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 26,
                                    fontWeight: FontWeight.w500,
                                    height: 1.2,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // 2. Scrollable Content overlapping the header
            Positioned.fill(
              top: MediaQuery.of(context).padding.top + 220,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    // Start Conversation Card
                    StartConversationCard(theme: theme, controller: controller),
                    const SizedBox(height: 20),
                    // Messages Section
                    _buildMessagesSection(context, theme),
                    const SizedBox(height: 24),
                    FAQListSection(theme: theme),
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

  Widget _buildMessagesSection(BuildContext context, LivechatTheme theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.cardShadowColor.withOpacity(0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.cardShadowColor.withOpacity(0.04),
            blurRadius: 12,
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
              MaterialPageRoute(builder: (_) => const MessagesListView()),
            );
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.primaryColor.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SvgPicture.asset(
                    'assets/icons/messages.svg',
                    package: 'livechat_sdk',
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                    width: 20,
                    height: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Messages',
                    style: theme.titleStyle.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
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
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.unreadBadgeColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$unreadTotal unread',
                        style: TextStyle(
                          color: theme.unreadTextColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.subtitleStyle.color?.withOpacity(0.3),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

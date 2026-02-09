import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../state/livechat_controller.dart';
import '../theme/livechat_theme.dart';
import 'faq_list_section.dart';
import 'messages_list_view.dart';
import 'shared_widgets.dart';
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
                            ? CachedNetworkImage(
                                imageUrl:
                                    controller.workspace?.livechatLogoUrl ??
                                    controller.workspace!.logoUrl!,
                                height: 32,
                                errorWidget: (context, url, error) =>
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
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.forum_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Glint',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
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
                    // Title
                    Builder(
                      builder: (context) {
                        final welcome = controller.workspace?.welcomeMessage;
                        final hasWelcome =
                            welcome != null && welcome.isNotEmpty;
                        return Text(
                          hasWelcome
                              ? welcome
                              : 'Welcome!\nHow can we help today?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        );
                      },
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
        color: widget.theme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.cardShadowColor,
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: theme.primaryColor,
                  radius: 20,
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

                    return StatusBadge(
                      text: '$unreadTotal unread',
                      backgroundColor: theme.unreadBadgeColor,
                      textColor: theme.unreadTextColor,
                    );
                  },
                ),
                const SizedBox(width: 8),
                SvgPicture.asset(
                  'assets/icons/arrow-right.svg',
                  package: 'livechat_sdk',
                  colorFilter: ColorFilter.mode(
                    theme.avatarIconColor,
                    BlendMode.srcIn,
                  ),
                  width: 14,
                  height: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

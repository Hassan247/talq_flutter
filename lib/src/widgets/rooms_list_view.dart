import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../state/talq_controller.dart';
import '../theme/talq_theme.dart';
import 'faq_list_section.dart';
import 'messages_list_view.dart';
import 'start_conversation_card.dart';

class RoomsListView extends StatefulWidget {
  final TalqTheme theme;

  const RoomsListView({super.key, this.theme = const TalqTheme()});

  @override
  State<RoomsListView> createState() => _RoomsListViewState();
}

class _RoomsListViewState extends State<RoomsListView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bootstrapHomeData();
    });
  }

  Future<void> _bootstrapHomeData() async {
    final controller = context.read<TalqController>();

    if (controller.isLoading) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      return _bootstrapHomeData();
    }

    if (!controller.isInitialized) {
      await controller.initialize();
      if (!mounted) return;
    }

    await controller.fetchRooms();
    if (!mounted) return;

    if (controller.faqs.isEmpty) {
      await controller.fetchFaqs(reload: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TalqController>();
    final theme = controller.theme;
    final mediaQuery = MediaQuery.of(context);
    final headerHeight = mediaQuery.padding.top + 360;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: theme.backgroundColor,
        body: Stack(
          children: [
            _buildAmbientBackground(theme),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: headerHeight,
              child: _buildHeroHeader(context, controller, theme),
            ),
            Positioned.fill(
              top: mediaQuery.padding.top + 238,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  18,
                  14,
                  18,
                  mediaQuery.padding.bottom + 34,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 14),
                    StartConversationCard(theme: theme, controller: controller),
                    const SizedBox(height: 16),
                    _buildMessagesSection(context, theme, controller),
                    const SizedBox(height: 20),
                    FAQListSection(theme: theme),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmbientBackground(TalqTheme theme) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(theme.primaryColor, Colors.white, 0.86)!,
              theme.backgroundColor,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -130,
              right: -80,
              child: _buildAmbientBlob(
                color: Color.lerp(theme.primaryColor, Colors.white, 0.65)!,
                size: 250,
              ),
            ),
            Positioned(
              top: 220,
              left: -95,
              child: _buildAmbientBlob(
                color: Color.lerp(theme.primaryColor, Colors.white, 0.82)!,
                size: 210,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmbientBlob({required Color color, required double size}) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }

  Widget _buildHeroHeader(
    BuildContext context,
    TalqController controller,
    TalqTheme theme,
  ) {
    final mediaQuery = MediaQuery.of(context);
    final welcome = controller.workspace?.welcomeMessage;
    final hasWelcome = welcome != null && welcome.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(theme.primaryColor, Colors.black, 0.08)!,
            Color.lerp(theme.primaryColor, Colors.black, 0.34)!,
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(42),
          bottomRight: Radius.circular(42),
        ),
        boxShadow: [
          BoxShadow(
            color: Color.lerp(
              theme.primaryColor,
              Colors.black,
              0.45,
            )!.withValues(alpha: 0.24),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -50,
            child: _buildAmbientBlob(
              color: Colors.white.withValues(alpha: 0.14),
              size: 230,
            ),
          ),
          Positioned(
            bottom: -90,
            left: -30,
            child: _buildAmbientBlob(
              color: Colors.white.withValues(alpha: 0.09),
              size: 190,
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              top: mediaQuery.padding.top + 8,
              left: 20,
              right: 20,
              bottom: 30,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildWorkspaceBrand(controller),
                    Material(
                      color: Colors.white.withValues(alpha: 0.14),
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        customBorder: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 34),
                Text(
                  hasWelcome
                      ? welcome
                      : 'Hello there! How can we help you today?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 35,
                    fontWeight: FontWeight.w800,
                    height: 1.08,
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Ask a question, check previous chats, or browse quick answers.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceBrand(TalqController controller) {
    final logoUrl =
        controller.workspace?.talqLogoUrl ?? controller.workspace?.logoUrl;

    if (logoUrl != null) {
      return CachedNetworkImage(
        imageUrl: logoUrl,
        height: 36,
        errorWidget: (context, url, error) => SvgPicture.asset(
          'assets/images/monosend_logo.svg',
          package: 'talq_sdk',
          height: 36,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Icon(Icons.forum_rounded, color: Colors.white, size: 28),
        SizedBox(width: 10),
        Text(
          'Talq',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ),
      ],
    );
  }

  Widget _buildMessagesSection(
    BuildContext context,
    TalqTheme theme,
    TalqController controller,
  ) {
    final unreadTotal = controller.rooms.fold<int>(
      0,
      (sum, room) => sum + room.visitorUnreadCount,
    );

    final subtitle = unreadTotal > 0
        ? '$unreadTotal unread message${unreadTotal > 1 ? 's' : ''} waiting'
        : 'Continue previous conversations';

    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.8),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.cardShadowColor.withValues(alpha: 0.1),
            blurRadius: 18,
            offset: const Offset(0, 8),
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
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(theme.primaryColor, Colors.white, 0.15)!,
                        Color.lerp(theme.primaryColor, Colors.black, 0.18)!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: theme.primaryColor.withValues(alpha: 0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/icons/messages.svg',
                      package: 'talq_sdk',
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                      width: 22,
                      height: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Messages',
                        style: theme.titleStyle.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: theme.subtitleStyle.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: theme.subtitleStyle.color?.withValues(
                            alpha: 0.85,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (unreadTotal > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.unreadBadgeColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      unreadTotal > 99 ? '99+' : '$unreadTotal',
                      style: TextStyle(
                        color: theme.unreadTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: theme.subtitleStyle.color?.withValues(alpha: 0.42),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

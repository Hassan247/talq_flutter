import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/talq_controller.dart';
import '../theme/talq_theme.dart';
import 'chat_view.dart';
import 'shared_widgets.dart';

class StartConversationCard extends StatelessWidget {
  final TalqTheme theme;
  final TalqController controller;

  const StartConversationCard({
    super.key,
    required this.theme,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = controller.workspace != null;
    final primarySoft = Color.lerp(theme.primaryColor, Colors.white, 0.8)!;
    final agentAvatars = _resolveAgentAvatars();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primarySoft, Colors.white],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: theme.cardShadowColor.withValues(alpha: 0.1),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(1.2),
        decoration: BoxDecoration(
          color: theme.surfaceColor,
          borderRadius: BorderRadius.circular(27),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Start a conversation',
                    style: theme.titleStyle.copyWith(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: primarySoft.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: primarySoft.withValues(alpha: 0.9),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 90,
                    height: 40,
                    child: Stack(
                      children: [
                        _buildAvatarItem(
                          0,
                          imageUrl: agentAvatars.isNotEmpty
                              ? agentAvatars[0]
                              : null,
                          isFaded: agentAvatars.isEmpty,
                        ),
                        _buildAvatarItem(
                          22,
                          imageUrl: agentAvatars.length > 1
                              ? agentAvatars[1]
                              : null,
                          isFaded: agentAvatars.length < 2,
                        ),
                        _buildAvatarItem(
                          44,
                          imageUrl: agentAvatars.length > 2
                              ? agentAvatars[2]
                              : null,
                          isFaded: agentAvatars.length < 3,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _buildSupportTeamSection()),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Opacity(
              opacity: isEnabled ? 1 : 0.55,
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.primaryColor,
                        Color.lerp(theme.primaryColor, Colors.black, 0.2)!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: theme.primaryColor.withValues(alpha: 0.28),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: !isEnabled
                        ? null
                        : () {
                            controller.prepareNewConversation();
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (context.mounted) {
                                Navigator.push(
                                  context,
                                  TalqPageRoute(
                                    builder: (_) => TalqView(
                                      theme: theme,
                                      isNewConversation: true,
                                    ),
                                  ),
                                );
                              }
                            });
                          },
                    borderRadius: BorderRadius.circular(18),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Start new conversation',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                package: 'talq_flutter',
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _resolveAgentAvatars() {
    final workspaceAvatars =
        controller.workspace?.agentAvatars
            .where((url) => url.trim().isNotEmpty)
            .toList() ??
        [];
    if (workspaceAvatars.isNotEmpty) {
      return workspaceAvatars;
    }

    return controller.rooms
        .map((room) => room.assigneeAvatarUrl)
        .whereType<String>()
        .where((url) => url.trim().isNotEmpty)
        .toSet()
        .toList();
  }

  Widget _buildAvatarItem(
    double left, {
    String? imageUrl,
    bool isFaded = false,
  }) {
    return Positioned(
      left: left,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: theme.primaryColor.withValues(alpha: 0.14),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: TalqAvatar(
          imageUrl: imageUrl,
          senderType: SenderType.agent,
          radius: 17,
          isFaded: isFaded,
          theme: theme,
        ),
      ),
    );
  }

  static String formatReplyTime(String raw) {
    // Try to parse patterns like "8483 min", "45 sec", "2 min"
    final minMatch = RegExp(
      r'^(\d+)\s*min$',
      caseSensitive: false,
    ).firstMatch(raw);
    if (minMatch != null) {
      final minutes = int.parse(minMatch.group(1)!);
      if (minutes < 1) return 'A few seconds';
      if (minutes < 5) return 'A few minutes';
      if (minutes < 60) return 'Under an hour';
      if (minutes < 120) return 'About an hour';
      if (minutes < 360) return 'A few hours';
      if (minutes < 1440) return 'Under a day';
      if (minutes < 2880) return 'About a day';
      return 'A few days';
    }
    final secMatch = RegExp(
      r'^(\d+)\s*sec$',
      caseSensitive: false,
    ).firstMatch(raw);
    if (secMatch != null) {
      return 'A few minutes';
    }
    // Already human-readable or custom text — return as-is
    return raw;
  }

  Widget _buildSupportTeamSection() {
    final replyTime = (controller.workspace?.responseTime ?? '').trim();
    final displayReplyTime = replyTime.isNotEmpty
        ? formatReplyTime(replyTime)
        : 'A few minutes';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Typical reply time',
          style: theme.subtitleStyle.copyWith(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: theme.subtitleStyle.color?.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Icon(Icons.access_time_filled, size: 16, color: theme.primaryColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                displayReplyTime,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.titleStyle.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/models.dart';
import '../state/livechat_controller.dart';
import '../theme/livechat_theme.dart';
import 'chat_view.dart';
import 'shared_widgets.dart';

class StartConversationCard extends StatelessWidget {
  final LivechatTheme theme;
  final LivechatController controller;

  const StartConversationCard({
    super.key,
    required this.theme,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Start a conversation',
            style: theme.titleStyle.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 90,
                height: 40,
                child: Stack(
                  children: [
                    _buildAvatarItem(
                      0,
                      imageUrl:
                          controller.workspace?.agentAvatars.isNotEmpty == true
                          ? controller.workspace?.agentAvatars[0]
                          : null,
                      isFaded:
                          controller.workspace?.agentAvatars.isEmpty == true,
                    ),
                    _buildAvatarItem(
                      22,
                      imageUrl:
                          (controller.workspace?.agentAvatars.length ?? 0) > 1
                          ? controller.workspace?.agentAvatars[1]
                          : null,
                      isFaded:
                          (controller.workspace?.agentAvatars.length ?? 0) < 2,
                    ),
                    _buildAvatarItem(
                      44,
                      imageUrl:
                          (controller.workspace?.agentAvatars.length ?? 0) > 2
                          ? controller.workspace?.agentAvatars[2]
                          : null,
                      isFaded:
                          (controller.workspace?.agentAvatars.length ?? 0) < 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Expanded(child: _buildResponseTimeSection()),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: controller.workspace == null
                  ? null
                  : () {
                      controller.prepareNewConversation();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LivechatView(
                                theme: theme,
                                isNewConversation: true,
                              ),
                            ),
                          );
                        }
                      });
                    },
              style:
                  ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    shadowColor: theme.primaryColor.withOpacity(0.3),
                  ).copyWith(
                    elevation: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.pressed)) return 2;
                      return 0;
                    }),
                  ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/icons/send-message.svg',
                    package: 'livechat_sdk',
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                    width: 20,
                    height: 20,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Start new conversation',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: LivechatAvatar(
          imageUrl: imageUrl,
          senderType: SenderType.agent,
          radius: 17,
          isFaded: isFaded,
          theme: theme,
        ),
      ),
    );
  }

  Widget _buildResponseTimeSection() {
    if (controller.workspace?.showResponseTime != true) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Our usual reply time',
          style: theme.subtitleStyle.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.access_time_filled, size: 16, color: theme.primaryColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                controller.workspace?.responseTime ?? 'A few minutes',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.titleStyle.copyWith(fontSize: 14),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

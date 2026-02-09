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
        boxShadow: [
          BoxShadow(
            color: theme.cardShadowColor,
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
            style: theme.titleStyle.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Avatar Stack
              SizedBox(
                width: 98,
                height: 48,
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
                      25,
                      imageUrl:
                          (controller.workspace?.agentAvatars.length ?? 0) > 1
                          ? controller.workspace?.agentAvatars[1]
                          : null,
                      isFaded:
                          (controller.workspace?.agentAvatars.length ?? 0) < 2,
                    ),
                    _buildAvatarItem(
                      50,
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
              const SizedBox(width: 12),
              Expanded(child: _buildResponseTimeSection()),
            ],
          ),
          const SizedBox(height: 24),
          // CTA Button
          SizedBox(
            width: double.infinity,
            height: 54,
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
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/icons/send-icon.svg',
                    package: 'livechat_sdk',
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                    width: 18,
                    height: 18,
                  ),
                  const SizedBox(width: 12),
                  const Text(
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

  Widget _buildAvatarItem(
    double left, {
    String? imageUrl,
    bool isFaded = false,
  }) {
    return Positioned(
      left: left,
      child: LivechatAvatar(
        imageUrl: imageUrl,
        senderType: SenderType.agent,
        radius: 20,
        isFaded: isFaded,
        theme: theme,
        borderColor: Colors.white,
        borderWidth: 4,
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
            Icon(
              Icons.access_time_filled,
              size: 16,
              color: theme.titleStyle.color,
            ),
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

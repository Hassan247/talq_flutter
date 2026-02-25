import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../state/livechat_controller.dart';
import '../theme/livechat_theme.dart';
import 'faq_views.dart';

class FAQListSection extends StatelessWidget {
  final LivechatTheme theme;

  const FAQListSection({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Consumer<LivechatController>(
      builder: (context, controller, _) {
        final faqs = controller.faqs;
        if (faqs.isEmpty) {
          return const SizedBox.shrink();
        }
        final displayFaqs = faqs.take(4).toList();
        final hasMore = faqs.length > displayFaqs.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: theme.surfaceColor,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: theme.cardShadowColor.withOpacity(0.08),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.cardShadowColor.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Help & Resources',
                            style: theme.titleStyle.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                            ),
                          ),
                        ),
                        if (hasMore)
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FAQListView(theme: theme),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: theme.primaryColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                            ),
                            child: const Text(
                              'See all',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    indent: 18,
                    endIndent: 18,
                    color: theme.cardShadowColor.withOpacity(0.08),
                  ),
                  ...displayFaqs.asMap().entries.map((entry) {
                    final index = entry.key;
                    final faq = entry.value;
                    return Column(
                      children: [
                        if (index > 0)
                          Divider(
                            height: 1,
                            indent: 18,
                            endIndent: 18,
                            color: theme.cardShadowColor.withOpacity(0.08),
                          ),
                        _buildResourceItem(
                          context,
                          faq.question,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    FAQDetailView(faq: faq, theme: theme),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  }),
                  if (hasMore) ...[
                    Divider(
                      height: 1,
                      indent: 18,
                      endIndent: 18,
                      color: theme.cardShadowColor.withOpacity(0.08),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FAQListView(theme: theme),
                            ),
                          );
                        },
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(28),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Browse all articles',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: theme.primaryColor,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: theme.primaryColor.withOpacity(0.7),
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
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
    BuildContext context,
    String title, {
    VoidCallback? onTap,
  }) {
    final titleColor = theme.titleStyle.color ?? const Color(0xFF111827);
    final subtitleColor = theme.subtitleStyle.color ?? const Color(0xFF6B7280);
    final iconTint = Color.lerp(theme.primaryColor, Colors.white, 0.88)!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconTint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/icons/article.svg',
                    package: 'livechat_sdk',
                    colorFilter: ColorFilter.mode(
                      titleColor.withOpacity(0.72),
                      BlendMode.srcIn,
                    ),
                    width: 22,
                    height: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.bodyStyle.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: titleColor.withOpacity(0.93),
                    letterSpacing: -0.25,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: subtitleColor.withOpacity(0.4),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

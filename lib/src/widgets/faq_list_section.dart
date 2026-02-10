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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Help & Resources',
              style: theme.titleStyle.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
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
                          context,
                          faq.question,
                          Icons.description_outlined,
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
                        vertical: 10,
                      ),
                      title: Text(
                        'See more articles',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: theme.primaryColor,
                          letterSpacing: -0.2,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: theme.primaryColor.withOpacity(0.6),
                        size: 22,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FAQListView(theme: theme),
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
    BuildContext context,
    String title,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: SvgPicture.asset(
          'assets/icons/article.svg',
          package: 'livechat_sdk',
          colorFilter: ColorFilter.mode(
            theme.titleStyle.color!.withOpacity(0.7),
            BlendMode.srcIn,
          ),
          width: 20,
          height: 20,
        ),
      ),
      title: Text(
        title,
        style: theme.bodyStyle.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: theme.titleStyle.color?.withOpacity(0.9),
          letterSpacing: -0.2,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: theme.subtitleStyle.color?.withOpacity(0.3),
        size: 20,
      ),
      onTap: onTap,
    );
  }
}

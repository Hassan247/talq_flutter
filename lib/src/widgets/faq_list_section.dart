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
              style: theme.titleStyle.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: theme.surfaceColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: theme.cardShadowColor,
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
                      trailing: SvgPicture.asset(
                        'assets/icons/arrow-right.svg',
                        package: 'livechat_sdk',
                        colorFilter: const ColorFilter.mode(
                          Colors.grey,
                          BlendMode.srcIn,
                        ),
                        width: 14,
                        height: 14,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.avatarBackgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: SvgPicture.asset(
          'assets/icons/article.svg',
          package: 'livechat_sdk',
          colorFilter: ColorFilter.mode(
            theme.subtitleStyle.color!,
            BlendMode.srcIn,
          ),
          width: 20,
          height: 20,
        ),
      ),
      title: Text(
        title,
        style: theme.bodyStyle.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: SvgPicture.asset(
        'assets/icons/arrow-right.svg',
        package: 'livechat_sdk',
        colorFilter: ColorFilter.mode(theme.avatarIconColor, BlendMode.srcIn),
        width: 14,
        height: 14,
      ),
      onTap: onTap,
    );
  }
}

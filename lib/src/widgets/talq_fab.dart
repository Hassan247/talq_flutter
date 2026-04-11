import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/talq_controller.dart';
import '../theme/talq_theme.dart';
import 'rooms_list_view.dart';
import 'shared_widgets.dart';

class TalqFAB extends StatelessWidget {
  final TalqTheme theme;
  final Widget icon;

  const TalqFAB({
    super.key,
    this.theme = const TalqTheme(),
    this.icon = const Icon(Icons.chat_bubble, color: Colors.white),
  });

  @override
  Widget build(BuildContext context) {
    // Try to get theme from controller first for dynamic customization
    TalqTheme activeTheme = theme;
    int unreadCount = 0;
    try {
      final controller = context.watch<TalqController>();
      activeTheme = controller.theme;
      unreadCount = controller.totalUnreadCount;
    } catch (_) {
      // Fallback to widget.theme if Provider is not found
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        FloatingActionButton(
          onPressed: () {
            Navigator.of(context).push(
              TalqPageRoute(
                builder: (context) => RoomsListView(theme: activeTheme),
              ),
            );
          },
          backgroundColor: activeTheme.primaryColor,
          child: icon,
        ),
        if (unreadCount > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 2),
              ),
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              child: Center(
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

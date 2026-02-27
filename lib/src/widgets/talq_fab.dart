import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../state/talq_controller.dart';
import '../theme/talq_theme.dart';
import 'rooms_list_view.dart';

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
    try {
      final controller = context.watch<TalqController>();
      activeTheme = controller.theme;
    } catch (_) {
      // Fallback to widget.theme if Provider is not found
    }

    return FloatingActionButton(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => RoomsListView(theme: activeTheme),
          ),
        );
      },
      backgroundColor: activeTheme.primaryColor,
      child: icon,
    );
  }
}

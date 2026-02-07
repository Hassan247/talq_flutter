import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../state/livechat_controller.dart';
import '../theme/livechat_theme.dart';
import 'rooms_list_view.dart';

class LivechatFAB extends StatelessWidget {
  final LivechatTheme theme;
  final Widget icon;

  const LivechatFAB({
    super.key,
    this.theme = const LivechatTheme(),
    this.icon = const Icon(Icons.chat_bubble, color: Colors.white),
  });

  @override
  Widget build(BuildContext context) {
    // Try to get theme from controller first for dynamic customization
    LivechatTheme activeTheme = theme;
    try {
      final controller = context.watch<LivechatController>();
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

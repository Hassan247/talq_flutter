import 'package:flutter/material.dart';

import 'rooms_list_view.dart';

class LivechatFAB extends StatelessWidget {
  final Color backgroundColor;
  final Widget icon;

  const LivechatFAB({
    super.key,
    this.backgroundColor = Colors.blueAccent,
    this.icon = const Icon(Icons.chat_bubble, color: Colors.white),
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => RoomsListView(primaryColor: backgroundColor),
          ),
        );
      },
      backgroundColor: backgroundColor,
      child: icon,
    );
  }
}

import 'package:flutter/material.dart';
import 'chat_view.dart';

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
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => const LivechatView()));
      },
      backgroundColor: backgroundColor,
      child: icon,
    );
  }
}

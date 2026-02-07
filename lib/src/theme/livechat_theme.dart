import 'package:flutter/material.dart';

class LivechatTheme {
  final Color primaryColor;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color darkHeaderColor;

  // Bubbles
  final Color userBubbleColor;
  final Color agentBubbleColor;
  final Color userTextColor;
  final Color agentTextColor;

  // Ticks/Status
  final Color sentTickColor;
  final Color deliveredTickColor;
  final Color readTickColor;

  // Typography
  final TextStyle titleStyle;
  final TextStyle subtitleStyle;
  final TextStyle bodyStyle;
  final TextStyle timestampStyle;

  // Shapes
  final double borderRadius;

  const LivechatTheme({
    this.primaryColor = Colors.blueAccent,
    this.backgroundColor = const Color(0xFFF5F7FA),
    this.surfaceColor = Colors.white,
    this.darkHeaderColor = const Color(0xFF151515),
    this.userBubbleColor = const Color(0xFF151515),
    this.agentBubbleColor = Colors.white,
    this.userTextColor = Colors.white,
    this.agentTextColor = Colors.black87,
    this.sentTickColor = Colors.grey,
    this.deliveredTickColor = Colors.grey,
    this.readTickColor = Colors.blue,
    this.titleStyle = const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: Colors.black,
    ),
    this.subtitleStyle = const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.normal,
      color: Color(0xFF757575), // Colors.grey[600]
    ),
    this.bodyStyle = const TextStyle(
      fontSize: 15,
      height: 1.4,
      color: Colors.black87,
    ),
    this.timestampStyle = const TextStyle(fontSize: 10),
    this.borderRadius = 20.0,
  });

  factory LivechatTheme.light() => const LivechatTheme();

  factory LivechatTheme.dark() => const LivechatTheme(
    backgroundColor: Color(0xFF121212),
    surfaceColor: Color(0xFF1E1E1E),
    darkHeaderColor: Color(0xFF000000),
    agentBubbleColor: Color(0xFF2C2C2C),
    agentTextColor: Colors.white,
    titleStyle: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
    subtitleStyle: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.normal,
      color: Color(0xFFAAAAAA),
    ),
  );

  LivechatTheme copyWith({
    Color? primaryColor,
    Color? backgroundColor,
    Color? surfaceColor,
    Color? darkHeaderColor,
    Color? userBubbleColor,
    Color? agentBubbleColor,
    Color? userTextColor,
    Color? agentTextColor,
    Color? sentTickColor,
    Color? deliveredTickColor,
    Color? readTickColor,
    TextStyle? titleStyle,
    TextStyle? subtitleStyle,
    TextStyle? bodyStyle,
    TextStyle? timestampStyle,
    double? borderRadius,
  }) {
    return LivechatTheme(
      primaryColor: primaryColor ?? this.primaryColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      darkHeaderColor: darkHeaderColor ?? this.darkHeaderColor,
      userBubbleColor: userBubbleColor ?? this.userBubbleColor,
      agentBubbleColor: agentBubbleColor ?? this.agentBubbleColor,
      userTextColor: userTextColor ?? this.userTextColor,
      agentTextColor: agentTextColor ?? this.agentTextColor,
      sentTickColor: sentTickColor ?? this.sentTickColor,
      deliveredTickColor: deliveredTickColor ?? this.deliveredTickColor,
      readTickColor: readTickColor ?? this.readTickColor,
      titleStyle: titleStyle ?? this.titleStyle,
      subtitleStyle: subtitleStyle ?? this.subtitleStyle,
      bodyStyle: bodyStyle ?? this.bodyStyle,
      timestampStyle: timestampStyle ?? this.timestampStyle,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }

  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
